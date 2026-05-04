#!/bin/bash
# Génère/met à jour l'appcast.xml après un cycle make-dmg → notarize → staple.
# Doit être lancé après scripts/staple-notarized-dmg.sh.
#
# Usage: scripts/release-update.sh <version> "<release notes>"
# Exemple: scripts/release-update.sh 0.2.0 "Corrige le crash au démarrage."

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: scripts/release-update.sh <version> [release-notes]" >&2
    exit 1
fi

VERSION="$1"
NOTES="${2:-Mise à jour RunBar $VERSION}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="$ROOT/build/RunBar.dmg"
APPCAST="$ROOT/website/public/appcast.xml"
DOWNLOAD_DIR="$ROOT/website/public/download"
PUBLIC_BASE="${RUNBAR_DOWNLOAD_BASE:-https://runbar.vercel.app}"
SIGN_UPDATE="$ROOT/.build/artifacts/sparkle/Sparkle/bin/sign_update"

if [ ! -f "$DMG" ]; then
    echo "DMG manquant à $DMG — relance scripts/make-dmg.sh d'abord." >&2
    exit 1
fi

if [ ! -x "$SIGN_UPDATE" ]; then
    echo "==> sign_update introuvable — résolution Sparkle"
    swift package resolve >/dev/null
fi

# Versionne le DMG (RunBar-0.2.0.dmg) pour pouvoir héberger plusieurs releases.
VERSIONED_DMG_NAME="RunBar-$VERSION.dmg"
VERSIONED_DMG="$DOWNLOAD_DIR/$VERSIONED_DMG_NAME"
mkdir -p "$DOWNLOAD_DIR"
cp "$DMG" "$VERSIONED_DMG"
# On garde aussi la copie générique (lien stable "dernière version").
cp "$DMG" "$DOWNLOAD_DIR/RunBar.dmg"

echo "==> Signature Sparkle (EdDSA)"
SIGN_OUTPUT="$("$SIGN_UPDATE" "$VERSIONED_DMG")"
# sign_update affiche: sparkle:edSignature="..." length="..."
ED_SIGNATURE="$(echo "$SIGN_OUTPUT" | sed -nE 's/.*sparkle:edSignature="([^"]+)".*/\1/p')"
LENGTH="$(echo "$SIGN_OUTPUT" | sed -nE 's/.*length="([^"]+)".*/\1/p')"

if [ -z "$ED_SIGNATURE" ] || [ -z "$LENGTH" ]; then
    echo "Impossible d'extraire la signature Sparkle: $SIGN_OUTPUT" >&2
    exit 1
fi

PUBDATE="$(LC_TIME=en_US.UTF-8 date -u +"%a, %d %b %Y %H:%M:%S +0000")"

echo "==> Mise à jour de $APPCAST"
cat > "$APPCAST" <<APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>RunBar</title>
        <link>$PUBLIC_BASE/appcast.xml</link>
        <description>Mises à jour RunBar</description>
        <language>fr</language>
        <item>
            <title>Version $VERSION</title>
            <pubDate>$PUBDATE</pubDate>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <description><![CDATA[$NOTES]]></description>
            <enclosure
                url="$PUBLIC_BASE/download/$VERSIONED_DMG_NAME"
                sparkle:edSignature="$ED_SIGNATURE"
                length="$LENGTH"
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
APPCAST_EOF

echo "==> Release prête"
echo "    DMG → $VERSIONED_DMG"
echo "    Appcast → $APPCAST"
echo "    Signature: $ED_SIGNATURE"
echo ""
echo "Prochaine étape : commit & push website/, puis déploie Vercel."
