#import <UIKit/UIKit.h>

@interface EOOverlayView : UIView

+ (instancetype)shared;

- (void)installWhenReady;

- (void)setStatus:(NSString *)status;
- (void)setDetail:(NSString *)detail;

@end
