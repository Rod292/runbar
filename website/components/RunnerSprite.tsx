/**
 * Runner sprite, ported from the actual app assets.
 *
 * Each state has its own dedicated sprite sheet (8 or 6 frames horizontal):
 *   - jogging / sprinting → /runner/sprite.png         (8 frames)
 *   - idle                → /runner/sprite-idle.png    (6 frames)
 *   - tired               → /runner/sprite-tired.png   (6 frames)
 *   - victory             → /runner/sprite-victory.png (6 frames)
 *
 * The CSS animation is a pure `steps(N)` shift on a horizontal sheet —
 * no JavaScript, no flicker. fps mirrors `RunnerState.fps` in Swift.
 *
 * Lean (-6°) is applied only to running poses (jogging/sprinting). Other
 * states are upright or pre-slouched, so we don't add tilt.
 */

export type RunnerStateName = "idle" | "jogging" | "sprinting" | "tired" | "victory";
type Variant = "ink" | "paper";

type CycleConfig = {
  sheet: { ink: string; paper: string };
  frameCount: number;
  fps: number;
  lean: number;
};

const CYCLES: Record<RunnerStateName, CycleConfig> = {
  idle: {
    sheet: { ink: "/runner/sprite-idle.png", paper: "/runner/sprite-idle-white.png" },
    frameCount: 6,
    fps: 3,
    lean: 0,
  },
  jogging: {
    sheet: { ink: "/runner/sprite.png", paper: "/runner/sprite-white.png" },
    frameCount: 8,
    fps: 6,
    lean: -6,
  },
  sprinting: {
    sheet: { ink: "/runner/sprite.png", paper: "/runner/sprite-white.png" },
    frameCount: 8,
    fps: 9,
    // Plus marqué que jogging (-6°) pour différencier visuellement deux états
    // qui partagent le même sprite sheet.
    lean: -11,
  },
  tired: {
    sheet: { ink: "/runner/sprite-tired.png", paper: "/runner/sprite-tired-white.png" },
    frameCount: 6,
    fps: 4,
    lean: 0,
  },
  victory: {
    sheet: { ink: "/runner/sprite-victory.png", paper: "/runner/sprite-victory-white.png" },
    frameCount: 6,
    fps: 6,
    lean: 0,
  },
};

type Props = {
  size?: number;
  state?: RunnerStateName;
  variant?: Variant;
  /** Override the default lean (-6° on running states, 0° elsewhere). */
  lean?: number;
  /**
   * Lock the sprite to a specific frame index (0-based). Skips the running
   * animation — useful for specimen sheets and contact strips where you want
   * to display all frames side-by-side.
   */
  frame?: number;
  className?: string;
};

export function RunnerSprite({
  size = 88,
  state = "jogging",
  variant = "ink",
  lean,
  frame,
  className = "",
}: Props) {
  const cfg = CYCLES[state];
  const sheet = variant === "paper" ? cfg.sheet.paper : cfg.sheet.ink;
  const tilt = lean ?? cfg.lean;
  const isStatic = frame !== undefined;

  // Sprinting: layered drop-shadows behind (left of) the figure create a
  // ghost-trail suggesting forward speed. Multiple offsets stack visibly when
  // the sprite is large enough; on a 28px contact-strip frame, the trail is
  // imperceptible (which is fine — it shouldn't clutter small renderings).
  const trail =
    state === "sprinting"
      ? "drop-shadow(-3px 0 0 rgba(15,15,14,0.10)) drop-shadow(-7px 0 0 rgba(15,15,14,0.05)) drop-shadow(-12px 0 0 rgba(15,15,14,0.03))"
      : undefined;

  const baseStyle: React.CSSProperties = {
    width: size,
    height: size,
    backgroundImage: `url(${sheet})`,
    backgroundSize: `${size * cfg.frameCount}px ${size}px`,
    backgroundRepeat: "no-repeat",
    transform: `rotate(${tilt}deg)`,
    imageRendering: "auto",
    filter: trail,
  };

  if (isStatic) {
    const safe = ((frame % cfg.frameCount) + cfg.frameCount) % cfg.frameCount;
    return (
      <span
        aria-hidden
        className={`inline-block ${className}`}
        style={{
          ...baseStyle,
          backgroundPosition: `${-safe * size}px 0`,
        }}
      />
    );
  }

  const duration = cfg.frameCount / cfg.fps;
  const sprite = (
    <span
      aria-hidden
      className="inline-block"
      style={{
        ...baseStyle,
        animation: `runner-cycle ${duration}s steps(${cfg.frameCount}, jump-none) infinite`,
      }}
    />
  );

  // Victory: layer a vertical bounce over the frame cycle so the figure reads
  // as airborne. The wrapper's height matches the sprite's so the bounce
  // doesn't shift downstream layout.
  if (state === "victory") {
    return (
      <span
        aria-hidden
        className={`inline-block ${className}`}
        style={{
          width: size,
          height: size,
          animation: `runner-jump ${duration}s ease-in-out infinite`,
        }}
      >
        {sprite}
      </span>
    );
  }

  return <span className={`inline-block ${className}`} aria-hidden>{sprite}</span>;
}
