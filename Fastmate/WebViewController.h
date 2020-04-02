#import <Cocoa/Cocoa.h>

@class WKWebView;

@interface WebViewController : NSViewController

@property (nonatomic, readonly) WKWebView *webView;
@property (nonatomic, strong) NSURL *baseURL;
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *mailboxes; // Name -> unreadCount

- (void)configureUserContentController;
- (void)composeNewEmail;
- (void)focusSearchField;
- (void)handleMailtoURL:(NSURL *)URL;
- (void)handleNotificationClickWithIdentifier:(NSString *)identifier;
- (void)reload;
- (void)queryToolbarColor;

@end
