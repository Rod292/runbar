/**
 * Runner sprite, ported from the actual app assets.
 *
 * Uses the 8-frame running cycle PNG sheet exported from
 * Sources/RunBar/Resources/RunnerFrames/. The CSS animation is a pure
 * `steps(8)` shift on a horizontal sprite — no JavaScript, no flicker.
 *
 * State semantics mirror RunnerState in the Swift code:
 *   - jogging  → 6 fps cycle
 *   - sprinting → 9 fps cycle
 *   - tired    → 4 fps cycle
 *   - idle     → single static frame (the app uses parametric rendering)
 *   - victory  → single static frame (parametric in the app)
 *
 * `lean = -6°` matches RunnerSprite.swift's leanDegrees.
 */

export type RunnerStateName = "idle" | "jogging" | "sprinting" | "tired" | "victory";
type Variant = "ink" | "paper";

const ANIM: Record<
  RunnerStateName,
  { kind: "cycle" | "static"; fps?: number; staticFrame?: number }
> = {
  idle: { kind: "static", staticFrame: 0 },
  jogging: { kind: "cycle", fps: 6 },
  sprinting: { kind: "cycle", fps: 9 },
  tired: { kind: "cycle", fps: 4 },
  victory: { kind: "static", staticFrame: 3 },
};

type Props = {
  size?: number;
  state?: RunnerStateName;
  variant?: Variant;
  lean?: number;
  className?: string;
};

export function RunnerSprite({
  size = 88,
  state = "jogging",
  variant = "ink",
  lean = -6,
  className = "",
}: Props) {
  const cfg = ANIM[state];
  const sheet =
    variant === "paper" ? "/runner/sprite-white.png" : "/runner/sprite.png";

  const baseStyle: React.CSSProperties = {
    width: size,
    height: size,
    backgroundImage: `url(${sheet})`,
    backgroundSize: `${size * 8}px ${size}px`,
    backgroundRepeat: "no-repeat",
    transform: `rotate(${lean}deg)`,
    imageRendering: "auto",
  };

  if (cfg.kind === "cycle") {
    const duration = 8 / (cfg.fps ?? 6);
    return (
      <span
        aria-hidden
        className={`inline-block ${className}`}
        style={{
          ...baseStyle,
          // jump-none distributes 8 stops over [0%, 100%] inclusive
          // (0, 1/7, 2/7, …, 7/7), so each stop lands on an integer frame
          // boundary. Default `steps(8)` = jump-end skips 100% and lands at
          // 0, 1/8, …, 7/8 — half-frame offsets, hence sliced silhouettes.
          animation: `runner-cycle ${duration}s steps(8, jump-none) infinite`,
        }}
      />
    );
  }

  const frame = cfg.staticFrame ?? 0;
  return (
    <span
      aria-hidden
      className={`inline-block ${className}`}
      style={{
        ...baseStyle,
        backgroundPosition: `${-frame * size}px 0`,
      }}
    />
  );
}
