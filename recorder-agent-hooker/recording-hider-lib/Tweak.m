#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h> // Include UIKit for UIViewController base class

// Define the class and methods we want to hook (from the SpringBoard framework)
@interface SBRecordingIndicatorViewController : UIViewController
- (void)updateIndicatorVisibility:(BOOL)animated;
- (BOOL)_shouldForceViewToShowForCurrentBacklightLuminance;
@end

// --- New Implementation for updateIndicatorVisibility: ---
// The implementation must match the original signature: (id self, SEL _cmd, BOOL animated)
void new_updateIndicatorVisibility(id self, SEL _cmd, BOOL animated) {
    // This function does nothing, effectively blocking the visibility update.
    NSLog(@"[RecordingHider] Blocked -[SBRecordingIndicatorViewController updateIndicatorVisibility:]");
}

// --- New Implementation for _shouldForceViewToShowForCurrentBacklightLuminance ---
// The implementation must match the original signature: (id self, SEL _cmd)
BOOL new_shouldForceViewToShow(id self, SEL _cmd) {
    // Force the return value to NO (false).
    NSLog(@"[RecordingHider] Blocked -[_shouldForceViewToShowForCurrentBacklightLuminance] and returning NO.");
    return NO;
}

// The constructor function runs automatically when the dylib is loaded into SpringBoard.
__attribute__((constructor))
static void initializeTweak() {
    NSLog(@"[RecordingHider] Start recorder hider program");
    @autoreleasepool {
        // Get the target class by string name
        Class SBRecordingIndicatorViewControllerClass = objc_getClass("SBRecordingIndicatorViewController");

        if (SBRecordingIndicatorViewControllerClass) {
            NSLog(@"[RecordingHider] Class found. Attempting to hook methods...");
            
            // 1. Hook updateIndicatorVisibility:
            SEL updateVisSelector = @selector(updateIndicatorVisibility:);
            Method updateVisMethod = class_getInstanceMethod(SBRecordingIndicatorViewControllerClass, updateVisSelector);
            if (updateVisMethod) {
                method_setImplementation(updateVisMethod, (IMP)new_updateIndicatorVisibility);
                NSLog(@"[RecordingHider] updateIndicatorVisibility: HOOKED");
            } else {
                NSLog(@"[RecordingHider] ERROR: updateIndicatorVisibility: method not found at runtime.");
            }

            // 2. Hook _shouldForceViewToShowForCurrentBacklightLuminance
            SEL shouldForceSelector = @selector(_shouldForceViewToShowForCurrentBacklightLuminance);
            Method shouldForceMethod = class_getInstanceMethod(SBRecordingIndicatorViewControllerClass, shouldForceSelector);
            if (shouldForceMethod) {
                method_setImplementation(shouldForceMethod, (IMP)new_shouldForceViewToShow);
                NSLog(@"[RecordingHider] _shouldForceViewToShowForCurrentBacklightLuminance HOOKED");
            } else {
                 NSLog(@"[RecordingHider] ERROR: _shouldForceViewToShowForCurrentBacklightLuminance method not found at runtime.");
            }
        } else {
            NSLog(@"[RecordingHider] ERROR: SBRecordingIndicatorViewController Class not found!");
        }
    }
}