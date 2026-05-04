import { RunnerSprite } from "./RunnerSprite";

/**
 * Section 2 / 6 — Menu bar showcase
 *
 * One beat: a single, large menu-bar mockup with one clean callout that
 * actually points to the runner. No faux desktop, no magnifier, no decoy
 * "23.4" floating in the void. The five-mood breakdown lives in §03.
 */

export function Showcase() {
  return (
    <section
      id="showcase"
      className="relative overflow-hidden border-y border-hairline bg-paper"
    >
      {/* tonal warm wash */}
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-paper via-paper to-ivory" />
      {/* paper grain */}
      <div className="pointer-events-none absolute inset-0 noise-bg opacity-40" />

      <div className="relative mx-auto w-full max-w-[1200px] px-6 pt-20 pb-28 md:px-10 md:pt-24 md:pb-32">
        {/* EYEBROW */}
        <div className="mb-10 flex items-end justify-between border-b border-hairline pb-4 md:mb-14">
          <div className="flex items-baseline gap-4">
            <span className="font-mono text-[11px] uppercase tracking-[0.28em] text-vermillon">
              §02
            </span>
            <span className="text-[11px] uppercase tracking-[0.22em] text-ink-mute">
              The runner · five moods
            </span>
          </div>
          <span className="hidden font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute md:block">
            fig. 02
          </span>
        </div>

        {/* HEADLINE */}
        <h2 className="font-display text-[clamp(2.2rem,4.4vw,4rem)] font-medium leading-[1.02] tracking-tightest text-ink md:max-w-[18ch]">
          A 16-pixel runner whose mood{" "}
          <span className="italic text-ink-soft">shifts</span> with your week —
          <span className="text-ink-mute"> quietly, in the corner.</span>
        </h2>

        {/* HERO SHOT — one large, clean menu bar */}
        <figure className="relative mt-14 md:mt-20">
          <div className="relative mx-auto max-w-[820px]">
            {/* the bar itself, scaled up */}
            <div className="relative flex items-center justify-between rounded-2xl border border-hairline bg-white/95 px-4 py-3 shadow-[0_1px_0_rgba(15,15,14,0.04),0_30px_80px_-30px_rgba(15,15,14,0.22)] backdrop-blur-sm md:px-6 md:py-3.5">
              {/* left — apple + app menu (Finder always, the rest only on wider) */}
              <div className="flex items-center gap-3 text-[13px] text-ink-soft md:gap-5 md:text-[14px]">
                <svg width="16" height="19" viewBox="0 0 22 26" className="text-ink">
                  <path
                    fill="currentColor"
                    d="M16.7 13.7c0-3 2.5-4.4 2.6-4.5-1.4-2.1-3.6-2.4-4.4-2.4-1.9-.2-3.6 1.1-4.6 1.1-.9 0-2.4-1.1-4-1-2 0-3.9 1.2-5 3-2.1 3.7-.5 9.2 1.5 12.2 1 1.4 2.2 3.1 3.7 3 1.5-.1 2-1 3.8-1 1.7 0 2.2 1 3.8 1 1.6 0 2.6-1.5 3.6-2.9 1.1-1.6 1.6-3.2 1.6-3.3-.1-.1-3-1.2-3-4.7-.1-2.9 2.4-4.4 2.5-4.5zM13.7 4.4c.8-1 1.4-2.4 1.3-3.8-1.2 0-2.7.8-3.6 1.8-.8.9-1.5 2.4-1.3 3.7 1.4.1 2.7-.7 3.6-1.7z"
                  />
                </svg>
                <span className="font-medium text-ink">Finder</span>
                <span className="hidden md:inline">File</span>
                <span className="hidden md:inline">Edit</span>
                <span className="hidden md:inline">View</span>
              </div>

              {/* right — status icons + RunBar */}
              <div className="flex items-center gap-3 md:gap-5">
                <span className="hidden h-4 w-4 rounded-sm bg-ink/40 sm:block" />
                <span className="hidden h-4 w-4 rounded-full bg-ink/40 sm:block" />
                <svg width="20" height="14" viewBox="0 0 18 12" className="hidden text-ink/55 sm:block">
                  <rect x="0" y="3" width="3" height="6" fill="currentColor" />
                  <rect x="5" y="1" width="3" height="8" fill="currentColor" />
                  <rect x="10" y="0" width="3" height="9" fill="currentColor" opacity=".6" />
                  <rect x="15" y="0" width="3" height="9" fill="currentColor" opacity=".25" />
                </svg>

                {/* RunBar — the star, with a clean highlight ring */}
                <div className="relative -my-1 px-2 py-1">
                  <span
                    aria-hidden
                    className="absolute inset-0 rounded-lg ring-1 ring-vermillon/50"
                  />
                  <span
                    aria-hidden
                    className="absolute -right-1 -top-1 block h-1.5 w-1.5 rounded-full bg-vermillon shadow-[0_0_0_2px_white]"
                  />
                  <div className="relative flex items-center gap-2">
                    <RunnerSprite size={28} state="sprinting" variant="ink" />
                    <span className="font-mono text-[14px] tabular-nums tracking-tight text-ink-soft">
                      23.4
                      <span className="text-ink-mute">/40</span>
                    </span>
                  </div>
                </div>

                <span className="font-mono text-[13px] tabular-nums text-ink md:text-[14px]">
                  2:32 PM
                </span>
              </div>
            </div>

            {/* CALLOUT — points cleanly at the runner */}
            <div
              aria-hidden
              className="pointer-events-none absolute right-[68px] -bottom-20 hidden h-20 w-20 md:block"
            >
              <svg viewBox="0 0 80 80" className="h-full w-full text-vermillon">
                <path
                  d="M40 4 L40 50 L70 70"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1"
                  strokeDasharray="2 3"
                />
                <circle cx="40" cy="4" r="2" fill="currentColor" />
              </svg>
            </div>
            <div className="pointer-events-none absolute -bottom-32 right-0 hidden w-72 md:block">
              <div className="font-mono text-[10px] uppercase tracking-[0.22em] text-vermillon">
                a · the runner
              </div>
              <div className="mt-1 font-display text-[18px] leading-[1.3] text-ink">
                16-pixel sprite, hand-drawn.
              </div>
              <div className="mt-1 text-[13px] leading-[1.5] text-ink-soft">
                Eight-frame cycle. Five mood states. Tracks your weekly goal,
                lives next to the clock.
              </div>
            </div>

            {/* mobile caption (no callout on mobile) */}
            <p className="mt-6 text-center text-[13px] text-ink-soft md:hidden">
              16-pixel sprite. Eight-frame cycle. Lives next to the clock.
            </p>
          </div>
        </figure>

        {/* OUTRO PARAGRAPH */}
        <div className="mt-32 grid grid-cols-12 gap-x-6 md:mt-44">
          <div className="col-span-12 md:col-span-7">
            <div className="border-l-2 border-vermillon pl-5">
              <p className="font-display text-[clamp(1.1rem,1.4vw,1.4rem)] leading-[1.4] text-ink">
                A quiet living signal in the top-right corner — caught in
                peripheral vision, recognized without reading.
              </p>
              <p className="mt-4 max-w-[44ch] text-[14px] leading-[1.65] text-ink-soft">
                No nagging notifications, no popups, no badges. The runner
                simply changes posture as your week unfolds.
              </p>
              <div className="mt-6 flex flex-wrap items-center gap-3 font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
                <span>macOS 14+</span>
                <span className="h-px w-6 bg-hairline" />
                <span>menu-bar only</span>
                <span className="h-px w-6 bg-hairline" />
                <span>no dock icon</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
