import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * POST /api/strava/exchange
 *
 * Exchanges an OAuth `code` (received by the desktop app on its localhost
 * callback) for access + refresh tokens. The Strava `client_secret` lives
 * here as a Vercel env var and never leaves the server.
 *
 * Request:  { "code": "<authorization_code>" }
 * Response: Strava's token payload, forwarded as-is on success.
 */
export async function POST(req: Request) {
  const clientId = process.env.STRAVA_CLIENT_ID;
  const clientSecret = process.env.STRAVA_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    return NextResponse.json(
      {
        error: "server_misconfigured",
        message:
          "STRAVA_CLIENT_ID or STRAVA_CLIENT_SECRET is not set on the backend.",
      },
      { status: 500 },
    );
  }

  let payload: { code?: unknown };
  try {
    payload = await req.json();
  } catch {
    return NextResponse.json(
      { error: "invalid_json", message: "Body must be JSON." },
      { status: 400 },
    );
  }

  const code = payload.code;
  if (typeof code !== "string" || code.trim() === "") {
    return NextResponse.json(
      { error: "invalid_code", message: "Field `code` is required." },
      { status: 400 },
    );
  }

  const stravaResp = await fetch("https://www.strava.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code,
      grant_type: "authorization_code",
    }),
  });

  const body = await stravaResp.text();
  return new Response(body, {
    status: stravaResp.status,
    headers: { "Content-Type": "application/json" },
  });
}
