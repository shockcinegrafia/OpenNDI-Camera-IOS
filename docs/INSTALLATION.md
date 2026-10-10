# Installation and packaging

The iPad mini 1 runs ARMv7 and supports iOS 9. The project must first compile into a valid **ARMv7** iOS application bundle.

## Option A: rootful jailbreak .deb

With a compatible Theos + legacy SDK environment:

```bash
make clean package
```

Inspect the resulting `packages/*.deb` and install it with a package manager compatible with the device's jailbreak. A successful package build does not guarantee camera/NDI functionality.

## Option B: unsigned .ipa

Once a valid `.app` exists:

```bash
bash scripts/package-ipa.sh .theos/_/Applications/OpenNDILegacy.app packages/OpenNDILegacy-unsigned.ipa
```

This produces a conventional `Payload/OpenNDILegacy.app` archive. **It is unsigned.** Installation requires a compatible signing or jailbreak installation method, and cannot be guaranteed by this script.

The script checks for an ARMv7 executable but cannot certify minimum deployment target, runtime compatibility, entitlements or dependencies.

Do not rename a .deb to .ipa; these are different package formats.

## Current project status

Source code and packaging scripts exist. There is no verified build output or installable artifact yet.
