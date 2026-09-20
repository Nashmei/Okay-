#import "EOOverlayView.h"

@implementation EOOverlayView {
    UILabel *_titleLabel;
    UILabel *_statusLabel;
    UILabel *_detailLabel;
}

+ (instancetype)shared {
    static EOOverlayView *v;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ v = [[self alloc] initWithFrame:CGRectMake(16, 90, 250, 132)]; });
    return v;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.90];
        self.layer.cornerRadius = 14;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 220, 24)];
        _titleLabel.text = @"EOSignal • Probe";
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_titleLabel];

        _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 40, 220, 22)];
        _statusLabel.text = @"Injected ✓";
        _statusLabel.textColor = UIColor.whiteColor;
        _statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [self addSubview:_statusLabel];

        _detailLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 66, 220, 52)];
        _detailLabel.numberOfLines = 3;
        _detailLabel.text = @"Runtime: starting…";
        _detailLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1];
        _detailLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        [self addSubview:_detailLabel];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)pan:(UIPanGestureRecognizer *)g {
    CGPoint p = [g translationInView:self.superview];
    self.center = CGPointMake(self.center.x + p.x, self.center.y + p.y);
    [g setTranslation:CGPointZero inView:self.superview];
}

- (UIWindow *)activeWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) return w;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

- (void)installWhenReady {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [self activeWindow];
        if (!w) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self installWhenReady]; });
            return;
        }
        if (!self.superview) [w addSubview:self];
        [w bringSubviewToFront:self];
    });
}

- (void)setStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{ self->_statusLabel.text = status ?: @""; });
}
- (void)setDetail:(NSString *)detail {
    dispatch_async(dispatch_get_main_queue(), ^{ self->_detailLabel.text = detail ?: @""; });
}
@end
