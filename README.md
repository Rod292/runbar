<div align="center">
  <img src="https://raw.githubusercontent.com/Rod292/runbar/main/website/public/og-image.png" alt="RunBar — A runner in your menu bar" width="640" />
</div>

<p align="center">
  <strong>A runner in your menu bar.</strong><br/>
  Strava tells you what you did. RunBar tells you where you stand — right now.
</p>

<p align="center">
  <a href="https://runbar.run/download/RunBar.dmg"><strong>↓ Download for macOS</strong></a>
  &nbsp;·&nbsp;
  <a href="https://runbar.run">runbar.run</a>
  &nbsp;·&nbsp;
  macOS 14+ · Apple Silicon &amp; Intel · Free
</p>

---

## What it does

An animated runner lives in your menu bar and reflects your weekly running progress at a glance — no app to open, no dashboard to check.

- **Live state in the menu bar.** Five runner states — idle, jogging, sprinting after a fresh upload, falling behind mid-week, victory when you cross the line.
- **Smart weekly target.** RunBar reads your last four weeks and proposes a weekly goal that grows with you (capped at +20%, suggests a more honest target if you're consistently below). Adjust it on the fly from the popover with ±2 / ±5 km shortcuts.
- **Optional AI coach (paused).** Bring your own API key (Gemini 2.5 Flash Lite by default). Two-to-four lines of grounded coaching, strict no-hallucination prompt. Currently paused: Strava's June 2026 API policy forbids feeding Strava data into AI tools, so the coach stays off while your runs sync from Strava — it returns with a non-Strava source (Apple Health is on the roadmap). Enforced in code, not just promised.
- **Race countdown.** Set a race date and the popover shows a live D-X banner; the coach weaves it in as the date approaches.
- **Streaks, history, sunday recap.** Eight-week sparkline, goal-completion streak badge, optional sunday evening summary notification.
- **Strava-synced, privacy-respecting.** OAuth + 30-min background sync. Your Strava tokens and (optional) AI coach key live in macOS Keychain. The AI coach only sees weekly aggregates — never activity names, timestamps, or GPS data.

## Why

Strava is a logbook. Apple Fitness is a dashboard. Neither answers the question you actually have on a Wednesday afternoon: *am I on track this week?* RunBar is a glance, not a session. Open it when you want detail; ignore it when you don't — the runner in the menu bar already told you.

## Install

The signed and notarised DMG is the only supported install:

> **[Download RunBar.dmg](https://runbar.run/download/RunBar.dmg)**

Drag to Applications, launch, follow the 8-step onboarding (Strava connect is optional but unlocks everything). The app is fully menu-bar (no Dock icon).

Sparkle ships in-app updates. Right-click the menu bar icon → *Check for updates* any time.

## Privacy

- **Strava data** stays local. SwiftData store at `~/Library/Application Support/RunBar/store.sqlite`. Tokens in Keychain.
- **AI coach** is opt-in and currently paused while data comes from Strava (per Strava's June 2026 API policy — no Strava data ever reaches an AI provider). When it runs, RunBar sends only weekly aggregates to your chosen provider: distance, run count, elevation, target, progress %, days left in the week, the last four weeks of distance totals, your goal streak, and (if set) your race name and days until race. **No activity names. No timestamps. No GPS data. No personal identifiers.** Your API key is stored in Keychain.
- **No analytics, no telemetry.** RunBar does not phone home. The only outbound calls are: Strava (auth + sync), Sparkle (update check), and your AI provider (only if you enabled it).

## Build from source

Requires Xcode 15+ / Swift 5.10. For a quick run:

```sh
git clone https://github.com/Rod292/runbar.git
cd runbar
swift run RunBar
```

Strava credentials are needed to sync. See [`RUNNING.md`](./RUNNING.md) for the full dev setup (BYO Strava app, webhook receiver, packaging, notarization).

## Stack

Swift 5.10 · SwiftUI · SwiftData · AppKit (NSStatusItem + NSPopover) · Network.framework · Sparkle · swift-log. No third-party UI dependencies.

## License

MIT — see [`LICENSE`](./LICENSE).
