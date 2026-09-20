#import "EOOverlayView.h"
#import <QuartzCore/QuartzCore.h>

@implementation EOOverlayView {
    UILabel *_titleLabel;
    UILabel *_statusLabel;
    UITextView *_detailView;
    UIButton *_expandButton;
    UIButton *_closeButton;
    BOOL _expanded;
    CGRect _compactFrame;
}

+ (instancetype)shared {
    static EOOverlayView *view;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        view = [[EOOverlayView alloc] initWithFrame:CGRectMake(16, 90, 300, 190)];
    });
    return view;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    _compactFrame = frame;
    self.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.94];
    self.layer.cornerRadius = 14.0;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    self.clipsToBounds = YES;

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = @"EOSignal • Probe";
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.font = [UIFont boldSystemFontOfSize:17];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_titleLabel];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.text = @"Injected ✓";
    _statusLabel.textColor = UIColor.whiteColor;
    _statusLabel.font = [UIFont boldSystemFontOfSize:14];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.numberOfLines = 2;
    [self addSubview:_statusLabel];

    _detailView = [[UITextView alloc] initWithFrame:CGRectZero];
    _detailView.backgroundColor = UIColor.clearColor;
    _detailView.textColor = [UIColor colorWithWhite:0.88 alpha:1];
    _detailView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    _detailView.editable = NO;
    _detailView.selectable = YES;
    _detailView.scrollEnabled = YES;
    _detailView.textAlignment = NSTextAlignmentLeft;
    _detailView.text = @"Runtime: starting...\nPlotCore: searching...";
    [self addSubview:_detailView];

    _expandButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_expandButton setTitle:@"⛶  تكبير" forState:UIControlStateNormal];
    _expandButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [_expandButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _expandButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    _expandButton.layer.cornerRadius = 9;
    [_expandButton addTarget:self action:@selector(toggleExpanded) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_expandButton];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_closeButton setTitle:@"✕ تصغير" forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [_closeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _closeButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    _closeButton.layer.cornerRadius = 9;
    [_closeButton addTarget:self action:@selector(toggleExpanded) forControlEvents:UIControlEventTouchUpInside];
    _closeButton.hidden = YES;
    [self addSubview:_closeButton];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];

    [self layoutHUD];
    return self;
}

- (UIWindow *)activeWindow {
    UIApplication *app = UIApplication.sharedApplication;
    for (UIScene *scene in app.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) if (w.isKeyWindow) return w;
        for (UIWindow *w in ws.windows) if (!w.hidden && w.alpha > 0 && w.windowLevel == UIWindowLevelNormal) return w;
    }
    return nil;
}

- (void)layoutHUD {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    if (_expanded) {
        _titleLabel.frame = CGRectMake(16, 16, w - 32, 28);
        _statusLabel.frame = CGRectMake(16, 48, w - 32, 42);
        _closeButton.frame = CGRectMake(w - 112, 98, 96, 36);
        _detailView.frame = CGRectMake(12, 142, w - 24, h - 154);
    } else {
        _titleLabel.frame = CGRectMake(12, 10, w - 24, 26);
        _statusLabel.frame = CGRectMake(12, 40, w - 24, 38);
        _detailView.frame = CGRectMake(12, 78, w - 24, h - 126);
        _expandButton.frame = CGRectMake(12, h - 42, w - 24, 32);
    }
}

- (void)toggleExpanded {
    UIWindow *window = [self activeWindow];
    if (!window) return;

    _expanded = !_expanded;
    _expandButton.hidden = _expanded;
    _closeButton.hidden = !_expanded;

    if (_expanded) {
        _compactFrame = self.frame;
        self.layer.cornerRadius = 0;
        self.frame = window.bounds;
        [window bringSubviewToFront:self];
    } else {
        self.layer.cornerRadius = 14;
        self.frame = _compactFrame;
    }
    [self layoutHUD];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (_expanded || !self.superview) return;
    CGPoint t = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
    if (gesture.state == UIGestureRecognizerStateEnded) _compactFrame = self.frame;
}

- (void)installWhenReady {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self activeWindow];
        if (!window) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self installWhenReady]; });
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
    dispatch_async(dispatch_get_main_queue(), ^{ self->_statusLabel.text = status ?: @"EOSignal"; });
}

- (void)setDetail:(NSString *)detail {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_detailView.text = detail ?: @"";
        [self->_detailView setContentOffset:CGPointZero animated:NO];
    });
}

@end
