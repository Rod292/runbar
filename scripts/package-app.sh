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

# 1b. Le binaire SwiftPM ne contient que `@loader_path` dans son rpath, qui
# pointe sur Contents/MacOS/. Il ne trouve donc pas Sparkle.framework qu'on
# embarque dans Contents/Frameworks/. On ajoute le rpath standard macOS
# `@executable_path/../Frameworks`. Doit être fait avant la signature, sinon
# install_name_tool casserait le code signing.
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/RunBar" 2>/dev/null || true

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
    <string>0.1.7</string>
    <key>CFBundleVersion</key>
    <string>8</string>
</dict>
</plist>
BPLIST
fi

# 3. AppIcon.icns
ICON_SRC="$ROOT/Sources/RunBar/Resources/AppIcon.icns"
if [ ! -f "$ICON_SRC" ]; then
    echo "==> Génération de l'AppIcon (placeholder)"
    "$ROOT/scripts/assets/build-iconset.sh"
fi
cp "$ICON_SRC" "$RES/AppIcon.icns"

# 4. Info.plist
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RunBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.rodrigue.runbar.app</string>
    <key>CFBundleName</key>
    <string>RunBar</string>
    <key>CFBundleDisplayName</key>
    <string>RunBar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.healthcare-fitness</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.7</string>
    <key>CFBundleVersion</key>
    <string>8</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://runbar.vercel.app/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUPublicEDKey</key>
    <string>JJWHXBIxpprgms6vm7YgvHiE4bO99FFE5nvWQvLQmtI=</string>
</dict>
</plist>
PLIST

# 5. Sparkle.framework — copié depuis l'artefact SwiftPM. Doit être embarqué
# dans Contents/Frameworks/ pour que le bundle soit lançable hors développement.
SPARKLE_XCFW="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ ! -d "$SPARKLE_XCFW" ]; then
    echo "==> Sparkle.framework introuvable — exécution de swift build pour le télécharger"
    swift build -c release >/dev/null
fi
mkdir -p "$CONTENTS/Frameworks"
rm -rf "$CONTENTS/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_XCFW" "$CONTENTS/Frameworks/Sparkle.framework"

# 6. Code signing. Par défaut on signe ad-hoc pour produire une app lançable.
# Pour éviter que macOS redemande l'accès Keychain à chaque rebuild, utilise
# une identité stable :
#   RUNBAR_CODESIGN_IDENTITY="RunBar Local Dev" scripts/package-app.sh
#
# IMPORTANT : on signe explicitement de l'intérieur vers l'extérieur. `--deep`
# ne signe pas correctement les XPC services Sparkle (déprécié par Apple) et
# ferait échouer la notarisation.
SIGN_IDENTITY="${RUNBAR_CODESIGN_IDENTITY:--}"
echo "==> Code signing ($SIGN_IDENTITY)"

SPARKLE_FW="$CONTENTS/Frameworks/Sparkle.framework"
SPARKLE_VERSION="$SPARKLE_FW/Versions/B"

# 6a. XPC services à l'intérieur de Sparkle
for xpc in "$SPARKLE_VERSION/XPCServices/"*.xpc; do
    [ -d "$xpc" ] || continue
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$xpc" 2>&1 | tail -1
done

# 6b. Updater.app et Autoupdate (helpers Sparkle)
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_VERSION/Updater.app" 2>&1 | tail -1
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_VERSION/Autoupdate" 2>&1 | tail -1

# 6c. Le framework lui-même
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_FW" 2>&1 | tail -1

# 6d. Resource bundle SwiftPM (s'il existe)
if [ -d "$MACOS/RunBar_RunBar.bundle" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$MACOS/RunBar_RunBar.bundle" 2>&1 | tail -1
fi

# 6e. Le binaire principal et l'app — en dernier
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$MACOS/RunBar" 2>&1 | tail -1
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR" 2>&1 | tail -1

echo "==> RunBar.app prêt"
echo "    → $APP_DIR"
echo ""
echo "Lance avec : open '$APP_DIR'"
