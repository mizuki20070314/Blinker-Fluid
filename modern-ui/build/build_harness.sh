#!/bin/bash
# Builds the simulator test app: the real modern-UI sources + a replica of the stock controller (see Harness/StockMock.m).
#   build_harness.sh <output dir> <path of shell_platform_delegate_ios.mm>
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?output dir}"
STOCK="${2:?stock source}"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

rm -rf "$OUT"
mkdir -p "$OUT/obj" "$OUT/Harness.app"
python3 "$HERE/Harness/extract_stock.py" "$STOCK" "$OUT/StockExtract.inc"

COMMON=(-arch arm64 -mios-simulator-version-min=13.0 -isysroot "$SDK")
CFLAGS=(-fobjc-arc -O0 -g -Wall -Wno-unused-parameter -Wno-deprecated-declarations -DBK_HARNESS=1 "-DBK_VERSION=\"harness\""
        "-I$HERE/Sources/Core" "-I$HERE/Sources/Theme" "-I$HERE/Sources/Views" "-I$HERE/Sources/Hooks" "-I$HERE/Harness" "-I$OUT")
FAILED=0
while IFS= read -r source; do
  xcrun --sdk iphonesimulator clang "${COMMON[@]}" "${CFLAGS[@]}" -c "$source" -o "$OUT/obj/$(basename "${source%.m}").o" || FAILED=1
done < <(find "$HERE/Sources" "$HERE/Harness" -name '*.m' | sort)
if [ "$FAILED" != 0 ]; then
  echo "compile errors above"
  exit 1
fi
xcrun --sdk iphonesimulator clang "${COMMON[@]}" -fobjc-arc -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics \
  "$OUT"/obj/*.o -o "$OUT/Harness.app/Harness"

cat > "$OUT/Harness.app/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Harness</string>
  <key>CFBundleIdentifier</key><string>jp.tank.bk.harness</string>
  <key>CFBundleName</key><string>Harness</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1</string>
  <key>UILaunchScreen</key><dict/>
  <key>UIRequiredDeviceCapabilities</key><array><string>arm64</string></array>
  <key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string></array>
</dict>
</plist>
PLIST
codesign --force --sign - "$OUT/Harness.app"
echo "built $OUT/Harness.app"
