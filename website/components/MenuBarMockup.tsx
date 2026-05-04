import { RunnerSprite } from "./RunnerSprite";

/**
 * macOS menu-bar mockup with the runner integrated.
 * Drawn from primitives — not a screenshot.
 */
export function MenuBarMockup() {
  return (
    <div className="relative">
      {/* desktop fade hint */}
      <div className="absolute -inset-x-8 -inset-y-6 -z-10 rounded-3xl bg-gradient-to-b from-paper to-transparent" />

      {/* The bar */}
      <div className="flex items-center justify-between rounded-xl border border-hairline bg-white/80 px-3 py-1.5 shadow-[0_1px_0_rgba(15,15,14,0.04),0_8px_28px_-12px_rgba(15,15,14,0.18)] backdrop-blur-sm">
        {/* left — apple + app menu */}
        <div className="flex items-center gap-3 text-[11px] text-ink-soft">
          <svg width="12" height="14" viewBox="0 0 22 26" className="text-ink">
            <path
              fill="currentColor"
              d="M16.7 13.7c0-3 2.5-4.4 2.6-4.5-1.4-2.1-3.6-2.4-4.4-2.4-1.9-.2-3.6 1.1-4.6 1.1-.9 0-2.4-1.1-4-1-2 0-3.9 1.2-5 3-2.1 3.7-.5 9.2 1.5 12.2 1 1.4 2.2 3.1 3.7 3 1.5-.1 2-1 3.8-1 1.7 0 2.2 1 3.8 1 1.6 0 2.6-1.5 3.6-2.9 1.1-1.6 1.6-3.2 1.6-3.3-.1-.1-3-1.2-3-4.7-.1-2.9 2.4-4.4 2.5-4.5zM13.7 4.4c.8-1 1.4-2.4 1.3-3.8-1.2 0-2.7.8-3.6 1.8-.8.9-1.5 2.4-1.3 3.7 1.4.1 2.7-.7 3.6-1.7z"
            />
          </svg>
          <span className="font-medium text-ink">Finder</span>
          <span>File</span>
          <span>Edit</span>
          <span>View</span>
        </div>

        {/* right — status icons + RunBar */}
        <div className="flex items-center gap-3">
          {/* fake status icons */}
          <span className="block h-3 w-3 rounded-sm bg-ink/40" />
          <span className="block h-3 w-3 rounded-full bg-ink/40" />
          <svg width="14" height="10" viewBox="0 0 18 12" className="text-ink/55">
            <rect x="0" y="3" width="3" height="6" fill="currentColor" />
            <rect x="5" y="1" width="3" height="8" fill="currentColor" />
            <rect x="10" y="0" width="3" height="9" fill="currentColor" opacity=".6" />
            <rect x="15" y="0" width="3" height="9" fill="currentColor" opacity=".25" />
          </svg>

          {/* RunBar — highlight ring */}
          <div className="relative -my-1 -mx-1 px-1 py-1">
            <span className="absolute inset-0 rounded-md ring-1 ring-vermillon/40" aria-hidden />
            <div className="relative flex items-center gap-2">
              <RunnerSprite size={16} state="jogging" variant="ink" />
              <span className="font-mono text-[10px] tracking-tight text-ink-soft">
                23.4<span className="text-ink-mute">/40</span>
              </span>
            </div>
          </div>

          {/* time */}
          <span className="font-mono text-[11px] tabular-nums text-ink">2:32 PM</span>
        </div>
      </div>

      {/* annotation */}
      <div className="mt-3 flex items-center gap-2 text-[11px] text-ink-mute">
        <span className="dot bg-vermillon" />
        <span>RunBar lives here, right next to the clock.</span>
      </div>
    </div>
  );
}
