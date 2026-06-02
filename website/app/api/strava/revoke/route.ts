import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * POST /api/strava/revoke
 *
 * Revokes a Strava grant on the user's behalf for the *shared* RunBar app,
 * where the `client_secret` lives here (Vercel env) and never reaches the
 * desktop client. Mirrors /exchange + /refresh.
 *
 * Uses Strava's `oauth/revoke` endpoint (HTTP Basic Auth with
 * client_id:client_secret, `token` as a form param) — the only deauthorization
 * endpoint supported after 2027-06-01; `oauth/deauthorize` is being retired.
 *
 * Request:  { "token": "<access_or_refresh_token>" }
 * Response: 200 with empty body on success; Strava's status forwarded otherwise.
 */
export async function POST(req: Request) {
  const clientId = requiredEnv(process.env.STRAVA_CLIENT_ID);
  const clientSecret = requiredEnv(process.env.STRAVA_CLIENT_SECRET);
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

  let payload: { token?: unknown };
  try {
    payload = await req.json();
  } catch {
    return NextResponse.json(
      { error: "invalid_json", message: "Body must be JSON." },
      { status: 400 },
    );
  }

  const token = payload.token;
  if (typeof token !== "string" || token.trim() === "") {
    return NextResponse.json(
      { error: "invalid_token", message: "Field `token` is required." },
      { status: 400 },
    );
  }

  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const stravaResp = await fetch("https://www.strava.com/oauth/revoke", {
    method: "POST",
    headers: {
      Authorization: `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({ token }),
  });

  // Forward Strava's status; body is empty on success.
  return new Response(null, { status: stravaResp.status });
}

function requiredEnv(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const trimmed = value.trim();
  if (!trimmed || trimmed === "\"\"" || trimmed === "''") return undefined;
  return trimmed.replace(/^['"]|['"]$/g, "");
}
