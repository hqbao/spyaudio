#import <Foundation/Foundation.h>
#import "RecorderAgent.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"--- Command-Driven Daemon Started (Polling @ 1s) ---");
        
        // Initialize the RecorderAgent class, which starts the command loop
        RecorderAgent *agent = [[RecorderAgent alloc] init];
        
        // CRITICAL: Keep the run loop alive indefinitely to allow NSTimer and network callbacks to fire.
        [[NSRunLoop currentRunLoop] run];
        
        // This code path is typically unreachable in a successful daemon
        [agent stopCommandLoop]; 
        NSLog(@"--- Command-Driven Daemon Finished ---");
    }
    return 0;
}