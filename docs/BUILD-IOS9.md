# Building for iOS 9 / ARMv7

This repository targets a jailbroken iPad mini 1 with iOS 9.3.x. **No verified IPA is available yet.**

## Prerequisites

- macOS or a compatible Theos host with a functioning ARMv7-capable compiler.
- Theos installed and available as `$THEOS`.
- A legally obtained iPhoneOS 9.x SDK placed under `$THEOS/sdks/`.
- Legacy linker and signing tooling that actually supports 32-bit ARMv7.
- A device-side package installer for rootful jailbreak packages.

Modern GitHub-hosted macOS images do not automatically provide these prerequisites. Do not download or commit proprietary SDKs from untrusted sources.

## Commands

```sh
export THEOS=/path/to/theos
make clean
make package
```

The `Makefile` is a starting point, not a verified build configuration. The build may need legacy compiler/linker changes after a real toolchain is available.

## Installation

Theos `make package` normally produces a **.deb**, not an IPA. The package must be installed on the jailbroken device through a compatible package manager. An IPA build is a separate packaging and signing task, not yet implemented.

## Current limitations

- Web HTTP service currently binds to all interfaces on port 8088, without authentication. Use only on a trusted isolated Wi-Fi network.
- Web preview uses JPEG polling, not MJPEG.
- No NDI implementation or redistributable NDI SDK integrated.
- No focus/exposure/zoom controls yet.
- The web server currently handles connections serially; performance under load is not validated.
- Real iOS 9 camera permission and API behavior remain untested.

## Validation checklist

1. Verify actual ARMv7 binary: `lipo -info <binary>` or `file <binary>`.
2. Verify minimum deployment target is <= 9.3.x.
3. Install rootful .deb on the jailbroken iPad.
4. Grant camera permission, verify capture and local preview toggle.
5. From another device on the same trusted LAN, open `http://IP-DO-IPAD:8088/`.
6. Inspect `/api/status` and `/snapshot.jpg`.
7. Record CPU, battery and frame rate; no NDI performance claim before benchmarks.

## GitHub Actions build

The repository now includes two separate workflows:

- `legacy-preflight.yml`: checks source layout and metadata on a GitHub-hosted Ubuntu runner. Does not compile iOS code.
- `legacy-build.yml`: builds with `make clean package` on a **self-hosted macOS runner** labeled `ios9-armv7`, then packages an unsigned IPA and uploads both artifacts.

The build workflow will remain queued until a matching runner is online. Provision the runner yourself with a legitimate iOS 9 SDK and a working ARMv7 toolchain. No external download of Apple SDKs is automated by this repository.

This is infrastructure only; no build has been successfully verified on hardware yet.
