#import <Foundation/Foundation.h>

@interface EORuntimeInspector : NSObject

+ (NSArray<NSString *> *)interestingClasses;
+ (NSString *)summary;

@end
