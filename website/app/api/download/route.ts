import { NextRequest, NextResponse } from "next/server";

const LATEST_DMG = "/download/RunBar-0.1.16.dmg";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const utmSource = url.searchParams.get("utm_source") ?? "direct";
  const utmMedium = url.searchParams.get("utm_medium") ?? "";
  const utmCampaign = url.searchParams.get("utm_campaign") ?? "";
  const referer = request.headers.get("referer") ?? "";
  const userAgent = request.headers.get("user-agent") ?? "";
  const country = request.headers.get("x-vercel-ip-country") ?? "";

  console.log(
    JSON.stringify({
      event: "download",
      version: "0.1.16",
      utm_source: utmSource,
      utm_medium: utmMedium,
      utm_campaign: utmCampaign,
      referer,
      country,
      ua_kind: classifyUA(userAgent),
      ts: new Date().toISOString(),
    })
  );

  return NextResponse.redirect(new URL(LATEST_DMG, request.url), 302);
}

function classifyUA(ua: string): string {
  if (/Mac|Darwin/i.test(ua)) {
    if (/arm64|Apple Silicon/i.test(ua)) return "mac-arm";
    return "mac";
  }
  if (/Windows/i.test(ua)) return "windows";
  if (/Linux/i.test(ua)) return "linux";
  if (/iPhone|iPad/i.test(ua)) return "ios";
  if (/Android/i.test(ua)) return "android";
  return "other";
}
