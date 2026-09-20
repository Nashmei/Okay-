#import "EOOverlayView.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@implementation EOOverlayView {
    UILabel *_titleLabel;
    UILabel *_statusLabel;
    UILabel *_detailLabel;
}

+ (instancetype)shared {
    static EOOverlayView *view = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        view = [[EOOverlayView alloc]
            initWithFrame:CGRectMake(16.0, 90.0, 280.0, 150.0)];
    });

    return view;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor =
            [UIColor colorWithWhite:0.08 alpha:0.92];

        self.layer.cornerRadius = 14.0;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor =
            [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;

        self.clipsToBounds = YES;

        _titleLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(14.0, 10.0, 252.0, 24.0)];

        _titleLabel.text = @"EOSignal • Probe";
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.font =
            [UIFont boldSystemFontOfSize:16.0];

        [self addSubview:_titleLabel];

        _statusLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(14.0, 40.0, 252.0, 22.0)];

        _statusLabel.text = @"Injected ✓";
        _statusLabel.textColor = UIColor.whiteColor;
        _statusLabel.font =
            [UIFont systemFontOfSize:14.0
                             weight:UIFontWeightSemibold];

        [self addSubview:_statusLabel];

        _detailLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(14.0, 68.0, 252.0, 68.0)];

        _detailLabel.numberOfLines = 4;
        _detailLabel.text = @"Runtime: starting...\nPlotCore: searching...";
        _detailLabel.textColor =
            [UIColor colorWithWhite:0.85 alpha:1.0];

        _detailLabel.font =
            [UIFont monospacedSystemFontOfSize:11.0
                                       weight:UIFontWeightRegular];

        [self addSubview:_detailLabel];

        UIPanGestureRecognizer *pan =
            [[UIPanGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(handlePan:)];

        self.userInteractionEnabled = YES;

        [self addGestureRecognizer:pan];
    }

    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *container = self.superview;

    if (!container) {
        return;
    }

    CGPoint translation =
        [gesture translationInView:container];

    self.center = CGPointMake(
        self.center.x + translation.x,
        self.center.y + translation.y
    );

    [gesture setTranslation:CGPointZero
                     inView:container];
}

- (UIWindow *)activeWindow {
    UIApplication *application =
        UIApplication.sharedApplication;

    for (UIScene *scene in application.connectedScenes) {
        if (scene.activationState !=
            UISceneActivationStateForegroundActive) {
            continue;
        }

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        /*
         * Prefer the actual key window.
         */
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }

        /*
         * Fallback to a visible normal-level window.
         */
        for (UIWindow *window in windowScene.windows) {
            if (!window.hidden &&
                window.alpha > 0.0 &&
                window.windowLevel == UIWindowLevelNormal) {
                return window;
            }
        }
    }

    return nil;
}

- (void)installWhenReady {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self activeWindow];

        if (!window) {
            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(0.75 * NSEC_PER_SEC)
                ),
                dispatch_get_main_queue(),
                ^{
                    [self installWhenReady];
                }
            );

            return;
        }

        if (self.superview != window) {
            [self removeFromSuperview];
            [window addSubview:self];
        }

        [window bringSubviewToFront:self];
    });
}

- (void)setStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_statusLabel.text =
            status ?: @"EOSignal";
    });
}

- (void)setDetail:(NSString *)detail {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_detailLabel.text =
            detail ?: @"";
    });
}

@end
