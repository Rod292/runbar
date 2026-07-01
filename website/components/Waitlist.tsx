"use client";

import { useState } from "react";

/**
 * Waitlist — capture demand for the shared Strava connection while RunBar
 * is in private beta (Strava's Standard tier caps the shared app at a handful
 * of athletes until Extended Access is approved). People who don't want to
 * register their own personal Strava API app can leave an email and get a
 * single notification when shared connect opens to everyone.
 *
 * Posts to /api/waitlist. Editorial-styled to match Hero / FinalCTA.
 */
type Status = "idle" | "submitting" | "success" | "error";

export function Waitlist() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState("");
  // Honeypot — bots fill hidden fields, humans don't.
  const [company, setCompany] = useState("");

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (status === "submitting") return;
    setStatus("submitting");
    setMessage("");
    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, company }),
      });
      const data = (await res.json().catch(() => ({}))) as {
        ok?: boolean;
        message?: string;
      };
      if (res.ok && data.ok) {
        setStatus("success");
        setMessage(data.message ?? "You're on the list.");
        setEmail("");
      } else {
        setStatus("error");
        setMessage(data.message ?? "Something went wrong — try again.");
      }
    } catch {
      setStatus("error");
      setMessage("Network error — try again.");
    }
  }

  return (
    <section
      id="waitlist"
      className="relative mx-auto w-full max-w-[1280px] px-6 py-24 md:px-10 md:py-28"
    >
      <div className="relative overflow-hidden rounded-[16px] border border-hairline bg-ivory p-8 md:p-14">
        {/* paper noise + faint vermillon bleed */}
        <div className="pointer-events-none absolute inset-0 noise-bg opacity-30" />
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_70%_60%_at_90%_-10%,rgba(229,82,61,0.10),transparent_60%)]" />

        <div className="relative grid grid-cols-12 items-center gap-y-10 gap-x-8">
          {/* left — copy */}
          <div className="col-span-12 md:col-span-7">
            <div className="mb-7 flex items-center gap-3 font-mono text-[10.5px] uppercase tracking-[0.24em] text-ink-mute">
              <span className="dot bg-vermillon" />
              <span>Private beta</span>
              <span aria-hidden className="h-px w-6 bg-hairline" />
              <span className="text-ink-soft">Shared Strava connect</span>
            </div>

            <h2 className="font-display font-medium leading-[0.92] tracking-crammed text-ink">
              <span className="block text-[clamp(2.2rem,5vw,3.6rem)]">
                One-tap Strava
              </span>
              <span className="block text-[clamp(2.2rem,5vw,3.6rem)] italic">
                is coming.
              </span>
            </h2>

            <p className="mt-7 max-w-[46ch] text-[15px] leading-[1.6] text-ink-soft">
              RunBar is free to download today. Right now, connecting Strava
              means registering your own personal API app (and Strava now
              requires a subscription for that). We&apos;re rolling out a
              <em className="not-italic text-ink"> one-tap shared connection</em>{" "}
              — no setup, no developer app. Leave your email and we&apos;ll
              send <span className="text-ink">a single message</span> the day
              it opens.
            </p>
          </div>

          {/* right — form */}
          <div className="col-span-12 md:col-span-5 md:pl-6">
            {status === "success" ? (
              <div className="rounded-[12px] border border-hairline bg-paper/60 p-6">
                <div className="mb-2 flex items-center gap-2 font-mono text-[10.5px] uppercase tracking-[0.2em] text-vermillon">
                  <span className="dot bg-vermillon" />
                  On the list
                </div>
                <p className="text-[14px] leading-[1.55] text-ink-soft">
                  {message}
                </p>
              </div>
            ) : (
              <form onSubmit={onSubmit} noValidate className="flex flex-col gap-3">
                {/* honeypot */}
                <input
                  type="text"
                  name="company"
                  tabIndex={-1}
                  autoComplete="off"
                  aria-hidden="true"
                  value={company}
                  onChange={(e) => setCompany(e.target.value)}
                  className="absolute h-0 w-0 overflow-hidden opacity-0"
                />

                <label
                  htmlFor="waitlist-email"
                  className="font-mono text-[10.5px] uppercase tracking-[0.18em] text-ink-mute"
                >
                  Email address
                </label>
                <input
                  id="waitlist-email"
                  type="email"
                  required
                  inputMode="email"
                  autoComplete="email"
                  placeholder="you@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={status === "submitting"}
                  className="w-full rounded-[10px] border border-hairline bg-paper px-4 py-3 text-[15px] text-ink outline-none transition placeholder:text-ink-mute/60 focus:border-ink/40 disabled:opacity-60"
                />

                <button
                  type="submit"
                  disabled={status === "submitting"}
                  className="mt-1 inline-flex items-center justify-center gap-2 rounded-[10px] bg-ink px-5 py-3 text-[14px] font-medium text-paper transition hover:bg-ink/90 disabled:opacity-60"
                >
                  {status === "submitting" ? "Adding…" : "Notify me at launch"}
                </button>

                {status === "error" && (
                  <p role="alert" className="text-[12.5px] text-vermillon">
                    {message}
                  </p>
                )}

                <p className="mt-1 font-mono text-[10px] uppercase tracking-[0.14em] text-ink-mute/80">
                  One email, then the list is deleted. Erasure anytime via
                  contact@runbar.run.
                </p>
              </form>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
