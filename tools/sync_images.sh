#!/bin/bash
# Copies every picture in images/ (and the shared ../images beside the project)
# that a running emulator or simulator does not have yet into its photo library, so it can be picked on the Upload tab.
#
# Safe to run any time: devices that are off are skipped, and a picture is
# only added once per device (tools/.image-sync/ remembers what each has).
# Run by hand, or automatically by tools/watch_images.sh install.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The project's own folder first; a name found in both is copied once.
FOLDERS=("$ROOT/images" "$(dirname "$ROOT")/images")
STATE="$ROOT/tools/.image-sync"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
ANDROID_DIR=/sdcard/Pictures/BluJem
mkdir -p "$STATE"
shopt -s nullglob nocaseglob

pictures=()
seen=" "
for dir in "${FOLDERS[@]}"; do
  for f in "$dir"/*.{png,jpg,jpeg,heic,webp}; do
    case "$seen" in *" $(basename "$f") "*) continue ;; esac
    seen="$seen$(basename "$f") "
    pictures+=("$f")
  done
done
if [ ${#pictures[@]} -eq 0 ]; then
  # Seen when macOS keeps this background job out of the folders (Privacy &
  # Security), which looks the same as an empty folder from in here.
  echo "$(date '+%F %T') no pictures readable in ${FOLDERS[*]}"
  exit 0
fi

# A picture's identity: its name and when it was last changed, so a replaced
# file is copied again.
stamp() { echo "$(basename "$1")|$(stat -f %m "$1")"; }

# The first time a device is seen, the pictures it already holds (names read
# from it, one per line on stdin) count as had.
seed() {
  [ -e "$1" ] && { cat >/dev/null; return; }
  local have
  have="$(cat)"
  touch "$1"
  for f in "${pictures[@]}"; do
    grep -qxF "$(basename "$f")" <<<"$have" && stamp "$f" >> "$1"
  done
}

# The pictures in images/ that the device behind state file $1 has not had.
missing() {
  touch "$1"
  for f in "${pictures[@]}"; do
    grep -qxF "$(stamp "$f")" "$1" || echo "$f"
  done
}

# ------------------------------------------------------------ simulators
while read -r udid; do
  [ -z "$udid" ] && continue
  record="$STATE/ios-$udid"
  sqlite3 "$HOME/Library/Developer/CoreSimulator/Devices/$udid/data/Media/PhotoData/Photos.sqlite" \
    "select ZORIGINALFILENAME from ZADDITIONALASSETATTRIBUTES" 2>/dev/null | seed "$record"
  new=()
  while IFS= read -r f; do new+=("$f"); done < <(missing "$record")
  [ ${#new[@]} -eq 0 ] && continue
  if xcrun simctl addmedia "$udid" "${new[@]}"; then
    for f in "${new[@]}"; do stamp "$f" >> "$record"; done
    echo "simulator $udid: added ${#new[@]} picture(s)"
  fi
done < <(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}')

# ------------------------------------------------------------- emulators
if [ -x "$ADB" ]; then
  while read -r serial; do
    [ -z "$serial" ] && continue
    record="$STATE/android-$serial"
    "$ADB" -s "$serial" shell ls "$ANDROID_DIR" 2>/dev/null | tr -d '\r' | seed "$record"
    new=()
    while IFS= read -r f; do new+=("$f"); done < <(missing "$record")
    [ ${#new[@]} -eq 0 ] && continue
    "$ADB" -s "$serial" shell mkdir -p "$ANDROID_DIR"
    added=0
    for f in "${new[@]}"; do
      if "$ADB" -s "$serial" push "$f" "$ANDROID_DIR/" >/dev/null 2>&1; then
        stamp "$f" >> "$record"
        added=$((added + 1))
      fi
    done
    # Tell the gallery about them; done on the device, where names with spaces
    # and brackets need no escaping.
    "$ADB" -s "$serial" shell "for f in $ANDROID_DIR/*; do am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d \"file://\$f\" >/dev/null; done"
    echo "emulator $serial: added $added picture(s)"
  done < <("$ADB" devices | awk '$2 == "device" && $1 ~ /^emulator-/ {print $1}')
fi
