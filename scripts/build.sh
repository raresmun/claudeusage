#!/usr/bin/env bash
# Local development build. Produces an unsigned ClaudeUsage.app.
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p build

xcodebuild build \
  -project ClaudeUsage.xcodeproj \
  -scheme ClaudeUsage \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

APP=$(find build/DerivedData/Build/Products -name "ClaudeUsage.app" -type d | head -n 1)

if [[ -z "$APP" ]]; then
  echo "Build succeeded but no .app produced. Check derived data." >&2
  exit 1
fi

echo ""
echo "Built: $APP"
echo "Run:   open \"$APP\""
