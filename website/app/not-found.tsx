import Link from "next/link";

export default function NotFound() {
  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-ivory px-6 py-24">
      <div className="pointer-events-none absolute inset-0 noise-bg opacity-30" />
      <div className="relative mx-auto w-full max-w-[640px]">
        {/* Eyebrow */}
        <div className="mb-10 flex items-center gap-3 font-mono text-[10.5px] uppercase tracking-[0.28em] text-ink-mute">
          <span className="dot bg-vermillon" />
          <span>Error · 404</span>
          <span aria-hidden className="h-px w-6 bg-hairline" />
          <span className="text-ink-soft">page not found</span>
        </div>

        {/* Headline */}
        <h1 className="font-display font-medium leading-[0.92] tracking-crammed text-ink">
          <span className="block text-[clamp(3rem,7vw,5.5rem)] italic">
            Off&nbsp;the&nbsp;track.
          </span>
        </h1>

        <p className="mt-8 max-w-[40ch] text-[clamp(1rem,1.3vw,1.1rem)] leading-[1.55] text-ink-soft">
          This page doesn&apos;t exist — or the runner already crossed the line.
          Head back to the start.
        </p>

        <div className="mt-9 flex flex-wrap items-center gap-x-7 gap-y-4">
          <Link
            href="/"
            className="inline-flex items-center gap-2 rounded-full bg-ink px-5 py-3 text-[14px] font-medium text-paper transition hover:bg-ink/90"
          >
            <span>← Back to RunBar</span>
          </Link>
          <Link
            href="/api/download?utm_source=404&utm_medium=site"
            className="text-[13px] text-ink-soft underline decoration-vermillon decoration-[1.5px] underline-offset-[5px] hover:text-ink"
          >
            Or just download
          </Link>
        </div>

        <div className="mt-14 flex items-center gap-3 font-mono text-[10px] uppercase tracking-[0.22em] text-ink-mute">
          <span className="h-px w-12 bg-hairline" />
          <span>Run · Bar · v0.1.16</span>
        </div>
      </div>
    </main>
  );
}
