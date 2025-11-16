# Tweak Name
TWEAK_NAME = MyHelloTweak

# Source File (Must be .xm for Objective-C++)
MyHelloTweak_FILES = Tweak.xm

# Compiler flags for ARC and C++ 
MyHelloTweak_CFLAGS = -fobjc-arc -std=gnu++17

# Set Target to a modern iOS version
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

# Architecture and Packaging settings for rootless jailbreaks
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
DPKG_ARCH = iphoneos-arm64

# CRITICAL FIX: Installation path for rootless jailbreaks
MyHelloTweak_INSTALL_PATH = /var/jb/Library/MobileSubstrate/DynamicLibraries

# Frameworks needed for the code
MyHelloTweak_FRAMEWORKS = UIKit Foundation CoreFoundation
MyHelloTweak_LIBRARIES = objc

# Inject into the SpringBoard process
MyHelloTweak_INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk