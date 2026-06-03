#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
PAYLOAD_DIR="$BUILD_DIR/Payload"
APP_PATH="$BUILD_DIR/Build/Products/Release-iphoneos/XiBubble.app"
IPA_PATH="$DIST_DIR/XiBubble.ipa"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild was not found. Build this on macOS with Xcode installed."
  exit 1
fi

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/XiBubble.xcodeproj" \
  -scheme XiBubble \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [ ! -d "$APP_PATH" ]; then
  echo "Build finished, but XiBubble.app was not found at $APP_PATH"
  exit 1
fi

if command -v ldid >/dev/null 2>&1; then
  ldid -S "$APP_PATH/XiBubble"
  if [ -f "$APP_PATH/PlugIns/XiBubbleShare.appex/XiBubbleShare" ]; then
    ldid -S "$APP_PATH/PlugIns/XiBubbleShare.appex/XiBubbleShare"
  fi
else
  echo "ldid not found; packaging unsigned app. Install ldid for a cleaner TrollStore IPA."
fi

mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

(cd "$BUILD_DIR" && /usr/bin/zip -qry "$IPA_PATH" Payload)
echo "Created $IPA_PATH"

