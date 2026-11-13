#!/bin/bash
# Publishes a new Android version of BluJem: every installed copy — and the
# old Daily Jumble app it replaces — offers it the next time it is opened
# ("BluJem x is here" → Update), with no store and no reinstall.
#
#   tools/publish_update.sh "What's new, in one line"
#
# What it does:
#   1. raises the version in pubspec.yaml (1.21.0+22 → 1.22.0+23)
#      (NO_BUMP=1 to publish the version as it stands)
#   2. runs the tests and builds the release APK, signed with the release key
#      from android/local.properties (the Daily Jumble key, so it installs over it)
#   3. signs in as an admin, uploads the APK and publishes it
#   4. copies it to ~/WFH/BluJem-<version>.apk, moving older ones to ~/WFH/oldversions
#
# Admin sign-in: BLUJEM_ADMIN_EMAIL and BLUJEM_ADMIN_PASSWORD, or asked for.
# UPDATE_SERVER=…/server to publish on another server (e.g. the old DailyJumble one).
# GRADLE_INIT=tools/maven_mirror.init.gradle when Maven Central is unreachable.
# Nothing is published if any step fails.

set -euo pipefail
cd "$(dirname "$0")/.."

NOTES="${1:-}"
# The server whose installed copies should be offered the update. Copies up to
# 1.26.0 still ask the old DailyJumble server; 1.27.0 and later ask BluJem's.
BASE="${UPDATE_SERVER:-https://blujem-60093843442.development.catalystserverless.in/server}"
SHARE_DIR="$HOME/WFH"
export LANG=en_US.UTF-8
command -v flutter >/dev/null || export PATH="$HOME/development/flutter/bin:$PATH"

json() { python3 -c "import sys,json; d=json.load(sys.stdin); print(d$1)"; }

version=$(sed -n 's/^version: \([0-9.]*\)+\([0-9]*\)$/\1 \2/p' pubspec.yaml)
read -r NAME CODE <<<"$version"
if [ "${NO_BUMP:-0}" != "1" ]; then
    new_name=$(python3 -c "a,b,c='$NAME'.split('.'); print(f'{a}.{int(b)+1}.0')")
    sed -i '' "s/^version: $NAME+$CODE$/version: $new_name+$((CODE + 1))/" pubspec.yaml
    echo "Version $NAME ($CODE) → $new_name ($((CODE + 1)))"
    NAME=$new_name CODE=$((CODE + 1))
fi

echo "Testing and building ${NAME}…"
flutter test
if [ -n "${GRADLE_INIT:-}" ]; then
    sed -i '' -E "s/^flutter\.versionName=.*/flutter.versionName=$NAME/; s/^flutter\.versionCode=.*/flutter.versionCode=$CODE/" android/local.properties
    (cd android && ./gradlew -q --init-script "$(cd .. && pwd)/$GRADLE_INIT" assembleRelease)
else
    flutter build apk --release
fi
APK=build/app/outputs/flutter-apk/app-release.apk
BT=$(ls -d "$(grep '^sdk.dir=' android/local.properties | cut -d= -f2)"/build-tools/* | sort -V | tail -1)
"$BT/apksigner" verify "$APK" || { echo "The APK is not signed; check the release keystore in android/local.properties."; exit 1; }
# Read in full first: grep -q stops at the first match, which cuts aapt2 off
# mid-write and, under pipefail, fails the check on a good APK.
BADGING=$("$BT/aapt2" dump badging "$APK")
grep -q "name='com.dailyjumble.app' versionCode='$CODE'" <<<"$BADGING" \
    || { echo "The APK is not com.dailyjumble.app version $CODE."; exit 1; }
SHA=$(shasum -a 256 "$APK" | cut -d' ' -f1)
SIZE=$(stat -f %z "$APK")

EMAIL="${BLUJEM_ADMIN_EMAIL:-}"
PASSWORD="${BLUJEM_ADMIN_PASSWORD:-}"
[ -n "$EMAIL" ] || read -r -p "Admin email: " EMAIL
[ -n "$PASSWORD" ] || { read -r -s -p "Admin password: " PASSWORD; echo; }
LOGIN=$(python3 -c 'import json,sys; print(json.dumps({"email": sys.argv[1], "password": sys.argv[2]}))' "$EMAIL" "$PASSWORD")
TOKEN=$(curl -sf -X POST "$BASE/jumble_auth/execute/login" -H 'Content-Type: application/json' -d "$LOGIN" | json '["token"]') \
    || { echo "Admin sign-in failed."; exit 1; }

echo "Uploading $(basename "$APK") ($((SIZE / 1024 / 1024)) MB)…"
UP=$(curl -s -X POST "$BASE/blujem_daily/execute/app-upload-url" -H "x-jumble-token: $TOKEN" \
    -H 'Content-Type: application/json' -d "{\"versionCode\":$CODE,\"versionName\":\"$NAME\"}")
URL=$(echo "$UP" | json '.get("uploadUrl","")')
[ -n "$URL" ] || { echo "No upload link: $UP"; exit 1; }
# Stratus refuses a signed upload sent without a Content-Type.
HTTP=$(curl -s -o /dev/null -w '%{http_code}' -X PUT -T "$APK" \
    -H 'Content-Type: application/vnd.android.package-archive' -H 'overwrite: true' "$URL")
[ "$HTTP" = "200" ] || { echo "Upload failed (HTTP $HTTP)."; exit 1; }

BODY=$(python3 -c 'import json,sys; print(json.dumps({"versionCode": int(sys.argv[1]), "versionName": sys.argv[2], "sha256": sys.argv[3], "size": int(sys.argv[4]), "notes": sys.argv[5]}))' \
    "$CODE" "$NAME" "$SHA" "$SIZE" "$NOTES")
PUB=$(curl -s -X POST "$BASE/blujem_daily/execute/app-publish" -H "x-jumble-token: $TOKEN" -H 'Content-Type: application/json' -d "$BODY")
[ "$(echo "$PUB" | json '.get("status","")')" = "success" ] || { echo "Publish failed: $PUB"; exit 1; }

mkdir -p "$SHARE_DIR/oldversions"
for old in "$SHARE_DIR"/BluJem-*.apk; do [ -e "$old" ] && mv "$old" "$SHARE_DIR/oldversions/"; done
cp "$APK" "$SHARE_DIR/BluJem-$NAME.apk"

echo "Published BluJem $NAME (versionCode $CODE)."
echo "Every installed copy offers it the next time it is opened. A copy for sharing: $SHARE_DIR/BluJem-$NAME.apk"
