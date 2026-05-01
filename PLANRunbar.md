# 🏃 RunBar — Plan de développement

> Mac app menu bar pour runners. Un bonhomme court vers la ligne d'arrivée selon tes objectifs hebdo. Sync Strava/Garmin = progression visuelle. Inspiration RunCat × Apple Fitness × terroir trail.

---

## 🎯 Vision produit

**Promesse** : transformer la discipline d'entraînement en un compagnon visuel discret, présent toute la journée dans la barre de menu macOS.

**Pour qui** : runners réguliers (route, trail, ultra) qui veulent un feedback ambiant sans ouvrir Strava 15 fois par jour.

**Pourquoi maintenant** : RunCat a prouvé qu'une icône animée dans la menu bar crée de l'attachement. Personne ne l'a fait pour le sport avec une vraie boucle d'objectif.

**Différenciateurs** :
- Animation **vivante** (pas juste une jauge) — le bonhomme reflète l'état réel de ta semaine
- **Boucle hebdomadaire** claire : lundi → ligne d'arrivée dimanche
- **Multi-source** : Strava + Garmin + HealthKit
- **Local-first** : tout en SwiftData, sync chiffrée optionnelle plus tard

---

## 🧩 Périmètre MVP (v0.1)

### Inclus
- Menu bar app SwiftUI (macOS 14+)
- Bonhomme animé dans la barre, popover au clic
- 1 objectif hebdo configurable : **km** *ou* **nombre de sorties** *ou* **D+**
- Connexion Strava (OAuth, sync auto toutes les 30 min)
- Vue popover : ligne d'arrivée, % atteint, sorties de la semaine
- Notification quand tu franchis la ligne
- Reset auto chaque lundi 00h00 (timezone locale)
- Settings minimaliste

### Exclus (post-MVP)
- Garmin Connect (API non officielle, complexe)
- HealthKit (vient en v0.2)
- Multi-objectifs simultanés
- Widget Desktop / Dock animé (v0.3)
- Plans d'entraînement
- Social / partage

---

## 🎨 Design system & UX

### Principes
1. **Discret par défaut** — l'icône menu bar respecte les 22px standard, pas de bling
2. **Lisible en un coup d'œil** — état de la semaine visible en <1 seconde
3. **Récompensant** — franchir la ligne = micro-célébration (animation + son optionnel)
4. **Cohérent** — palette inspirée trail breton (vert mousse, granit, océan)

### Palette (à valider en design)
```
--accent-run:     #2D7A3E   (vert mousse)
--accent-late:    #C75D2C   (terre cuite, en retard)
--accent-done:    #D4A24C   (or breton, objectif atteint)
--bg-popover:     systemBackground (auto light/dark)
--ink:            primaryLabel
--ink-muted:      secondaryLabel
--track:          quaternaryLabel (ligne au sol)
```

### Typo
- **SF Pro** partout (système)
- Numéros : `.monospacedDigit()` pour éviter les sauts visuels
- Tailles : Title (popover header), Headline (% progression), Caption (métadonnées)

### États du bonhomme (5 animations à designer)
| État | Trigger | Animation |
|------|---------|-----------|
| `idle` | Repos / pas de sync récente | Respire sur place, légère oscillation |
| `jogging` | En cours de semaine, dans les clous | Foulée régulière |
| `sprinting` | Vient de sync une grosse sortie | Foulée rapide pendant 5s puis retour |
| `tired` | En retard sur l'objectif (>50% semaine, <40% objectif) | Foulée lente, épaules basses |
| `victory` | Objectif atteint | Bras en l'air, confettis dans le popover |

### Layout popover (320 × 420)
```
┌─────────────────────────────────────┐
│  Cette semaine          ⚙️  ✕      │  ← header
├─────────────────────────────────────┤
│                                     │
│   42 / 60 km          70%          │  ← chiffres
│                                     │
│   🏃 ─────────────────────🏁       │  ← piste avec bonhomme
│                                     │
├─────────────────────────────────────┤
│  Sorties (3)                        │
│  ─────────────────────────          │
│  Lun  •  Footing      8 km   45'   │
│  Mer  •  Fractionné  12 km   58'   │
│  Sam  •  Sortie long 22 km  2h10   │
├─────────────────────────────────────┤
│  Dernière sync : il y a 12 min     │
│         [Synchroniser maintenant]   │
└─────────────────────────────────────┘
```

### Settings (fenêtre dédiée, pas popover)
- **Objectif** : type (km / sorties / D+) + valeur cible + jour de reset
- **Comptes** : Strava connecté, futur Garmin
- **Apparence** : taille bonhomme menu bar (S/M/L), animation on/off, son victoire
- **Notifications** : objectif atteint, rappel mi-semaine si en retard
- **Avancé** : intervalle de sync, export données

---

## 🏗️ Architecture technique

### Stack
- **Swift 5.10+ / SwiftUI** (macOS 14 Sonoma minimum pour les nouvelles APIs)
- **SwiftData** pour persistance (sorties, objectifs, settings)
- **MenuBarExtra** API native (iOS 14+) pour l'icône menu bar
- **OAuth via ASWebAuthenticationSession** pour Strava
- **Combine** pour la sync réactive
- **swift-log** pour le logging structuré

### Structure projet
```
RunBar/
├── App/
│   ├── RunBarApp.swift           # @main, MenuBarExtra
│   └── AppDelegate.swift         # lifecycle, deep links OAuth
├── Features/
│   ├── MenuBar/
│   │   ├── MenuBarIconView.swift # le bonhomme animé
│   │   └── MenuBarViewModel.swift
│   ├── Popover/
│   │   ├── PopoverView.swift
│   │   ├── ProgressTrackView.swift   # piste + bonhomme + ligne
│   │   └── ActivityRowView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Onboarding/
│       └── OnboardingView.swift  # connexion Strava, choix objectif
├── Domain/
│   ├── Models/
│   │   ├── Activity.swift        # SwiftData @Model
│   │   ├── WeeklyGoal.swift
│   │   └── RunnerState.swift     # enum idle/jogging/...
│   ├── Services/
│   │   ├── StravaService.swift   # OAuth + API
│   │   ├── SyncManager.swift     # orchestration
│   │   ├── GoalCalculator.swift  # % progression, état du runner
│   │   └── NotificationService.swift
│   └── Stores/
│       └── ActivityStore.swift   # SwiftData wrapper
├── Design/
│   ├── Animations/
│   │   ├── RunnerAnimator.swift  # state machine + frames
│   │   └── runner-frames/        # 🎨 PNG/SVG exportés depuis Claude
│   ├── Colors.swift
│   └── Components/
│       └── FinishLineView.swift
├── Utilities/
│   ├── Keychain.swift            # tokens Strava
│   ├── DateExtensions.swift      # début/fin semaine ISO
│   └── Logger.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings       # FR + EN
```

### Modèles SwiftData
```swift
@Model
final class Activity {
    @Attribute(.unique) var id: String  // ID Strava
    var name: String
    var distance: Double                 // mètres
    var movingTime: Int                  // secondes
    var elevationGain: Double            // mètres
    var startDate: Date
    var type: String                     // "Run", "TrailRun"
    var source: String                   // "strava" | "garmin" | "manual"

    init(...) { }
}

@Model
final class WeeklyGoal {
    var metric: GoalMetric               // .distance | .count | .elevation
    var target: Double
    var resetWeekday: Int                // 2 = lundi (ISO)
    var createdAt: Date

    init(...) { }
}

enum GoalMetric: String, Codable {
    case distance, count, elevation
}
```

### Calcul de l'état du runner
```swift
struct GoalCalculator {
    func currentProgress(activities: [Activity], goal: WeeklyGoal) -> Double
    func runnerState(progress: Double, dayOfWeek: Int) -> RunnerState {
        // Si progress >= 1.0 -> .victory
        // Si dayOfWeek >= 5 (jeudi) && progress < 0.4 -> .tired
        // Si une activité < 5 min -> .sprinting (transient)
        // Sinon -> .jogging
    }
}
```

### Sync Strava
- OAuth flow avec scope `activity:read`
- Refresh token stocké en Keychain
- Endpoint : `GET /api/v3/athlete/activities?after={mondayTimestamp}`
- Sync triggers :
  - Au lancement
  - Toutes les 30 min en background (`Timer` ou `BGAppRefreshTask`)
  - Manuel via bouton popover
- Dédup par `id` Strava

---

## 🎨 Workflow design (Claude Artifacts → Xcode)

Tu fais le design dans Claude. Voici comment livrer au dev pour que ça s'intègre proprement.

### À designer dans Claude
1. **Bonhomme — 5 états × frames d'animation**
   - Idle : 4 frames (cycle respiration)
   - Jogging : 6 frames (cycle de course)
   - Sprinting : 6 frames (cadence rapide)
   - Tired : 6 frames (cadence lente, posture)
   - Victory : 4 frames (bras levés)

2. **Format de livraison**
   - **SVG** pour l'icône menu bar (vectoriel, scaling parfait Retina)
   - Alternative : sprite sheet PNG @2x et @3x si animations complexes
   - Fond transparent obligatoire
   - Une seule couleur (template image macOS) → s'adapte light/dark auto
   - Taille canvas : **22×22 pt** pour menu bar, **64×64 pt** pour popover

3. **Ligne d'arrivée + piste**
   - SVG pour le popover (320pt large)
   - Drapeau à damier stylisé
   - Sol/piste : ligne pointillée ou route stylisée

4. **Convention de nommage des assets**
```
runner-idle-01.svg ... runner-idle-04.svg
runner-jogging-01.svg ... runner-jogging-06.svg
runner-sprinting-01.svg ... runner-sprinting-06.svg
runner-tired-01.svg ... runner-tired-06.svg
runner-victory-01.svg ... runner-victory-04.svg
finish-line.svg
track-segment.svg
```

5. **Mockup popover complet**
   - À designer en HTML/CSS dans Claude pour valider le layout
   - Le dev s'en sert comme spec visuelle

---

## 📋 Roadmap d'implémentation (pour Claude Code)

### Phase 0 — Setup (30 min)
- [ ] Créer projet Xcode "RunBar" (macOS App, SwiftUI, SwiftData)
- [ ] Configurer bundle ID `com.rodrigue.runbar`
- [ ] Activer App Sandbox + entitlement réseau (sortant)
- [ ] Init repo Git, `.gitignore` Swift standard
- [ ] Ajouter dépendance `swift-log` via SPM

### Phase 1 — Squelette menu bar (1h)
- [ ] Convertir l'app en `MenuBarExtra` only (pas de fenêtre principale)
- [ ] Icône statique (placeholder SF Symbol `figure.run`)
- [ ] Popover s'ouvre au clic, fermé par défaut
- [ ] Vue popover vide avec layout de base

### Phase 2 — Modèles & store (1h30)
- [ ] Définir `Activity`, `WeeklyGoal`, `GoalMetric` (SwiftData)
- [ ] `ActivityStore` avec CRUD + query "activités de la semaine en cours"
- [ ] Helper `Date.startOfWeek(weekday:)` pour ISO weeks
- [ ] Seeds de dev (10 activités factices) derrière flag `#if DEBUG`

### Phase 3 — UI popover statique (2h)
- [ ] `ProgressTrackView` : piste horizontale, bonhomme positionné selon `progress: Double`
- [ ] `ActivityRowView` : ligne par sortie (jour, nom, distance, durée)
- [ ] Header avec titre semaine + bouton settings + close
- [ ] Footer avec dernière sync + bouton "Synchroniser"
- [ ] **Tester avec données seed** avant de brancher Strava

### Phase 4 — Intégration assets design (1h)
- [ ] Importer les SVG du bonhomme dans `Assets.xcassets` (template image)
- [ ] `RunnerAnimator` : timer qui cycle les frames selon l'état
- [ ] Remplacer le SF Symbol menu bar par `runner-idle-01`
- [ ] Remplacer le bonhomme du popover (taille 64pt)

### Phase 5 — State machine du runner (1h)
- [ ] `RunnerState` enum + `GoalCalculator.runnerState()`
- [ ] Binding entre progression réelle et état affiché
- [ ] Animation de transition entre états (cross-fade 200ms)

### Phase 6 — Strava OAuth (2h)
- [ ] Créer une app sur developers.strava.com
- [ ] Stocker `client_id` / `client_secret` (côté dev) — **jamais en clair en prod**
- [ ] Onboarding : bouton "Connecter Strava" → `ASWebAuthenticationSession`
- [ ] Callback URL custom scheme `runbar://oauth`
- [ ] Échange code → tokens, stocker en Keychain
- [ ] Refresh token auto quand expiré

### Phase 7 — Sync activités (2h)
- [ ] `StravaService.fetchActivities(since:)` avec pagination
- [ ] `SyncManager` orchestre : refresh token si besoin → fetch → dédup → save
- [ ] Sync au launch + timer 30 min
- [ ] Bouton manuel popover déclenche `SyncManager.syncNow()`
- [ ] Indicateur visuel pendant sync (spinner discret)

### Phase 8 — Settings (1h30)
- [ ] Fenêtre Settings (`Settings { ... }` SwiftUI)
- [ ] Choix de l'objectif + valeur + jour reset
- [ ] Statut compte Strava + bouton déconnexion
- [ ] Toggle son victoire, taille bonhomme

### Phase 9 — Notifications & polish (1h30)
- [ ] Demander permission `UNUserNotificationCenter` au premier objectif atteint
- [ ] Notif "🏁 Objectif atteint !" quand on franchit la ligne
- [ ] Notif rappel jeudi 18h si <40% (configurable)
- [ ] Animation confettis dans popover en mode `.victory`
- [ ] Son discret optionnel (system sound)

### Phase 10 — QA & ship (1h)
- [ ] Tester light + dark mode
- [ ] Tester reset hebdo (manipuler la date système)
- [ ] Tester déconnexion / reconnexion Strava
- [ ] Tester avec 0 / 1 / 50 activités dans la semaine
- [ ] Build release, signature développeur
- [ ] DMG ou notarisation pour distribution

**Total estimé : ~16h de dev pour le MVP**

---

## 🧪 Tests à écrire en priorité

```swift
// GoalCalculatorTests
- progress_distance_returns_correct_ratio
- progress_count_caps_at_1
- runnerState_returns_tired_when_late_in_week
- runnerState_returns_victory_when_complete
- weekStart_handles_monday_reset_correctly
- weekStart_handles_sunday_reset_correctly

// SyncManagerTests
- dedup_avoids_duplicate_activities
- sync_filters_only_current_week
- sync_handles_token_refresh_transparently
```

---

## 🔐 Sécurité & vie privée

- **Tokens Strava** : Keychain uniquement, jamais UserDefaults
- **Pas de télémétrie** par défaut (tu ajoutes plus tard si besoin)
- **App Sandbox** activé, entitlements minimaux (network out only)
- **Données** : 100% local SwiftData, pas de backend RunBar
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) requis pour App Store éventuel

---

## 🚀 Idées v0.2+

- HealthKit comme source alternative (pas besoin de compte tiers)
- Garmin Connect via reverse-engineering (`garth` Python style)
- Widget bureau avec scène qui défile (paysage breton)
- Mode "race countdown" — gros chiffre des jours restants à l'A-race
- Multi-objectifs (km + D+ simultanés)
- Streaks (semaines consécutives où l'objectif est atteint)
- Export ICS du plan d'entraînement
- Versions iOS / iPad partagées via SwiftUI

---

## 📝 Prompt à coller dans Claude Code

> Tu vas implémenter RunBar, une app macOS menu bar pour runners. Lis `PLAN.md` à la racine. Démarre par la Phase 0 et avance phase par phase. À la fin de chaque phase :
> 1. Récapitule ce qui est fait
> 2. Lance les tests si applicable
> 3. Demande validation avant la phase suivante
>
> Contraintes :
> - macOS 14 minimum, Swift 5.10, SwiftUI + SwiftData
> - Pas de dépendance externe sauf swift-log
> - Code commenté en français pour la logique métier, en anglais pour l'API
> - Respecte la structure de dossiers définie dans le plan
> - Les assets du bonhomme arriveront en SVG dans `Design/Animations/runner-frames/` — utilise des SF Symbols en placeholder en attendant
>
> Commence par confirmer que tu as bien lu le plan, puis lance Phase 0.

---

## ✅ Checklist avant de lancer Claude Code

- [ ] Designs bonhomme prêts (au moins 1 frame par état pour démarrer)
- [ ] Compte Strava developer créé, `client_id`/`client_secret` en main
- [ ] Xcode 15.4+ installé
- [ ] Repo Git initialisé
- [ ] `PLAN.md` à la racine du projet
- [ ] Lancer Claude Code avec le prompt ci-dessus
