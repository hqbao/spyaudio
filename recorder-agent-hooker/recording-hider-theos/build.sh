# Remove old bin
rm -rf RecordingHider.dylib

xcrun --sdk iphoneos clang \
    -arch arm64 \
    -shared \
    -o RecordingHider.dylib \
    Tweak.m \
    -framework Foundation \
    -framework UIKit \
    -lobjc \
    -install_name /Library/TweakLoader/RecordingHider.dylib