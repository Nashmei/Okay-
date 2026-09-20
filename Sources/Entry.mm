#import <Foundation/Foundation.h>
#import "EOProbe.h"

__attribute__((constructor)) static void EOSignalEntry(void) {
    @autoreleasepool {
        NSLog(@"[EOSignal] dylib loaded");
        dispatch_async(dispatch_get_main_queue(), ^{ [EOProbe start]; });
    }
}
