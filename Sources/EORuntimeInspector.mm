#import "EORuntimeInspector.h"
#import <objc/runtime.h>

@implementation EORuntimeInspector
+ (NSArray<NSString *> *)interestingClasses {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return @[];
    Class *classes = (__unsafe_unretained Class *)calloc((size_t)count, sizeof(Class));
    count = objc_getClassList(classes, count);
    NSMutableArray *hits = [NSMutableArray array];
    NSArray *needles = @[@"plot", @"market", @"asset", @"candle", @"chart", @"rate", @"timeframe"];
    for (int i=0; i<count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        NSString *lower = name.lowercaseString;
        for (NSString *n in needles) {
            if ([lower containsString:n]) { [hits addObject:name]; break; }
        }
    }
    free(classes);
    [hits sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return hits;
}

+ (NSString *)summary {
    NSArray *hits = [self interestingClasses];
    BOOL plot = NO;
    NSString *first = nil;
    for (NSString *s in hits) {
        if ([s.lowercaseString containsString:@"plot"]) { plot = YES; first = s; break; }
    }
    if (!first) first = hits.firstObject;
    return [NSString stringWithFormat:@"Runtime classes: %lu\nPlot-like: %@\n%@", (unsigned long)hits.count, plot ? @"YES" : @"NO", first ?: @"No matching ObjC class yet"];
}
@end
