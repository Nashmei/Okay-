#import "EORuntimeInspector.h"
#import <objc/runtime.h>

@implementation EORuntimeInspector

+ (NSArray<NSString *> *)interestingClasses {
    int count = objc_getClassList(NULL, 0);

    if (count <= 0) {
        return @[];
    }

    Class *classes =
        (__unsafe_unretained Class *)
        calloc((size_t)count, sizeof(Class));

    if (!classes) {
        return @[];
    }

    count = objc_getClassList(classes, count);

    NSMutableArray<NSString *> *results =
        [NSMutableArray array];

    NSArray<NSString *> *keywords = @[
        @"plot",
        @"market",
        @"asset",
        @"candle",
        @"chart",
        @"rate",
        @"timeframe",
        @"expertoption"
    ];

    for (int i = 0; i < count; i++) {
        Class cls = classes[i];

        if (!cls) {
            continue;
        }

        NSString *name = NSStringFromClass(cls);

        if (name.length == 0) {
            continue;
        }

        NSString *lower =
            name.lowercaseString;

        for (NSString *keyword in keywords) {
            if ([lower containsString:keyword]) {
                [results addObject:name];
                break;
            }
        }
    }

    free(classes);

    [results sortUsingSelector:
        @selector(localizedCaseInsensitiveCompare:)];

    return results;
}

+ (NSString *)summary {
    NSArray<NSString *> *classes =
        [self interestingClasses];

    BOOL plotFound = NO;
    NSString *interestingClass = nil;

    for (NSString *name in classes) {
        NSString *lower =
            name.lowercaseString;

        if ([lower containsString:@"plot"]) {
            plotFound = YES;
            interestingClass = name;
            break;
        }
    }

    if (!interestingClass) {
        interestingClass =
            classes.firstObject;
    }

    return [NSString stringWithFormat:
        @"Runtime classes: %lu\n"
         "Plot-like: %@\n"
         "%@",
        (unsigned long)classes.count,
        plotFound ? @"YES" : @"NO",
        interestingClass ?: @"No matching ObjC class yet"
    ];
}

@end
