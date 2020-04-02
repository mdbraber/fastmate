#import "FastmateScriptCommand.h"
#import "AppDelegate.h"

@implementation FastmateScriptCommand

- (id)performDefaultImplementation
{
    AppDelegate *delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    
    // get the arguments
    NSDictionary *args = [self evaluatedArguments];
    NSString *stringToEvaluate = @"";
    if(args.count) {
        stringToEvaluate = [args valueForKey:@""];    // get the direct argument
    } else {
        // raise error
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:@"Error: provide a string/command to evalauate"];
    }
    // Implement your code logic (in this example, I'm just posting an internal notification)
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"AppShouldLookupStringNotification" object:stringToSearch];
    
    [delegate evaluateJavaScript:stringToEvaluate];
    return nil;
}

@end
