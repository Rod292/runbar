#!/bin/bash
# Bump de version en un seul endroit.
#
# Usage: scripts/bump-version.sh <nouvelle-semver>
# Exemple: scripts/bump-version.sh 0.1.24
#
# Met à jour :
#   - VERSION (source de vérité : semver ligne 1, build number ligne 2 —
#     incrémenté automatiquement ; lu par scripts/package-app.sh)
#   - les stamps du site (layout.tsx, not-found.tsx, download/route.ts,
#     Hero.tsx, FinalCTA.tsx)
# L'appcast est régénéré par scripts/release-update.sh après notarisation.

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: scripts/bump-version.sh <semver>" >&2
    exit 1
fi

NEW="$1"
if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: '$NEW' n'est pas une semver (attendu: X.Y.Z)." >&2
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"

OLD="$(sed -n '1p' "$VERSION_FILE")"
BUILD="$(sed -n '2p' "$VERSION_FILE")"
if [ -z "$OLD" ] || [ -z "$BUILD" ]; then
    echo "ERROR: VERSION file malformé ($VERSION_FILE)." >&2
    exit 1
fi
if [ "$NEW" = "$OLD" ]; then
    echo "Déjà en $OLD — rien à faire."
    exit 0
fi

NEW_BUILD=$((BUILD + 1))
printf '%s\n%s\n' "$NEW" "$NEW_BUILD" > "$VERSION_FILE"

# Stamps du site — remplacement littéral de l'ancienne semver.
SITE_FILES=(
    "website/app/layout.tsx"
    "website/app/not-found.tsx"
    "website/app/api/download/route.ts"
    "website/components/Hero.tsx"
    "website/components/FinalCTA.tsx"
)
for f in "${SITE_FILES[@]}"; do
    if [ -f "$ROOT/$f" ]; then
        perl -pi -e "s/\Q$OLD\E/$NEW/g" "$ROOT/$f"
        echo "  ✓ $f"
    else
        echo "  ⚠ $f introuvable — stamp non mis à jour" >&2
    fi
done

echo "==> $OLD → $NEW (build $NEW_BUILD)"
echo "Reste à faire : make-dmg → notarize → staple → release-update.sh $NEW \"notes\""
