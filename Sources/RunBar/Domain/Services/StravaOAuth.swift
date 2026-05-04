import AppKit
import Foundation
import Network

/// Flow OAuth Strava : on ouvre le navigateur sur l'URL d'autorisation,
/// et on lance un mini serveur HTTP localhost pour intercepter le callback.
///
/// Pourquoi cette approche : Strava ne supporte pas les custom URL schemes
/// (`runbar://oauth` → `Bad Request: redirect_uri invalid`). Le pattern desktop
/// recommandé est un callback HTTP local. La "Authorization Callback Domain"
/// sur le portail Strava doit valoir `localhost`.
@MainActor
final class StravaOAuthCoordinator {
    func authorize() async throws -> String {
        guard Secrets.hasStravaCredentials else { throw StravaError.missingConfiguration }
        let state = UUID().uuidString
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id",       value: Secrets.stravaClientID),
            URLQueryItem(name: "response_type",   value: "code"),
            URLQueryItem(name: "redirect_uri",    value: Secrets.stravaRedirectURI),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope",           value: Secrets.stravaScope),
            URLQueryItem(name: "state",           value: state),
        ]
        let authURL = components.url!

        // On démarre le listener AVANT d'ouvrir le navigateur, sinon le
        // callback peut arriver avant qu'on écoute.
        async let code: String = waitForCode(expectedState: state)
        RunBarLog.strava.info("Starting OAuth listener on localhost:\(Secrets.stravaLocalCallbackPort)")
        RunBarLog.strava.info("Opening Strava OAuth URL with redirect \(Secrets.stravaRedirectURI)")
        NSWorkspace.shared.open(authURL)
        return try await code
    }

    private func waitForCode(expectedState: String) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            do {
                // Loopback uniquement : le callback OAuth doit venir du browser
                // local de l'utilisateur, jamais d'un host distant sur le LAN.
                let params = NWParameters.tcp
                params.acceptLocalOnly = true
                let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Secrets.stravaLocalCallbackPort)!)
                let handler = LocalCallbackHandler(
                    continuation: cont,
                    listener: listener,
                    expectedState: expectedState
                )
                listener.newConnectionHandler = { conn in
                    RunBarLog.strava.info("Received Strava OAuth callback connection")
                    handler.handle(connection: conn)
                }
                listener.start(queue: .global(qos: .userInitiated))
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 120) {
                    handler.timeout()
                }
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}

/// Encapsule l'état partagé entre les connexions et la continuation
/// (on ne resume qu'une seule fois, et on stoppe le listener proprement).
private final class LocalCallbackHandler: @unchecked Sendable {
    private let continuation: CheckedContinuation<String, Error>
    private let listener: NWListener
    private let expectedState: String
    private var done = false
    private let lock = NSLock()

    init(continuation: CheckedContinuation<String, Error>, listener: NWListener, expectedState: String) {
        self.continuation = continuation
        self.listener = listener
        self.expectedState = expectedState
    }

    func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            guard let self else { return }
            let parsed = Self.parseCallback(data: data)
            // On répond toujours quelque chose, succès ou échec.
            connection.send(content: Self.responsePayload(success: parsed.code != nil),
                            completion: .contentProcessed { _ in connection.cancel() })
            guard parsed.state == self.expectedState else {
                self.finish(.failure(StravaError.invalidOAuthState))
                return
            }
            if let code = parsed.code {
                self.finish(.success(code))
            } else if parsed.error != nil {
                self.finish(.failure(StravaError.oauthFailed))
            }
        }
    }

    /// Parse une ligne `GET /callback?code=...` (ou `?error=...`).
    func timeout() {
        finish(.failure(StravaError.oauthTimeout))
    }

    private static func parseCallback(data: Data?) -> (code: String?, error: String?, state: String?) {
        guard
            let data = data,
            let request = String(data: data, encoding: .utf8),
            let path = requestPath(in: request),
            let comps = URLComponents(string: "http://x" + path)
        else { return (nil, nil, nil) }
        let code  = comps.queryItems?.first(where: { $0.name == "code"  })?.value
        let error = comps.queryItems?.first(where: { $0.name == "error" })?.value
        let state = comps.queryItems?.first(where: { $0.name == "state" })?.value
        return (code, error, state)
    }

    private func finish(_ result: Result<String, Error>) {
        lock.lock(); defer { lock.unlock() }
        guard !done else { return }
        done = true
        listener.cancel()
        switch result {
        case .success(let code): continuation.resume(returning: code)
        case .failure(let err):  continuation.resume(throwing: err)
        }
    }

    /// Première ligne d'une requête HTTP : `GET /callback?code=... HTTP/1.1`.
    private static func requestPath(in raw: String) -> String? {
        guard let firstLine = raw.split(separator: "\r\n", maxSplits: 1).first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        return String(parts[1])
    }

    private static func responsePayload(success: Bool) -> Data {
        let eyebrow = success ? "Step 04 of 06 · Strava" : "Step 04 of 06 · Strava"
        let italicWord = success ? "Connected." : "Failed."
        let supportingTitle = success ? "Tokens stored." : "Try again from RunBar."
        let body = success
            ? "You can close this tab and head back to your menu bar."
            : "Something went wrong on our side. Re-open the popover and tap Connect Strava."
        let accent = success ? "#2D7A3E" : "#C75D2C"
        let html = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>RunBar — \(italicWord)</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root {
              --ivory: #F7F4EE;
              --paper: #FBF9F4;
              --ink: #0F0F0E;
              --ink-soft: #46463F;
              --ink-mute: #8A887E;
              --hairline: #DDD7CB;
              --accent: \(accent);
            }
            * { box-sizing: border-box; }
            html, body { margin: 0; padding: 0; height: 100%; }
            body {
              background: var(--ivory);
              color: var(--ink);
              font-family: -apple-system, BlinkMacSystemFont, "Inter",
                "Helvetica Neue", Arial, sans-serif;
              -webkit-font-smoothing: antialiased;
              display: flex;
              align-items: center;
              justify-content: center;
              padding: 32px;
              background-image: radial-gradient(rgba(15,15,14,.025) 1px, transparent 1px);
              background-size: 3px 3px;
            }
            .stage {
              max-width: 520px;
              width: 100%;
            }
            .eyebrow {
              display: flex;
              align-items: center;
              gap: 12px;
              font: 500 10.5px/1 ui-monospaced, SFMono-Regular, Menlo, monospace;
              letter-spacing: .28em;
              text-transform: uppercase;
              color: var(--ink-mute);
              margin-bottom: 20px;
            }
            .eyebrow .dot {
              width: 6px; height: 6px; border-radius: 999px;
              background: var(--accent);
            }
            .eyebrow .rule {
              flex: 0 0 22px; height: 1px; background: var(--hairline);
            }
            h1 {
              font: 500 clamp(48px, 9vw, 92px)/.9 "Times New Roman", Georgia, serif;
              font-style: italic;
              letter-spacing: -.045em;
              margin: 0 0 6px 0;
              color: var(--ink);
            }
            h2 {
              font: 400 clamp(18px, 2.4vw, 24px)/1.1 "Times New Roman", Georgia, serif;
              letter-spacing: -.02em;
              color: var(--ink-soft);
              margin: 0 0 24px 0;
            }
            .hairline {
              height: 1px; background: var(--hairline);
              margin: 24px 0;
            }
            p.body {
              font: 400 15px/1.5 -apple-system, BlinkMacSystemFont, sans-serif;
              color: var(--ink-soft);
              max-width: 44ch;
              margin: 0 0 28px 0;
            }
            .colophon {
              display: flex;
              align-items: baseline;
              gap: 16px;
              font: 500 10px/1 ui-monospaced, SFMono-Regular, Menlo, monospace;
              letter-spacing: .22em;
              text-transform: uppercase;
              color: var(--ink-mute);
            }
            .colophon .rule { flex: 1; height: 1px; background: var(--hairline); }
            .colophon .accent { color: var(--accent); }
          </style>
        </head>
        <body>
          <div class="stage">
            <div class="eyebrow">
              <span class="dot"></span>
              <span>\(eyebrow)</span>
              <span class="rule" aria-hidden="true"></span>
              <span>oauth callback</span>
            </div>

            <h1>\(italicWord)</h1>
            <h2>— \(supportingTitle)</h2>

            <div class="hairline"></div>

            <p class="body">\(body)</p>

            <div class="colophon">
              <span>RunBar</span>
              <span class="rule" aria-hidden="true"></span>
              <span class="accent">localhost:47862</span>
            </div>
          </div>
        </body>
        </html>
        """
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """
        return Data(response.utf8)
    }
}
