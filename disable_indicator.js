if (ObjC.available) {
    const SBRecordingIndicatorViewController = ObjC.classes.SBRecordingIndicatorViewController;

    if (SBRecordingIndicatorViewController) {
        // 1. Hook the primary visibility update method and replace it with a NO-OP function
        const updateVisibilityMethod = SBRecordingIndicatorViewController["- updateIndicatorVisibility:"];
        if (updateVisibilityMethod) {
            updateVisibilityMethod.implementation = ObjC.implement(updateVisibilityMethod, function (self, sel, animated) {
                // Do nothing. This effectively blocks the update logic that shows the indicator.
                console.log("[-] SBRecordingIndicatorViewController: updateIndicatorVisibility: BLOCKED!");
            });
            console.log("[+] Hooked and blocked -[SBRecordingIndicatorViewController updateIndicatorVisibility:].");
        }

        // 2. Hook the "force show" check and force it to return NO (optional but good defense)
        const shouldForceMethod = SBRecordingIndicatorViewController["- _shouldForceViewToShowForCurrentBacklightLuminance"];
        if (shouldForceMethod) {
            shouldForceMethod.implementation = ObjC.implement(shouldForceMethod, function (self, sel) {
                // Force the method to return NO (false)
                return false;
            });
            console.log("[+] Hooked -[_shouldForceViewToShowForCurrentBacklightLuminance] to return NO.");
        }
    } else {
        console.error("[-] SBRecordingIndicatorViewController class not found.");
    }
} else {
    console.error("[-] Objective-C runtime not available.");
}
