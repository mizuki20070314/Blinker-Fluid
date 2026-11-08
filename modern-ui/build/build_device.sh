#!/bin/bash
# Builds BlinkerModernUI.framework for iOS devices (arm64, iOS 12.0+) with the plain clang of the installed Xcode.
#   build_device.sh <output dir>
# No Swift (so no Swift runtime has to ship for iOS 12.0/12.1), no storyboards, no resources: everything is drawn in code.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?usage: build_device.sh <output dir>}"
VERSION="${BK_VERSION:-dev}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"

rm -rf "$OUT"
mkdir -p "$OUT/obj" "$OUT/BlinkerModernUI.framework"
COMMON=(-arch arm64 -miphoneos-version-min=12.0 -isysroot "$SDK")
CFLAGS=(-fobjc-arc -O2 -g0 -fvisibility=hidden -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations
        "-DBK_VERSION=\"${VERSION}\"" "-I$HERE/Sources/Core" "-I$HERE/Sources/Theme" "-I$HERE/Sources/Views" "-I$HERE/Sources/Hooks")

FAILED=0
while IFS= read -r source; do
  xcrun --sdk iphoneos clang "${COMMON[@]}" "${CFLAGS[@]}" -c "$source" -o "$OUT/obj/$(basename "${source%.m}").o" || FAILED=1
done < <(find "$HERE/Sources" -name '*.m' | sort)
if [ "$FAILED" != 0 ]; then
  echo "compile errors above"
  exit 1
fi

xcrun --sdk iphoneos clang "${COMMON[@]}" -dynamiclib -fobjc-arc \
  -install_name "@rpath/BlinkerModernUI.framework/BlinkerModernUI" \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics \
  -Wl,-dead_strip "$OUT"/obj/*.o -o "$OUT/BlinkerModernUI.framework/BlinkerModernUI"

cat > "$OUT/BlinkerModernUI.framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>BlinkerModernUI</string>
  <key>CFBundleIdentifier</key><string>jp.tank.blinkerfluid.modernui</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>BlinkerModernUI</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>MinimumOSVersion</key><string>12.0</string>
</dict>
</plist>
PLIST
echo "built $OUT/BlinkerModernUI.framework ($(du -h "$OUT/BlinkerModernUI.framework/BlinkerModernUI" | cut -f1))"
