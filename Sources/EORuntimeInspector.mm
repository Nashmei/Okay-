#import "EORuntimeInspector.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@implementation EORuntimeInspector

+ (id)safeObjectValue:(id)obj selectorName:(NSString *)name {
    if (!obj || !name.length) return nil;
    SEL sel = NSSelectorFromString(name);
    if (![obj respondsToSelector:sel]) return nil;
    NSMethodSignature *sig = [obj methodSignatureForSelector:sel];
    if (!sig || sig.numberOfArguments != 2) return nil;
    const char *ret = sig.methodReturnType;
    if (!ret || ret[0] != '@') return nil;
    return ((id(*)(id,SEL))objc_msgSend)(obj, sel);
}

+ (NSString *)safeScalarValue:(id)obj selectorName:(NSString *)name {
    SEL sel = NSSelectorFromString(name);
    if (!obj || ![obj respondsToSelector:sel]) return nil;
    NSMethodSignature *sig = [obj methodSignatureForSelector:sel];
    if (!sig || sig.numberOfArguments != 2) return nil;
    const char *t = sig.methodReturnType;
    if (!t) return nil;
    if (!strcmp(t, @encode(NSInteger))) return [NSString stringWithFormat:@"%ld", (long)((NSInteger(*)(id,SEL))objc_msgSend)(obj,sel)];
    if (!strcmp(t, @encode(NSUInteger))) return [NSString stringWithFormat:@"%lu", (unsigned long)((NSUInteger(*)(id,SEL))objc_msgSend)(obj,sel)];
    if (!strcmp(t, @encode(BOOL))) return ((BOOL(*)(id,SEL))objc_msgSend)(obj,sel) ? @"YES" : @"NO";
    if (!strcmp(t, @encode(double))) return [NSString stringWithFormat:@"%.8f", ((double(*)(id,SEL))objc_msgSend)(obj,sel)];
    if (!strcmp(t, @encode(float))) return [NSString stringWithFormat:@"%.8f", ((float(*)(id,SEL))objc_msgSend)(obj,sel)];
    return nil;
}

+ (void)collectViews:(UIView *)view into:(NSMutableArray<UIView *> *)out {
    if (!view) return;
    [out addObject:view];
    for (UIView *child in view.subviews) [self collectViews:child into:out];
}

+ (NSArray<UIWindow *> *)windows {
    NSMutableArray<UIWindow *> *out = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            [out addObjectsFromArray:ws.windows];
        }
    }
    return out;
}

+ (BOOL)looksUsefulText:(NSString *)s {
    if (!s.length || s.length > 90) return NO;
    NSString *l = s.lowercaseString;
    if ([l containsString:@"eosignal"] || [l containsString:@"probe"]) return NO;
    NSCharacterSet *digits = NSCharacterSet.decimalDigitCharacterSet;
    BOOL hasDigit = [s rangeOfCharacterFromSet:digits].location != NSNotFound;
    BOOL marketWord = [l containsString:@"usd"] || [l containsString:@"eur"] || [l containsString:@"smarty"] ||
                      [l containsString:@"otc"] || [l containsString:@"إغلاق"] || [l containsString:@"شراء"] || [l containsString:@"بيع"];
    return hasDigit || marketWord;
}

+ (NSString *)liveReport {
    NSMutableString *r = [NSMutableString stringWithString:@"EOSignal Live Probe v4\nREAD-ONLY / received UI data\n\n"];
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    for (UIWindow *w in [self windows]) {
        if (!w.hidden && w.alpha > 0.01) [self collectViews:w into:views];
    }

    NSUInteger plotCount = 0;
    [r appendString:@"PLOT OBJECTS\n"];
    for (UIView *v in views) {
        NSString *cn = NSStringFromClass(v.class);
        NSString *lc = cn.lowercaseString;
        if (![lc containsString:@"expertoption"] && ![lc containsString:@"plot"]) continue;
        if ([lc containsString:@"eosignal"]) continue;
        plotCount++;
        [r appendFormat:@"%@\n", cn];
        for (NSString *key in @[@"plotId", @"plotMode", @"assetId", @"currentAssetId", @"timeframe", @"rate", @"price"]) {
            id ov = [self safeObjectValue:v selectorName:key];
            NSString *sv = ov ? [ov description] : [self safeScalarValue:v selectorName:key];
            if (sv.length) [r appendFormat:@"  %@ = %@\n", key, sv];
        }
    }
    if (!plotCount) [r appendString:@"(none visible yet)\n"];

    [r appendString:@"\nVISIBLE MARKET TEXT\n"];
    NSMutableOrderedSet<NSString *> *texts = [NSMutableOrderedSet orderedSet];
    for (UIView *v in views) {
        NSString *s = nil;
        if ([v isKindOfClass:UILabel.class]) s = ((UILabel *)v).text;
        else if ([v isKindOfClass:UITextField.class]) s = ((UITextField *)v).text;
        else if ([v isKindOfClass:UITextView.class]) s = ((UITextView *)v).text;
        else if ([v isKindOfClass:UIButton.class]) s = [((UIButton *)v) titleForState:UIControlStateNormal];
        s = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([self looksUsefulText:s]) [texts addObject:s];
        if (texts.count >= 80) break;
    }
    if (!texts.count) [r appendString:@"(no useful labels found)\n"];
    else for (NSString *s in texts) [r appendFormat:@"%@\n", s];

    [r appendFormat:@"\nVisible views scanned: %lu", (unsigned long)views.count];
    return r;
}

@end
