#import "AppDelegate.h"
#import "WebViewController.h"
#import "UnreadCountObserver.h"
#import "VersionChecker.h"
#import "PrintManager.h"
@import WebKit;

@interface AppDelegate () <VersionCheckerDelegate, NSUserNotificationCenterDelegate>

@property (nonatomic, strong) UnreadCountObserver *unreadCountObserver;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, assign) BOOL isAutomaticUpdateCheck;

@end

@implementation AppDelegate

@synthesize fastmailTitle;
@synthesize fastmailURL;

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    NSColor *windowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[NSUserDefaults.standardUserDefaults dataForKey:@"lastUsedWindowColor"]];
    NSApplication.sharedApplication.mainWindow.backgroundColor = windowColor ?: [NSColor colorWithRed:0.27 green:0.34 blue:0.49 alpha:1.0];
    
    [self updateStatusItemVisibility];
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:@"shouldShowStatusBarIcon" options:0 context:nil];
    [NSUserNotificationCenter.defaultUserNotificationCenter setDelegate:self];

    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(workspaceDidWake:) name:NSWorkspaceDidWakeNotification object:NULL];
}

- (void)workspaceDidWake:(NSNotification *)notification {
    [self.mainWebViewController reload];
}

- (void)setMainWebViewController:(WebViewController *)mainWebViewController {
    _mainWebViewController = mainWebViewController;
    self.unreadCountObserver.webViewController = mainWebViewController;
}

- (void)setComposeWebViewController:(WebViewController *)composeWebViewController {
    _composeWebViewController = composeWebViewController;
}

- (UnreadCountObserver *)unreadCountObserver {
    if (_unreadCountObserver == nil) {
        _unreadCountObserver = [UnreadCountObserver new];
    }
    return _unreadCountObserver;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"automaticUpdateChecks": @YES, @"shouldShowUnreadMailIndicator": @YES, @"shouldShowUnreadMailInDock": @YES, @"shouldShowUnreadMailCountInDock": @YES, @"shouldUseFastmailBeta": @NO, @"shouldColorizeMessageItems": @NO}];
    [self performAutomaticUpdateCheckIfNeeded];
}

- (void)dealloc {
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:@"shouldShowStatusBarIcon"];
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSAppleEventDescriptor *directObjectDescriptor = [event paramDescriptorForKeyword:keyDirectObject];
    NSURL *eventURL = [NSURL URLWithString:directObjectDescriptor.stringValue];
    if ([eventURL.scheme isEqualToString:@"mailto"]) {
        [self.mainWebViewController handleMailtoURL:eventURL];
    } else if ([eventURL.host hasSuffix:@".fastmail.com"] && [eventURL.path hasPrefix:@"/mail"]) {
        [self.mainWebViewController.webView loadRequest:[NSURLRequest requestWithURL:eventURL]];
    }
}

- (IBAction)newDocument:(id)sender {
    [self.mainWebViewController composeNewEmail];
}
 
- (IBAction)performFindPanelAction:(id)sender {
    [self.mainWebViewController focusSearchField];
}

- (IBAction)print:(id)sender {
    [[PrintManager sharedInstance] printWebView:self.mainWebViewController.webView];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == NSUserDefaults.standardUserDefaults && [keyPath isEqualToString:@"shouldShowStatusBarIcon"]) {
        [self updateStatusItemVisibility];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateStatusItemVisibility {
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"shouldShowStatusBarIcon"]) {
        self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        self.statusItem.target = self;
        self.statusItem.action = @selector(statusItemSelected:);
        self.unreadCountObserver.statusItem = self.statusItem;
    } else {
        [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
    }
}

- (void)statusItemSelected:(id)sender {
    [NSApp unhide:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

- (NSString *)fastmailURL {
    return [self.mainWebViewController.webView URL].absoluteString;
}

- (NSString *)fastmailTitle {
    return [self.mainWebViewController.webView title];
}

- (void)evaluateJavaScript:(NSString *)scriptString {
    [self.mainWebViewController.webView evaluateJavaScript:scriptString completionHandler:^(id response, NSError *error) {
        if (error != nil) {
            NSLog(@"Error evaluating JavaScript: %@", error);
        }
    }];
}
    
- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
    NSSet *keySet = [NSSet setWithObjects:@"fastmailURL",@"fastmailTitle",nil];
    return [keySet containsObject:key];
}

#pragma mark - Version checking

- (void)performAutomaticUpdateCheckIfNeeded {
    BOOL automaticUpdatesEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"automaticUpdateChecks"];
    if (!automaticUpdatesEnabled) {
        return;
    }

    NSDate *lastUpdateCheckDate = VersionChecker.sharedInstance.lastUpdateCheckDate;
    NSDateComponents *components = [NSCalendar.currentCalendar components:NSCalendarUnitDay fromDate:lastUpdateCheckDate toDate:NSDate.date options:0];
    if (components.day >= 7) {
        self.isAutomaticUpdateCheck = YES;
        [self checkForUpdates];
    }
}

- (IBAction)checkForUpdates:(id)sender {
    self.isAutomaticUpdateCheck = NO;
    [self checkForUpdates];
}

- (void)checkForUpdates {
    VersionChecker.sharedInstance.delegate = self;
    [VersionChecker.sharedInstance checkForUpdates];
}

- (void)versionCheckerDidFindNewVersion:(NSString *)latestVersion withURL:(NSURL *)latestVersionURL {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Take me there!"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.messageText = [NSString stringWithFormat:@"New version available: %@", latestVersion];
    alert.informativeText = [NSString stringWithFormat:@"You're currently at v%@", [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    alert.alertStyle = NSAlertStyleInformational;
    alert.showsSuppressionButton = self.isAutomaticUpdateCheck;
    alert.suppressionButton.title = @"Don't check for new versions automatically";
    [alert beginSheetModalForWindow:self.mainWebViewController.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [NSWorkspace.sharedWorkspace openURL:latestVersionURL];
        }

        if (alert.suppressionButton.state == NSOnState) {
            [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"automaticUpdateChecks"];
        }
    }];
}

- (void)versionCheckerDidNotFindNewVersion {
    if (!self.isAutomaticUpdateCheck) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Nice!"];
        [alert setMessageText:@"Up to date!"];
        [alert setInformativeText:[NSString stringWithFormat:@"You're on the latest version. (v%@)", [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert beginSheetModalForWindow:self.mainWebViewController.view.window completionHandler:nil];
    }
}

#pragma mark - Notification handling

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [self.mainWebViewController handleNotificationClickWithIdentifier:notification.identifier];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

@end
