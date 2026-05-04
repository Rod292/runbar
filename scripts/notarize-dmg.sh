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

echo "==> Gatekeeper check"
spctl -a -vv --type open "$DMG"
