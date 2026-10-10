# Roadmap

## Phase 1: camera and build
- [x] Minimal Objective-C AVFoundation source scaffold
- [ ] Establish reproducible ARMv7/iOS 9 build and installable IPA
- [ ] Camera authorization/error UI, camera switching and focus/exposure controls
- [ ] Move session start/stop off the main thread

## Phase 2: remote control
- [ ] Local HTTP server with access token
- [ ] MJPEG preview, target 10 FPS
- [ ] Focus/exposure/zoom remote endpoints with hardware capability checks
- [ ] Remote Camera mode: 0 FPS local preview, minimum brightness, foreground operation

## Phase 3: NDI
- [ ] Identify legally distributable iOS 9 ARMv7 NDI SDK or alternative
- [ ] Implement native NDI sender with target 30 FPS
- [ ] Benchmark capture, web preview, battery and temperature
- [ ] GitHub Actions build once legacy toolchain is validated

No proprietary framework extracted from another application may be committed without distribution rights.
