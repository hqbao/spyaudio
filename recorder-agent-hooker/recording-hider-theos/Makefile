# Tweak Name
TWEAK_NAME = recagenthooker

# Source File (Must be .xm for Objective-C++)
recagenthooker_FILES = Tweak.xm

# Compiler flags for ARC and C++ 
recagenthooker_CFLAGS = -fobjc-arc -std=gnu++17

# Set Target to a modern iOS version
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

# Architecture and Packaging settings for rootless jailbreaks
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
DPKG_ARCH = iphoneos-arm64

# CRITICAL FIX: Installation path for rootless jailbreaks
recagenthooker_INSTALL_PATH = $(THEOS_DEVICE_JB_PATH)/Library/MobileSubstrate/DynamicLibraries

# Frameworks needed for the code
recagenthooker_FRAMEWORKS = UIKit Foundation CoreFoundation
recagenthooker_LIBRARIES = objc

# Inject into the SpringBoard process
recagenthooker_INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk