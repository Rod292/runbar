import { RunnerSprite, type RunnerStateName } from "./RunnerSprite";

/**
 * Section 3 / 6 — The five states
 * Layout: Typological catalog / specimen sheet
 * - Editorial header with numeric tag, display "FIVE", italic "states"
 * - Asymmetric bento: Sprinting hero spans 2 cols with frame strip + fps badge
 * - Mini stats row under each runner: fps · trigger · mood
 * - Hairline numbering 01–05 in each cell
 */

type StateMeta = {
  num: string;
  name: string;
  state: RunnerStateName;
  frames: string;
  fps: string;
  trigger: string;
  mood: string;
  caption: string;
};

const STATES: StateMeta[] = [
  {
    num: "01",
    name: "Warming up",
    state: "idle",
    frames: "6 frames",
    fps: "3 fps",
    trigger: "week begins",
    mood: "bracing",
    caption: "High knees on the spot. The week hasn't started yet.",
  },
  {
    num: "02",
    name: "Jogging",
    state: "jogging",
    frames: "8 frames",
    fps: "6 fps",
    trigger: "steady week",
    mood: "neutral",
    caption: "Forward stride, even tempo. On pace.",
  },
  {
    num: "03",
    name: "Sprinting",
    state: "sprinting",
    frames: "8 frames",
    fps: "9 fps",
    trigger: "just logged a run",
    mood: "charged",
    caption: "Same cycle, faster. Fresh kilometers in the bank.",
  },
  {
    num: "04",
    name: "Tired",
    state: "tired",
    frames: "6 frames",
    fps: "4 fps",
    trigger: "falling behind",
    mood: "muted",
    caption: "Slumped shoulders, head down. Behind on the goal.",
  },
  {
    num: "05",
    name: "Victory",
    state: "victory",
    frames: "6 frames",
    fps: "6 fps",
    trigger: "goal cleared",
    mood: "loud",
    caption: "Arms up, mid-jump. Goal cleared.",
  },
];

export function States() {
  const idle = STATES[0];
  const jogging = STATES[1];
  const sprinting = STATES[2];
  const tired = STATES[3];
  const victory = STATES[4];

  return (
    <section
      id="features"
      className="mx-auto w-full max-w-[1280px] px-6 py-24 md:px-10 md:py-32"
    >
      {/* Editorial header */}
      <div className="mb-14 grid grid-cols-12 items-end gap-x-6 gap-y-6">
        <div className="col-span-12 flex items-end gap-5 md:col-span-7">
          <div className="flex flex-col pb-2">
            <span className="font-mono text-[10px] uppercase tracking-[0.24em] text-ink-mute">
              §
            </span>
            <span className="font-mono text-[10px] uppercase tracking-[0.24em] text-ink-mute">
              02
            </span>
          </div>
          <div className="h-[clamp(3rem,7vw,6rem)] w-px bg-hairline" />
          <div className="flex items-end gap-3 leading-none">
            <span className="font-display text-[clamp(3.25rem,8vw,6.5rem)] font-medium tracking-crammed text-ink">
              FIVE
            </span>
            <span className="pb-2 font-display text-[clamp(1.25rem,2.2vw,1.75rem)] italic text-ink-soft">
              states
            </span>
          </div>
        </div>

        <div className="col-span-12 md:col-span-5">
          <div className="mb-3 flex items-center gap-3">
            <span className="h-px flex-1 bg-hairline" />
            <span className="font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
              specimen sheet
            </span>
          </div>
          <p className="text-[13px] leading-[1.6] text-ink-soft">
            The little runner follows your rhythm — warming up at week start,
            jogging through the middle, sprinting after a fresh run, slumping
            if you fall behind, raising arms when you cross the line. Four
            hand-drawn cycles. Six to eight frames each.
          </p>
        </div>
      </div>

      {/* Asymmetric bento: 6-col grid. Sprinting hero spans 2. */}
      <div className="grid grid-cols-2 gap-px overflow-hidden rounded-2xl border border-hairline bg-hairline md:grid-cols-6">
        <StateCell meta={idle} />
        <StateCell meta={jogging} />
        <SprintingHero meta={sprinting} />
        <StateCell meta={tired} muted />
        <StateCell meta={victory} />
      </div>

      {/* Footer caption — catalog-style colophon */}
      <div className="mt-6 flex flex-wrap items-center justify-between gap-4 px-1">
        <div className="flex items-center gap-3">
          <span className="font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
            sheet 02 / 06
          </span>
          <span className="dot bg-hairline" aria-hidden />
          <span className="font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
            four cycles · 6–8 frames
          </span>
        </div>
        <span className="font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
          ink on paper · 1×
        </span>
      </div>
    </section>
  );
}

function StateCell({
  meta,
  muted,
}: {
  meta: StateMeta;
  muted?: boolean;
}) {
  return (
    <div className="relative flex aspect-square flex-col justify-between bg-paper p-5 md:aspect-auto md:min-h-[280px]">
      {/* Hairline numbering — top-left corner */}
      <span className="pointer-events-none absolute left-3 top-3 font-mono text-[9px] tracking-[0.2em] text-ink-mute/70">
        {meta.num}
      </span>

      <div className="flex items-start justify-end">
        <span className="font-mono text-[10px] uppercase tracking-[0.18em] text-ink">
          {meta.name}
        </span>
      </div>

      <div
        className={`my-2 flex flex-1 items-center justify-center ${
          muted ? "opacity-40" : ""
        }`}
      >
        <RunnerSprite size={76} state={meta.state} variant="ink" />
      </div>

      {/* Data layer: fps · frames · trigger · mood */}
      <div className="mt-2 border-t border-hairline pt-2">
        <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
          <span className="font-mono text-[10px] tracking-tight text-ink">
            {meta.fps}
          </span>
          <span className="text-ink-mute">·</span>
          <span className="font-mono text-[10px] tracking-tight text-ink-soft">
            {meta.frames}
          </span>
          <span className="text-ink-mute">·</span>
          <span className="text-[10px] italic text-ink-soft">{meta.mood}</span>
        </div>
        <p className="mt-1.5 text-[11px] leading-[1.45] text-ink-soft">
          {meta.caption}
        </p>
      </div>
    </div>
  );
}

function SprintingHero({ meta }: { meta: StateMeta }) {
  // 8-frame strip — the actual jogging cycle, frame-by-frame. Sprinting
  // reuses the jogging sprite sheet (faster fps), so showing the 8 jogging
  // poses here is the truthful contact sheet for both states.
  const FRAMES = 8;

  return (
    <div className="relative col-span-2 flex flex-col justify-between bg-paper p-5 md:min-h-[280px]">
      {/* Hairline numbering */}
      <span className="pointer-events-none absolute left-3 top-3 font-mono text-[9px] tracking-[0.2em] text-vermillon">
        {meta.num}
      </span>

      {/* Top: name + accent fps badge */}
      <div className="flex items-start justify-between">
        <div className="ml-7">
          <div className="font-mono text-[10px] uppercase tracking-[0.18em] text-vermillon-deep">
            featured pose
          </div>
          <div className="mt-1 font-display text-[clamp(1.5rem,2.4vw,2rem)] font-medium leading-none tracking-crammed text-ink">
            {meta.name}
          </div>
        </div>

        {/* fps mini-stat badge */}
        <div className="flex items-center gap-2 rounded-full border border-hairline bg-ivory px-2.5 py-1">
          <span className="dot bg-vermillon" aria-hidden />
          <span className="font-mono text-[10px] uppercase tracking-widest text-ink">
            {meta.fps}
          </span>
        </div>
      </div>

      {/* Center: enlarged runner */}
      <div className="my-3 flex flex-1 items-center justify-center">
        <RunnerSprite size={132} state={meta.state} variant="ink" />
      </div>

      {/* Frame strip — 8 mini frames suggesting the running cycle */}
      <div className="mb-3">
        <div className="mb-1.5 flex items-center justify-between">
          <span className="font-mono text-[9px] uppercase tracking-[0.22em] text-ink-mute">
            cycle · 8 frames
          </span>
          <span className="font-mono text-[9px] uppercase tracking-[0.22em] text-ink-mute">
            f01 — f08
          </span>
        </div>
        <div className="flex items-center gap-px overflow-hidden rounded-sm border border-hairline bg-hairline">
          {Array.from({ length: FRAMES }).map((_, i) => (
            <div
              key={i}
              className="flex flex-1 items-center justify-center bg-ivory py-1.5"
            >
              <RunnerSprite size={28} state="jogging" variant="ink" frame={i} lean={0} />
            </div>
          ))}
        </div>
      </div>

      {/* Data layer */}
      <div className="border-t border-hairline pt-2">
        <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
          <span className="font-mono text-[10px] tracking-tight text-ink">
            {meta.fps}
          </span>
          <span className="text-ink-mute">·</span>
          <span className="font-mono text-[10px] tracking-tight text-ink-soft">
            {meta.frames}
          </span>
          <span className="text-ink-mute">·</span>
          <span className="text-[10px] text-ink-soft">{meta.trigger}</span>
          <span className="text-ink-mute">·</span>
          <span className="text-[10px] italic text-ink-soft">{meta.mood}</span>
        </div>
        <p className="mt-1.5 max-w-[44ch] text-[11px] leading-[1.45] text-ink-soft">
          {meta.caption}
        </p>
      </div>
    </div>
  );
}
