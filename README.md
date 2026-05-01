# RunBar

> Mac menu-bar app pour runners. Un bonhomme animé court vers la ligne d'arrivée selon ton objectif hebdo. Sync Strava → progression visuelle. Inspiration RunCat × Apple Fitness × terroir trail breton.

![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg)

## Pourquoi

Strava raconte ce que tu as fait. RunBar te dit où tu en es **maintenant**, en un coup d'œil, sans ouvrir une app. Un coureur dans la barre de menu reflète ton état hebdo : tranquille, dans les clous, en sprint après une nouvelle sortie, fatigué si tu prends du retard, victorieux quand tu franchis la ligne.

## Features

- 🏃 **Coureur animé** dans la menu bar (5 états — idle, jogging, sprinting, tired, victory)
- 📊 **Popover 320×420** : stats de la semaine, piste avec ligne d'arrivée, liste des sorties
- 🔥 **Streaks** : compteur de semaines consécutives à 100%, badge flamme dans le header
- 🏁 **Race countdown** : si une course est configurée, banner J-X dans le popover quand <30 jours
- ⚙️ **Settings macOS-natives** : objectif, métrique (km / sorties / D+), apparence, sources
- 🎉 **Onboarding 5 étapes** avec gamification (tier de coureur — Découverte → Endurance)
- 🔔 **Notifications** : objectif atteint (avec son), récap dominical 21h
- 🔄 **Sync Strava** OAuth + webhook receiver pour sync instantanée
- 💾 **SwiftData** persistence locale
- 🌓 **Light/dark** mode auto

## Stack

Swift 5.10, SwiftUI, SwiftData, AppKit (NSStatusItem + NSPopover), Network.framework, swift-log.

Pas d'autres dépendances externes.

## Démarrer

```sh
git clone https://github.com/<your-handle>/runbar.git
cd runbar
cp Sources/RunBar/App/Secrets.template.swift.txt Sources/RunBar/App/Secrets.swift
# Édite Secrets.swift avec tes credentials Strava
swift run RunBar
```

Voir [`RUNNING.md`](./RUNNING.md) pour le détail (configuration Strava OAuth, webhook, tests).

## Architecture

```
Sources/RunBar/
├── App/                    # entry point + AppDelegate (NSStatusItem)
├── Design/                 # palette, typography, runner animation
│   ├── Animations/         # RunnerView, RunnerPose, RunnerFrames, RunnerBitmap
│   └── Components/         # TrackView, FinishFlagView, ConfettiView
├── Features/
│   ├── MenuBar/
│   ├── Popover/
│   ├── Settings/
│   └── Onboarding/
├── Domain/
│   ├── Models/             # Activity (@Model), WeeklyGoal, RunnerState, WeeklySnapshot
│   ├── Services/           # StravaService (OAuth + API), SyncManager, NotificationService, StravaWebhookServer
│   └── Stores/             # ActivityStore (SwiftData), SnapshotStore
└── Utilities/              # Keychain, DateExtensions, Logger
```

## Roadmap

Voir [`PLANRunbar.md`](./PLANRunbar.md) — phases du MVP au shipping.

Idées v0.2+ : HealthKit, Garmin, multi-objectifs, plans d'entraînement, shoe tracking, vue historique, paysage qui défile derrière le runner.

## Licence

MIT.
