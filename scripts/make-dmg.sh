#!/usr/bin/env bash
# Build a drag-to-Applications DMG.
# Usage: make-dmg.sh <path/to/App.app> <path/to/output.dmg>
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <App.app> <output.dmg>" >&2
  exit 1
fi

APP="$1"
DMG="$2"
NAME="$(basename "$APP" .app)"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "DMG written to: $DMG"
