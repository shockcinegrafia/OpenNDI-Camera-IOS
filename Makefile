TARGET := iphone:clang:9.3:9.0
ARCHS := armv7
include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = OpenNDILegacy
OpenNDILegacy_FILES = ios/OpenNDILegacy/main.m ios/OpenNDILegacy/AppDelegate.m ios/OpenNDILegacy/CameraViewController.m ios/OpenNDILegacy/CameraFrameStore.m ios/OpenNDILegacy/RemoteHTTPServer.m ios/OpenNDILegacy/CameraControl.m
OpenNDILegacy_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo CoreGraphics CoreImage
OpenNDILegacy_CFLAGS = -fobjc-arc -fno-modules -Wno-error=deprecated-module-dot-map
OpenNDILegacy_INFOPLIST_FILE = ios/OpenNDILegacy/Info.plist
OpenNDILegacy_RESOURCE_FILES = ios/OpenNDILegacy/Info.plist ios/OpenNDILegacy/index_full.html ios/OpenNDILegacy/index_lite.html ios/OpenNDILegacy/legacy.js

include $(THEOS_MAKE_PATH)/application.mk
