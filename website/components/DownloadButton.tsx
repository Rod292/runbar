type Props = {
  variant?: "primary" | "ghost";
  size?: "md" | "lg";
  className?: string;
  href?: string;
};

export function DownloadButton({
  variant = "primary",
  size = "md",
  className = "",
  href = "/download/RunBar.dmg",
}: Props) {
  const sizing =
    size === "lg" ? "h-12 px-6 text-[14px]" : "h-10 px-4 text-[13px]";

  const palette =
    variant === "primary"
      ? "bg-ink text-paper hover:bg-ink/90"
      : "bg-transparent text-ink ring-1 ring-inset ring-ink/15 hover:ring-ink/35";

  return (
    <a
      href={href}
      className={`group inline-flex items-center gap-2.5 rounded-full font-medium tracking-tight transition ${sizing} ${palette} ${className}`}
    >
      {/* Apple glyph */}
      <svg width="13" height="15" viewBox="0 0 22 26" aria-hidden>
        <path
          fill="currentColor"
          d="M16.7 13.7c0-3 2.5-4.4 2.6-4.5-1.4-2.1-3.6-2.4-4.4-2.4-1.9-.2-3.6 1.1-4.6 1.1-.9 0-2.4-1.1-4-1-2 0-3.9 1.2-5 3-2.1 3.7-.5 9.2 1.5 12.2 1 1.4 2.2 3.1 3.7 3 1.5-.1 2-1 3.8-1 1.7 0 2.2 1 3.8 1 1.6 0 2.6-1.5 3.6-2.9 1.1-1.6 1.6-3.2 1.6-3.3-.1-.1-3-1.2-3-4.7-.1-2.9 2.4-4.4 2.5-4.5zM13.7 4.4c.8-1 1.4-2.4 1.3-3.8-1.2 0-2.7.8-3.6 1.8-.8.9-1.5 2.4-1.3 3.7 1.4.1 2.7-.7 3.6-1.7z"
        />
      </svg>
      Download for macOS
      <span className="opacity-50 transition group-hover:translate-x-0.5">
        →
      </span>
    </a>
  );
}
