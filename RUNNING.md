# RunBar — Comment tester

## Clés API requises

**Strava uniquement** (Apple Health et Garmin sont prévus mais pas branchés en v0.1).

Crée tes credentials sur https://www.strava.com/settings/api puis copie le template :

```sh
cp Sources/RunBar/App/Secrets.template.swift.txt Sources/RunBar/App/Secrets.swift
# Édite Secrets.swift avec ton client_id et client_secret
```

`Secrets.swift` est gitignored — il ne sera jamais commit.

## Configurer l'app Strava

Sur https://www.strava.com/settings/api :
- **Authorization Callback Domain** → mets `runbar` (n'importe quel domaine — `ASWebAuthenticationSession` intercepte le callback côté app, le domaine n'a pas besoin d'être réel).
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

1. `swift build -c release`
2. Créer une structure `RunBar.app/Contents/{MacOS,Resources}/`
3. Copier le binaire dans `MacOS/RunBar`
4. Copier `AppBundle/Info.plist` dans `Contents/Info.plist` (il contient déjà `LSUIElement = true` et le scheme `runbar://`)
5. Code-signing si distribution externe (cf. Phase 10 du plan)

À ce stade le scheme `runbar://` est aussi enregistré système — utile uniquement si tu veux qu'un autre process (Slack, terminal...) puisse ouvrir RunBar via une URL.

## Limites connues

- **OAuth en `swift run`** : ASWebAuthenticationSession ouvre le navigateur Strava et capture le callback `runbar://` *en interne*. Pas besoin de bundle .app. Si le browser n'a pas de fenêtre clé, passe `prefersEphemeralWebBrowserSession = true` dans `StravaOAuth.swift`.
- **Refresh token** : stocké en Keychain sous service `com.rodrigue.runbar.strava`, account `refresh_token`. Pour reset l'auth : `security delete-generic-password -s com.rodrigue.runbar.strava -a refresh_token`.
- **HealthKit / Garmin** : pas encore branchés (post-MVP, cf. PLANRunbar.md).
