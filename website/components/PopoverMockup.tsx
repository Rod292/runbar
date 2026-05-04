import { RunnerSprite } from "./RunnerSprite";

/**
 * 320×420 popover mockup — track + finish line + activities.
 * All drawn from primitives.
 */
export function PopoverMockup() {
  return (
    <div className="w-[320px] rounded-2xl border border-hairline bg-paper shadow-[0_1px_0_rgba(15,15,14,0.04),0_30px_60px_-30px_rgba(15,15,14,0.35)]">
      {/* header */}
      <div className="flex items-center justify-between border-b border-hairline px-4 py-3">
        <div className="flex items-center gap-2">
          <span className="text-[11px] uppercase tracking-[0.18em] text-ink-mute">
            Week 18
          </span>
          {/* streak flame */}
          <span className="inline-flex items-center gap-1 rounded-full bg-vermillon/10 px-2 py-0.5 text-[10px] font-medium text-vermillon-deep">
            <svg width="9" height="11" viewBox="0 0 12 14" fill="currentColor">
              <path d="M6 0c0 3-4 4-4 8a4 4 0 1 0 8 0c0-2-2-3-2-5 0 0 2 .5 2 2 0-2-1-4-4-5z" />
            </svg>
            5
          </span>
        </div>
        <button className="text-[11px] text-ink-mute hover:text-ink">⋯</button>
      </div>

      {/* big metric */}
      <div className="px-4 pt-4">
        <div className="flex items-baseline gap-1.5">
          <span className="font-mono text-[40px] font-light leading-none tracking-tightest text-ink tabular-nums">
            23.4
          </span>
          <span className="text-[12px] text-ink-mute">/ 40 km</span>
        </div>
        <div className="mt-1 text-[11px] text-ink-soft">
          16.6 km left — 3 days remaining
        </div>
      </div>

      {/* track */}
      <div className="relative mx-4 mt-4 h-12 rounded-md border border-hairline bg-white">
        {/* lane lines */}
        <div className="absolute inset-y-0 left-0 right-0 grid grid-cols-1">
          <div className="border-b border-dashed border-hairline" />
        </div>
        {/* runner along the track */}
        <div className="absolute top-1/2 -translate-y-1/2" style={{ left: "58%" }}>
          <RunnerSprite size={28} state="jogging" variant="ink" />
        </div>
        {/* finish flag */}
        <div className="absolute right-2 top-1/2 -translate-y-1/2 flex flex-col items-center">
          <div className="h-7 w-px bg-ink" />
          <div className="-mt-7 ml-px h-3 w-4 bg-[repeating-conic-gradient(#0F0F0E_0%_25%,#FBF9F4_0%_50%)_50%/2px_2px]" />
        </div>
        {/* progress line */}
        <div
          className="absolute bottom-0 left-0 h-px bg-vermillon"
          style={{ width: "58%" }}
        />
      </div>

      {/* activities */}
      <div className="mt-4 divide-y divide-hairline border-t border-hairline">
        <Row day="MON" title="Morning run" dist="8.2 km" pace="5'12''" />
        <Row day="WED" title="Intervals" dist="6.1 km" pace="4'48''" />
        <Row day="FRI" title="Easy run" dist="9.1 km" pace="5'34''" />
      </div>

      {/* footer */}
      <div className="flex items-center justify-between border-t border-hairline px-4 py-2.5 text-[10px] text-ink-mute">
        <span className="inline-flex items-center gap-1.5">
          <span className="dot bg-emerald-500/80" />
          Synced with Strava · 2:31 PM
        </span>
        <span className="font-mono">⌘,</span>
      </div>
    </div>
  );
}

function Row({
  day,
  title,
  dist,
  pace,
}: {
  day: string;
  title: string;
  dist: string;
  pace: string;
}) {
  return (
    <div className="flex items-center justify-between px-4 py-2.5">
      <div className="flex items-center gap-3">
        <span className="font-mono text-[10px] text-ink-mute">{day}</span>
        <span className="text-[12px] text-ink">{title}</span>
      </div>
      <div className="flex items-center gap-3 text-[11px] text-ink-soft">
        <span className="font-mono tabular-nums">{dist}</span>
        <span className="font-mono tabular-nums text-ink-mute">{pace}</span>
      </div>
    </div>
  );
}
