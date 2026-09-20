#import "EOProbe.h"
#import "EOOverlayView.h"
#import "EORuntimeInspector.h"

@implementation EOProbe
+ (void)start {
    [[EOOverlayView shared] installWhenReady];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"?";
        if (![bundle isEqualToString:@"com.eoservices.eobrokerios"]) {
            [[EOOverlayView shared] setStatus:@"Wrong target bundle"];
            [[EOOverlayView shared] setDetail:bundle];
            return;
        }
        [[EOOverlayView shared] setStatus:@"EO Broker detected ✓"];
        [[EOOverlayView shared] setDetail:[EORuntimeInspector summary]];
        NSLog(@"[EOSignal] %@", [EORuntimeInspector summary]);
    });
}
@end
