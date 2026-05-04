#!/usr/bin/env python3
"""
Process raw runner animation frames delivered as 3776x3776 white silhouettes
into the formats RunBar expects:

  Sources/RunBar/Resources/RunnerFrames/<state>-<n>.png        (36x36)
  Sources/RunBar/Resources/RunnerFrames/<state>-<n>@2x.png     (72x72)
  Sources/RunBar/Resources/RunnerFrames/<state>-<n>@3x.png     (108x108)
  website/public/runner/sprite-<state>.png                     (6×108 horizontal)
  website/public/runner/sprite-<state>-white.png               (paper variant)

Per state, all frames share the same union bounding box so the figure stays
anchored across the cycle. Color is normalized to black for the dark sprite
and kept white for the paper sprite.
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = Path("/Users/rod/Downloads/Runbar animation")
OUT_FRAMES = ROOT / "Sources/RunBar/Resources/RunnerFrames"
OUT_WEB = ROOT / "website/public/runner"

STATES = {
    "idle":    [SRC_DIR / f"Idle {i}.png"    for i in range(1, 7)],
    "tired":   [SRC_DIR / f"Tired {i}.png"   for i in range(1, 7)],
    "victory": [SRC_DIR / f"Victory {i}.png" for i in range(1, 7)],
}

CANVAS = 108  # @3x size, matches existing jogging frames


def union_bbox(images):
    boxes = [img.getbbox() for img in images]
    return (
        min(b[0] for b in boxes),
        min(b[1] for b in boxes),
        max(b[2] for b in boxes),
        max(b[3] for b in boxes),
    )


def fit_to_canvas(img, size):
    """Resize preserving aspect ratio, center on transparent canvas."""
    w, h = img.size
    scale = size / max(w, h)
    new_w, new_h = max(1, int(w * scale)), max(1, int(h * scale))
    resized = img.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(resized, ((size - new_w) // 2, (size - new_h) // 2), resized)
    return canvas


def recolor(img, target_rgb):
    """Replace any non-transparent pixel with target color, keep alpha."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (target_rgb[0], target_rgb[1], target_rgb[2], a)
    return img


def process_state(name, paths):
    print(f"==> {name}")
    raws = [Image.open(p).convert("RGBA") for p in paths]
    bbox = union_bbox(raws)
    print(f"   union bbox: {bbox}")

    # Crop all to the union bbox so the figure stays anchored across frames.
    cropped = [img.crop(bbox) for img in raws]

    # Pad each cropped frame to a square canvas at 108×108 (the @3x baseline).
    base_frames_black = []
    base_frames_white = []
    for img in cropped:
        squared = fit_to_canvas(img, CANVAS)
        base_frames_black.append(recolor(squared.copy(), (0, 0, 0)))
        base_frames_white.append(recolor(squared.copy(), (255, 255, 255)))

    # Per-frame PNGs for the macOS app — black silhouette only. The menu bar
    # treats them as template images, so the actual fill is reapplied by the
    # OS based on light/dark mode anyway.
    for i, img108 in enumerate(base_frames_black, start=1):
        img72 = img108.resize((72, 72), Image.LANCZOS)
        img36 = img108.resize((36, 36), Image.LANCZOS)
        img36.save(OUT_FRAMES / f"{name}-{i}.png")
        img72.save(OUT_FRAMES / f"{name}-{i}@2x.png")
        img108.save(OUT_FRAMES / f"{name}-{i}@3x.png")

    # Sprite sheet for the website — 6 frames × 108 wide.
    def make_sheet(frames):
        sheet = Image.new("RGBA", (CANVAS * len(frames), CANVAS), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.paste(fr, (i * CANVAS, 0), fr)
        return sheet

    make_sheet(base_frames_black).save(OUT_WEB / f"sprite-{name}.png")
    make_sheet(base_frames_white).save(OUT_WEB / f"sprite-{name}-white.png")
    print(f"   wrote {len(paths)*3} frame files + 2 sprite sheets")


def main():
    OUT_FRAMES.mkdir(parents=True, exist_ok=True)
    OUT_WEB.mkdir(parents=True, exist_ok=True)
    for name, paths in STATES.items():
        process_state(name, paths)
    print("Done.")


if __name__ == "__main__":
    main()
