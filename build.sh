#!/bin/bash
set -e

APP_NAME="OpenMagnet"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
# Ad-hoc sign ("-") by default so a fresh clone builds on any Mac with no
# Apple Developer account. Export SIGNING_IDENTITY to a real identity (e.g.
# "Apple Development: Your Name (TEAMID)") to keep the TCC Accessibility grant
# across rebuilds; ad-hoc changes the cdhash each build, so the grant resets.
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile. Host arch by default; set UNIVERSAL=1 for a fat arm64 + x86_64
# binary with a macOS 11 deployment target (used by the release workflow so
# the download runs on both Intel and Apple Silicon).
BIN="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
if [ "${UNIVERSAL:-}" = "1" ]; then
  swiftc -O -target arm64-apple-macos11  -framework Cocoa -framework Carbon -o "$BIN.arm64"  OpenMagnet.swift
  swiftc -O -target x86_64-apple-macos11 -framework Cocoa -framework Carbon -o "$BIN.x86_64" OpenMagnet.swift
  lipo -create -output "$BIN" "$BIN.arm64" "$BIN.x86_64"
  rm -f "$BIN.arm64" "$BIN.x86_64"
else
  swiftc -O -framework Cocoa -framework Carbon -o "$BIN" OpenMagnet.swift
fi

# Bundle the app icon
cp resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Sign the bundle (ad-hoc by default, or with $SIGNING_IDENTITY if exported).
codesign --force --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
codesign --verify --verbose "$APP_BUNDLE"

echo "Built and signed: $APP_BUNDLE"

# Install to ~/Applications via rsync (set INSTALL=0 to skip, e.g. in CI).
# With a stable SIGNING_IDENTITY the existing TCC Accessibility grant carries
# over; --delete prunes anything removed from the bundle.
if [ "${INSTALL:-1}" = "1" ]; then
  INSTALL_DIR="$HOME/Applications"
  mkdir -p "$INSTALL_DIR"
  rsync -a --delete "$APP_BUNDLE/" "$INSTALL_DIR/$APP_NAME.app/"
  echo "Installed:        $INSTALL_DIR/$APP_NAME.app"
  echo "Run:   open '$INSTALL_DIR/$APP_NAME.app'"
fi
