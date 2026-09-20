#import "EORuntimeInspector.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@implementation EORuntimeInspector

+ (NSArray<UIWindow *> *)windows {
    NSMutableArray *a = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:UIWindowScene.class]) [a addObjectsFromArray:((UIWindowScene *)s).windows];
        }
    }
    return a;
}

+ (void)collect:(UIView *)v out:(NSMutableArray *)out {
    if (!v) return;
    [out addObject:v];
    for (UIView *x in v.subviews) [self collect:x out:out];
}

+ (BOOL)marketName:(NSString *)s {
    NSString *x = s.lowercaseString;
    NSArray *keys = @[@"asset",@"symbol",@"instrument",@"price",@"rate",@"quote",@"candle",@"point",@"timeframe",@"interval",@"plot",@"chart",@"tick"];
    for (NSString *k in keys) if ([x containsString:k]) return YES;
    return NO;
}

+ (BOOL)sensitiveName:(NSString *)s {
    NSString *x = s.lowercaseString;
    NSArray *keys = @[@"token",@"cookie",@"auth",@"password",@"secret",@"session",@"credential",@"header"];
    for (NSString *k in keys) if ([x containsString:k]) return YES;
    return NO;
}

+ (NSString *)shortValue:(id)v {
    if (!v || v == (id)kCFNull) return nil;
    if ([v isKindOfClass:NSString.class] || [v isKindOfClass:NSNumber.class]) {
        NSString *s = [v description];
        return s.length > 100 ? [s substringToIndex:100] : s;
    }
    if ([v isKindOfClass:NSArray.class]) return [NSString stringWithFormat:@"<array count=%lu>",(unsigned long)[(NSArray *)v count]];
    if ([v isKindOfClass:NSDictionary.class]) return [NSString stringWithFormat:@"<dict count=%lu>",(unsigned long)[(NSDictionary *)v count]];
    return [NSString stringWithFormat:@"<%@>", NSStringFromClass([v class])];
}

+ (NSString *)scalarAt:(void *)p type:(const char *)t {
    if (!t || !p) return nil;
    while (*t == 'r' || *t == 'n' || *t == 'N' || *t == 'o' || *t == 'O' || *t == 'R' || *t == 'V') t++;
    if (!strcmp(t,@encode(BOOL))) return (*(BOOL *)p) ? @"YES" : @"NO";
    if (!strcmp(t,@encode(int))) return [NSString stringWithFormat:@"%d",*(int *)p];
    if (!strcmp(t,@encode(unsigned int))) return [NSString stringWithFormat:@"%u",*(unsigned int *)p];
    if (!strcmp(t,@encode(long))) return [NSString stringWithFormat:@"%ld",*(long *)p];
    if (!strcmp(t,@encode(unsigned long))) return [NSString stringWithFormat:@"%lu",*(unsigned long *)p];
    if (!strcmp(t,@encode(long long))) return [NSString stringWithFormat:@"%lld",*(long long *)p];
    if (!strcmp(t,@encode(unsigned long long))) return [NSString stringWithFormat:@"%llu",*(unsigned long long *)p];
    if (!strcmp(t,@encode(float))) return [NSString stringWithFormat:@"%.8g",*(float *)p];
    if (!strcmp(t,@encode(double))) return [NSString stringWithFormat:@"%.12g",*(double *)p];
    return nil;
}

+ (void)appendIvars:(id)obj to:(NSMutableString *)r {
    for (Class c=[obj class]; c && c!=UIView.class && c!=NSObject.class; c=class_getSuperclass(c)) {
        unsigned int n=0; Ivar *iv=class_copyIvarList(c,&n);
        for (unsigned int i=0;i<n;i++) {
            NSString *name=@(ivar_getName(iv[i]) ?: "");
            if (![self marketName:name] || [self sensitiveName:name]) continue;
            const char *t=ivar_getTypeEncoding(iv[i]);
            ptrdiff_t off=ivar_getOffset(iv[i]);
            NSString *val=nil;
            if (t && t[0]=='@') {
                id x=object_getIvar(obj,iv[i]);
                val=[self shortValue:x];
            } else {
                val=[self scalarAt:((uint8_t *)(__bridge void *)obj)+off type:t];
            }
            if (val.length) [r appendFormat:@"  ivar %@ = %@\n",name,val];
        }
        free(iv);
    }
}

+ (void)appendSelectors:(id)obj to:(NSMutableString *)r {
    NSMutableOrderedSet *seen=[NSMutableOrderedSet orderedSet];
    for (Class c=[obj class]; c && c!=UIView.class && c!=NSObject.class; c=class_getSuperclass(c)) {
        unsigned int n=0; Method *ms=class_copyMethodList(c,&n);
        for (unsigned int i=0;i<n;i++) {
            SEL sel=method_getName(ms[i]); NSString *name=NSStringFromSelector(sel);
            if (![self marketName:name] || [self sensitiveName:name] || [name hasPrefix:@"set"]) continue;
            NSMethodSignature *sig=[obj methodSignatureForSelector:sel];
            if (!sig || sig.numberOfArguments!=2 || [seen containsObject:name]) continue;
            [seen addObject:name];
            const char *t=sig.methodReturnType; NSString *val=nil;
            @try {
                if (t && t[0]=='@') val=[self shortValue:((id(*)(id,SEL))objc_msgSend)(obj,sel)];
                else if (!strcmp(t,@encode(BOOL))) val=((BOOL(*)(id,SEL))objc_msgSend)(obj,sel)?@"YES":@"NO";
                else if (!strcmp(t,@encode(NSInteger))) val=[NSString stringWithFormat:@"%ld",(long)((NSInteger(*)(id,SEL))objc_msgSend)(obj,sel)];
                else if (!strcmp(t,@encode(NSUInteger))) val=[NSString stringWithFormat:@"%lu",(unsigned long)((NSUInteger(*)(id,SEL))objc_msgSend)(obj,sel)];
                else if (!strcmp(t,@encode(double))) val=[NSString stringWithFormat:@"%.12g",((double(*)(id,SEL))objc_msgSend)(obj,sel)];
                else if (!strcmp(t,@encode(float))) val=[NSString stringWithFormat:@"%.8g",((float(*)(id,SEL))objc_msgSend)(obj,sel)];
            } @catch (__unused NSException *e) {}
            if (val.length) [r appendFormat:@"  %@ = %@\n",name,val];
        }
        free(ms);
    }
}

+ (void)appendAccessibility:(UIView *)v to:(NSMutableString *)r {
    NSArray *vals=@[v.accessibilityLabel ?: @"", v.accessibilityValue ?: @"", v.accessibilityHint ?: @""];
    for (NSString *s in vals) {
        if (s.length && ([self marketName:s] || [s rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location!=NSNotFound))
            [r appendFormat:@"  a11y = %@\n", s.length>120?[s substringToIndex:120]:s];
    }
}

+ (NSString *)liveReport {
    NSMutableString *r=[NSMutableString stringWithString:@"EOSignal Runtime Probe v5\nREAD-ONLY • no trade actions\n\n"];
    NSMutableArray *views=[NSMutableArray array];
    for (UIWindow *w in [self windows]) if (!w.hidden && w.alpha>0.01) [self collect:w out:views];

    NSUInteger found=0;
    for (UIView *v in views) {
        NSString *cn=NSStringFromClass(v.class);
        if (![cn isEqualToString:@"RNExpertOptionMobilePlot"] && ![cn isEqualToString:@"ExpertOptionPlotView"]) continue;
        found++;
        [r appendFormat:@"[%@]\n",cn];
        [self appendSelectors:v to:r];
        [self appendIvars:v to:r];
        [self appendAccessibility:v to:r];
        [r appendString:@"\n"];
    }
    if (!found) [r appendString:@"Plot instance not visible yet.\n\n"];

    [r appendString:@"VISIBLE CANDIDATES\n"];
    NSMutableOrderedSet *texts=[NSMutableOrderedSet orderedSet];
    for (UIView *v in views) {
        NSString *s=v.accessibilityLabel ?: v.accessibilityValue;
        if (!s.length) continue;
        NSString *l=s.lowercaseString;
        BOOL asset=[l containsString:@"smarty"]||[l containsString:@"usd"]||[l containsString:@"eur"]||[l containsString:@"otc"];
        BOOL num=[s rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location!=NSNotFound;
        if (asset || num) [texts addObject:s];
        if (texts.count>=25) break;
    }
    if (!texts.count) [r appendString:@"(none)\n"];
    else for (NSString *s in texts) [r appendFormat:@"%@\n",s];
    [r appendFormat:@"\nPlot instances: %lu • views: %lu",(unsigned long)found,(unsigned long)views.count];
    return r;
}
@end
