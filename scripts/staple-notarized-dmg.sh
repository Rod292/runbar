#!/bin/bash
# Check a notary submission and staple RunBar.dmg once Apple marks it Accepted.

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: scripts/staple-notarized-dmg.sh <submission-id>" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="$ROOT/build/RunBar.dmg"
WEBSITE_DOWNLOAD="$ROOT/website/public/download/RunBar.dmg"
PROFILE="${RUNBAR_NOTARY_PROFILE:-RunBarNotary}"
SUBMISSION_ID="$1"

xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "$PROFILE"

STATUS="$(xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "$PROFILE" 2>/dev/null | awk -F': ' '/status:/ {print $2; exit}')"
if [ "$STATUS" != "Accepted" ]; then
    echo "Not ready to staple. Current status: $STATUS" >&2
    exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vv -t open --context context:primary-signature "$DMG" || true

mkdir -p "$(dirname "$WEBSITE_DOWNLOAD")"
cp "$DMG" "$WEBSITE_DOWNLOAD"
echo "==> DMG publié vers $WEBSITE_DOWNLOAD"
