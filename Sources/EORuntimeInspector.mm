#import "EORuntimeInspector.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation EORuntimeInspector

+ (NSArray<UIWindow *> *)windows {
    NSMutableArray<UIWindow *> *out = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState == UISceneActivationStateUnattached) continue;
            [out addObjectsFromArray:ws.windows];
        }
    }
    return out;
}

+ (void)collectViews:(UIView *)view out:(NSMutableArray<UIView *> *)out {
    if (!view) return;
    [out addObject:view];
    for (UIView *sub in view.subviews) [self collectViews:sub out:out];
}

+ (BOOL)blocked:(NSString *)name {
    NSString *s = name.lowercaseString;
    NSArray *bad = @[@"token",@"cookie",@"auth",@"password",@"secret",@"session",@"credential",@"header",@"account",@"balance"];
    for (NSString *x in bad) if ([s containsString:x]) return YES;
    return NO;
}

+ (BOOL)interesting:(NSString *)name {
    NSString *s = name.lowercaseString;
    NSArray *keys = @[@"asset",@"symbol",@"instrument",@"price",@"rate",@"quote",@"candle",@"ohlc",@"open",@"high",@"low",@"close",@"point",@"tick",@"timeframe",@"interval",@"period",@"timestamp",@"time",@"plot",@"chart",@"viewport",@"delegate",@"callback",@"event"];
    for (NSString *x in keys) if ([s containsString:x]) return YES;
    return NO;
}

+ (NSString *)shortObject:(id)obj {
    if (!obj || obj == (id)kCFNull) return @"nil";
    if ([obj isKindOfClass:NSString.class] || [obj isKindOfClass:NSNumber.class]) {
        NSString *s = [obj description];
        return s.length > 140 ? [s substringToIndex:140] : s;
    }
    if ([obj isKindOfClass:NSArray.class]) return [NSString stringWithFormat:@"<%@ count=%lu>", NSStringFromClass([obj class]), (unsigned long)[(NSArray *)obj count]];
    if ([obj isKindOfClass:NSDictionary.class]) return [NSString stringWithFormat:@"<%@ count=%lu>", NSStringFromClass([obj class]), (unsigned long)[(NSDictionary *)obj count]];
    return [NSString stringWithFormat:@"<%@>", NSStringFromClass([obj class])];
}

+ (NSString *)scalarAt:(const uint8_t *)p type:(const char *)type {
    if (!p || !type) return nil;
    while (strchr("rnNoORV", *type)) type++;
    if (!strcmp(type, @encode(BOOL))) return (*(const BOOL *)p) ? @"YES" : @"NO";
    if (!strcmp(type, @encode(char))) return [NSString stringWithFormat:@"%d", *(const char *)p];
    if (!strcmp(type, @encode(unsigned char))) return [NSString stringWithFormat:@"%u", *(const unsigned char *)p];
    if (!strcmp(type, @encode(short))) return [NSString stringWithFormat:@"%d", *(const short *)p];
    if (!strcmp(type, @encode(unsigned short))) return [NSString stringWithFormat:@"%u", *(const unsigned short *)p];
    if (!strcmp(type, @encode(int))) return [NSString stringWithFormat:@"%d", *(const int *)p];
    if (!strcmp(type, @encode(unsigned int))) return [NSString stringWithFormat:@"%u", *(const unsigned int *)p];
    if (!strcmp(type, @encode(long))) return [NSString stringWithFormat:@"%ld", *(const long *)p];
    if (!strcmp(type, @encode(unsigned long))) return [NSString stringWithFormat:@"%lu", *(const unsigned long *)p];
    if (!strcmp(type, @encode(long long))) return [NSString stringWithFormat:@"%lld", *(const long long *)p];
    if (!strcmp(type, @encode(unsigned long long))) return [NSString stringWithFormat:@"%llu", *(const unsigned long long *)p];
    if (!strcmp(type, @encode(float))) return [NSString stringWithFormat:@"%.9g", *(const float *)p];
    if (!strcmp(type, @encode(double))) return [NSString stringWithFormat:@"%.14g", *(const double *)p];
    return nil;
}

+ (NSArray<NSDictionary *> *)interestingIvars:(id)obj {
    NSMutableArray *rows = [NSMutableArray array];
    if (!obj) return rows;
    for (Class c = [obj class]; c && c != NSObject.class; c = class_getSuperclass(c)) {
        unsigned int count = 0; Ivar *ivars = class_copyIvarList(c, &count);
        for (unsigned int i=0; i<count; i++) {
            const char *raw = ivar_getName(ivars[i]);
            NSString *name = raw ? @(raw) : @"";
            if (![self interesting:name] || [self blocked:name]) continue;
            const char *type = ivar_getTypeEncoding(ivars[i]);
            NSString *value = nil; id child = nil;
            @try {
                if (type && type[0] == '@') {
                    child = object_getIvar(obj, ivars[i]);
                    value = [self shortObject:child];
                } else {
                    ptrdiff_t off = ivar_getOffset(ivars[i]);
                    value = [self scalarAt:((const uint8_t *)(__bridge const void *)obj)+off type:type];
                }
            } @catch (__unused NSException *e) {}
            if (value.length) [rows addObject:@{@"name":name, @"value":value, @"child":child ?: (id)kCFNull}];
        }
        free(ivars);
    }
    return rows;
}

+ (NSArray<NSString *> *)interestingMethods:(id)obj {
    NSMutableOrderedSet<NSString *> *set = [NSMutableOrderedSet orderedSet];
    if (!obj) return set.array;
    for (Class c=[obj class]; c && c!=NSObject.class; c=class_getSuperclass(c)) {
        unsigned int count=0; Method *methods=class_copyMethodList(c,&count);
        for (unsigned int i=0;i<count;i++) {
            NSString *name=NSStringFromSelector(method_getName(methods[i]));
            if ([self interesting:name] && ![self blocked:name]) [set addObject:name];
        }
        free(methods);
    }
    return set.array;
}

+ (void)dumpObject:(id)obj title:(NSString *)title into:(NSMutableString *)r depth:(NSUInteger)depth seen:(NSHashTable *)seen {
    if (!obj || [seen containsObject:obj]) return;
    [seen addObject:obj];
    [r appendFormat:@"[%@] %@\n", title, NSStringFromClass([obj class])];
    NSArray<NSDictionary *> *ivars=[self interestingIvars:obj];
    if (!ivars.count) [r appendString:@"  interesting ivars: none\n"];
    for (NSDictionary *row in ivars) [r appendFormat:@"  %@ = %@\n", row[@"name"], row[@"value"]];
    NSArray<NSString *> *methods=[self interestingMethods:obj];
    if (methods.count) {
        [r appendString:@"  EVENTS/API: "];
        NSUInteger lim=MIN((NSUInteger)18, methods.count);
        for (NSUInteger i=0;i<lim;i++) [r appendFormat:@"%@%@", methods[i], (i+1<lim?@", ":@"")];
        if (methods.count>lim) [r appendFormat:@" … +%lu",(unsigned long)(methods.count-lim)];
        [r appendString:@"\n"];
    }
    [r appendString:@"\n"];
    if (!depth) return;
    NSUInteger followed=0;
    for (NSDictionary *row in ivars) {
        id child=row[@"child"];
        if (child==(id)kCFNull || !child || followed>=6) continue;
        NSString *cn=NSStringFromClass([child class]);
        NSString *nm=row[@"name"];
        if ([self interesting:cn] || [self interesting:nm] || [cn containsString:@"ExpertOption"] || [cn containsString:@"Plot"]) {
            followed++;
            [self dumpObject:child title:[NSString stringWithFormat:@"%@.%@",title,nm] into:r depth:depth-1 seen:seen];
        }
    }
}

+ (void)appendVisibleMarketText:(NSArray<UIView *> *)views into:(NSMutableString *)r {
    [r appendString:@"VISIBLE MARKET CANDIDATES\n"];
    NSMutableOrderedSet<NSString *> *texts=[NSMutableOrderedSet orderedSet];
    for (UIView *v in views) {
        NSArray<NSString *> *vals=@[v.accessibilityLabel ?: @"", v.accessibilityValue ?: @""];
        for (NSString *s in vals) {
            if (!s.length || s.length>100) continue;
            NSString *l=s.lowercaseString;
            BOOL asset=[l containsString:@"smarty"]||[l containsString:@"otc"]||[l containsString:@"usd"]||[l containsString:@"eur"];
            BOOL tf=[s containsString:@":"];
            BOOL numeric=[s rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location!=NSNotFound;
            if (asset || tf || numeric) [texts addObject:s];
            if (texts.count>=32) break;
        }
        if (texts.count>=32) break;
    }
    if (!texts.count) [r appendString:@"  none\n"];
    else for (NSString *s in texts) [r appendFormat:@"  %@\n",s];
    [r appendString:@"\n"];
}

+ (NSString *)liveReport {
    NSMutableString *r=[NSMutableString stringWithString:@"EOSignal Runtime Probe v6\nREAD-ONLY • passive runtime inspection\n\n"];
    NSMutableArray<UIView *> *views=[NSMutableArray array];
    for (UIWindow *w in [self windows]) if (!w.hidden && w.alpha>0.01) [self collectViews:w out:views];

    NSMutableArray *targets=[NSMutableArray array];
    for (UIView *v in views) {
        NSString *cn=NSStringFromClass(v.class);
        if ([cn isEqualToString:@"RNExpertOptionMobilePlot"] || [cn isEqualToString:@"ExpertOptionPlotView"]) [targets addObject:v];
    }

    NSHashTable *seen=[NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    NSUInteger idx=0;
    for (id obj in targets) {
        idx++;
        [self dumpObject:obj title:[NSString stringWithFormat:@"PLOT %lu",(unsigned long)idx] into:r depth:2 seen:seen];
    }

    Class vcClass=NSClassFromString(@"ExpertoptionPlotViewController");
    if (vcClass) {
        for (UIView *v in views) {
            UIResponder *x=v;
            NSUInteger guard=0;
            while (x && guard++<12) {
                if ([x isKindOfClass:vcClass]) { [self dumpObject:x title:@"PLOT CONTROLLER" into:r depth:2 seen:seen]; break; }
                x=x.nextResponder;
            }
        }
    }

    [self appendVisibleMarketText:views into:r];
    [r appendFormat:@"SUMMARY\n  plot objects: %lu\n  visible views: %lu\n  inspected objects: %lu\n",(unsigned long)targets.count,(unsigned long)views.count,(unsigned long)seen.count];
    [r appendString:@"\nLooking for: asset/id • live rate • OHLC/points • timeframe • timestamps • callbacks"];
    return r;
}
@end
