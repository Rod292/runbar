import Foundation

/// Provider Gemini 2.5 Flash Lite. Endpoint REST — pas de SDK externe, on garde
/// le binaire léger.
public struct GeminiCoachProvider: AICoachProvider {
    public let id = "gemini-2.5-flash-lite"
    public let displayName = "Gemini 2.5 Flash Lite"

    private let endpoint = URL(string:
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"
    )!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func generate(context: CoachContext, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw CoachProviderError.missingKey }

        var request = URLRequest(url: endpoint.appending(queryItems: [
            URLQueryItem(name: "key", value: apiKey)
        ]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        // Format Gemini : on combine system + user dans un seul tour pour
        // éviter le besoin de gérer le rôle "system" explicitement (toujours
        // supporté mais varie entre versions).
        let combined = CoachPrompt.system + "\n\n" + CoachPrompt.userPrompt(context: context)
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": combined]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 200,
                "topP": 0.95
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoachProviderError.decoding("not an HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw CoachProviderError.http(status: http.statusCode, body: body)
        }

        return try Self.extractText(from: data)
    }

    /// Parser tolérant : on cible `candidates[0].content.parts[*].text`
    /// concaténés. Toute structure inattendue → erreur.
    static func extractText(from data: Data) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CoachProviderError.decoding("root is not an object")
        }
        guard let candidates = root["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw CoachProviderError.decoding("missing candidates[0].content.parts")
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CoachProviderError.empty }
        return trimmed
    }
}
