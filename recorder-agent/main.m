#import <Foundation/Foundation.h>
#import "RecorderAgent.h" // Updated import to new file name

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"--- Command-Driven Daemon Started (Polling @ 1s) ---");
        
        // Initialize the RecorderAgent class, which starts the command loop
        RecorderAgent *agent = [[RecorderAgent alloc] init]; // Uses the renamed class
        
        // CRITICAL: Keep the run loop alive indefinitely to allow NSTimer and network callbacks to fire.
        [[NSRunLoop currentRunLoop] run];
        
        // Clean up when the run loop eventually terminates (though typically it won't in a daemon)
        [agent stopCommandLoop]; 
        NSLog(@"--- Command-Driven Daemon Finished ---"); 
    }
    return 0;
}
