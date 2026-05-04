import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RunBar — a runner in your menu bar",
  description:
    "Mac menu-bar app for runners. A tiny figure runs toward your weekly finish line. Strava sync. Built for macOS.",
  metadataBase: new URL("https://runbar.app"),
  openGraph: {
    title: "RunBar — a runner in your menu bar",
    description:
      "Strava tells you what you did. RunBar tells you where you stand — right now.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-ivory text-ink">
        {children}
      </body>
    </html>
  );
}
