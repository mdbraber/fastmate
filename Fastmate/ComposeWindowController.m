#import "ComposeWindowController.h"
#import "ComposeViewController.h"
#import "AppDelegate.h"
@import WebKit;

@interface ComposeWindowController () <NSWindowDelegate>

@end

@implementation ComposeWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    NSColor *windowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[NSUserDefaults.standardUserDefaults dataForKey:@"lastUsedWindowColor"]];
    self.window.backgroundColor = windowColor ?: [NSColor colorWithRed:0.27 green:0.34 blue:0.49 alpha:1.0];
    
    // Fixes that we can't trust that the main window exists in applicationDidFinishLaunching:.
    // Here we always know that this content view controller will be the main web view controller,
    // so inform the app delegate
    AppDelegate *appDelegate = (AppDelegate *)NSApplication.sharedApplication.delegate;
    appDelegate.composeWebViewController = (ComposeViewController *)self.contentViewController;
    
    NSString *lastWindowFrame = [NSUserDefaults.standardUserDefaults objectForKey:@"composeWindowFrame"];
    if (lastWindowFrame) {
        NSRect frame = NSRectFromString(lastWindowFrame);
        [self.window setFrame:frame display:NO];
    }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    return YES;
}

- (void)windowDidResize:(NSNotification *)notification {
    if (self.windowLoaded) {
        [NSUserDefaults.standardUserDefaults setObject:NSStringFromRect(self.window.frame) forKey:@"composeWindowFrame"];
    }
}

@end
