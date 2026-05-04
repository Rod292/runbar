#!/bin/bash
# Empaquette RunBar dans un .app utilisable hors Xcode.
# Sans bundle identifier ni LSUIElement, macOS masque parfois la status item
# d'un binaire CLI — d'où ce wrapper.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/build/RunBar.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

echo "==> Build release"
cd "$ROOT"
swift build -c release

echo "==> Empaquetage dans $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"

# 1. Binaire
cp ".build/release/RunBar" "$MACOS/RunBar"
chmod +x "$MACOS/RunBar"

# 2. Resource bundle SwiftPM (frames PNG). Doit rester à côté du binaire dans
# MacOS/ pour que `Bundle.module` le trouve. On lui injecte un Info.plist
# minimal sinon codesign --deep le rejette ("bundle format unrecognized").
RESOURCE_BUNDLE=".build/release/RunBar_RunBar.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    DEST_BUNDLE="$MACOS/RunBar_RunBar.bundle"
    cp -R "$RESOURCE_BUNDLE" "$DEST_BUNDLE"
    cat > "$DEST_BUNDLE/Info.plist" <<'BPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.rodrigue.runbar.resources</string>
    <key>CFBundleName</key>
    <string>RunBar_RunBar</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
BPLIST
fi

# 3. Info.plist
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RunBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.rodrigue.runbar</string>
    <key>CFBundleName</key>
    <string>RunBar</string>
    <key>CFBundleDisplayName</key>
    <string>RunBar</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 4. Ad-hoc code signing — sans ça, macOS ne reconnaît pas l'app entre les
# runs et redemande à chaque fois le mot de passe du trousseau pour les
# items Keychain (Strava refresh token, etc.).
echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_DIR" 2>&1 | tail -3 || true

echo "==> RunBar.app prêt"
echo "    → $APP_DIR"
echo ""
echo "Lance avec : open '$APP_DIR'"
