import type { Metadata } from "next";
import { LegalLayout } from "@/components/LegalLayout";

export const metadata: Metadata = {
  title: "Contact",
  description: "How to reach the RunBar team for support, bugs, and privacy.",
};

const SUPPORT_EMAIL = "contact@runbar.run";

export default function ContactPage() {
  return (
    <LegalLayout
      eyebrow="§ Legal · 03"
      italicWord="Contact"
      title="us."
    >
      <p>
        RunBar is built and run by an individual developer. Pick the
        channel that fits your need — they all reach the same person.
      </p>

      <h2>Bugs &amp; feature ideas</h2>
      <p>
        Open an issue on GitHub: it is the fastest path because it gives
        you a public thread, version traceability, and notifications when
        the fix ships.
      </p>
      <p>
        <a
          href="https://github.com/Rod292/runbar/issues/new"
          target="_blank"
          rel="noopener noreferrer"
          className="font-medium text-ink underline decoration-vermillon decoration-[1.5px] underline-offset-[5px]"
        >
          → File an issue on GitHub
        </a>
      </p>

      <h2>Privacy &amp; deletion requests</h2>
      <p>
        For GDPR / UK GDPR rights of access, deletion, or portability —
        and for any privacy enquiry that should not be public — write to{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>. We aim to
        reply within 7 days.
      </p>

      <h2>Strava-specific concerns</h2>
      <p>
        If you want to revoke RunBar&rsquo;s access to your Strava
        account, you can do so directly at{" "}
        <a
          href="https://www.strava.com/settings/apps"
          target="_blank"
          rel="noopener noreferrer"
        >
          strava.com/settings/apps
        </a>{" "}
        — you do not need to wait for us. RunBar will purge the cached
        Strava activities at the next launch.
      </p>

      <h2>Security disclosures</h2>
      <p>
        Found a vulnerability? Please email{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> with{" "}
        <code>[security]</code> in the subject. Do not open a public
        issue for security reports.
      </p>

      <h2>What RunBar isn&rsquo;t</h2>
      <p>
        RunBar is not Strava, and is not affiliated with or endorsed by
        Strava, Inc. For Strava account, billing, or activity data
        questions, please contact Strava support directly.
      </p>
    </LegalLayout>
  );
}
