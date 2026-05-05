import type { ReactNode } from "react";
import Link from "next/link";

/**
 * Layout partagé pour les pages légales (Privacy, Terms, Contact).
 * Reprend le ton éditorial de la landing : ivory + ink, hairlines, italique
 * serif pour le titre, mono small-caps pour la nav.
 */
export function LegalLayout({
  eyebrow,
  title,
  italicWord,
  lastUpdated,
  children,
}: {
  eyebrow: string;
  title: string;
  italicWord?: string;
  lastUpdated?: string;
  children: ReactNode;
}) {
  return (
    <main className="relative min-h-screen bg-ivory text-ink">
      <div className="mx-auto max-w-3xl px-6 py-16 md:px-10 md:py-24">
        <header className="mb-12">
          <div className="flex items-center gap-3 text-[10px] font-medium uppercase tracking-[0.22em] text-ink-mute">
            <Link href="/" className="hover:text-ink">
              <span className="font-display italic">Run</span>
              <span>Bar</span>
            </Link>
            <span className="opacity-50">·</span>
            <span>{eyebrow}</span>
          </div>
          <h1 className="mt-6 font-display text-[clamp(2.25rem,4vw,3.75rem)] font-medium leading-[1.05] text-ink">
            {italicWord ? <em className="not-italic font-display italic">{italicWord}</em> : null}
            {italicWord ? " " : ""}
            {title}
          </h1>
          {lastUpdated ? (
            <p className="mt-4 text-[11px] uppercase tracking-[0.18em] text-ink-mute">
              Last updated · {lastUpdated}
            </p>
          ) : null}
          <div className="mt-8 h-px w-full bg-hairline" />
        </header>

        <article className="prose-legal space-y-6 text-[15px] leading-[1.7] text-ink-soft">
          {children}
        </article>

        <footer className="mt-16 flex items-center justify-between border-t border-hairline pt-6 text-[11px] uppercase tracking-[0.18em] text-ink-mute">
          <Link href="/" className="hover:text-ink">← Back to RunBar</Link>
          <div className="flex gap-5">
            <Link href="/privacy" className="hover:text-ink">Privacy</Link>
            <Link href="/terms" className="hover:text-ink">Terms</Link>
            <Link href="/contact" className="hover:text-ink">Contact</Link>
          </div>
        </footer>
      </div>
    </main>
  );
}
