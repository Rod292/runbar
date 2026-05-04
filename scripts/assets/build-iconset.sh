#!/bin/bash
# Génère AppIcon.icns à partir du PNG 1024x1024 produit par generate-icon.swift.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Source de vérité du logo. Si présent on l'utilise tel quel, sinon fallback
# sur le placeholder généré.
LOGO_SRC="$ROOT/scripts/assets/source-icon.png"
SOURCE_PNG="$ROOT/build/AppIcon-1024.png"
ICONSET_DIR="$ROOT/build/AppIcon.iconset"
ICNS_OUT="$ROOT/Sources/RunBar/Resources/AppIcon.icns"

mkdir -p "$ROOT/build"
if [ -f "$LOGO_SRC" ]; then
    echo "==> Source logo trouvée — redimensionnement à 1024"
    sips -z 1024 1024 "$LOGO_SRC" --out "$SOURCE_PNG" >/dev/null
elif [ ! -f "$SOURCE_PNG" ]; then
    echo "==> Génération du PNG placeholder"
    swift "$ROOT/scripts/assets/generate-icon.swift" "$SOURCE_PNG"
fi

echo "==> Construction de l'iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Tailles requises par iconutil — chaque @2x est le double de la taille de base.
declare -a SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for entry in "${SIZES[@]}"; do
    SIZE="${entry%%:*}"
    NAME="${entry##*:}"
    sips -z "$SIZE" "$SIZE" "$SOURCE_PNG" --out "$ICONSET_DIR/$NAME" >/dev/null
done

echo "==> Compilation .icns"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUT"

echo "==> AppIcon.icns prêt"
echo "    → $ICNS_OUT"
