import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * POST /api/strava/refresh
 *
 * Exchanges a stored `refresh_token` for a fresh access token. Same
 * server-side secret as /api/strava/exchange.
 *
 * Request:  { "refresh_token": "<token>" }
 * Response: Strava's token payload (access_token, refresh_token, expires_at, …)
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

  let payload: { refresh_token?: unknown };
  try {
    payload = await req.json();
  } catch {
    return NextResponse.json(
      { error: "invalid_json", message: "Body must be JSON." },
      { status: 400 },
    );
  }

  const refreshToken = payload.refresh_token;
  if (typeof refreshToken !== "string" || refreshToken.trim() === "") {
    return NextResponse.json(
      {
        error: "invalid_refresh_token",
        message: "Field `refresh_token` is required.",
      },
      { status: 400 },
    );
  }

  const stravaResp = await fetch("https://www.strava.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });

  const body = await stravaResp.text();
  return new Response(body, {
    status: stravaResp.status,
    headers: { "Content-Type": "application/json" },
  });
}
