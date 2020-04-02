#import <Cocoa/Cocoa.h>

@class WebViewController;
@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) WebViewController *mainWebViewController;
@property (nonatomic, strong) WebViewController *composeWebViewController;

@property (nonatomic, strong) NSString* fastmailURL;
@property (nonatomic, strong) NSString* fastmailTitle;

- (void)evaluateJavaScript:(NSString *)scriptString;

@end
