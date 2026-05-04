#!/bin/bash
# Build RunBar.app, then package it as a customized drag-to-Applications DMG.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/RunBar.app"
DMG_STAGING="$ROOT/build/dmg-staging"
DMG_NAME="RunBar.dmg"
DMG_PATH="$ROOT/build/$DMG_NAME"
DMG_BACKGROUND="$ROOT/scripts/assets/dmg/background.png"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg manquant. Installer avec: brew install create-dmg" >&2
    exit 1
fi

"$ROOT/scripts/package-app.sh"

if [ ! -f "$DMG_BACKGROUND" ]; then
    echo "==> Génération du background DMG"
    swift "$ROOT/scripts/assets/generate-dmg-background.swift" "$DMG_BACKGROUND" 1
    swift "$ROOT/scripts/assets/generate-dmg-background.swift" "${DMG_BACKGROUND%.png}@2x.png" 2
fi

echo "==> Préparation du dossier source DMG"
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP" "$DMG_STAGING/RunBar.app"

echo "==> Création du DMG"
create-dmg \
    --volname "RunBar" \
    --background "$DMG_BACKGROUND" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 128 \
    --icon "RunBar.app" 150 200 \
    --hide-extension "RunBar.app" \
    --app-drop-link 450 200 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$DMG_STAGING" >/dev/null

SIGN_IDENTITY="${RUNBAR_CODESIGN_IDENTITY:-}"
if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    echo "==> Signature DMG ($SIGN_IDENTITY)"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
fi

echo "==> DMG prêt"
echo "    → $DMG_PATH"
echo "    Étape suivante : scripts/notarize-dmg.sh"
