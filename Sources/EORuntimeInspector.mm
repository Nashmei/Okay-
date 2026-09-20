#import "EORuntimeInspector.h"
#import <objc/runtime.h>

@implementation EORuntimeInspector

+ (BOOL)isInterestingName:(NSString *)name {
    if (name.length == 0) return NO;
    NSString *s = name.lowercaseString;
    NSArray<NSString *> *keywords = @[@"expertoption", @"plot", @"chart", @"asset", @"candle", @"rate", @"timeframe", @"market", @"price", @"indicator"];
    for (NSString *keyword in keywords) if ([s containsString:keyword]) return YES;
    return NO;
}

+ (BOOL)isInterestingSelector:(NSString *)name {
    if (name.length == 0) return NO;
    NSString *s = name.lowercaseString;
    NSArray<NSString *> *keywords = @[@"asset", @"candle", @"rate", @"price", @"timeframe", @"plot", @"chart", @"indicator", @"viewport"];
    for (NSString *keyword in keywords) if ([s containsString:keyword]) return YES;
    return NO;
}

+ (NSArray<NSString *> *)interestingClasses {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return @[];
    Class *classes = (__unsafe_unretained Class *)calloc((size_t)count, sizeof(Class));
    if (!classes) return @[];
    count = objc_getClassList(classes, count);
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (!cls) continue;
        NSString *name = NSStringFromClass(cls);
        if ([self isInterestingName:name]) [result addObject:name];
    }
    free(classes);
    [result sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return result;
}

+ (NSArray<NSString *> *)selectorsForClassNamed:(NSString *)className {
    Class cls = NSClassFromString(className);
    if (!cls) return @[];
    NSMutableOrderedSet<NSString *> *result = [NSMutableOrderedSet orderedSet];
    Class current = cls;
    for (NSInteger depth = 0; current && depth < 4; depth++, current = class_getSuperclass(current)) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(current, &count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([self isInterestingSelector:name]) [result addObject:name];
        }
        free(methods);
    }
    return result.array;
}

+ (NSString *)summary {
    NSArray<NSString *> *classes = [self interestingClasses];
    NSUInteger selectorCount = 0;
    NSMutableArray<NSString *> *priority = [NSMutableArray array];
    for (NSString *name in classes) {
        NSArray<NSString *> *selectors = [self selectorsForClassNamed:name];
        selectorCount += selectors.count;
        NSString *lower = name.lowercaseString;
        if ([lower containsString:@"expertoption"] || [lower containsString:@"plot"] || [lower containsString:@"candle"]) {
            if (priority.count < 3) [priority addObject:name];
        }
    }
    NSString *targets = priority.count > 0 ? [priority componentsJoinedByString:@", "] : @"none yet";
    return [NSString stringWithFormat:@"Market classes: %lu\nSelectors: %lu\nTargets: %@", (unsigned long)classes.count, (unsigned long)selectorCount, targets];
}

+ (void)dumpMarketRuntime {
    NSArray<NSString *> *classes = [self interestingClasses];
    NSLog(@"[EOSignal] ===== Probe v2 =====");
    NSLog(@"[EOSignal] market classes: %lu", (unsigned long)classes.count);
    for (NSString *className in classes) {
        NSArray<NSString *> *selectors = [self selectorsForClassNamed:className];
        if (selectors.count == 0) continue;
        NSLog(@"[EOSignal] CLASS %@", className);
        for (NSString *selector in selectors) NSLog(@"[EOSignal]   - %@", selector);
    }
    NSLog(@"[EOSignal] ===== End Probe v2 =====");
}

@end
