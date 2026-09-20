#import "EOOverlayView.h"
#import <QuartzCore/QuartzCore.h>

@interface EOOverlayView ()
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UITextView *detailView;
@property(nonatomic,strong) UIButton *expandButton;
@property(nonatomic,assign) CGRect compactFrame;
@property(nonatomic,assign) BOOL expanded;
@end

@implementation EOOverlayView

+ (instancetype)shared {
    static EOOverlayView *v;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        v = [[EOOverlayView alloc] initWithFrame:CGRectMake(16, 90, 330, 230)];
    });
    return v;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.compactFrame = frame;
        self.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.94];
        self.layer.cornerRadius = 14;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = @"EOSignal • Probe";
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [self addSubview:_titleLabel];

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.textColor = UIColor.whiteColor;
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.font = [UIFont boldSystemFontOfSize:15];
        [self addSubview:_statusLabel];

        _detailView = [[UITextView alloc] init];
        _detailView.backgroundColor = UIColor.clearColor;
        _detailView.textColor = UIColor.whiteColor;
        _detailView.editable = NO;
        _detailView.selectable = YES;
        _detailView.alwaysBounceVertical = YES;
        _detailView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        [self addSubview:_detailView];

        _expandButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_expandButton setTitle:@"⛶ تكبير" forState:UIControlStateNormal];
        _expandButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [_expandButton addTarget:self action:@selector(toggleExpanded)
                forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_expandButton];

        UIPanGestureRecognizer *pan =
          [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    self.titleLabel.frame = CGRectMake(12, 10, w - 24, 28);
    self.statusLabel.frame = CGRectMake(12, 42, w - 24, 25);
    self.expandButton.frame = CGRectMake(w - 105, 70, 95, 38);
    self.detailView.frame = CGRectMake(12, 108, w - 24, MAX(80, h - 120));
}

- (UIWindow *)activeWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) if (w.isKeyWindow) return w;
        for (UIWindow *w in ws.windows)
            if (!w.hidden && w.alpha > 0 && w.windowLevel == UIWindowLevelNormal) return w;
    }
    return nil;
}

- (void)installWhenReady {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [self activeWindow];
        if (!w) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self installWhenReady]; });
            return;
        }
        if (self.superview != w) {
            [self removeFromSuperview];
            [w addSubview:self];
        }
        [w bringSubviewToFront:self];
    });
}

- (void)toggleExpanded {
    UIWindow *w = [self activeWindow];
    if (!w) return;

    self.expanded = !self.expanded;
    if (self.expanded) {
        self.compactFrame = self.frame;
        self.layer.cornerRadius = 0;
        self.frame = w.bounds;
        [self.expandButton setTitle:@"✕ تصغير" forState:UIControlStateNormal];
        self.detailView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    } else {
        self.layer.cornerRadius = 14;
        self.frame = self.compactFrame;
        [self.expandButton setTitle:@"⛶ تكبير" forState:UIControlStateNormal];
        self.detailView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    }
    [self setNeedsLayout];
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    if (self.expanded || !self.superview) return;
    CGPoint p = [g translationInView:self.superview];
    self.center = CGPointMake(self.center.x + p.x, self.center.y + p.y);
    [g setTranslation:CGPointZero inView:self.superview];
}

- (void)setStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{ self.statusLabel.text = status ?: @""; });
}

- (void)setDetail:(NSString *)detail {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.detailView.text = detail ?: @"";
        [self.detailView setContentOffset:CGPointZero animated:NO];
    });
}

@end
