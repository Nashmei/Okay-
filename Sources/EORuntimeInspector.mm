#import "EORuntimeInspector.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@implementation EORuntimeInspector

+ (NSArray<UIWindow *> *)windows {
    NSMutableArray<UIWindow *> *out = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateUnattached) [out addObjectsFromArray:ws.windows];
        }
    }
    return out;
}

+ (void)collectViews:(UIView *)v out:(NSMutableArray<UIView *> *)out {
    if (!v) return;
    [out addObject:v];
    for (UIView *s in v.subviews) [self collectViews:s out:out];
}

+ (BOOL)blocked:(NSString *)s {
    NSString *x=s.lowercaseString;
    for (NSString *k in @[@"token",@"cookie",@"auth",@"password",@"secret",@"session",@"credential",@"header",@"account",@"balance",@"trade",@"bet",@"buy",@"sell"]) {
        if ([x containsString:k]) return YES;
    }
    return NO;
}

+ (BOOL)marketName:(NSString *)s {
    if (!s.length || [self blocked:s]) return NO;
    NSString *x=s.lowercaseString;
    for (NSString *k in @[@"asset",@"symbol",@"instrument",@"price",@"rate",@"quote",@"candle",@"ohlc",@"open",@"high",@"low",@"close",@"point",@"tick",@"timeframe",@"interval",@"period",@"timestamp",@"time",@"plotid",@"plotmode",@"viewport"]) {
        if ([x containsString:k]) return YES;
    }
    return NO;
}

+ (NSString *)compact:(id)o {
    if (!o || o==(id)kCFNull) return @"nil";
    if ([o isKindOfClass:NSString.class] || [o isKindOfClass:NSNumber.class]) {
        NSString *s=[o description]; return s.length>100?[s substringToIndex:100]:s;
    }
    if ([o isKindOfClass:NSArray.class]) return [NSString stringWithFormat:@"<array %lu>",(unsigned long)[(NSArray *)o count]];
    if ([o isKindOfClass:NSDictionary.class]) return [NSString stringWithFormat:@"<dict %lu>",(unsigned long)[(NSDictionary *)o count]];
    return [NSString stringWithFormat:@"<%@>",NSStringFromClass([o class])];
}

+ (NSString *)scalar:(const void *)p type:(const char *)t {
    if (!p || !t) return nil;
    while (*t && strchr("rnNoORV",*t)) t++;
    if (!strcmp(t,@encode(BOOL))) return (*(const BOOL *)p)?@"YES":@"NO";
    if (!strcmp(t,@encode(int))) return [NSString stringWithFormat:@"%d",*(const int *)p];
    if (!strcmp(t,@encode(unsigned int))) return [NSString stringWithFormat:@"%u",*(const unsigned int *)p];
    if (!strcmp(t,@encode(long))) return [NSString stringWithFormat:@"%ld",*(const long *)p];
    if (!strcmp(t,@encode(unsigned long))) return [NSString stringWithFormat:@"%lu",*(const unsigned long *)p];
    if (!strcmp(t,@encode(long long))) return [NSString stringWithFormat:@"%lld",*(const long long *)p];
    if (!strcmp(t,@encode(unsigned long long))) return [NSString stringWithFormat:@"%llu",*(const unsigned long long *)p];
    if (!strcmp(t,@encode(float))) return [NSString stringWithFormat:@"%.9g",*(const float *)p];
    if (!strcmp(t,@encode(double))) return [NSString stringWithFormat:@"%.14g",*(const double *)p];
    return nil;
}

+ (void)appendContainer:(id)o prefix:(NSString *)prefix out:(NSMutableOrderedSet<NSString *> *)out depth:(NSUInteger)depth {
    if (!o || !depth || out.count>=30) return;
    if ([o isKindOfClass:NSDictionary.class]) {
        NSDictionary *d=(NSDictionary *)o;
        for (id key in d) {
            NSString *ks=[key description]; if (![self marketName:ks]) continue;
            id v=d[key]; [out addObject:[NSString stringWithFormat:@"%@%@ = %@",prefix,ks,[self compact:v]]];
            [self appendContainer:v prefix:[NSString stringWithFormat:@"%@%@.",prefix,ks] out:out depth:depth-1];
            if (out.count>=30) break;
        }
    } else if ([o isKindOfClass:NSArray.class]) {
        NSArray *a=(NSArray *)o; NSUInteger n=MIN((NSUInteger)8,a.count);
        for (NSUInteger i=0;i<n;i++) [self appendContainer:a[i] prefix:prefix out:out depth:depth-1];
    }
}

+ (void)inspectObject:(id)obj label:(NSString *)label out:(NSMutableOrderedSet<NSString *> *)out children:(NSMutableArray *)children {
    if (!obj) return;
    for (Class c=[obj class]; c && c!=NSObject.class; c=class_getSuperclass(c)) {
        unsigned int ic=0; Ivar *iv=class_copyIvarList(c,&ic);
        for (unsigned int i=0;i<ic;i++) {
            NSString *n=@(ivar_getName(iv[i])?:""); if (![self marketName:n]) continue;
            const char *t=ivar_getTypeEncoding(iv[i]); NSString *v=nil; id child=nil;
            @try {
                if (t && t[0]=='@') { child=object_getIvar(obj,iv[i]); v=[self compact:child]; }
                else { ptrdiff_t off=ivar_getOffset(iv[i]); v=[self scalar:((const uint8_t *)(__bridge const void *)obj)+off type:t]; }
            } @catch (__unused NSException *e) {}
            if (v.length) [out addObject:[NSString stringWithFormat:@"%@.%@ = %@",label,n,v]];
            if (child) { [self appendContainer:child prefix:[NSString stringWithFormat:@"%@.%@.",label,n] out:out depth:2]; [children addObject:child]; }
        }
        free(iv);

        unsigned int pc=0; objc_property_t *props=class_copyPropertyList(c,&pc);
        for (unsigned int i=0;i<pc;i++) {
            NSString *n=@(property_getName(props[i])?:""); if (![self marketName:n]) continue;
            SEL sel=NSSelectorFromString(n); Method m=class_getInstanceMethod([obj class],sel); if (!m || method_getNumberOfArguments(m)!=2) continue;
            char rt[64]={0}; method_getReturnType(m,rt,sizeof(rt)); NSString *v=nil; id child=nil;
            @try {
                if (rt[0]=='@') { child=((id(*)(id,SEL))objc_msgSend)(obj,sel); v=[self compact:child]; }
                else if (!strcmp(rt,@encode(double))) v=[NSString stringWithFormat:@"%.14g",((double(*)(id,SEL))objc_msgSend)(obj,sel)];
                else if (!strcmp(rt,@encode(float))) v=[NSString stringWithFormat:@"%.9g",((float(*)(id,SEL))objc_msgSend)(obj,sel)];
                else if (!strcmp(rt,@encode(int))) v=[NSString stringWithFormat:@"%d",((int(*)(id,SEL))objc_msgSend)(obj,sel)];
                else if (!strcmp(rt,@encode(NSInteger))) v=[NSString stringWithFormat:@"%ld",(long)((NSInteger(*)(id,SEL))objc_msgSend)(obj,sel)];
                else if (!strcmp(rt,@encode(NSUInteger))) v=[NSString stringWithFormat:@"%lu",(unsigned long)((NSUInteger(*)(id,SEL))objc_msgSend)(obj,sel)];
            } @catch (__unused NSException *e) {}
            if (v.length) [out addObject:[NSString stringWithFormat:@"%@.%@() = %@",label,n,v]];
            if (child) { [self appendContainer:child prefix:[NSString stringWithFormat:@"%@.%@.",label,n] out:out depth:2]; [children addObject:child]; }
        }
        free(props);
    }
}

+ (void)appendVisible:(NSArray<UIView *> *)views out:(NSMutableString *)r {
    NSMutableOrderedSet<NSString *> *s=[NSMutableOrderedSet orderedSet];
    for (UIView *v in views) {
        for (NSString *x in @[v.accessibilityLabel?:@"",v.accessibilityValue?:@""]) {
            if (!x.length || x.length>80) continue;
            NSString *l=x.lowercaseString;
            BOOL asset=[l containsString:@"smarty"]||[l containsString:@"otc"]||[l containsString:@"eur"]||[l containsString:@"usd"];
            BOOL numeric=[x rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location!=NSNotFound;
            if (asset || numeric) [s addObject:x];
            if (s.count>=14) break;
        }
        if (s.count>=14) break;
    }
    if (s.count) {
        [r appendString:@"\nUI FALLBACK\n"];
        for (NSString *x in s) [r appendFormat:@"  %@\n",x];
    }
}

+ (NSString *)liveReport {
    NSMutableArray<UIView *> *views=[NSMutableArray array];
    for (UIWindow *w in [self windows]) if (!w.hidden && w.alpha>0.01) [self collectViews:w out:views];

    NSMutableArray *roots=[NSMutableArray array];
    for (UIView *v in views) {
        NSString *c=NSStringFromClass(v.class);
        if ([c isEqualToString:@"RNExpertOptionMobilePlot"] || [c isEqualToString:@"ExpertOptionPlotView"]) [roots addObject:v];
    }

    Class vcClass=NSClassFromString(@"ExpertoptionPlotViewController");
    if (vcClass) for (UIView *v in views) {
        UIResponder *x=v; NSUInteger guard=0;
        while (x && guard++<10) { if ([x isKindOfClass:vcClass]) { if (![roots containsObject:x]) [roots addObject:x]; break; } x=x.nextResponder; }
    }

    NSMutableOrderedSet<NSString *> *values=[NSMutableOrderedSet orderedSet];
    NSMutableArray *children=[NSMutableArray array];
    NSUInteger i=0;
    for (id o in roots) { [self inspectObject:o label:[NSString stringWithFormat:@"P%lu",(unsigned long)++i] out:values children:children]; }
    NSUInteger lim=MIN((NSUInteger)24,children.count);
    for (NSUInteger j=0;j<lim;j++) [self inspectObject:children[j] label:[NSString stringWithFormat:@"D%lu",(unsigned long)(j+1)] out:values children:[NSMutableArray array]];

    NSMutableString *r=[NSMutableString stringWithString:@"EOSignal Data Probe v7\nREAD-ONLY • plot data path\n\n"];
    [r appendFormat:@"Plot path objects: %lu\n\n",(unsigned long)roots.count];
    if (values.count) {
        [r appendString:@"LIVE MARKET FIELDS\n"];
        NSUInteger n=0; for (NSString *x in values) { [r appendFormat:@"  %@\n",x]; if (++n>=38) break; }
    } else [r appendString:@"LIVE MARKET FIELDS\n  no ObjC-exposed market fields yet\n"];
    [self appendVisible:views out:r];
    [r appendString:@"\nTARGET\n  asset/id • live price/rate • OHLC/candles/points • timeframe/time\n"];
    return r;
}
@end
