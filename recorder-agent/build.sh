#!/bin/sh

# --- 1. Cleanup ---
# Remove old binaries to ensure a clean build
rm -f recagent
rm -f recagent-macos
echo "Removed previous binaries."

# --- 2. iOS Cross-Compilation (Daemon Target) ---
# Compiles for iOS devices (ARM64 architecture) using the iPhoneOS SDK.
# -arch arm64: Specifies the architecture for modern iOS devices.
# -framework: Links the necessary Apple frameworks (Foundation for core logic, AVFoundation for audio).
xcrun --sdk iphoneos clang \
    -arch arm64 \
    -framework Foundation \
    -framework AVFoundation \
    -framework UIKit \
    -o recagent \
    main.m RecorderAgent.m APIService.m AudioRecorderManager.m
    
echo "Successfully compiled recagent for iOS (ARM64)."

# --- 3. macOS Native Compilation (Development/Testing Target) ---
# Compiles for running directly on the Mac, necessary for local testing.
# -arch x86_64: Specifies the architecture for most development Macs.
xcrun --sdk macosx clang \
    -arch x86_64 \
    -framework Foundation \
    -framework AVFoundation \
    -o recagent-macos \
    main.m RecorderAgent.m APIService.m AudioRecorderManager.m

echo "Successfully compiled recagent-macos for development."

# --- 4. Post-Compilation Steps (iOS Target) ---
# Fake sign for deployment on non-standard iOS environments.
# The bundle ID (com.hoa.recagent) should match the expected service identifier.
ldid -Shq.bao.recagent.plist recagent

echo "Binary 'recagent' (iOS) is ready."
echo "Binary 'recagent-macos' (macOS) is ready for testing."

# Testing on macos during development
# Note: You may need 'sudo' to access microphone and file paths like /var/log/
# sudo ./recagent-macos