import Foundation
import Network

/// Mini serveur HTTP local pour recevoir les webhooks Strava.
///
/// Strava POST sur notre callback à chaque nouvelle activité (event `create`),
/// modification (`update`), ou suppression (`delete`). On répond 200 et on
/// déclenche une sync immédiate — pas besoin d'attendre le polling 30 min.
///
/// Note : ce serveur tourne sur localhost uniquement. Pour que Strava puisse
/// vraiment nous joindre il faut soit un tunnel (ngrok, cloudflared) soit
/// déployer le récepteur sur un vrai serveur. En dev local, on utilise le
/// serveur surtout pour valider le challenge GET initial et pour debugger.
public final class StravaWebhookServer: @unchecked Sendable {
    private var listener: NWListener?
    private let port: NWEndpoint.Port
    private let onActivityEvent: (Int) -> Void

    public init(port: UInt16, onActivityEvent: @escaping (Int) -> Void) {
        self.port = NWEndpoint.Port(rawValue: port) ?? 47863
        self.onActivityEvent = onActivityEvent
    }

    public func start() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: .tcp, on: port)
            listener.newConnectionHandler = { [weak self] conn in
                self?.handle(conn)
            }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
            RunBarLog.strava.info("Webhook server listening on port \(self.port)")
        } catch {
            RunBarLog.strava.error("Failed to start webhook server: \(error.localizedDescription)")
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .userInitiated))
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self, let data = data, let raw = String(data: data, encoding: .utf8) else {
                conn.cancel()
                return
            }
            let response = self.handleRequest(raw)
            conn.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }

    /// Parse une requête HTTP brute. Dispatch sur GET (challenge Strava) ou POST (event).
    private func handleRequest(_ raw: String) -> String {
        let lines = raw.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let firstLine = lines.first else { return Self.simple(status: "400 Bad Request", body: "{}") }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return Self.simple(status: "400 Bad Request", body: "{}") }
        let method = String(parts[0])
        let path   = String(parts[1])

        switch method {
        case "GET":  return handleChallenge(path: path)
        case "POST": return handleEvent(raw: raw)
        default:     return Self.simple(status: "405 Method Not Allowed", body: "{}")
        }
    }

    /// Strava envoie GET /webhook?hub.mode=subscribe&hub.verify_token=...&hub.challenge=...
    /// On doit répondre `{"hub.challenge":"..."}` SI le verify_token matche.
    private func handleChallenge(path: String) -> String {
        guard let comps = URLComponents(string: "http://x" + path),
              let challenge = comps.queryItems?.first(where: { $0.name == "hub.challenge" })?.value,
              let token     = comps.queryItems?.first(where: { $0.name == "hub.verify_token" })?.value
        else { return Self.simple(status: "400 Bad Request", body: "{}") }
        guard token == Secrets.webhookVerifyToken else {
            RunBarLog.strava.error("Webhook verify token mismatch")
            return Self.simple(status: "401 Unauthorized", body: "{}")
        }
        let body = "{\"hub.challenge\":\"\(challenge)\"}"
        return Self.simple(status: "200 OK", body: body, contentType: "application/json")
    }

    /// Body POST : `{"object_type":"activity","aspect_type":"create","object_id":12345, ...}`.
    /// On extrait l'object_id et on déclenche le callback.
    private func handleEvent(raw: String) -> String {
        // Body séparé du header par double CRLF
        if let bodyStart = raw.range(of: "\r\n\r\n") {
            let body = String(raw[bodyStart.upperBound...])
            if let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["object_type"] as? String, type == "activity",
               let objectId = json["object_id"] as? Int {
                let cb = onActivityEvent
                Task { @MainActor in cb(objectId) }
            }
        }
        return Self.simple(status: "200 OK", body: "{}", contentType: "application/json")
    }

    private static func simple(status: String, body: String,
                                contentType: String = "text/plain") -> String {
        """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
    }
}
