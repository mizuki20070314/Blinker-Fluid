#!/bin/bash
# Runs the harness on a simulator once per variant and collects the pictures.
#   run_harness.sh <Harness.app> <output dir>
set -euo pipefail
APP="${1:?Harness.app}"
OUT="${2:?output dir}"
mkdir -p "$OUT"

UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
best = None
for runtime in sorted(d):
    if "iOS" not in runtime:
        continue
    for dev in d[runtime]:
        if dev.get("isAvailable") and dev["name"].startswith("iPhone"):
            best = dev["udid"]
print(best or "")
')"
if [ -z "$UDID" ]; then
  echo "no iPhone simulator available"
  exit 1
fi
echo "simulator: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"

for variant in ${BK_VARIANTS:-light dark bottom private ja landscape guardtest imetest}; do
  echo "== variant $variant"
  xcrun simctl launch "$UDID" jp.tank.bk.harness -bk-variant "$variant" >/dev/null
  CONTAINER="$(xcrun simctl get_app_container "$UDID" jp.tank.bk.harness data)"
  for _ in $(seq 1 90); do
    [ -f "$CONTAINER/Documents/shots/$variant.done" ] && break
    sleep 1
  done
  if [ ! -f "$CONTAINER/Documents/shots/$variant.done" ]; then
    echo "variant $variant did not finish"
  fi
  xcrun simctl terminate "$UDID" jp.tank.bk.harness 2>/dev/null || true
done
CONTAINER="$(xcrun simctl get_app_container "$UDID" jp.tank.bk.harness data)"
cp -R "$CONTAINER/Documents/shots/." "$OUT/"
if [ -f "$CONTAINER/Documents/ModernUI.log" ]; then
  cp "$CONTAINER/Documents/ModernUI.log" "$OUT/ModernUI.log"
fi
ls -la "$OUT" | head -100

# The checks the harness made about the layout, the stock hand-over (fullscreen, keyboard) and the crash guard.
echo "== checks"
cat "$OUT"/*-checks.txt
if grep -q "^FAIL" "$OUT"/*-checks.txt; then
  echo "some checks FAILED"
  exit 1
fi
if [ "$(grep -c '^PASS' "$OUT"/guardtest-checks.txt)" -lt 10 ]; then
  echo "the guard test did not run completely"
  exit 1
fi
if [ "$(grep -c '^PASS' "$OUT"/imetest-checks.txt)" -lt 30 ]; then
  echo "the input-method test did not run completely"
  exit 1
fi
# A step that threw would leave no FAIL line behind, so count what passed in the layout variants too.
for variant in light dark bottom private ja landscape; do
  if [ -f "$OUT/$variant-checks.txt" ] && [ "$(grep -c '^PASS' "$OUT/$variant-checks.txt")" -lt 28 ]; then
    echo "the $variant run did not complete all of its checks"
    exit 1
  fi
done
