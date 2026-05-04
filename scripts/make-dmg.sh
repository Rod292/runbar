#!/bin/bash
# Build RunBar.app, then package it as a simple drag-to-Applications DMG.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/RunBar.app"
DMG_DIR="$ROOT/build/dmg"
DMG_NAME="RunBar.dmg"
DMG_PATH="$ROOT/build/$DMG_NAME"
WEBSITE_DOWNLOAD="$ROOT/website/public/download/$DMG_NAME"

"$ROOT/scripts/package-app.sh"

echo "==> Préparation du volume DMG"
rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR"
cp -R "$APP" "$DMG_DIR/RunBar.app"
ln -s /Applications "$DMG_DIR/Applications"

echo "==> Création de $DMG_PATH"
hdiutil create \
  -volname "RunBar" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

mkdir -p "$(dirname "$WEBSITE_DOWNLOAD")"
cp "$DMG_PATH" "$WEBSITE_DOWNLOAD"

echo "==> DMG prêt"
echo "    → $DMG_PATH"
echo "    → $WEBSITE_DOWNLOAD"
