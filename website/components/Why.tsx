/**
 * Section 5 / 6 — Manifesto
 * Editorial pull-quote spread. Asymmetric, magazine-grade.
 * Background: Solid surface (ivory) with hairlines.
 */
import { RunnerSprite } from "./RunnerSprite";

export function Why() {
  return (
    <section
      id="why"
      className="relative border-t border-hairline bg-ivory"
    >
      <div className="mx-auto w-full max-w-[1280px] px-6 py-32 md:px-10 md:py-48">
        {/* Editorial frame: vertical eyebrow on the left edge, asymmetric copy block right of center */}
        <div className="relative grid grid-cols-12 gap-x-6 md:gap-x-10">
          {/* Vertical mono eyebrow — rotated 90°, sits on the left rail */}
          <div className="col-span-1 hidden md:block">
            <div className="sticky top-32 flex h-full items-start">
              <div
                className="origin-top-left translate-x-2 translate-y-32 whitespace-nowrap font-mono text-[10px] uppercase tracking-[0.32em] text-ink-mute"
                style={{ transform: "rotate(-90deg) translate(-100%, 0)" }}
              >
                04 &nbsp;&middot;&nbsp; Manifesto &nbsp;&mdash;&nbsp; on quiet software
              </div>
            </div>
          </div>

          {/* Mobile eyebrow — flat, since rotation is awkward at small widths */}
          <div className="col-span-12 mb-10 md:hidden">
            <div className="font-mono text-[10px] uppercase tracking-[0.28em] text-ink-mute">
              04 &middot; Manifesto
            </div>
          </div>

          {/* Quote block — pulled left of center, ~60% width on desktop */}
          <div className="col-span-12 md:col-span-8 md:col-start-2">
            <div className="relative">
              {/* Oversized italic drop-word "Quiet." floated left */}
              <span
                aria-hidden
                className="float-left mr-4 mt-[0.18em] font-display italic font-normal leading-[0.82] tracking-tightest text-ink"
                style={{ fontSize: "clamp(5rem, 11vw, 9.5rem)" }}
              >
                Quiet.
              </span>

              <p className="font-display text-[clamp(1.5rem,2.5vw,2.15rem)] font-normal italic leading-[1.28] tracking-tight text-ink">
                <span className="not-italic">An app that demands your attention has already lost the race.</span>{" "}
                <span className="text-ink-soft">
                  RunBar does the opposite&thinsp;&mdash;&thinsp;it stays out of the way,
                </span>{" "}
                until the moment your{" "}
                <span className="not-italic font-normal">runner crosses the line.</span>
              </p>

              <div className="clear-both" />

              {/* Attribution / colophon line */}
              <div className="mt-10 flex items-center gap-3">
                <span className="block h-px w-10 bg-ink/60" />
                <span className="font-mono text-[10px] uppercase tracking-[0.28em] text-ink-mute">
                  House note &nbsp;&middot;&nbsp; <span className="text-ink-soft">Rod, maker of RunBar</span>
                </span>
              </div>
            </div>
          </div>

          {/* Right gutter — a single faded sprite as a quiet anchor in the negative space */}
          <div className="col-span-3 hidden md:block md:col-span-2 md:col-start-11">
            <div className="flex h-full items-end justify-end pb-2 opacity-30">
              <RunnerSprite size={20} state="idle" variant="ink" lean={-6} />
            </div>
          </div>
        </div>

        {/* Colophon specs band — single horizontal row, hairline verticals between */}
        <div className="mt-32 md:mt-48">
          <div className="border-t border-hairline" />
          <div className="grid grid-cols-3 divide-x divide-hairline">
            <ColophonCell value="0" label="Ad notifications" />
            <ColophonCell value="100%" label="Local-first" />
            <ColophonCell value="MIT" label="Open source" />
          </div>
          <div className="border-b border-hairline" />

          {/* Foot caption */}
          <div className="mt-5 flex items-center justify-between">
            <span className="font-mono text-[10px] uppercase tracking-[0.28em] text-ink-mute">
              Colophon
            </span>
            <span className="font-mono text-[10px] uppercase tracking-[0.28em] text-ink-mute">
              No tracking &nbsp;&middot;&nbsp; No account &nbsp;&middot;&nbsp; macOS&nbsp;13+
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}

function ColophonCell({ value, label }: { value: string; label: string }) {
  return (
    <div className="flex items-baseline gap-4 px-6 py-7 first:pl-0 last:pr-0">
      <span className="font-mono text-[22px] leading-none text-ink tabular-nums">
        {value}
      </span>
      <span className="font-mono text-[10px] uppercase tracking-[0.26em] text-ink-mute">
        {label}
      </span>
    </div>
  );
}
