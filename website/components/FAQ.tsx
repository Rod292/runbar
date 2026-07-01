/**
 * Section — Frequently asked questions
 *
 * Drains the four to five questions every Reddit / HN thread asks
 * before the comment section answers them for me. Editorial style:
 * numbered §, italic display serif heading, mono labels, vermillon
 * accent — matches Showcase / Why / Popover sections.
 */

const QUESTIONS: { q: string; a: React.ReactNode }[] = [
  {
    q: "Why a menu-bar app, not a regular one?",
    a: (
      <>
        Because the question RunBar answers — <em>am I on track this week?</em>{" "}
        — should not require opening anything. A menu-bar app is always there,
        in your peripheral vision. You glance, you know, you move on. A regular
        app would mean another tab to open, another habit to build. The
        five-state runner does the work for you.
      </>
    ),
  },
  {
    q: "What happened to the AI coach?",
    a: (
      <>
        It&rsquo;s paused — honestly and deliberately. Strava&rsquo;s API
        policy update of June 2026 forbids feeding Strava data into AI
        tools, so while your runs sync from Strava, RunBar sends nothing to
        any AI provider (this is enforced in code, not just promised). The
        coach returns with a non-Strava source — Apple Health is next on
        the roadmap. It will stay bring-your-own-key: RunBar is free, I&rsquo;m
        a solo dev, and I refuse to charge $5&nbsp;/&nbsp;month for one API
        call per week.
      </>
    ),
  },
  {
    q: "Why macOS only?",
    a: (
      <>
        Because RunBar is built on AppKit + SwiftUI specifics that don&rsquo;t
        port — <code>NSStatusItem</code>, <code>NSPopover</code>, the menu-bar
        metaphor itself. A solo dev cannot maintain three native ports. An
        Electron version would compromise the very thing that makes the app
        feel right (a 2.4 MB notch-friendly binary, no dock icon, instant
        boot). Maybe one day. Not today.
      </>
    ),
  },
  {
    q: "Is my Strava data safe?",
    a: (
      <>
        Three guarantees. <strong>(1)</strong> Tokens live in macOS Keychain,
        never in plain files. <strong>(2)</strong> Raw activities are kept
        locally for at most seven days (rolling cache, per Strava&rsquo;s API
        Agreement); only weekly aggregates persist beyond that.{" "}
        <strong>(3)</strong> Zero telemetry. RunBar phones home for exactly
        two things today: Strava (auth + sync) and Sparkle (update
        manifest). No Strava data ever reaches an AI provider — the coach
        is disabled while your data comes from Strava, per their June 2026
        API policy.
      </>
    ),
  },
  {
    q: "What about Apple Watch, Garmin, manual entry?",
    a: (
      <>
        Manual entry is shipping today (Settings → Sources → Manual entry).
        Apple Health and Garmin Connect are <em>coming soon</em> — the
        plumbing is there but I want to ship them properly with their own
        OAuth flow and aggregate models, not as half-finished placeholders.
        Email <a href="mailto:contact@runbar.run">contact@runbar.run</a> if
        you&rsquo;d like to be told the day they land.
      </>
    ),
  },
];

export function FAQ() {
  return (
    <section
      id="faq"
      className="relative overflow-hidden border-t border-hairline bg-paper"
    >
      <div className="pointer-events-none absolute inset-0 noise-bg opacity-30" />

      <div className="relative mx-auto w-full max-w-[1200px] px-6 py-24 md:px-10 md:py-32">
        {/* eyebrow */}
        <div className="mb-10 flex items-end justify-between border-b border-hairline pb-4 md:mb-14">
          <div className="flex items-baseline gap-4">
            <span className="font-mono text-[11px] uppercase tracking-[0.28em] text-vermillon">
              §06
            </span>
            <span className="text-[11px] uppercase tracking-[0.22em] text-ink-mute">
              Frequently asked
            </span>
          </div>
          <span className="hidden font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute md:block">
            fig. 06
          </span>
        </div>

        {/* headline */}
        <h2 className="font-display text-[clamp(2.2rem,4.4vw,4rem)] font-medium leading-[1.02] tracking-tightest text-ink md:max-w-[20ch]">
          The <span className="italic text-ink-soft">five</span> questions
          everyone asks{" "}
          <span className="text-ink-mute">— answered up front.</span>
        </h2>

        {/* questions */}
        <ol className="mt-14 grid grid-cols-1 gap-x-12 gap-y-10 md:mt-20 md:grid-cols-2">
          {QUESTIONS.map((item, i) => (
            <li
              key={i}
              className="border-l-2 border-vermillon/60 pl-5"
            >
              <div className="mb-3 font-mono text-[10px] uppercase tracking-[0.22em] text-vermillon">
                §06 · {String(i + 1).padStart(2, "0")}
              </div>
              <h3 className="font-display text-[clamp(1.1rem,1.5vw,1.4rem)] font-medium leading-[1.3] text-ink">
                {item.q}
              </h3>
              <div className="prose-faq mt-3 max-w-[52ch] text-[14px] leading-[1.65] text-ink-soft">
                {item.a}
              </div>
            </li>
          ))}
        </ol>

        {/* outro */}
        <p className="mt-16 max-w-[52ch] text-[13px] leading-[1.6] text-ink-mute md:mt-20">
          A question we missed?{" "}
          <a
            href="mailto:contact@runbar.run"
            className="text-ink-soft underline decoration-vermillon decoration-[1.5px] underline-offset-[5px] hover:text-ink"
          >
            contact@runbar.run
          </a>{" "}
          — or open an issue on{" "}
          <a
            href="https://github.com/Rod292/runbar/issues"
            target="_blank"
            rel="noopener noreferrer"
            className="text-ink-soft underline decoration-vermillon decoration-[1.5px] underline-offset-[5px] hover:text-ink"
          >
            GitHub
          </a>
          .
        </p>
      </div>
    </section>
  );
}
