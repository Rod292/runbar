import type { Metadata } from "next";
import { LegalLayout } from "@/components/LegalLayout";

export const metadata: Metadata = {
  title: "Changelog",
  description: "What shipped in each RunBar release.",
};

type Release = {
  version: string;
  date: string;
  title: string;
  bullets: React.ReactNode[];
};

// Hand-curated entries — every published GitHub release that
// shipped a user-visible change. Older patch-only releases are
// rolled up. When we ship a new public release, add an entry at
// the top.
const RELEASES: Release[] = [
  {
    version: "0.1.26",
    date: "2026-07-07",
    title: "Clear words when Strava says no",
    bullets: [
      <>
        When Strava deactivates an API application (as happened during the
        June 2026 developer-program enforcement), RunBar used to show a
        cryptic &quot;Server error (HTTP 403)&quot;. It now reads
        Strava&apos;s actual answer and says what&apos;s wrong and who can
        fix it — and that reconnecting won&apos;t help.
      </>,
      <>
        Invalid or revoked tokens now surface as &quot;Not connected to
        Strava&quot; instead of a server error, and sync failures log the
        full API response for diagnostics.
      </>,
    ],
  },
  {
    version: "0.1.25",
    date: "2026-07-02",
    title: "Your history heals itself + recovery mode",
    bullets: [
      <>
        <strong>Self-healing history.</strong> Weeks where your Mac was off
        used to leave permanent holes in the sparkline, and past-week totals
        could get stuck on partial sums. RunBar now refetches the last 12
        weeks from Strava daily (in memory only — still 7-day-cache
        compliant) and corrects every weekly total, both ways.
      </>,
      <>
        <strong>Sunday weeks, fixed everywhere.</strong> If your week starts
        on Sunday, the sparkline matched nothing and your streak always read
        zero — week boundaries now follow your setting in the chart, streak,
        week numbers and &quot;days left&quot;.
      </>,
      <>
        <strong>Recovery mode.</strong> After a big week (≥ 140 % of
        target), a quiet start isn&apos;t laziness — the runner now takes an
        earned breather instead of looking idle or guilt-tripping you.
      </>,
      <>
        <strong>Past weeks read better.</strong> &quot;Last week.&quot; /
        &quot;Week 24.&quot; titles with a clear &quot;back to now&quot;
        button (no more cryptic &quot;That week NOW&quot;), plus a
        week-over-week delta on every past-week card.
      </>,
      <>
        Honest percentages: a 147 % week now says 147 %, not 100 %. Small
        touches: &quot;LAST DAY&quot; instead of &quot;0 days left&quot;, a
        GOAL tag on the chart&apos;s dashed line.
      </>,
    ],
  },
  {
    version: "0.1.24",
    date: "2026-07-01",
    title: "Browse past weeks + Strava AI-policy compliance",
    bullets: [
      <>
        <strong>Past weeks, at last.</strong> Chevrons in the popover header
        (or a tap on any sparkline bar) walk you through up to 52 weeks of
        history — total, target, goal reached or shortfall. Run-by-run
        details stay for 7 days only, per Strava&rsquo;s data policy; past
        weeks keep their totals.
      </>,
      <>
        <strong>AI coach paused for compliance.</strong> Strava&rsquo;s June
        2026 API policy forbids feeding Strava data into AI tools. RunBar
        now enforces this in code: while your runs sync from Strava,
        nothing is ever sent to an AI provider. Your key stays saved — the
        coach returns with a non-Strava source (Apple Health is next).
      </>,
      <>
        <strong>Sturdier sync.</strong> Rate-limit (HTTP 429) and server
        errors now retry with exponential backoff honouring Strava&rsquo;s{" "}
        <code>Retry-After</code>; the OAuth window allows 5 minutes for
        2FA logins; Keychain and database write failures are surfaced
        instead of swallowed.
      </>,
      <>
        <strong>History integrity.</strong> Changing your goal or metric
        no longer rewrites past weeks&rsquo; snapshots — streaks and the
        sparkline stay truthful. A run that syncs after Monday still
        counts toward last week.
      </>,
      <>
        The coach (when it runs) now speaks your unit — miles users no
        longer get km numbers — and testing an API key sends sample
        figures only, never your data.
      </>,
    ],
  },
  {
    version: "0.1.23",
    date: "2026-05-07",
    title: "Buy Me a Gel button now actually looks like one",
    bullets: [
      <>
        Settings → About gets a dedicated support card with the Ko-fi
        orange button, and the website footer button adopts the same brand
        orange. Same link, same &quot;Buy Me a Gel&quot; label everywhere.
        RunBar stays free and MIT.
      </>,
    ],
  },
  {
    version: "0.1.22",
    date: "2026-05-07",
    title: "Victory bounce + Buy me a gel",
    bullets: [
      <>
        The native runner now mirrors the website&rsquo;s victory jump when
        you cross the weekly line — arms up, small bounce, confetti as
        before.
      </>,
      <>
        First appearance of the Ko-fi &quot;Buy me a gel&quot; support link
        (site footer + Settings → About).
      </>,
    ],
  },
  {
    version: "0.1.21",
    date: "2026-05-06",
    title: "Restart onboarding actually restarts",
    bullets: [
      <>
        Settings → <em>Restart onboarding</em> now walks you through the steps
        again. Previously the SwiftUI Window scene was reusing the existing
        view so <code>step</code> stayed at the Done screen — clicking Restart
        re-opened the window straight on the Finish button.
      </>,
    ],
  },
  {
    version: "0.1.20",
    date: "2026-05-06",
    title: "Save & reconnect actually reconnects",
    bullets: [
      <>
        The <em>Save & reconnect</em> button in Settings → Strava → Manage now
        actually triggers the OAuth round-trip and opens Strava in your
        default browser. It used to only persist the credentials and dismiss
        the sheet — a confusing dead end.
      </>,
    ],
  },
  {
    version: "0.1.19",
    date: "2026-05-06",
    title: "Accurate target suggestions",
    bullets: [
      <>
        Fixed the &quot;A more realistic target?&quot; banner telling 85
        km/week runners that their 4-week average was 15 km. Root cause: the
        engine was reading raw activities (rolling 7-day cache, only one week
        of data) instead of the persisted weekly snapshots. Engine now reads
        the right source.
      </>,
    ],
  },
  {
    version: "0.1.18",
    date: "2026-05-06",
    title: "8-week history seeded on connect",
    bullets: [
      <>
        On a successful Strava connect, RunBar now fetches eight weeks of
        running history in memory, extracts the weekly aggregates, and
        persists only those derived snapshots. Raw activities older than seven
        days are never written to disk — fully conformant with the API
        Agreement, while the goal seed and the popover sparkline reflect
        reality from the very first launch.
      </>,
    ],
  },
  {
    version: "0.1.17",
    date: "2026-05-06",
    title: "Sharper goal seed math",
    bullets: [
      <>
        The seed&rsquo;s divisor now adapts to the actual span of available
        data instead of dividing by a hard-coded four weeks — correct on a
        fresh sync, where the rolling cache only fills one week.
      </>,
      <>
        The in-progress ISO week is now excluded from the average. A Monday
        morning install would otherwise drag the seed down to zero.
      </>,
    ],
  },
  {
    version: "0.1.16",
    date: "2026-05-06",
    title: "Clean state on disconnect",
    bullets: [
      <>
        Disconnecting Strava now also wipes the 8-week sparkline history.
        Previously the derived snapshots survived a disconnect, leaving the
        new account&rsquo;s popover showing prior-account bars under a fresh
        &quot;0 runs found&quot; line.
      </>,
      <>
        New diagnostic logging in Console.app: when Strava returns activities
        but none of type Run / TrailRun / VirtualRun, the type histogram is
        printed (e.g.&nbsp;<code>Walk×3 Workout×7</code>) so you can tell
        immediately whether you OAuthed against the wrong account or the
        runs are filtered by type.
      </>,
    ],
  },
  {
    version: "0.1.15",
    date: "2026-05-06",
    title: "Three quality fixes for BYO users",
    bullets: [
      <>
        The onboarding goal seed is now reactive: BYO users routinely land on
        the Goal step before the first sync has pulled any activities, so the
        target updates the moment data arrives rather than getting stuck on
        the 40 km fallback.
      </>,
      <>
        Settings → Strava gains a <em>Reconnect</em> button when an error
        surfaces. One click instead of disconnect-then-reconfigure.
      </>,
      <>
        Webhook receiver now honours Strava&rsquo;s <code>aspect_type=delete</code>{" "}
        events and removes the matching activity from the local store within
        seconds — closing the gap between the API Agreement&rsquo;s 48-hour
        delete SLA and the 7-day rolling cache.
      </>,
    ],
  },
  {
    version: "0.1.14",
    date: "2026-05-06",
    title: "Official Strava brand assets",
    bullets: [
      <>
        The <em>Connect with Strava</em> button now uses the official
        Strava-provided asset (orange, retina-ready). The{" "}
        <em>Powered by Strava</em> attribution in the popover footer also
        switches to the official horizontal logo, auto-toggling between black
        and white variants for light / dark mode.
      </>,
      <>
        Settings → Sources collapses into a single Strava card. While the
        shared RunBar Strava app is queued for quota approval, the{" "}
        <em>Configure</em> flow takes you straight through registering a
        personal API client — no more two-card confusion.
      </>,
    ],
  },
  {
    version: "0.1.13",
    date: "2026-05-06",
    title: "Strava API Agreement compliance + runbar.run launch",
    bullets: [
      <>
        Rolling 7-day cache: activities fetched from Strava are purged
        automatically after a week. Long-term history is preserved as
        locally-derived weekly snapshots — never raw Strava records.
      </>,
      <>
        Disconnect now wipes Strava data, not just OAuth tokens, per the
        revocation clause.
      </>,
      <>
        AI coach disclaimer now cites the Strava API Agreement explicitly and
        labels the data sent to the LLM as <em>derived aggregates</em>{" "}
        (computed locally), never raw Strava data. Recommendation surfaced
        in-app: use a paid Gemini API tier — Google may use free-tier
        prompts for model improvement, paid tiers do not.
      </>,
      <>
        Site moves to runbar.run with new /privacy /terms /contact pages.
      </>,
    ],
  },
];

function formatDate(iso: string): string {
  const d = new Date(iso + "T00:00:00Z");
  return d.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  });
}

export default function ChangelogPage() {
  return (
    <LegalLayout
      eyebrow="§ Changelog"
      italicWord="What"
      title="shipped."
    >
      <p>
        Every public release of RunBar since the canonical site moved to
        runbar.run. Older internal builds (0.1.0–0.1.12) are not listed —
        they all preceded full Strava API Agreement compliance.
      </p>
      <p>
        For the unabridged list with full release notes, see{" "}
        <a
          href="https://github.com/Rod292/runbar/releases"
          target="_blank"
          rel="noopener noreferrer"
        >
          GitHub releases
        </a>
        .
      </p>

      {RELEASES.map((release) => (
        <section
          key={release.version}
          // No inline styles in the prose flow — LegalLayout already
          // provides the editorial column. We just lean on h2 + ul.
        >
          <h2>
            v{release.version} <span className="font-normal text-ink-mute">·</span>{" "}
            <span className="font-normal italic text-ink-soft">
              {release.title}
            </span>
          </h2>
          <p
            // tighten the metadata directly under the heading
            className="!-mt-2 font-mono !text-[11px] uppercase tracking-[0.18em] !text-ink-mute"
          >
            {formatDate(release.date)}
          </p>
          <ul>
            {release.bullets.map((b, i) => (
              <li key={i}>{b}</li>
            ))}
          </ul>
        </section>
      ))}
    </LegalLayout>
  );
}
