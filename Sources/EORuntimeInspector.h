#import <Foundation/Foundation.h>

@interface EORuntimeInspector : NSObject

+ (NSArray<NSString *> *)interestingClasses;
+ (NSArray<NSString *> *)selectorsForClassNamed:(NSString *)className;
+ (NSString *)summary;
+ (void)dumpMarketRuntime;

@end
