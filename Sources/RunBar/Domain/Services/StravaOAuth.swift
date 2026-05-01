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
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id",       value: Secrets.stravaClientID),
            URLQueryItem(name: "response_type",   value: "code"),
            URLQueryItem(name: "redirect_uri",    value: Secrets.stravaRedirectURI),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope",           value: Secrets.stravaScope),
        ]
        let authURL = components.url!

        // On démarre le listener AVANT d'ouvrir le navigateur, sinon le
        // callback peut arriver avant qu'on écoute.
        async let code: String = waitForCode()
        NSWorkspace.shared.open(authURL)
        return try await code
    }

    private func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            do {
                let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: Secrets.stravaLocalCallbackPort)!)
                let handler = LocalCallbackHandler(continuation: cont, listener: listener)
                listener.newConnectionHandler = { conn in
                    handler.handle(connection: conn)
                }
                listener.start(queue: .global(qos: .userInitiated))
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
    private var done = false
    private let lock = NSLock()

    init(continuation: CheckedContinuation<String, Error>, listener: NWListener) {
        self.continuation = continuation
        self.listener = listener
    }

    func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            guard let self else { return }
            let parsed = Self.parseCallback(data: data)
            // On répond toujours quelque chose, succès ou échec.
            connection.send(content: Self.responsePayload(success: parsed.code != nil),
                            completion: .contentProcessed { _ in connection.cancel() })
            if let code = parsed.code {
                self.finish(.success(code))
            } else if parsed.error != nil {
                self.finish(.failure(StravaError.oauthFailed))
            }
        }
    }

    /// Parse une ligne `GET /callback?code=...` (ou `?error=...`).
    private static func parseCallback(data: Data?) -> (code: String?, error: String?) {
        guard
            let data = data,
            let request = String(data: data, encoding: .utf8),
            let path = requestPath(in: request),
            let comps = URLComponents(string: "http://x" + path)
        else { return (nil, nil) }
        let code  = comps.queryItems?.first(where: { $0.name == "code"  })?.value
        let error = comps.queryItems?.first(where: { $0.name == "error" })?.value
        return (code, error)
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
        let title = success ? "Connecté ✓" : "Échec"
        let body = success
            ? "Tu peux fermer cet onglet et retourner à RunBar."
            : "Quelque chose s'est mal passé. Réessaie depuis RunBar."
        let html = """
        <!doctype html>
        <html lang="fr"><head><meta charset="utf-8"><title>RunBar</title>
        <style>
          body{font-family:-apple-system,sans-serif;background:#F5F0E6;color:#1C1C1E;
               display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
          .card{padding:32px 40px;border-radius:14px;background:#fff;
                box-shadow:0 8px 32px rgba(0,0,0,.08);text-align:center;max-width:360px}
          h1{margin:0 0 8px;font-size:22px;color:#2D7A3E}
          p{margin:0;color:#4A4A4A;line-height:1.5}
        </style></head>
        <body><div class="card"><h1>\(title)</h1><p>\(body)</p></div></body></html>
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
