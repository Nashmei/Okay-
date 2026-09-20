#import "EOProbe.h"
#import "EOOverlayView.h"
#import "EORuntimeInspector.h"

@implementation EOProbe

+ (void)start {
    EOOverlayView *overlay = [EOOverlayView shared];
    [overlay installWhenReady];
    [overlay setStatus:@"Probe v2 starting…"];
    [overlay setDetail:@"Mapping market runtime…"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"?";
        if (![bundle isEqualToString:@"com.eoservices.eobrokerios"]) {
            [overlay setStatus:@"Wrong target"];
            [overlay setDetail:bundle];
            return;
        }

        NSString *summary = [EORuntimeInspector summary];
        [overlay setStatus:@"EO Broker • Probe v2 ✓"];
        [overlay setDetail:summary];
        NSLog(@"[EOSignal] %@", summary);

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [EORuntimeInspector dumpMarketRuntime];
        });
    });
}

@end
