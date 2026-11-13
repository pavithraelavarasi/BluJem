#!/bin/bash
# Builds ios/ZohoSim/ZohoPortalAuthKit.framework: Zoho's sign-in library with
# its arm64 objects re-tagged for the iOS Simulator, so the app runs on
# Apple Silicon simulators (iOS 26+ has no Rosetta). Simulator builds only;
# device builds keep using the original from Pods. Run after `pod install`.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=ios/Pods/ZohoPortalAuth/ZohoPortalAuthKit.framework
OUT=ios/ZohoSim/ZohoPortalAuthKit.framework
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

lipo -thin arm64 "$SRC/ZohoPortalAuthKit" -output "$WORK/arm64.a"
mkdir "$WORK/objs" "$WORK/sim"
(cd "$WORK/objs" && ar -x ../arm64.a)
for o in "$WORK"/objs/*.o; do
  python3 -I tool/arm64_to_sim.py "$o" "$WORK/sim/$(basename "$o")"
done
xcrun libtool -static -o "$WORK/arm64-sim.a" "$WORK"/sim/*.o 2>/dev/null
# Intel simulators keep Zoho's own x86_64 slice.
lipo -thin x86_64 "$SRC/ZohoPortalAuthKit" -output "$WORK/x86_64.a"

rm -rf "$OUT" && mkdir -p "$OUT"
cp -R "$SRC/Headers" "$OUT/"
lipo -create "$WORK/arm64-sim.a" "$WORK/x86_64.a" -output "$OUT/ZohoPortalAuthKit"
echo "Built $OUT"
