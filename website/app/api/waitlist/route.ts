import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Waitlist capture for the shared Strava connection (private beta).
 *
 * POST { email, company? }  → adds the email to the list.
 *   `company` is a honeypot; if filled, we 200 silently (drop the bot).
 *
 * GET ?token=<WAITLIST_ADMIN_TOKEN>  → exports the list for the launch email.
 *
 * Storage: Vercel KV / Upstash Redis over its REST API (no SDK dependency).
 * Needs KV_REST_API_URL + KV_REST_API_TOKEN env (auto-set when a KV store is
 * connected to the project). If absent, we fall back to a structured log line
 * so the endpoint still works before the store is provisioned.
 */

const EMAILS_KEY = "waitlist:emails"; // Redis SET — canonical, deduped list
const ENTRIES_KEY = "waitlist:entries"; // Redis HASH — email → JSON metadata

export async function POST(req: Request) {
  let payload: { email?: unknown; company?: unknown };
  try {
    payload = await req.json();
  } catch {
    return NextResponse.json(
      { ok: false, message: "Invalid request." },
      { status: 400 },
    );
  }

  // Honeypot: a filled hidden field means a bot. Accept silently, store nothing.
  if (typeof payload.company === "string" && payload.company.trim() !== "") {
    return NextResponse.json({ ok: true, message: "You're on the list." });
  }

  const email =
    typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
  if (!isValidEmail(email)) {
    return NextResponse.json(
      { ok: false, message: "Please enter a valid email address." },
      { status: 400 },
    );
  }

  const country = req.headers.get("x-vercel-ip-country") ?? "";
  const meta = JSON.stringify({ ts: new Date().toISOString(), country });

  const kv = kvConfig();
  if (!kv) {
    // No store yet — don't lose the signup.
    console.log(JSON.stringify({ event: "waitlist_signup", email, country }));
    return NextResponse.json({ ok: true, message: "You're on the list." });
  }

  try {
    const added = await kvCommand(kv, ["SADD", EMAILS_KEY, email]);
    await kvCommand(kv, ["HSET", ENTRIES_KEY, email, meta]);
    const already = added?.result === 0;
    return NextResponse.json({
      ok: true,
      message: already
        ? "You're already on the list — we'll be in touch."
        : "You're on the list. We'll email you the day it opens.",
    });
  } catch (err) {
    console.error("waitlist KV write failed:", err);
    // Last resort so the signup survives even if KV hiccups.
    console.log(JSON.stringify({ event: "waitlist_signup", email, country }));
    return NextResponse.json({ ok: true, message: "You're on the list." });
  }
}

export async function GET(req: Request) {
  const adminToken = process.env.WAITLIST_ADMIN_TOKEN?.trim();
  const token = new URL(req.url).searchParams.get("token")?.trim();
  if (!adminToken || !token || token !== adminToken) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const kv = kvConfig();
  if (!kv) {
    return NextResponse.json(
      { error: "kv_unconfigured", message: "No KV store connected." },
      { status: 500 },
    );
  }

  const emails = await kvCommand(kv, ["SMEMBERS", EMAILS_KEY]);
  const list: string[] = Array.isArray(emails?.result) ? emails.result : [];
  return NextResponse.json({ count: list.length, emails: list });
}

// ── helpers ──────────────────────────────────────────────────────────────

function isValidEmail(email: string): boolean {
  // Pragmatic check: one @, a dot in the domain, no spaces, sane length.
  return (
    email.length <= 254 &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  );
}

function kvConfig(): { url: string; token: string } | null {
  const url = process.env.KV_REST_API_URL?.trim();
  const token = process.env.KV_REST_API_TOKEN?.trim();
  if (!url || !token) return null;
  return { url, token };
}

async function kvCommand(
  kv: { url: string; token: string },
  command: string[],
): Promise<{ result: unknown }> {
  const res = await fetch(kv.url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${kv.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(command),
    cache: "no-store",
  });
  if (!res.ok) {
    throw new Error(`KV ${command[0]} failed: HTTP ${res.status}`);
  }
  return (await res.json()) as { result: unknown };
}
