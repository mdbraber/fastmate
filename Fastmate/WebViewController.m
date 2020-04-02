#import "WebViewController.h"
#import "PrintManager.h"
@import WebKit;

@interface WebViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKWebView *temporaryWebView;
@property (nonatomic, strong) WKUserContentController *userContentController;

@end

static NSString * const ShouldUseFastmailBetaUserDefaultsKey = @"shouldUseFastmailBeta";
static NSString * const ShouldColorizeMessageItemsUserDefaultsKey = @"shouldColorizeMessageItems";

@implementation WebViewController

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
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:self.baseURL]];
    [self addObserver:self forKeyPath:@"webView.URL" options:NSKeyValueObservingOptionNew context:nil];
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:ShouldUseFastmailBetaUserDefaultsKey options:NSKeyValueObservingOptionNew context:nil];
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:ShouldColorizeMessageItemsUserDefaultsKey options:NSKeyValueObservingOptionNew context:nil];
}

- (void)reload {
    [self.webView reload];
}

- (NSURL *)baseURL {
    BOOL shouldUseFastmailBeta = [NSUserDefaults.standardUserDefaults boolForKey:ShouldUseFastmailBetaUserDefaultsKey];
    return shouldUseFastmailBeta ? [NSURL URLWithString:@"https://beta.fastmail.com"] : [NSURL URLWithString:@"https://www.fastmail.com"];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"webView.URL"];
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:ShouldUseFastmailBetaUserDefaultsKey];
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:ShouldColorizeMessageItemsUserDefaultsKey];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (webView == self.temporaryWebView) {
        // A temporary web view means we caught a link URL which we want to open externally
        [NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL];
        decisionHandler(WKNavigationActionPolicyCancel);
        self.temporaryWebView = nil;
    } else if ([navigationAction.request.URL.host hasSuffix:@".fastmailusercontent.com"]) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:navigationAction.request.URL resolvingAgainstBaseURL:NO];
        BOOL shouldDownload = [components.queryItems indexOfObjectPassingTest:^BOOL(NSURLQueryItem *item, NSUInteger index, BOOL *stop) {
            return [item.name isEqualToString:@"download"] && [item.value isEqualToString:@"1"];
        }] != NSNotFound;
        if (shouldDownload || ![components.path.lastPathComponent hasSuffix:@".pdf"]) {
            //[NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL];
            [self downloadFileFromURL:navigationAction.request.URL completion:^(NSString *filepath) {}];
            decisionHandler(WKNavigationActionPolicyCancel);
        } else {
            decisionHandler(WKNavigationActionPolicyAllow);
        }
    } else if (!([navigationAction.request.URL.host hasSuffix:@".fastmail.com"])) {
        // Link isn't within fastmail.com, open externally
        [NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;
    NSArray *cookies =[NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:response.URL];

    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }

    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)downloadFileFromURL:(NSURL *)url completion:(void (^)(NSString *filepath))completion {
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";

    NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                    NSString *downloadsDir = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) firstObject];
                    NSString *downloadsPath = [downloadsDir stringByAppendingPathComponent:response.suggestedFilename];
                    
                    NSFileManager *fileManager = [NSFileManager defaultManager];
                    if (![fileManager fileExistsAtPath:downloadsPath]) {
                        [data writeToFile:downloadsPath atomically:YES];
                    } else {
                        NSError *err = nil;
                        NSDate *now = [NSDate date];
                        NSDictionary *modificationDateAttr = [NSDictionary dictionaryWithObjectsAndKeys: now, NSFileModificationDate, nil];
                        [fileManager setAttributes:modificationDateAttr ofItemAtPath:downloadsPath error:&err];
                        if(err != nil) {
                            NSLog(@"Error downloading file %@=", err);
                         }
                        //NSLog(@"Updated file: %@", downloadsPath);
                    }
                    
                    //NSLog(@"Downloaded file to: %@",downloadsPath);
                    NSSet *extSet = [NSSet setWithObjects:@"doc",@"docx",@"ppt",@"pptx",@"xls",@"xlsx",@"pdf",@"png",@"jpg",nil];
                    if ([extSet containsObject:downloadsPath.pathExtension]) {
                        [NSWorkspace.sharedWorkspace openFile:downloadsPath];
                    }
                    
                    completion(downloadsPath);
                });
            }
            else {
                NSLog(@"ERROR: %@",error);
                completion([NSString string]);
            }
    }];
    [postDataTask resume];
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    self.temporaryWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.temporaryWebView.navigationDelegate = self;
    return self.temporaryWebView;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self && [keyPath isEqualToString:@"webView.URL"]) {
        [self webViewDidChangeURL:change[NSKeyValueChangeNewKey]];
    } else if (object == NSUserDefaults.standardUserDefaults && [keyPath isEqualToString:ShouldColorizeMessageItemsUserDefaultsKey]) {
        NSString *evalJS = [NSString stringWithFormat:@"Fastmate.setColorizeMessageItems(%@);", change[NSKeyValueChangeNewKey]];
        [self.webView evaluateJavaScript:evalJS completionHandler:nil];
    } else if (object == NSUserDefaults.standardUserDefaults && [keyPath isEqualToString:ShouldUseFastmailBetaUserDefaultsKey]) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.baseURL]];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)webViewDidChangeURL:(NSURL *)newURL {
    [self queryToolbarColor];
    [self adjustV67Width];
    [self updateStylesheet];
    [self colorizeMessageItems];
    [self addLabelShortcuts];
}

- (void)composeNewEmail {
    [self.webView evaluateJavaScript:@"Fastmate.compose()" completionHandler:nil];
}

- (void)focusSearchField {
    [self.webView evaluateJavaScript:@"Fastmate.focusSearch()" completionHandler:nil];
}

- (void)queryToolbarColor {
    [self.webView evaluateJavaScript:@"Fastmate.getToolbarColor()" completionHandler:^(id response, NSError *error) {
        NSString *colorString = [response isKindOfClass:NSString.class] ? response : nil;
        if (colorString) {
            colorString = [colorString stringByReplacingOccurrencesOfString:@"rgb(" withString:@""];
            colorString = [colorString stringByReplacingOccurrencesOfString:@")" withString:@""];
            NSArray<NSString *> *components = [colorString componentsSeparatedByString:@","];
            NSInteger red = components[0].integerValue;
            NSInteger green = components[1].integerValue;
            NSInteger blue = components[2].integerValue;
            NSColor *color = [NSColor colorWithRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:1.0];
            [self setWindowBackgroundColor:color];
        }
    }];
}

- (void)updateStylesheet {
    BOOL shouldColorizeMessageItems = [NSUserDefaults.standardUserDefaults boolForKey:ShouldColorizeMessageItemsUserDefaultsKey];
    //shouldColorizeMessageItems = YES;
    if (shouldColorizeMessageItems) {
        [self.webView evaluateJavaScript:@"Fastmate.updateStylesheet()" completionHandler:nil];
    }
}

- (void)colorizeMessageItems {
    BOOL shouldColorizeMessageItems = [NSUserDefaults.standardUserDefaults boolForKey:ShouldColorizeMessageItemsUserDefaultsKey];
    //shouldColorizeMessageItems = YES;
    if (shouldColorizeMessageItems) {
        [self.webView evaluateJavaScript:@"Fastmate.colorizeMessageItems()" completionHandler:nil];
    }
}

- (void)addLabelShortcuts {
    [self.webView evaluateJavaScript:@"Fastmate.addLabelShortcuts()" completionHandler:nil];
}

- (void)adjustV67Width {
    [self.webView evaluateJavaScript:@"Fastmate.adjustV67Width()" completionHandler:nil];
}

- (void)updateUnreadCounts {
    [self.webView evaluateJavaScript:@"Fastmate.getMailboxUnreadCounts()" completionHandler:^(id response, NSError *error) {
        if (![response isKindOfClass:[NSDictionary class]]) {
            self.mailboxes = nil;
            return;
        }
        self.mailboxes = response;
    }];
}

- (void)setWindowBackgroundColor:(NSColor *)color {
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
    [NSUserDefaults.standardUserDefaults setObject:colorData forKey:@"lastUsedWindowColor"];
    self.view.window.backgroundColor = color;
}

- (void)handleMailtoURL:(NSURL *)URL {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self.baseURL resolvingAgainstBaseURL:NO];
    components.path = @"/action/compose/";
    NSString *mailtoString = [URL.absoluteString stringByReplacingOccurrencesOfString:@"mailto:" withString:@""];
    components.percentEncodedQueryItems = @[[NSURLQueryItem queryItemWithName:@"mailto" value:mailtoString]];
    NSURL *actionURL = components.URL;
    [self.webView loadRequest:[NSURLRequest requestWithURL:actionURL]];
}

- (void)configureUserContentController {
    self.userContentController = [WKUserContentController new];
    [self.userContentController addScriptMessageHandler:self name:@"Fastmate"];

    NSString *FastmateSource = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"Fastmate" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *FastmateScript = [[WKUserScript alloc] initWithSource:FastmateSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [self.userContentController addUserScript:FastmateScript];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isEqualToString:@"documentDidChange"]) {
        [self queryToolbarColor];
        [self updateUnreadCounts];
        [self colorizeMessageItems];
    } else if ([message.body isEqualToString:@"print"]) {
        [PrintManager.sharedInstance printWebView:self.webView];
    } else {
        [self postNotificationForMessage:message];
    }
}

- (void)postNotificationForMessage:(WKScriptMessage *)message {
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[message.body dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

    NSUserNotification *notification = [NSUserNotification new];
    notification.identifier = [dictionary[@"notificationID"] stringValue];
    notification.title = dictionary[@"title"];
    notification.subtitle = [dictionary valueForKeyPath:@"options.body"];
    notification.soundName = NSUserNotificationDefaultSoundName;

    [NSUserNotificationCenter.defaultUserNotificationCenter deliverNotification:notification];
}

- (void)handleNotificationClickWithIdentifier:(NSString *)identifier {
    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"Fastmate.handleNotificationClick(\"%@\")", identifier] completionHandler:nil];
}

- (void)webView:(WKWebView *)webView runOpenPanelWithParameters:(WKOpenPanelParameters *)parameters initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSArray<NSURL *> *URLs))completionHandler {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    if (@available(macOS 10.13.4, *)) {
        panel.canChooseDirectories = parameters.allowsDirectories;
    } else {
        panel.canChooseDirectories = NO;
    }
    panel.allowsMultipleSelection = parameters.allowsMultipleSelection;
    panel.canCreateDirectories = NO;
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        completionHandler(result == NSModalResponseOK ? panel.URLs : nil);
    }];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    NSAlert *alert = [NSAlert new];
    alert.messageText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleInformational;
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler(returnCode == NSAlertFirstButtonReturn);
    }];
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    NSAlert *alert = [NSAlert new];
    alert.messageText = message;
    [alert addButtonWithTitle:@"OK"];
    alert.alertStyle = NSAlertStyleInformational;
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler();
    }];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))completionHandler {
    NSAlert *alert = [NSAlert new];
    alert.messageText = prompt;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleInformational;
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    textField.stringValue = defaultText;
    [alert setAccessoryView:textField];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler(returnCode == NSAlertFirstButtonReturn ? textField.stringValue : defaultText);
    }];
}

@end
