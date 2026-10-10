#!/usr/bin/env bash
# Package an existing ARMv7 .app into an unsigned IPA for jailbroken-device testing.
# This does not compile, sign, or guarantee installation.
set -euo pipefail
APP_PATH="${1:-.theos/_/Applications/OpenNDILegacy.app}"
OUT="${2:-packages/OpenNDILegacy-unsigned.ipa}"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi
if [[ ! -f "$APP_PATH/Info.plist" || ! -f "$APP_PATH/OpenNDILegacy" ]]; then
  echo "Incomplete .app: Info.plist or executable missing" >&2
  exit 1
fi
if ! command -v lipo >/dev/null 2>&1; then
  echo "lipo is required to verify ARMv7 architecture" >&2
  exit 1
fi
if ! lipo -info "$APP_PATH/OpenNDILegacy" | grep -q 'armv7'; then
  echo "Executable is not verified as ARMv7" >&2
  exit 1
fi
mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/Payload"
cp -R "$APP_PATH" "$TMP/Payload/"
(cd "$TMP" && zip -qr "$OUT" Payload)
echo "Created unsigned IPA: $OUT"
echo "Unsigned IPA is for compatible jailbreak installation methods only."
