import { MenuBarMockup } from "./MenuBarMockup";
import { RunnerSprite } from "./RunnerSprite";

/**
 * Section 2 / 6 — Menu bar showcase
 * Anchor: editorial product-sheet — top eyebrow, centered desktop scene,
 *         hairline annotations, magnifier detail crop, bottom paragraph.
 * Background: tonal warm layers + vertical rhythm hairlines + paper noise.
 * Density: high.
 */
export function Showcase() {
  return (
    <section
      id="showcase"
      className="relative overflow-hidden border-y border-hairline bg-paper"
    >
      {/* tonal warm wash — paper above, ivory toward the floor */}
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-paper via-paper to-ivory" />
      {/* vertical rhythm hairlines (12-col echo) */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-y-0 left-1/2 hidden w-full max-w-[1280px] -translate-x-1/2 md:block"
      >
        <div className="grid h-full grid-cols-12 gap-x-6 px-10">
          {Array.from({ length: 12 }).map((_, i) => (
            <div
              key={i}
              className={
                i === 0 || i === 6 || i === 11
                  ? "border-l border-hairline/60"
                  : "border-l border-hairline/20"
              }
            />
          ))}
        </div>
      </div>
      {/* paper grain */}
      <div className="pointer-events-none absolute inset-0 noise-bg opacity-40" />

      <div className="relative mx-auto w-full max-w-[1280px] px-6 pt-20 pb-28 md:px-10 md:pt-24 md:pb-36">
        {/* TOP EYEBROW — section index + chapter title, full-width band */}
        <div className="mb-12 flex items-end justify-between border-b border-hairline pb-4 md:mb-16">
          <div className="flex items-baseline gap-4">
            <span className="font-mono text-[11px] uppercase tracking-[0.28em] text-vermillon">
              §02
            </span>
            <span className="text-[11px] uppercase tracking-[0.22em] text-ink-mute">
              The icon · menu-bar residency
            </span>
          </div>
          <span className="hidden font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute md:block">
            fig. 02 — runner at rest
          </span>
        </div>

        {/* HEADLINE — wraps over the visual, editorial pull */}
        <div className="grid grid-cols-12 gap-x-6">
          <h2 className="col-span-12 font-display text-[clamp(2.2rem,4.4vw,4rem)] font-medium leading-[1.02] tracking-tightest text-ink md:col-span-10">
            A 16-pixel runner whose mood{" "}
            <span className="italic text-ink-soft">shifts</span> with your week —
            <span className="text-ink-mute"> quietly, in the corner.</span>
          </h2>
        </div>

        {/* DESKTOP SCENE — main stage */}
        <div className="relative mt-14 md:mt-20">
          {/* faint window outline behind the bar (suggestion of an open app) */}
          <div
            aria-hidden
            className="absolute -left-2 right-24 top-24 hidden h-[260px] rounded-[14px] border border-hairline/70 bg-white/40 shadow-[0_20px_60px_-40px_rgba(15,15,14,0.18)] md:block"
          >
            <div className="flex h-7 items-center gap-1.5 border-b border-hairline/60 px-3">
              <span className="h-2 w-2 rounded-full bg-hairline" />
              <span className="h-2 w-2 rounded-full bg-hairline" />
              <span className="h-2 w-2 rounded-full bg-hairline" />
            </div>
          </div>
          <div
            aria-hidden
            className="absolute -right-6 left-32 top-40 hidden h-[200px] rounded-[14px] border border-hairline/50 bg-white/25 md:block"
          />

          {/* the desktop card itself */}
          <div className="relative">
            <div className="rounded-[18px] border border-hairline bg-white p-3 shadow-[0_40px_120px_-50px_rgba(15,15,14,0.35)]">
              {/* traffic lights */}
              <div className="mb-3 flex items-center gap-1.5">
                <span className="h-2.5 w-2.5 rounded-full bg-[#FF5F57]" />
                <span className="h-2.5 w-2.5 rounded-full bg-[#FEBC2E]" />
                <span className="h-2.5 w-2.5 rounded-full bg-[#28C840]" />
                <span className="ml-3 font-mono text-[10px] uppercase tracking-[0.2em] text-ink-mute">
                  desktop · 2:32 PM
                </span>
              </div>

              {/* abstracted desktop interior */}
              <div className="relative h-[320px] overflow-hidden rounded-[10px] bg-gradient-to-br from-ivory via-paper to-[#F2ECDF] md:h-[420px]">
                {/* tonal wallpaper crop — warm/cream layers, no gradient slop */}
                <div
                  aria-hidden
                  className="absolute inset-0"
                  style={{
                    background:
                      "radial-gradient(80% 60% at 20% 30%, rgba(229,82,61,0.06), transparent 60%), radial-gradient(60% 50% at 85% 70%, rgba(31,42,34,0.05), transparent 60%)",
                  }}
                />
                <div className="absolute inset-0 noise-bg opacity-60" />

                {/* faded stat — second-read */}
                <div className="absolute bottom-20 left-10 max-w-[60%]">
                  <div className="font-display text-[140px] font-light leading-none tracking-crammed text-ink/[0.07] md:text-[180px]">
                    23.4
                  </div>
                  <div className="mt-2 font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute/70">
                    km · this week / 40
                  </div>
                </div>

                {/* dock band — soft hint at bottom */}
                <div
                  aria-hidden
                  className="absolute inset-x-12 bottom-3 h-9 rounded-xl border border-hairline/70 bg-white/55 backdrop-blur-sm md:inset-x-24"
                >
                  <div className="flex h-full items-center justify-center gap-2 px-3">
                    {Array.from({ length: 7 }).map((_, i) => (
                      <span
                        key={i}
                        className={`block rounded-[6px] ${
                          i === 3
                            ? "h-6 w-6 bg-vermillon/70"
                            : "h-6 w-6 bg-ink/10"
                        }`}
                      />
                    ))}
                  </div>
                </div>

                {/* The bar — pinned crisp at top */}
                <div className="absolute inset-x-3 top-3">
                  <MenuBarMockup />
                </div>
              </div>
            </div>

            {/* HAIRLINE ANNOTATIONS — editorial product-sheet style */}
            {/* Top-right: "16-pixel runner" — line goes up & right from runner */}
            <div className="pointer-events-none absolute -right-4 top-2 hidden w-56 md:block lg:-right-10">
              <svg
                viewBox="0 0 200 60"
                className="absolute -left-32 top-3 h-[60px] w-[200px] text-ink-mute"
                aria-hidden
              >
                <path
                  d="M2 56 L70 56 L130 12 L198 12"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="0.75"
                />
                <circle cx="2" cy="56" r="2" fill="currentColor" />
              </svg>
              <div className="pl-2">
                <div className="font-mono text-[10px] uppercase tracking-[0.22em] text-vermillon">
                  a · runner
                </div>
                <div className="mt-1 font-display text-[14px] leading-[1.3] text-ink">
                  16-pixel sprite
                </div>
                <div className="mt-1 text-[11px] leading-[1.45] text-ink-soft">
                  Hand-drawn, 8-frame cycle. Five mood states tied to your goal.
                </div>
              </div>
            </div>

            {/* Right-mid: "Live state" — points to highlight ring */}
            <div className="pointer-events-none absolute -right-2 top-44 hidden w-52 md:block lg:-right-8">
              <svg
                viewBox="0 0 180 40"
                className="absolute -left-24 top-2 h-[40px] w-[180px] text-ink-mute"
                aria-hidden
              >
                <path
                  d="M2 20 L88 20 L120 8 L178 8"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="0.75"
                />
                <circle cx="2" cy="20" r="2" fill="currentColor" />
              </svg>
              <div className="pl-2 pt-3">
                <div className="font-mono text-[10px] uppercase tracking-[0.22em] text-vermillon">
                  b · live state
                </div>
                <div className="mt-1 font-display text-[14px] leading-[1.3] text-ink">
                  Mood reads at a glance
                </div>
              </div>
            </div>

            {/* Bottom-left: "Strava-sync dot" */}
            <div className="pointer-events-none absolute -left-2 bottom-6 hidden w-56 md:block lg:-left-6">
              <svg
                viewBox="0 0 200 50"
                className="absolute left-32 bottom-7 h-[50px] w-[200px] text-ink-mute"
                aria-hidden
              >
                <path
                  d="M2 12 L70 12 L120 44 L198 44"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="0.75"
                />
                <circle cx="198" cy="44" r="2" fill="currentColor" />
              </svg>
              <div className="pb-2">
                <div className="font-mono text-[10px] uppercase tracking-[0.22em] text-vermillon">
                  c · strava sync
                </div>
                <div className="mt-1 font-display text-[14px] leading-[1.3] text-ink">
                  Vermillon dot = fresh data
                </div>
                <div className="mt-1 text-[11px] leading-[1.45] text-ink-soft">
                  Polls every 90s when you're online. Silent otherwise.
                </div>
              </div>
            </div>
          </div>

          {/* MAGNIFIER DETAIL CROP — bottom-right of stage, breaking the frame */}
          <div className="relative mt-10 grid grid-cols-12 gap-x-6 md:mt-0">
            <div className="col-span-12 md:col-start-8 md:col-span-5 md:-mt-20 md:translate-x-6 lg:translate-x-12">
              <figure className="relative">
                {/* magnifier frame */}
                <div className="relative overflow-hidden rounded-full border border-hairline bg-white shadow-[0_20px_60px_-30px_rgba(15,15,14,0.35)]">
                  <div className="aspect-square w-full bg-gradient-to-br from-ivory to-paper">
                    {/* crosshair */}
                    <div
                      aria-hidden
                      className="absolute inset-0 flex items-center justify-center"
                    >
                      <div className="h-px w-full bg-hairline/60" />
                    </div>
                    <div
                      aria-hidden
                      className="absolute inset-0 flex items-center justify-center"
                    >
                      <div className="h-full w-px bg-hairline/60" />
                    </div>
                    {/* the zoomed runner + km counter */}
                    <div className="absolute inset-0 flex items-center justify-center gap-4">
                      <RunnerSprite size={96} state="sprinting" variant="ink" />
                      <div className="flex flex-col items-start">
                        <span className="font-mono text-[28px] tabular-nums tracking-tight text-ink">
                          23.4
                        </span>
                        <span className="font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
                          / 40 km
                        </span>
                      </div>
                    </div>
                    {/* focus ring */}
                    <div
                      aria-hidden
                      className="absolute inset-4 rounded-full border border-vermillon/40"
                    />
                  </div>
                </div>
                {/* magnifier handle */}
                <div
                  aria-hidden
                  className="absolute -bottom-6 -right-2 h-16 w-2 origin-top rotate-[35deg] rounded-full bg-ink/80"
                />
                <figcaption className="mt-5 flex items-baseline gap-3 border-t border-hairline pt-3">
                  <span className="font-mono text-[10px] uppercase tracking-[0.22em] text-vermillon">
                    detail
                  </span>
                  <span className="font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
                    600 % zoom · sprinting state
                  </span>
                </figcaption>
              </figure>
            </div>

            {/* BOTTOM PARAGRAPH — anchored bottom-left, wraps under visual */}
            <div className="col-span-12 mt-10 md:col-span-6 md:row-start-1 md:mt-16">
              <div className="border-l-2 border-vermillon pl-5">
                <p className="font-display text-[clamp(1.1rem,1.4vw,1.4rem)] leading-[1.4] text-ink">
                  Five subtle states — calm, jogging, sprinting, tired,
                  victorious.
                </p>
                <p className="mt-4 max-w-[42ch] text-[14px] leading-[1.65] text-ink-soft">
                  No nagging notifications, no popups, no badges. Just a quiet
                  living signal in the top-right corner that you'll catch in
                  peripheral vision while you work — and recognize without
                  reading.
                </p>
                <div className="mt-6 flex items-center gap-4 font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
                  <span>macOS 13+</span>
                  <span className="h-px w-6 bg-hairline" />
                  <span>menu-bar only</span>
                  <span className="h-px w-6 bg-hairline" />
                  <span>no dock icon</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
