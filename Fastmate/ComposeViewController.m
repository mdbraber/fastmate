#import "ComposeViewController.h"
#import "AppDelegate.h"
@import WebKit;

@interface ComposeViewController () <WKNavigationDelegate, WKUIDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKWebView *temporaryWebView;
@property (nonatomic, strong) WKUserContentController *userContentController;

@end

static NSString * const ShouldUseFastmailBetaUserDefaultsKey = @"shouldUseFastmailBeta";

@implementation ComposeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureUserContentController];

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.applicationNameForUserAgent = @"Fastmate";
    configuration.userContentController = self.userContentController;

    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    [self.view addSubview:self.webView];
    
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:ShouldUseFastmailBetaUserDefaultsKey options:NSKeyValueObservingOptionNew context:nil];
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self.baseURL resolvingAgainstBaseURL:NO];
    components.path = @"/mail/compose";    
    [self.webView loadRequest:[NSURLRequest requestWithURL:components.URL]];
    
    [self addObserver:self forKeyPath:@"webView.URL" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)webViewDidChangeURL:(NSURL *)newURL {
    
    [self queryToolbarColor];
    [self hideSidebar];
    
    if(![self.webView.URL.path hasPrefix:@"/mail/compose"]) {
        NSWindow *composeWindow = [NSApplication.sharedApplication.windows objectAtIndex:1];
        [composeWindow close];
    }
}

- (void)hideSidebar {
    [self.webView evaluateJavaScript:@"Fastmate.hideSidebar()" completionHandler:nil];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isEqualToString:@"documentDidChange"]) {
        [self queryToolbarColor];
        [self hideSidebar];
    }
}


@end
