# RunBar — Comment tester

## Clés API requises

**Strava uniquement** (Apple Health et Garmin sont prévus mais pas branchés en v0.1).

Crée tes credentials sur https://www.strava.com/settings/api puis fournis-les via variables d'environnement :

```sh
export RUNBAR_STRAVA_CLIENT_ID="..."
export RUNBAR_STRAVA_CLIENT_SECRET="..."
```

Pour lancer le bundle `.app` via Finder/LaunchServices, utilise plutôt `defaults` :

```sh
defaults write com.rodrigue.runbar runbar.strava.clientID "..."
defaults write com.rodrigue.runbar runbar.strava.clientSecret "..."
```

`Sources/RunBar/App/Secrets.swift` ne doit pas contenir de secret en clair. Si un secret Strava a déjà été partagé, régénère-le côté Strava.

## Configurer l'app Strava

Sur https://www.strava.com/settings/api :
- **Authorization Callback Domain** → mets `localhost`.
- Vérifie que le scope `activity:read_all` est autorisé (devrait l'être par défaut).

## Lancer l'app

```sh
swift run RunBar
```

L'icône runner apparaît dans la barre de menu (pas dans le Dock — `setActivationPolicy(.accessory)` est forcé). En mode `DEBUG` (build par défaut), 3 sorties seed sont préchargées : Footing 8 km, Fractionné 12 km, Sortie longue 22 km → 42/60 km, 70%, état **jogging**.

## Tester le flow complet

1. **Click sur le runner dans la barre de menu** → popover 320×420 avec stats, track, sorties, footer sync.
2. **Click sur l'engrenage du popover** → ouvre la fenêtre Préférences.
3. **Onglet "Sources" → bouton "Connecter"** sur Strava → ouverture du navigateur Strava OAuth → autoriser → retour automatique dans l'app, activités synchronisées.
4. **Onglet "Objectifs"** → ajuste l'objectif hebdo (10–150 km) et la métrique.
5. **Footer popover → "Synchroniser"** → relance une sync manuelle.

## Tester les états du runner sans Strava

Les 5 états sont visibles via les seeds :

```sh
# Semaine vide → état "idle"
RUNBAR_SEED=0 swift run RunBar
```

Pour les autres états (sprinting, tired, victory), il faut soit modifier `SeedData` dans `ActivityStore.swift`, soit faire varier la date d'une seed (jour ≥ jeudi + progression < 40% → tired ; progression ≥ 100% → victory).

## Tests unitaires

```sh
swift test
```

11 tests couvrant `GoalCalculator` (progression, états du runner, semaine ISO) et `ActivityStore` (dédup, upsert).

## Empaqueter en .app (optionnel)

`swift run` est suffisant pour tester en dev. Pour un vrai bundle distribuable :

```sh
scripts/package-app.sh
open build/RunBar.app
```

Pour éviter que macOS redemande l'accès au trousseau après chaque rebuild, signe
avec une identité stable au lieu de la signature ad-hoc par défaut :

```sh
RUNBAR_CODESIGN_IDENTITY="RunBar Local Dev" scripts/package-app.sh
```

Cette identité doit exister dans Trousseau d'accès. Pour un usage quotidien,
copie ensuite `build/RunBar.app` vers `/Applications/RunBar.app` et lance cette
copie stable.

## Créer le DMG

```sh
scripts/make-dmg.sh
```

Le DMG contient `RunBar.app` et un raccourci vers `/Applications`. Il est aussi
copié vers `website/public/download/RunBar.dmg`, qui est l'URL utilisée par le
site Next.js (`/download/RunBar.dmg`).

Pour une distribution publique, il faudra signer avec Developer ID puis notariser
le `.dmg`. L'auto-update à distance demande ensuite un appcast signé, par exemple
avec Sparkle.

Après avoir configuré `notarytool` avec un profil Keychain `RunBarNotary` :

```sh
RUNBAR_CODESIGN_IDENTITY="Developer ID Application: Rodrigue Pers (7YG2H7L32J)" scripts/make-dmg.sh
scripts/notarize-dmg.sh
```

Si Apple laisse une soumission longtemps en attente, récupère son ID puis relance
le stapling plus tard :

```sh
scripts/staple-notarized-dmg.sh <submission-id>
```

## Limites connues

- **OAuth en `swift run`** : RunBar ouvre Strava dans le navigateur et écoute temporairement `http://localhost:47862/callback`. Le callback est protégé par un paramètre `state` et expire après 120 secondes.
- **Refresh token** : stocké en Keychain sous service `com.rodrigue.runbar.strava`, account `refresh_token`. Pour reset l'auth : `security delete-generic-password -s com.rodrigue.runbar.strava -a refresh_token`.
- **Webhook Strava** : le serveur local est conservé pour du debug, mais il n'est pas lancé par défaut. Une app desktop derrière localhost ne peut pas recevoir les webhooks Strava sans tunnel ou backend public.
- **HealthKit / Garmin** : pas encore branchés (post-MVP, cf. PLANRunbar.md).
