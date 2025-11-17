#!/bin/sh

# Remove old bin
rm -rf recagent
rm -rf recagent-macos

# Example cross-compilation command on a Mac
# This tells clang to compile for the ARM64 CPU (arch arm64) 
# using the iPhoneOS SDK, and link against the minimum version of iOS
xcrun --sdk iphoneos clang \
    -arch arm64 \
    -framework Foundation \
    -framework AVFoundation \
    -o recagent \
    main.m RecorderAgent.m APIService.m AudioRecorderManager.m

xcrun --sdk macosx clang \
    -arch x86_64 \
    -framework Foundation \
    -framework AVFoundation \
    -o recagent-macos \
    main.m RecorderAgent.m APIService.m AudioRecorderManager.m

# Fake sign for jailkroken iOS
ldid -Shq.bao.recagent.plist recagent

# Testing on macos during development
# sudo ./recagent-macos