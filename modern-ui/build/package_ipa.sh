#!/bin/bash
# Puts the modern UI into a copy of the released IPA.
#   package_ipa.sh <base.ipa> <BlinkerModernUI.framework> <output.ipa> <build number>
# The base app is not touched except for: the framework is added, the executable gets one more LC_LOAD_DYLIB (and is signed
# again with its ORIGINAL entitlements), and CFBundleVersion gets the build number.  Needs ldid (brew install ldid).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(cd "$(dirname "${1:?base ipa}")" && pwd)/$(basename "$1")"
FRAMEWORK="$(cd "$(dirname "${2:?framework}")" && pwd)/$(basename "$2")"
OUT="${3:?output ipa}"
BUILD="${4:-0}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -q "$BASE" -d "$WORK/ipa"
APP="$(echo "$WORK"/ipa/Payload/*.app)"
EXE="$APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
echo "app: $APP"
echo "executable: $EXE"

ldid -e "$EXE" > "$WORK/original.entitlements.xml"
echo "original entitlements:"
cat "$WORK/original.entitlements.xml"

mkdir -p "$APP/Frameworks"
rm -rf "$APP/Frameworks/BlinkerModernUI.framework"
cp -R "$FRAMEWORK" "$APP/Frameworks/BlinkerModernUI.framework"
ldid -S "$APP/Frameworks/BlinkerModernUI.framework/BlinkerModernUI"

python3 "$HERE/tools/inject_dylib.py" "$EXE" "@rpath/BlinkerModernUI.framework/BlinkerModernUI"
ldid -S"$WORK/original.entitlements.xml" "$EXE"

BASE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BASE_VERSION%%+*}.${BUILD}" "$APP/Info.plist"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
ABS_OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
( cd "$WORK/ipa" && zip -qry9 "$ABS_OUT" Payload )
echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
