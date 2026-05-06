import type { Metadata } from "next";
import { LegalLayout } from "@/components/LegalLayout";

export const metadata: Metadata = {
  title: "Terms of Service",
  description: "Terms covering use of the RunBar macOS app.",
};

export default function TermsPage() {
  return (
    <LegalLayout
      eyebrow="§ Legal · 02"
      italicWord="Terms"
      title="of service."
      lastUpdated="May 5, 2026"
    >
      <p>
        These terms govern your use of RunBar (the &quot;App&quot;), a
        macOS menu-bar application. By installing or using the App you
        agree to these terms. If you do not agree, do not install or use
        the App.
      </p>

      <h2>Licence</h2>
      <p>
        The App is distributed under the MIT licence. You receive a
        non-exclusive right to install and use the App on Macs that you
        own or control. The source is available at
        {" "}
        <a
          href="https://github.com/Rod292/runbar"
          target="_blank"
          rel="noopener noreferrer"
        >github.com/Rod292/runbar</a>
        .
      </p>

      <h2>Free of charge</h2>
      <p>
        RunBar is free. We do not charge for the App, do not run paid
        tiers, and do not run advertising. Costs you may incur from
        third-party services you connect (Strava, AI providers) are
        between you and those providers.
      </p>

      <h2>Third-party services</h2>
      <p>
        The App integrates with two third-party services on your behalf:
      </p>
      <ul>
        <li>
          <strong>Strava</strong>. By connecting Strava you accept the
          {" "}
          <a
            href="https://www.strava.com/legal/terms"
            target="_blank"
            rel="noopener noreferrer"
          >Strava Terms of Service</a>
          {" "}and{" "}
          <a
            href="https://www.strava.com/legal/api"
            target="_blank"
            rel="noopener noreferrer"
          >API Agreement</a>
          . RunBar accesses only the data scopes you authorise at OAuth
          time.
        </li>
        <li>
          <strong>AI coach providers</strong> (e.g.&nbsp;Google Gemini, when
          you opt in by entering an API key). By enabling the coach you
          accept that provider&rsquo;s terms (e.g.&nbsp;{" "}
          <a
            href="https://ai.google.dev/gemini-api/terms"
            target="_blank"
            rel="noopener noreferrer"
          >Gemini API terms</a>
          ). You are responsible for the API key you provide and any
          charges your provider may bill against it.
        </li>
      </ul>

      <h2>Disclaimer of warranties</h2>
      <p>
        THE APP IS PROVIDED &quot;AS IS&quot;, WITHOUT WARRANTY OF ANY
        KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
        WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
        AND NON-INFRINGEMENT.
      </p>
      <p>
        Third-party services accessed through the App (Strava, AI
        providers) are independent of RunBar. We disclaim, on behalf of
        those third-party service providers, all implied warranties of
        merchantability, fitness for a particular purpose, and
        non-infringement, and we exclude those providers from any
        liability for consequential, special, punitive, or indirect
        damages.
      </p>

      <h2>Limitation of liability</h2>
      <p>
        IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
        ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
        CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
        WITH THE APP OR THE USE OR OTHER DEALINGS IN THE APP.
      </p>

      <h2>Acceptable use</h2>
      <p>
        Do not use the App in violation of applicable law or in a manner
        that breaches the terms of any service the App connects to
        (Strava, AI providers). In particular, do not attempt to use the
        App to extract Strava data outside the scope authorised by your
        Strava account, or to circumvent the rate limits or retention
        rules built into the App.
      </p>

      <h2>Updates</h2>
      <p>
        The App ships an in-app update mechanism (Sparkle) which fetches
        a signed update feed from
        {" "}
        <code>runbar.run/appcast.xml</code>. Updates are validated
        with EdDSA before install. You may decline an update; some
        features may stop working over time as third-party APIs evolve.
      </p>

      <h2>Termination</h2>
      <p>
        You may stop using the App at any time by quitting and dragging
        it to the Trash. Your local data, OAuth tokens, and API keys can
        be removed as described in the
        {" "}
        <a href="/privacy">privacy policy</a>.
      </p>

      <h2>Governing law</h2>
      <p>
        These terms are governed by French law. Any dispute that cannot
        be resolved informally will be brought before the competent
        French courts. EU consumers retain their statutory rights.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about these terms? See the{" "}
        <a href="/contact">contact page</a>.
      </p>
    </LegalLayout>
  );
}
