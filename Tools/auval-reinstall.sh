#!/usr/bin/env bash
# auval-reinstall.sh — build Synt (Debug, DerivedData ~/.synt_dd), install to /Applications,
# re-register the AUv3 extensions and run auval for both AUs with retries.
#
# Usage:  Tools/auval-reinstall.sh            # build + install + auval
#         SKIP_BUILD=1 Tools/auval-reinstall.sh   # just reinstall the last build + auval
# Gate note: unit tests + Init/Factory goldens + this auval are the mandatory round gate; UITests are not.
set -uo pipefail
cd "$(dirname "$0")/.."
DD="${DD:-$HOME/.synt_dd}"
APP_SRC="$DD/Build/Products/Debug/Synt_swiftUI.app"
APP=/Applications/Synt_swiftUI.app
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if [[ -z "${SKIP_BUILD:-}" ]]; then
  xcodebuild build -scheme Synt_swiftUI -configuration Debug -destination 'platform=macOS' \
    -derivedDataPath "$DD" 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | tail -5
  [[ ${PIPESTATUS[0]} -eq 0 ]] || { echo "build failed"; exit 1; }
fi
[[ -d "$APP_SRC" ]] || { echo "no build at $APP_SRC"; exit 1; }

killall Synt_swiftUI 2>/dev/null || true
rm -rf "$APP" && cp -R "$APP_SRC" /Applications/
"$LSREG" -f "$APP"
pluginkit -a "$APP"/Contents/PlugIns/*.appex 2>/dev/null || true
open -g "$APP"; sleep 5
killall -9 AudioComponentRegistrar 2>/dev/null || true; sleep 2

rc=0
for au in "aumu Synt Nixr" "aumi Arp1 Nixr"; do
  ok=0
  for try in 1 2 3; do
    # shellcheck disable=SC2086
    if auval -v $au 2>&1 | grep -q "AU VALIDATION SUCCEEDED"; then ok=1; break; fi
    echo "$au: try $try failed (e.g. 4097 / not found) — kicking registrar"
    killall -9 AudioComponentRegistrar 2>/dev/null || true; sleep 5
  done
  if [[ $ok -eq 1 ]]; then echo "$au: AU VALIDATION SUCCEEDED"; else echo "$au: FAILED"; rc=1; fi
done
exit $rc
