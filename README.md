# OpenNDI Camera Legacy

Native iOS 9 / ARMv7 camera app for iPad mini 1 (jailbroken).

## v0.1 development baseline
- Native AVFoundation capture (Objective-C)
- Local preview disabled in Remote Camera mode
- Web MJPEG preview target: 10 FPS
- NDI transmission target: 30 FPS (not yet implemented; SDK compatibility/licensing pending)
- Local HTTP controls and dark-screen mode planned

**Status:** Initial source scaffold only. No compiled IPA or functional NDI sender yet. NDI binaries from third-party apps are not redistributed.

Build requirements: compatible legacy iOS SDK, ARMv7 toolchain and signing/installation path for iOS 9. Modern Xcode alone may not support ARMv7.
