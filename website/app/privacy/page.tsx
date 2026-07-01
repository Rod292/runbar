import type { Metadata } from "next";
import { LegalLayout } from "@/components/LegalLayout";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How RunBar handles your data — Strava, AI coach, and what stays local.",
};

export default function PrivacyPage() {
  return (
    <LegalLayout
      eyebrow="§ Legal · 01"
      italicWord="Privacy"
      title="policy."
      lastUpdated="July 1, 2026"
    >
      <p>
        RunBar is a local-first macOS menu-bar app. We do not run servers,
        we do not collect analytics, and we do not phone home. This page
        describes the only places your data leaves your Mac, and on whose
        behalf.
      </p>

      <h2>Who we are</h2>
      <p>
        RunBar is built and operated by an individual developer (the
        <em> Data Controller</em>). For privacy enquiries, deletion
        requests, or any GDPR / UK GDPR right of access:
        {" "}
        <a href="/contact">contact page</a>.
      </p>

      <h2>What data lives on your Mac</h2>
      <ul>
        <li>
          <strong>Strava activities (last 7 days).</strong> RunBar
          synchronises a rolling 7-day window of your runs from the Strava
          API into a local SwiftData store at
          <code> ~/Library/Application Support/RunBar/store.sqlite</code>.
          Activities older than 7 days are purged automatically on every
          sync, in line with the Strava API Agreement.
        </li>
        <li>
          <strong>Weekly snapshots (derived).</strong> RunBar stores
          per-week aggregates (target, achieved distance / runs / elevation,
          metric used) in <code>UserDefaults</code>. These are summary
          numbers computed locally — they are not raw Strava data.
        </li>
        <li>
          <strong>Strava OAuth tokens</strong> and (optionally) your AI
          provider API key are stored in the macOS Keychain with
          {" "}
          <code>kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly</code>.
        </li>
        <li>
          <strong>Settings &amp; preferences.</strong> Goal target, metric,
          unit, race date and name. Stored in <code>UserDefaults</code>.
        </li>
      </ul>

      <h2>What leaves your Mac, and to whom</h2>
      <p>
        RunBar makes outbound network calls only in three situations:
      </p>
      <ol>
        <li>
          <strong>Strava API</strong> (
          <a
            href="https://www.strava.com/legal/privacy"
            target="_blank"
            rel="noopener noreferrer"
          >privacy policy</a>): OAuth login + activity sync over HTTPS.
          Strava is the source of the run data; their privacy terms apply
          to the access we have on your behalf, scoped to the permissions
          you granted at OAuth time.
        </li>
        <li>
          <strong>Sparkle update check.</strong> The app fetches{" "}
          <code>https://runbar.run/appcast.xml</code> roughly every
          24 hours to check for new versions. The request carries no
          identifier beyond a generic User-Agent.
        </li>
        <li>
          <strong>RunBar OAuth backend (shared connection only).</strong>{" "}
          When you use the shared one-tap Strava connection, the OAuth
          code/token exchange is proxied through minimal serverless
          routes on <code>runbar.run</code> (they hold the app&rsquo;s
          client secret so it never ships in the binary). Tokens pass
          through these routes and are returned to your Mac;{" "}
          <strong>nothing is stored server-side</strong> — no database, no
          logs of tokens. If you bring your own Strava API app instead,
          RunBar talks to Strava directly and these routes are never
          called.
        </li>
        <li>
          <strong>AI coach (opt-in, currently paused).</strong> Since
          Strava&rsquo;s API policy update of June 2026 forbids feeding
          Strava data into AI tools, the coach does not run while your
          runs sync from Strava — no data is sent to any AI provider,
          even if you saved a key. When the coach runs (with a future
          non-Strava source such as Apple Health), it sends a small JSON
          payload of weekly aggregates to the chosen provider (default:
          Google Gemini):
          <em>
            {" "}
            distance, run count, elevation, target, progress %, days left
            in the week, the last four weeks of distance totals, your goal
            streak, and (if set) your race name and days until race.
          </em>{" "}
          Never activity names, timestamps, GPS data, or personal
          identifiers. Your API key is sent over HTTPS to authenticate the
          request and is never stored on any server we control.
        </li>
      </ol>

      <h2>Website waitlist</h2>
      <p>
        If you join the waitlist on <code>runbar.run</code>, we store your
        email address, the signup timestamp, and your coarse country code
        (for send-time scheduling) in a managed key-value store (Vercel
        KV / Upstash). This data is used for exactly one launch
        announcement, then the list is deleted. No sharing, no profiling,
        no recurring newsletter. You can request erasure at any time via
        the <a href="/contact">contact page</a> — removals are processed
        within 30 days.
      </p>

      <h2>Strava data &amp; third parties</h2>
      <p>
        Per the{" "}
        <a
          href="https://www.strava.com/legal/api"
          target="_blank"
          rel="noopener noreferrer"
        >
          Strava API Agreement
        </a>{" "}
        and API Policy (updated June 2026), RunBar may not share Strava
        Data with third parties and may not use it in connection with any
        AI application. RunBar enforces this in code: the AI coach is
        disabled whenever the local store contains Strava-sourced
        activities.
      </p>
      <p>
        We recommend the paid Gemini API tier when using the AI coach.
        Google&rsquo;s free tier may use prompts to improve their models;
        paid tiers do not. See{" "}
        <a
          href="https://ai.google.dev/gemini-api/terms"
          target="_blank"
          rel="noopener noreferrer"
        >
          Gemini API terms
        </a>
        .
      </p>

      <h2>What we don&rsquo;t do</h2>
      <ul>
        <li>No analytics or telemetry in the app.</li>
        <li>No advertising of any kind.</li>
        <li>No data sold, rented, leased, or otherwise shared.</li>
        <li>No tracking cookies on the website.</li>
      </ul>

      <h2>Your rights</h2>
      <p>
        You have the right under GDPR / UK GDPR to access, correct, port,
        and erase the personal data RunBar holds about you. Because the
        app is local-first, most of these rights are exercised in the app
        itself:
      </p>
      <ul>
        <li>
          <strong>Access &amp; portability</strong>: every activity row in
          the popover is a view on the local database; the SQLite file is
          yours and can be opened with any SQLite client.
        </li>
        <li>
          <strong>Deletion (Strava data)</strong>: Settings → Sources →
          <em> Disconnect</em>. RunBar deletes the OAuth tokens and purges
          all locally cached Strava activities from the store.
        </li>
        <li>
          <strong>Deletion (everything)</strong>: drag RunBar.app to the
          Trash and remove
          {" "}
          <code>~/Library/Application Support/RunBar/</code> and the
          {" "}
          <code>com.rodrigue.runbar.tahoe</code> entries from
          {" "}
          <code>~/Library/Preferences/</code>.
        </li>
        <li>
          <strong>Withdraw AI consent</strong>: Settings → Coach →{" "}
          <em>Remove key</em>, or toggle the coach off. The key is wiped
          from the Keychain and no further requests are sent.
        </li>
        <li>
          <strong>Strava revocation</strong>: at any time you can revoke
          RunBar&rsquo;s access at{" "}
          <a
            href="https://www.strava.com/settings/apps"
            target="_blank"
            rel="noopener noreferrer"
          >
            strava.com/settings/apps
          </a>
          . On revocation, RunBar deletes the cached activities at the
          next launch.
        </li>
      </ul>

      <h2>Data retention</h2>
      <p>
        Strava data is retained for at most 7 days locally, in line with
        the Strava API Agreement. Derived weekly aggregates (snapshots)
        and your settings are retained for as long as you use the app and
        are removed when you uninstall.
      </p>

      <h2>Security</h2>
      <p>
        All outbound traffic uses HTTPS. Tokens and API keys live in the
        macOS Keychain with device-only access. The only server-side
        surface is a set of stateless OAuth proxy routes and the waitlist
        endpoint described above — neither stores activity data or
        tokens.
      </p>

      <h2>Children</h2>
      <p>
        RunBar is not directed at children under 13. If you are a parent
        and believe a child has used the app, contact us and we will help
        with deletion guidance.
      </p>

      <h2>Changes to this policy</h2>
      <p>
        Material changes will be reflected here, with a new
        <em> Last updated</em> date. Continued use of RunBar after a
        change constitutes acceptance.
      </p>
    </LegalLayout>
  );
}
