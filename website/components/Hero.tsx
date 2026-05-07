import { DownloadButton } from "./DownloadButton";
import { RunnerSprite } from "./RunnerSprite";

/**
 * Section 1 / 6 — Hero
 * Two-column editorial: content left (cols 1–7), self-contained "stage" right
 * (cols 8–12). The stage is a bounded frame so the runner trail never bleeds
 * into the next section.
 */
export function Hero() {
  return (
    <section
      id="top"
      className="relative mx-auto w-full max-w-[1280px] px-6 pb-24 pt-14 md:px-10 md:pb-28 md:pt-20"
    >
      <div className="grid grid-cols-12 items-center gap-x-8 gap-y-12">
        {/* ─────────── LEFT — content ─────────── */}
        <div className="col-span-12 md:col-span-7">
          {/* Eyebrow */}
          <div className="mb-10 flex items-center gap-3 text-[10.5px] uppercase tracking-[0.28em] text-ink-mute md:mb-14">
            <span className="dot bg-vermillon" />
            <span>Menu-bar app</span>
            <span aria-hidden className="h-px w-6 bg-hairline" />
            <span className="font-mono normal-case tracking-[0.05em] text-ink-soft">
              macOS 14+
            </span>
          </div>

          {/* Headline — "A runner — in your menu bar." */}
          <h1 className="font-display font-medium leading-[0.9] tracking-crammed text-ink">
            <span className="block text-[clamp(3.75rem,9.5vw,8.5rem)] italic">
              A&nbsp;runner
            </span>
            <span className="mt-1 flex items-baseline gap-3 text-[clamp(1.4rem,2.8vw,2.3rem)] font-normal not-italic tracking-tight text-ink-soft md:mt-2">
              <span aria-hidden className="text-vermillon">—</span>
              <span>in your menu&nbsp;bar.</span>
            </span>
          </h1>

          {/* Sub */}
          <p className="mt-9 max-w-[42ch] text-[clamp(1rem,1.4vw,1.18rem)] leading-[1.55] text-ink-soft md:mt-10">
            Strava tells you what you did. RunBar tells you where you stand{" "}
            <em className="not-italic text-ink underline decoration-vermillon decoration-[1.5px] underline-offset-[5px]">
              right now
            </em>
            — at a glance, without opening an app.
          </p>

          {/* CTAs */}
          <div className="mt-9 flex flex-wrap items-center gap-x-7 gap-y-4 md:mt-11">
            <DownloadButton size="lg" source="hero" />
            <a
              href="#showcase"
              className="group inline-flex items-center gap-2 text-[13px] font-medium text-ink"
            >
              <span className="border-b border-ink/25 pb-[3px] transition group-hover:border-ink">
                See how it works
              </span>
              <span
                aria-hidden
                className="text-ink-mute transition group-hover:translate-x-0.5 group-hover:text-ink"
              >
                →
              </span>
            </a>
          </div>

          {/* Editorial caption row */}
          <div className="mt-10 flex items-stretch gap-4 md:mt-12">
            <span aria-hidden className="w-px shrink-0 bg-hairline" />
            <dl className="flex flex-wrap items-baseline gap-x-6 gap-y-1.5 font-mono text-[10.5px] uppercase tracking-[0.14em] text-ink-mute">
              <div className="flex items-baseline gap-1.5">
                <dt className="text-ink-mute/70">Build</dt>
                <dd className="text-ink-soft">v0.1.23 · 2.4 MB DMG</dd>
              </div>
              <div className="flex items-baseline gap-1.5">
                <dt className="text-ink-mute/70">Arch</dt>
                <dd className="text-ink-soft">Apple Silicon · Intel</dd>
              </div>
              <div className="flex items-baseline gap-1.5">
                <dt className="text-ink-mute/70">Privacy</dt>
                <dd className="text-ink-soft">No ads · No tracking</dd>
              </div>
            </dl>
          </div>
        </div>

        {/* ─────────── RIGHT — bounded stage ─────────── */}
        <div className="col-span-12 md:col-span-5">
          <RunnerStage />
        </div>
      </div>
    </section>
  );
}

/**
 * RunnerStage — bounded right-column composition.
 *
 *   ┌──────────────────────────────────────┐
 *   │  WK 18                  GOAL · 40 KM │  header
 *   │                                      │
 *   │             18  ← oversized faint    │
 *   │     🏃  🏃  🏃  🏃                    │  trail
 *   │  ────────────────────────────·●      │  hairline track + finish
 *   │                                      │
 *   │  23.4 KM THIS WEEK     16.6 LEFT     │  data strip
 *   └──────────────────────────────────────┘
 *
 * Track sits at a fixed offset from the bottom of the frame. Runners use
 * `items-end` to plant their feet on the track. Nothing escapes the frame.
 */
function RunnerStage() {
  return (
    <div className="relative w-full">
      {/* eyebrow row above the frame */}
      <div className="mb-3 flex items-center justify-between font-mono text-[10px] uppercase tracking-[0.24em] text-ink-mute">
        <span>Wk 18</span>
        <span aria-hidden className="h-px flex-1 mx-3 bg-hairline" />
        <span>Goal · 40 km</span>
      </div>

      {/* the bounded frame */}
      <div className="relative h-[280px] w-full overflow-hidden rounded-[14px] border border-hairline bg-ivory">
        {/* paper noise */}
        <div className="pointer-events-none absolute inset-0 noise-bg opacity-30" />

        {/* second-read — oversized faint week numeral */}
        <div
          aria-hidden
          className="pointer-events-none absolute -right-3 top-2 select-none font-display italic font-medium leading-[0.85] tracking-crammed text-ink/[0.06]"
          style={{ fontSize: "clamp(7rem, 14vw, 12rem)" }}
        >
          18
        </div>

        {/* hairline track */}
        <div className="absolute inset-x-7 bottom-[88px] h-px bg-hairline" />

        {/* km ticks */}
        <div className="absolute inset-x-7 bottom-[88px] flex items-center justify-between">
          {Array.from({ length: 5 }).map((_, i) => (
            <span
              key={i}
              aria-hidden
              className="block h-[5px] w-px -translate-y-[2px] bg-hairline"
            />
          ))}
        </div>

        {/* runner trail — feet planted on the track */}
        <div className="absolute bottom-[88px] left-7 right-16 flex items-end justify-end gap-3">
          <span className="opacity-[0.14]">
            <RunnerSprite size={32} state="jogging" variant="ink" lean={-5} />
          </span>
          <span className="opacity-[0.30]">
            <RunnerSprite size={42} state="jogging" variant="ink" lean={-5} />
          </span>
          <span className="opacity-[0.55]">
            <RunnerSprite size={56} state="sprinting" variant="ink" lean={-6} />
          </span>
          <span>
            <RunnerSprite size={88} state="sprinting" variant="ink" lean={-7} />
          </span>
        </div>

        {/* finish marker — vertical line + vermillon dot */}
        <div
          aria-hidden
          className="absolute bottom-[88px] right-9"
          style={{ width: 1, height: 18, background: "rgba(15,15,14,0.55)" }}
        />
        <span
          aria-hidden
          className="absolute bottom-[103px] right-[33px] block h-[7px] w-[7px] rounded-full bg-vermillon"
        />

        {/* data strip — bottom */}
        <div className="absolute inset-x-7 bottom-5 flex items-baseline justify-between">
          <div className="flex items-baseline gap-2 font-mono text-[10px] uppercase tracking-[0.16em]">
            <span className="text-ink">23.4</span>
            <span className="text-ink-mute">km this week</span>
          </div>
          <div className="flex items-baseline gap-2 font-mono text-[10px] uppercase tracking-[0.16em]">
            <span className="text-vermillon">·</span>
            <span className="text-ink-mute">16.6 left</span>
          </div>
        </div>

        {/* progress hairline — vermillon, under the track */}
        <div
          aria-hidden
          className="absolute left-7 bottom-[87px] h-px bg-vermillon"
          style={{ width: "calc((100% - 3.5rem) * 0.585)" }}
        />
      </div>

      {/* foot caption */}
      <div className="mt-3 flex items-center justify-between font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
        <span>fig. 01 — your week, in motion</span>
        <span className="text-ink-mute/60">live</span>
      </div>
    </div>
  );
}
