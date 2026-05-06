import { Wordmark } from "./Wordmark";

export function Header() {
  return (
    <header className="sticky top-0 z-30 mx-auto flex w-full max-w-[1280px] items-center justify-between px-6 py-5 md:px-10">
      <a href="#top" className="text-[18px] text-ink">
        <Wordmark />
      </a>

      <nav className="hidden items-center gap-8 text-[13px] text-ink-soft md:flex">
        <a href="#showcase" className="hover:text-ink">Overview</a>
        <a href="#features" className="hover:text-ink">States</a>
        <a href="#why" className="hover:text-ink">Manifesto</a>
        <a
          href="/api/download?utm_source=header&utm_medium=site"
          className="rounded-full bg-ink px-4 py-2 text-paper hover:bg-ink/90"
        >
          Download
        </a>
      </nav>

      <a
        href="/api/download?utm_source=header-mobile&utm_medium=site"
        className="rounded-full bg-ink px-4 py-2 text-[13px] text-paper md:hidden"
      >
        ↓ macOS
      </a>
    </header>
  );
}
