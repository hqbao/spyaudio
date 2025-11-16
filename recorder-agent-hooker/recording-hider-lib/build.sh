#!/bin/bash
# Remove old binaries
rm -rf RecordingHider.dylib

# Build for iOS
xcrun --sdk iphoneos clang -arch arm64 -arch arm64e -shared \
    -fobjc-arc \
    -framework Foundation \
    -framework UIKit \
    Tweak.m \
    -o RecordingHider.dylib

if [ -f "RecordingHider.dylib" ]; then
    echo "✅ Build successful! RecordingHider.dylib created."
    echo "📦 File size: $(stat -f%z RecordingHider.dylib) bytes"
else
    echo "❌ Build failed!"
    exit 1
fi