#!/bin/bash
set -e

APP_NAME="OpenMagnet"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SIGNING_IDENTITY="Apple Development: Ishan Panta (TEAMID)"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# compile
swiftc -O -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
  -framework Cocoa \
  -framework Carbon \
  OpenMagnet.swift

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>OpenMagnet</string>
    <key>CFBundleIdentifier</key>
    <string>com.ishan.open-magnet</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>OpenMagnet</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>OpenMagnet uses Apple Events to move and resize the focused window of other apps.</string>
</dict>
</plist>
PLIST

# Sign with a stable Developer identity so TCC keeps the Automation grant
# across rebuilds. An unsigned binary's cdhash changes every build, and TCC
# silently drops grants whose identity no longer matches.
codesign --force --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
codesign --verify --verbose "$APP_BUNDLE"

echo "Built and signed: $APP_BUNDLE"
echo "Run:   open $APP_BUNDLE"
