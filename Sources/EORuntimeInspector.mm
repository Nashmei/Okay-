#import "EORuntimeInspector.h"
#import <objc/runtime.h>

@implementation EORuntimeInspector

+ (BOOL)interestingClassName:(NSString *)name {
    NSString *s = name.lowercaseString;
    NSArray *keys = @[@"expertoption", @"plot", @"candle", @"asset",
                      @"rate", @"timeframe", @"chart", @"indicator"];
    for (NSString *k in keys) {
        if ([s containsString:k]) return YES;
    }
    return NO;
}

+ (BOOL)interestingSelectorName:(NSString *)name {
    NSString *s = name.lowercaseString;
    NSArray *keys = @[@"asset", @"candle", @"rate", @"price",
                      @"timeframe", @"viewport", @"indicator",
                      @"plot", @"chart", @"callback"];
    for (NSString *k in keys) {
        if ([s containsString:k]) return YES;
    }
    return NO;
}

+ (NSArray<NSString *> *)selectorsForClass:(Class)cls {
    NSMutableOrderedSet<NSString *> *out = [NSMutableOrderedSet orderedSet];
    for (Class cur = cls; cur; cur = class_getSuperclass(cur)) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cur, &count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *s = NSStringFromSelector(method_getName(methods[i]));
            if ([self interestingSelectorName:s]) [out addObject:s];
        }
        free(methods);
        if (out.count >= 80) break;
    }
    return out.array;
}

+ (NSString *)fullReport {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return @"No Objective-C classes found.";

    Class *classes = (__unsafe_unretained Class *)calloc((size_t)count, sizeof(Class));
    if (!classes) return @"Unable to allocate runtime class list.";

    count = objc_getClassList(classes, count);
    NSMutableArray<NSString *> *names = [NSMutableArray array];

    for (int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if ([self interestingClassName:name]) [names addObject:name];
    }
    free(classes);

    [names sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    // Put ExpertOption/Plot candidates first so screenshots are immediately useful.
    [names sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        BOOL ap = [a.lowercaseString containsString:@"expertoption"];
        BOOL bp = [b.lowercaseString containsString:@"expertoption"];
        if (ap != bp) return ap ? NSOrderedAscending : NSOrderedDescending;
        BOOL apl = [a.lowercaseString containsString:@"plot"];
        BOOL bpl = [b.lowercaseString containsString:@"plot"];
        if (apl != bpl) return apl ? NSOrderedAscending : NSOrderedDescending;
        return [a localizedCaseInsensitiveCompare:b];
    }];

    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"EOSignal Probe v3\nRuntime classes: %d\nMatched classes: %lu\n\n",
                         count, (unsigned long)names.count];

    NSUInteger shown = 0;
    for (NSString *name in names) {
        Class cls = NSClassFromString(name);
        if (!cls) continue;

        NSArray<NSString *> *selectors = [self selectorsForClass:cls];
        NSString *lower = name.lowercaseString;

        BOOL priority = [lower containsString:@"expertoption"] ||
                        [lower containsString:@"plot"] ||
                        [lower containsString:@"candle"] ||
                        [lower containsString:@"timeframe"];

        if (!priority && selectors.count == 0) continue;

        [report appendFormat:@"CLASS: %@\n", name];

        Class superCls = class_getSuperclass(cls);
        [report appendFormat:@"SUPER: %@\n",
         superCls ? NSStringFromClass(superCls) : @"(none)"];

        [report appendFormat:@"SELECTORS (%lu):\n",
         (unsigned long)selectors.count];

        if (selectors.count == 0) {
            [report appendString:@"  (no matching ObjC selectors)\n"];
        } else {
            for (NSString *selector in selectors) {
                [report appendFormat:@"  %@\n", selector];
            }
        }

        [report appendString:@"\n"];
        shown++;
        if (shown >= 40) break;
    }

    return report;
}

@end
