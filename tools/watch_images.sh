#!/bin/bash
# Keeps the emulator and simulator photo libraries in step with images/ and
# the shared ../images beside the project:
#
#   tools/watch_images.sh install     start watching (also after every login)
#   tools/watch_images.sh uninstall   stop watching
#   tools/watch_images.sh status      is it running, and its latest output
#
# A macOS launch agent runs tools/sync_images.sh whenever something in images/
# changes, and every two minutes too, so a device booted later still gets
# every picture.

set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL=com.dailyjumble.blujem.image-sync
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$ROOT/tools/.image-sync/sync.log"

case "${1:-status}" in
  install)
    mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$ROOT/tools/sync_images.sh</string></array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string></dict>
  <key>WatchPaths</key><array><string>$ROOT/images</string><string>$(dirname "$ROOT")/images</string></array>
  <key>StartInterval</key><integer>120</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    echo "Watching $ROOT/images and $(dirname "$ROOT")/images — new pictures go to the running emulator and simulator."
    ;;
  uninstall)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Stopped watching."
    ;;
  status)
    if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then echo "Watching."; else echo "Not watching."; fi
    [ -f "$LOG" ] && tail -5 "$LOG"
    ;;
  *) echo "usage: $0 install|uninstall|status" >&2; exit 2 ;;
esac
