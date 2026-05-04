type Props = { className?: string };

export function Wordmark({ className = "" }: Props) {
  return (
    <span className={`inline-flex items-baseline gap-[0.06em] ${className}`}>
      <span className="font-display italic font-medium tracking-tighter">Run</span>
      <span className="font-sans font-medium tracking-tight">Bar</span>
      <span
        className="ml-1 mt-[0.45em] h-[0.35em] w-[0.35em] rounded-full bg-vermillon align-middle"
        aria-hidden
      />
    </span>
  );
}
