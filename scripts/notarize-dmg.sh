#!/bin/bash
# Submit the DMG to Apple's notary service and staple the ticket when accepted.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="$ROOT/build/RunBar.dmg"
PROFILE="${RUNBAR_NOTARY_PROFILE:-RunBarNotary}"

if [ ! -f "$DMG" ]; then
    echo "Missing $DMG. Run scripts/make-dmg.sh first." >&2
    exit 1
fi

echo "==> Submit $DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> Staple ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

WEBSITE_DOWNLOAD="$ROOT/website/public/download/RunBar.dmg"
mkdir -p "$(dirname "$WEBSITE_DOWNLOAD")"
cp "$DMG" "$WEBSITE_DOWNLOAD"
echo "==> DMG publié vers $WEBSITE_DOWNLOAD"
