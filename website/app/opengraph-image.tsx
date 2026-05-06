import { ImageResponse } from "next/og";

// OG image — dynamic, generated at the edge. Replaces the static
// /og-image.png reference for the home page; legal pages still
// inherit from this one unless they override it themselves.
//
// Design follows the site: ivory paper background, vermillon
// accent dots, italic serif headline, monospace small-caps for
// the metadata strip. No custom fonts loaded — we use the
// platform serif/system stack that next/og falls back to, which
// renders cleanly on every consumer (Twitter, Slack, Discord,
// iMessage, Telegram) without payload cost.

export const alt = "RunBar — a runner in your menu bar";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

const PAPER = "#FBF9F4";
const INK = "#0F0F0E";
const INK_SOFT = "#3A3A38";
const INK_MUTE = "#7A7A75";
const HAIRLINE = "#D8D5CD";
const VERMILLON = "#E03C1B";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          background: PAPER,
          display: "flex",
          flexDirection: "column",
          padding: "72px 80px",
          fontFamily: "Georgia, ui-serif, serif",
          position: "relative",
        }}
      >
        {/* eyebrow row */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 18,
            color: INK_MUTE,
            fontSize: 18,
            letterSpacing: "0.28em",
            textTransform: "uppercase",
            fontFamily: "ui-monospace, monospace",
          }}
        >
          <div
            style={{
              width: 12,
              height: 12,
              borderRadius: 6,
              background: VERMILLON,
            }}
          />
          <span>Menu-bar app</span>
          <span
            style={{
              width: 28,
              height: 1,
              background: HAIRLINE,
            }}
          />
          <span style={{ color: INK_SOFT, letterSpacing: "0.06em" }}>
            macOS 14+
          </span>
        </div>

        {/* headline — A runner */}
        <div
          style={{
            display: "flex",
            color: INK,
            fontStyle: "italic",
            fontWeight: 500,
            fontSize: 220,
            lineHeight: 1,
            letterSpacing: "-0.03em",
            marginTop: 56,
          }}
        >
          A runner
        </div>

        {/* sub-headline — — in your menu bar. */}
        <div
          style={{
            display: "flex",
            alignItems: "baseline",
            gap: 18,
            color: INK_SOFT,
            fontSize: 56,
            fontWeight: 400,
            letterSpacing: "-0.01em",
            marginTop: 12,
          }}
        >
          <span style={{ color: VERMILLON }}>—</span>
          <span>in your menu bar.</span>
        </div>

        {/* spacer */}
        <div style={{ flex: 1, display: "flex" }} />

        {/* hairline */}
        <div
          style={{
            width: "100%",
            height: 1,
            background: HAIRLINE,
            marginBottom: 28,
          }}
        />

        {/* footer row — wordmark left, stats right */}
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "flex-end",
          }}
        >
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              gap: 6,
            }}
          >
            <div
              style={{
                color: INK,
                fontSize: 30,
                fontWeight: 500,
                letterSpacing: "-0.02em",
                fontFamily: "Georgia, ui-serif, serif",
              }}
            >
              RunBar
            </div>
            <div
              style={{
                color: INK_MUTE,
                fontSize: 16,
                letterSpacing: "0.18em",
                textTransform: "uppercase",
                fontFamily: "ui-monospace, monospace",
              }}
            >
              runbar.run
            </div>
          </div>
          <div
            style={{
              display: "flex",
              gap: 22,
              color: INK_MUTE,
              fontSize: 16,
              letterSpacing: "0.18em",
              textTransform: "uppercase",
              fontFamily: "ui-monospace, monospace",
              alignItems: "center",
            }}
          >
            <span>Strava-synced</span>
            <span style={{ width: 18, height: 1, background: HAIRLINE }} />
            <span>Free</span>
            <span style={{ width: 18, height: 1, background: HAIRLINE }} />
            <span>Open source</span>
          </div>
        </div>
      </div>
    ),
    { ...size }
  );
}
