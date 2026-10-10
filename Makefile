TARGET := iphone:clang:9.3:9.0
ARCHS := armv7
THEOS_PACKAGE_SCHEME := rootful

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = OpenNDILegacy
OpenNDILegacy_FILES = ios/OpenNDILegacy/main.m ios/OpenNDILegacy/AppDelegate.m ios/OpenNDILegacy/CameraViewController.m ios/OpenNDILegacy/CameraFrameStore.m ios/OpenNDILegacy/RemoteHTTPServer.m
OpenNDILegacy_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo CoreGraphics CoreImage
OpenNDILegacy_CFLAGS = -fobjc-arc
OpenNDILegacy_RESOURCE_FILES = ios/OpenNDILegacy/Info.plist

include $(THEOS_MAKE_PATH)/application.mk
