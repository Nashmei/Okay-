#import "EOProbe.h"
#import "EOOverlayView.h"
#import "EORuntimeInspector.h"

@implementation EOProbe
+ (void)refresh {
    EOOverlayView *hud = [EOOverlayView shared];
    [hud installWhenReady];
    [hud setStatus:@"EO Broker • Data Probe v7 ✓"];
    [hud setDetail:[EORuntimeInspector liveReport]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self refresh]; });
}
+ (void)start {
    EOOverlayView *hud = [EOOverlayView shared];
    [hud installWhenReady];
    [hud setStatus:@"Data Probe v7 • starting…"];
    [hud setDetail:@"Reading plot/controller data path…"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"?";
        if (![bundle isEqualToString:@"com.eoservices.eobrokerios"]) {
            [hud setStatus:@"Wrong target"];
            [hud setDetail:bundle];
            return;
        }
        [self refresh];
    });
}
@end
