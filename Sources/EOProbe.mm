#import "EOProbe.h"
#import "EOOverlayView.h"
#import "EORuntimeInspector.h"

@implementation EOProbe

+ (void)start {
    EOOverlayView *hud = [EOOverlayView shared];
    [hud installWhenReady];
    [hud setStatus:@"Probe v3 • scanning…"];
    [hud setDetail:@"Waiting for EO Broker runtime…"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"?";
        if (![bundle isEqualToString:@"com.eoservices.eobrokerios"]) {
            [hud setStatus:@"Wrong target"];
            [hud setDetail:bundle];
            return;
        }

        NSString *report = [EORuntimeInspector fullReport];
        [hud setStatus:@"EO Broker • Probe v3 ✓"];
        [hud setDetail:report];
        NSLog(@"[EOSignal]\n%@", report);
    });
}

@end
