//
//  SVWebViewController.m
//
//  Created by Sam Vermette on 08.11.10.
//  Copyright 2010 Sam Vermette. All rights reserved.
//
//  https://github.com/samvermette/SVWebViewController

#import <WebKit/WebKit.h>

#import "SVWebViewControllerActivityChrome.h"
#import "SVWebViewControllerActivitySafari.h"
#import "SVWebViewController.h"

@interface SVWebViewController () <UIWebViewDelegate, WKNavigationDelegate>

@property (nonatomic, strong) UIBarButtonItem *backBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *forwardBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *refreshBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *stopBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *actionBarButtonItem;

@property (nonatomic, strong) WKWebView* wkWebView; // Will use a WebKit WebView if available (iOS8+)

@property (nonatomic, strong) NSURLRequest *request;

@end


@implementation SVWebViewController

#pragma mark - Initialization

- (void)dealloc
{
    [self.wkWebView stopLoading];
    self.wkWebView = nil;
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (instancetype)initWithAddress:(NSString *)urlString {
    return [self initWithURL:[NSURL URLWithString:urlString]];
}

- (instancetype)initWithURL:(NSURL*)pageURL {
    return [self initWithURLRequest:[NSURLRequest requestWithURL:pageURL]];
}

- (instancetype)initWithURLRequest:(NSURLRequest*)request {
    self = [super init];
    if (self) {
        self.request = request;
    }
    return self;
}

- (void)loadRequest:(NSURLRequest*)request
{
    [self.wkWebView loadRequest:request];
}

#pragma mark - View lifecycle

- (void)loadView
{
    self.view = self.wkWebView;
    [self loadRequest:self.request];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateToolbarItems];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    self.wkWebView = nil;
    
    _backBarButtonItem = nil;
    _forwardBarButtonItem = nil;
    _refreshBarButtonItem = nil;
    _stopBarButtonItem = nil;
    _actionBarButtonItem = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    NSAssert(self.navigationController, @"SVWebViewController needs to be contained in a UINavigationController. If you are presenting SVWebViewController modally, use SVModalWebViewController instead.");
    
    [super viewWillAppear:animated];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController setToolbarHidden:NO animated:animated];
    }
    else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return YES;
    
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - Getters

- (WKWebView*)wkWebView
{
    if (!_wkWebView)
    {
        if ([WKWebView class])
        {
            _wkWebView = [[WKWebView alloc] initWithFrame:[UIScreen mainScreen].bounds];
            _wkWebView.navigationDelegate = self;
        }
    }
    
    return _wkWebView;
}

- (UIBarButtonItem *)backBarButtonItem {
    if (!_backBarButtonItem) {
        _backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"SVWebViewController.bundle/SVWebViewControllerBack"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(goBackTapped:)];
        _backBarButtonItem.width = 18.0f;
    }
    return _backBarButtonItem;
}

- (UIBarButtonItem *)forwardBarButtonItem {
    if (!_forwardBarButtonItem) {
        _forwardBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"SVWebViewController.bundle/SVWebViewControllerNext"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(goForwardTapped:)];
        _forwardBarButtonItem.width = 18.0f;
    }
    return _forwardBarButtonItem;
}

- (UIBarButtonItem *)refreshBarButtonItem {
    if (!_refreshBarButtonItem) {
        _refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadTapped:)];
    }
    return _refreshBarButtonItem;
}

- (UIBarButtonItem *)stopBarButtonItem {
    if (!_stopBarButtonItem) {
        _stopBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopTapped:)];
    }
    return _stopBarButtonItem;
}

- (UIBarButtonItem *)actionBarButtonItem {
    if (!_actionBarButtonItem) {
        _actionBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonTapped:)];
    }
    return _actionBarButtonItem;
}

#pragma mark - Toolbar

- (void)updateToolbarItems
{
    self.backBarButtonItem.enabled = self.wkWebView.canGoBack;
    self.forwardBarButtonItem.enabled = self.wkWebView.canGoForward;
    
    BOOL isLoading = self.wkWebView.isLoading;
    self.actionBarButtonItem.enabled = !isLoading;
    
    UIBarButtonItem *refreshStopBarButtonItem = isLoading ? self.stopBarButtonItem : self.refreshBarButtonItem;
    
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        CGFloat toolbarWidth = 250.0f;
        fixedSpace.width = 35.0f;
        
        NSArray *items = [NSArray arrayWithObjects:
                          fixedSpace,
                          refreshStopBarButtonItem,
                          fixedSpace,
                          self.backBarButtonItem,
                          fixedSpace,
                          self.forwardBarButtonItem,
                          fixedSpace,
                          self.actionBarButtonItem,
                          nil];
        
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, toolbarWidth, 44.0f)];
        toolbar.items = items;
        toolbar.barStyle = self.navigationController.navigationBar.barStyle;
        toolbar.tintColor = self.navigationController.navigationBar.tintColor;
        self.navigationItem.rightBarButtonItems = items.reverseObjectEnumerator.allObjects;
    }
    
    else {
        NSArray *items = [NSArray arrayWithObjects:
                          fixedSpace,
                          self.backBarButtonItem,
                          flexibleSpace,
                          self.forwardBarButtonItem,
                          flexibleSpace,
                          refreshStopBarButtonItem,
                          flexibleSpace,
                          self.actionBarButtonItem,
                          fixedSpace,
                          nil];
        
        self.navigationController.toolbar.barStyle = self.navigationController.navigationBar.barStyle;
        self.navigationController.toolbar.tintColor = self.navigationController.navigationBar.tintColor;
        self.toolbarItems = items;
    }
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self updateToolbarItems];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    self.navigationItem.title = webView.title;
    [self updateToolbarItems];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self updateToolbarItems];
}

#pragma mark - Target actions

- (void)goBackTapped:(UIBarButtonItem *)sender
{
    [self.wkWebView goBack];
}

- (void)goForwardTapped:(UIBarButtonItem *)sender
{
    [self.wkWebView goForward];
}

- (void)reloadTapped:(UIBarButtonItem *)sender
{
    [self.wkWebView reload];
}

- (void)stopTapped:(UIBarButtonItem *)sender
{
    [self.wkWebView stopLoading];
    
    [self updateToolbarItems];
}

- (void)actionButtonTapped:(id)sender
{
    // Can't see the request URL in the wkWebView and this code will fall down to self.request.URL for iOS8 so should be ok
    NSURL *url = self.request.URL;
    if (url != nil) {
        NSArray *activities = @[[SVWebViewControllerActivitySafari new], [SVWebViewControllerActivityChrome new]];
        
        if ([[url absoluteString] hasPrefix:@"file:///"]) {
            UIDocumentInteractionController *dc = [UIDocumentInteractionController interactionControllerWithURL:url];
            [dc presentOptionsMenuFromRect:self.view.bounds inView:self.view animated:YES];
        } else {
            UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:activities];
            
#ifdef __IPHONE_8_0
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1 &&
                UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            {
                UIPopoverPresentationController *ctrl = activityController.popoverPresentationController;
                ctrl.sourceView = self.view;
                ctrl.barButtonItem = sender;
            }
#endif
            
            [self presentViewController:activityController animated:YES completion:nil];
        }
    }
}

- (void)doneButtonTapped:(id)sùender {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
