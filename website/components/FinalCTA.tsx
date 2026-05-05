import { DownloadButton } from "./DownloadButton";
import { RunnerSprite } from "./RunnerSprite";

/**
 * Section 6 / 6 — Final CTA + Footer
 * Cinematic close: a horizontal hairline track crosses the section,
 * a trail of runners (paper variant) approaches a vermillon finish marker,
 * the leader has crossed past it. Echoes the Hero — the journey ends here.
 *
 * Second-read: ultra-faded "FINISH" colophon (closure metaphor).
 * Atmospherics: top finish-line hairline, faint vertical light beam from the
 * marker, tonal vermillon radial bleed at bottom-left, paper noise.
 */
export function FinalCTA() {
  return (
    <footer className="relative isolate overflow-hidden bg-ink text-paper">
      {/* tonal gradient depth */}
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(ellipse_80%_60%_at_20%_120%,rgba(229,82,61,0.18),transparent_60%)]" />
      <div className="absolute inset-0 -z-10 noise-bg opacity-[0.04]" />

      {/* top finish-line hairline */}
      <div className="absolute inset-x-0 top-0 h-px bg-paper/15" />

      {/* second-read — ultra-faded "FINISH" colophon */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 -bottom-6 select-none text-center font-display italic text-[clamp(140px,26vw,360px)] font-medium leading-[0.8] tracking-crammed text-paper/[0.035]"
      >
        Finish.
      </div>

      <div className="mx-auto flex w-full max-w-[1280px] flex-col gap-24 px-6 py-24 md:px-10 md:py-32">
        {/* ─── finish-line composition ─── */}
        <FinishLine />

        {/* ─── CTA block: asymmetric two-column close ─── */}
        <div className="grid grid-cols-12 items-end gap-y-12 gap-x-8">
          {/* left — eyebrow + supporting copy + CTAs */}
          <div className="col-span-12 md:col-span-5">
            <div className="mb-6 flex items-center gap-2 text-[11px] uppercase tracking-[0.22em] text-paper/45">
              <span className="dot bg-vermillon" />
              Available today
            </div>

            <p className="max-w-[34ch] text-[15px] leading-[1.55] text-paper/65">
              A tiny runner that lives in your menu bar and keeps moving until
              your weekly goal is done. Strava-synced. Mac-only. Free.
            </p>

            <div className="mt-9 flex flex-col items-start gap-3">
              <DownloadButton
                size="lg"
                variant="primary"
                className="!bg-paper !text-ink hover:!bg-paper/90"
              />
              {/* legitimacy strip */}
              <div className="flex items-center gap-2 pl-1 font-mono text-[10.5px] uppercase tracking-[0.16em] text-paper/35">
                <span>macOS 14+</span>
                <span className="text-paper/20">·</span>
                <span>2.2 MB</span>
                <span className="text-paper/20">·</span>
                <span>Free</span>
              </div>
            </div>
          </div>

          {/* right — dominant typographic close */}
          <div className="col-span-12 md:col-span-7 md:pl-8">
            <h2 className="font-display font-medium leading-[0.86] tracking-crammed text-paper">
              <span className="block text-[clamp(1.6rem,3.4vw,2.6rem)] font-normal not-italic text-paper/55">
                Put a runner in your menu bar.
              </span>
              <span className="mt-2 block text-[clamp(5rem,14vw,11rem)] italic text-paper">
                Run.
              </span>
            </h2>
          </div>
        </div>

        {/* ─── footer line ─── */}
        <div className="flex flex-col items-start justify-between gap-6 border-t border-paper/12 pt-8 text-[12px] text-paper/50 md:flex-row md:items-center">
          <div className="flex items-center gap-3">
            <span className="font-display italic text-paper">Run</span>
            <span className="font-medium text-paper">Bar</span>
            <span>· v0.1.13 · 2026</span>
          </div>
          <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
            <a href="#showcase" className="hover:text-paper">Overview</a>
            <a href="#features" className="hover:text-paper">States</a>
            <a href="#why" className="hover:text-paper">Manifesto</a>
            <a href="/privacy" className="hover:text-paper">Privacy</a>
            <a href="/terms" className="hover:text-paper">Terms</a>
            <a href="/contact" className="hover:text-paper">Contact</a>
            <span className="text-[10px] uppercase tracking-[0.18em] text-[#FC5200]">
              Powered by Strava
            </span>
          </div>
        </div>
      </div>
    </footer>
  );
}

/**
 * FinishLine — horizontal hairline track with a trail of runners
 * approaching a vermillon finish marker on the right edge.
 *
 * Composition (left → right):
 *   • runner @ 36px, opacity 0.18  (far back)
 *   • runner @ 56px, opacity 0.32  (mid back)
 *   • runner @ 88px, opacity 0.55  (mid)
 *   • runner @ 140px, opacity 1.0  (leader, crossing past the marker)
 *   • vermillon finish marker — vertical line + dot, with faint light beam
 *
 * Track extends edge-to-edge for cinematic horizon. Mobile keeps the same
 * composition at reduced scale (no element hidden).
 */
function FinishLine() {
  return (
    <div
      aria-hidden
      className="relative h-[150px] w-full md:h-[200px]"
    >
      {/* the track — hairline horizon */}
      <div className="absolute inset-x-0 top-[68%] h-px bg-paper/18" />
      {/* faint shadow under the track for depth */}
      <div className="absolute inset-x-0 top-[calc(68%+1px)] h-3 bg-[linear-gradient(to_bottom,rgba(251,249,244,0.04),transparent)]" />

      {/* tick marks along the track — distance hints */}
      <div className="absolute inset-x-0 top-[68%] flex justify-between px-[6%]">
        {Array.from({ length: 9 }).map((_, i) => (
          <span
            key={i}
            className="block h-[5px] w-px bg-paper/15"
            style={{ transform: "translateY(-2px)" }}
          />
        ))}
      </div>

      {/* runners — anchored to the track via bottom alignment */}
      {/* far back */}
      <div
        className="absolute"
        style={{ left: "8%", top: "68%", transform: "translate(-50%, -100%)" }}
      >
        <div className="opacity-[0.18]">
          <RunnerSprite size={36} state="jogging" variant="paper" />
        </div>
      </div>
      <div
        className="absolute"
        style={{ left: "26%", top: "68%", transform: "translate(-50%, -100%)" }}
      >
        <div className="opacity-[0.32]">
          <RunnerSprite size={52} state="jogging" variant="paper" />
        </div>
      </div>
      <div
        className="absolute"
        style={{ left: "48%", top: "68%", transform: "translate(-50%, -100%)" }}
      >
        <div className="opacity-[0.55]">
          <RunnerSprite size={78} state="jogging" variant="paper" />
        </div>
      </div>

      {/* finish marker — vermillon vertical line with dot, ~84% across */}
      <div
        className="absolute top-0 bottom-0"
        style={{ left: "84%" }}
      >
        {/* faint vertical light beam from the marker */}
        <div className="absolute left-1/2 -top-12 -bottom-12 w-[2px] -translate-x-1/2 bg-[linear-gradient(to_bottom,transparent,rgba(229,82,61,0.22),transparent)]" />
        {/* the marker line itself */}
        <div className="absolute left-1/2 top-[calc(68%-44px)] h-[58px] w-px -translate-x-1/2 bg-vermillon md:h-[78px] md:top-[calc(68%-60px)]" />
        {/* finish dot at top */}
        <div className="absolute left-1/2 top-[calc(68%-50px)] h-[7px] w-[7px] -translate-x-1/2 rounded-full bg-vermillon md:top-[calc(68%-68px)] md:h-2 md:w-2" />
        {/* tiny "FIN" label, mono, vermillon */}
        <div className="absolute left-1/2 top-[calc(68%+10px)] -translate-x-1/2 font-mono text-[9px] uppercase tracking-[0.22em] text-vermillon/80">
          Fin
        </div>
      </div>

      {/* leader — large, crosses past the marker (~92%) */}
      {/* mobile leader */}
      <div
        className="absolute md:hidden"
        style={{ left: "92%", top: "68%", transform: "translate(-50%, -100%)" }}
      >
        <RunnerSprite size={96} state="jogging" variant="paper" />
      </div>
      {/* desktop leader */}
      <div
        className="absolute hidden md:block"
        style={{ left: "92%", top: "68%", transform: "translate(-50%, -100%)" }}
      >
        <RunnerSprite size={140} state="jogging" variant="paper" />
      </div>
    </div>
  );
}
