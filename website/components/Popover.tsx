import { PopoverMockup } from "./PopoverMockup";
import { RunnerSprite } from "./RunnerSprite";

/**
 * Section 4 / 6 — Popover preview
 * Editorial product spread: the popover floats across a moss/paper diptych,
 * with hairline leader-line callouts annotating live UI elements.
 * This is the darkest moment of the page — leaned into.
 */
export function Popover() {
  return (
    <section className="relative overflow-hidden">
      {/* color-blocked diptych background */}
      <div className="absolute inset-0 -z-10 grid grid-cols-12">
        <div className="relative col-span-12 bg-moss md:col-span-7">
          {/* atmospheric noise on the dark side */}
          <div className="noise-bg absolute inset-0 opacity-[0.35] mix-blend-overlay" />
          {/* tonal gradient softening the seam */}
          <div
            aria-hidden
            className="absolute inset-y-0 right-0 w-40"
            style={{
              background:
                "linear-gradient(to right, rgba(31,42,34,0) 0%, rgba(31,42,34,0.55) 60%, rgba(31,42,34,0.85) 100%)",
            }}
          />
        </div>
        <div className="relative col-span-12 bg-paper md:col-span-5">
          <div
            aria-hidden
            className="absolute inset-y-0 left-0 w-40"
            style={{
              background:
                "linear-gradient(to left, rgba(251,249,244,0) 0%, rgba(251,249,244,0.6) 70%, rgba(251,249,244,0.9) 100%)",
            }}
          />
        </div>
      </div>

      <div className="relative mx-auto grid w-full max-w-[1280px] grid-cols-12 gap-x-6 gap-y-12 px-6 py-24 md:px-10 md:py-36">
        {/* ───────── Caption block — moss side ───────── */}
        <div className="col-span-12 self-center md:col-span-7 md:pr-16">
          <div className="mb-5 flex items-center gap-3 text-[11px] uppercase tracking-[0.24em] text-paper/45">
            <span>03</span>
            <span className="h-px w-8 bg-paper/25" />
            <span>The popover</span>
          </div>

          <h2 className="font-display text-[clamp(2.5rem,5.6vw,4.75rem)] font-medium leading-[0.95] tracking-crammed text-paper">
            One <span className="italic font-normal text-paper/90">track</span>,
            <br />
            one finish
            <br />
            <span className="text-paper/55">line.</span>
          </h2>

          {/* manifesto fragment */}
          <div className="mt-10 max-w-[34ch] border-l border-paper/20 pl-5 font-display text-[18px] italic leading-[1.5] text-paper/75">
            Nothing else fits. Nothing else belongs.
            <br />
            The week, the run, the line.
          </div>

          {/* architectural specs table */}
          <dl className="mt-14 max-w-[460px] divide-y divide-paper/10 border-t border-b border-paper/15 text-paper">
            <SpecRow label="Format" value="320 × 420 px" />
            <SpecRow label="Open" value="One click" />
            <SpecRow label="Latency" value="0 ms — local first" />
            <SpecRow label="Refresh" value="On wake · on sync" />
          </dl>

          {/* tiny runner accent + signature line */}
          <div className="mt-10 flex items-center gap-4 text-[10px] uppercase tracking-[0.22em] text-paper/40">
            <RunnerSprite size={28} state="jogging" variant="paper" />
            <span className="h-px w-16 bg-paper/25" />
            <span>Live · Strava-synced</span>
          </div>
        </div>

        {/* ───────── Popover mockup — floats across the seam ───────── */}
        <div className="relative col-span-12 md:col-span-5">
          {/*
            On md+ we shift the mockup leftward so it visually crosses the
            7/5 seam — about 60% on moss, 40% on paper. Strong drop shadow
            sells the float. On mobile it just centers.
          */}
          <div className="relative flex items-center justify-center md:block md:-ml-[38%] md:mt-4">
            <div
              className="relative"
              style={{
                filter:
                  "drop-shadow(0 40px 60px rgba(0,0,0,0.45)) drop-shadow(0 8px 14px rgba(0,0,0,0.25))",
              }}
            >
              <PopoverMockup />

              {/* ───── Exploded annotation callouts (md+ only) ───── */}

              {/* Callout 1 — streak flame → "5-week streak" */}
              <Callout
                className="hidden md:block"
                style={{ top: 18, left: -180, width: 170 }}
                line={{ from: "right", length: 160 }}
                index="A"
                label="5-week streak"
                hint="Flame increments on consecutive weeks ≥ 80% goal"
              />

              {/* Callout 2 — 23.4 big metric → "Live total" */}
              <Callout
                className="hidden md:block"
                style={{ top: 92, left: -210, width: 200 }}
                line={{ from: "right", length: 190 }}
                index="B"
                label="Live total"
                hint="Distance this week, polled from Strava on focus"
              />

              {/* Callout 3 — runner on track → "Live state" */}
              <Callout
                className="hidden md:block"
                style={{ top: 196, left: -200, width: 190 }}
                line={{ from: "right", length: 180 }}
                index="C"
                label="Live state"
                hint="Sprite mirrors pace · five moods, hand-drawn"
              />

              {/* Callout 4 — synced footer → "Local-first" (right side, paper) */}
              <Callout
                className="hidden md:block"
                style={{ bottom: 14, right: -170, width: 160 }}
                line={{ from: "left", length: 150 }}
                index="D"
                label="Local-first"
                hint="Cache survives offline · refresh on wake"
                tone="ink"
              />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ────────────────────────────────────────────────────────────── */

function SpecRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between py-3">
      <dt className="text-[10px] uppercase tracking-[0.22em] text-paper/45">
        {label}
      </dt>
      <dd className="font-mono text-[14px] tabular-nums tracking-tight text-paper">
        {value}
      </dd>
    </div>
  );
}

type CalloutTone = "paper" | "ink";

function Callout({
  className = "",
  style,
  line,
  index,
  label,
  hint,
  tone = "paper",
}: {
  className?: string;
  style: React.CSSProperties;
  line: { from: "left" | "right"; length: number };
  index: string;
  label: string;
  hint?: string;
  tone?: CalloutTone;
}) {
  const isPaper = tone === "paper";
  const lineColor = isPaper ? "bg-paper/35" : "bg-ink/25";
  const dotColor = isPaper ? "bg-paper/60" : "bg-ink/55";
  const indexColor = isPaper ? "text-paper/40" : "text-ink-mute";
  const labelColor = isPaper ? "text-paper" : "text-ink";
  const hintColor = isPaper ? "text-paper/55" : "text-ink-soft";

  // Leader line anchor: from the side closest to the popover.
  const lineStyle: React.CSSProperties =
    line.from === "right"
      ? { right: -line.length, top: 9, width: line.length }
      : { left: -line.length, top: 9, width: line.length };

  // Terminal dot sits at the popover end of the line.
  const dotStyle: React.CSSProperties =
    line.from === "right"
      ? { right: -line.length - 3, top: 6 }
      : { left: -line.length - 3, top: 6 };

  return (
    <div className={`absolute ${className}`} style={style}>
      <div className="relative">
        {/* hairline leader */}
        <span
          aria-hidden
          className={`absolute h-px ${lineColor}`}
          style={lineStyle}
        />
        {/* terminal dot at popover element */}
        <span
          aria-hidden
          className={`absolute h-1.5 w-1.5 rounded-full ${dotColor}`}
          style={dotStyle}
        />
        {/* caption */}
        <div
          className={`flex items-baseline gap-2 ${
            line.from === "left" ? "flex-row-reverse text-right" : ""
          }`}
        >
          <span
            className={`font-mono text-[10px] tracking-[0.18em] ${indexColor}`}
          >
            {index}
          </span>
          <div>
            <div
              className={`text-[12px] font-medium leading-tight tracking-tight ${labelColor}`}
            >
              {label}
            </div>
            {hint ? (
              <div
                className={`mt-1 max-w-[16ch] text-[10px] leading-[1.4] ${hintColor}`}
              >
                {hint}
              </div>
            ) : null}
          </div>
        </div>
      </div>
    </div>
  );
}
