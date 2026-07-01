import Foundation

/// Provider IA — abstraction sur Gemini / OpenAI / Claude / Ollama. Chaque
/// implémentation prend un contexte factuel et produit un message court.
public protocol AICoachProvider: Sendable {
    /// Identifiant stable (utilisé pour persister la sélection utilisateur).
    var id: String { get }
    /// Nom affiché (« Gemini 2.5 Flash Lite »).
    var displayName: String { get }
    /// Génère un message en se basant sur le contexte. Erreur si clé invalide,
    /// quota dépassé, ou réponse mal formée.
    func generate(context: CoachContext, apiKey: String) async throws -> String
}

public enum CoachProviderError: Error, LocalizedError {
    case missingKey
    case http(status: Int, body: String?)
    case decoding(String)
    case empty
    case timeout

    public var errorDescription: String? {
        switch self {
        case .missingKey:
            return "API key is missing."
        case .http(let status, let body):
            return "HTTP \(status)\(body.map { ": \($0)" } ?? "")"
        case .decoding(let detail):
            return "Bad response: \(detail)"
        case .empty:
            return "Provider returned an empty message."
        case .timeout:
            return "The coach took too long to answer. Try again later."
        }
    }
}

/// Prompt commun aux providers — gardé ici pour rester cohérent. Le ton est
/// factuel, chaleureux ; le prompt interdit les inventions et fixe la longueur.
public enum CoachPrompt {
    public static let system = """
    You are a running coach embedded in Runbar, a macOS menubar app.
    Tone: factual, warm, concise. Never sappy, never generic.
    Reply in 2 to 4 short lines. No emoji. No headings. No lists.
    All distances in the JSON are in the unit given by its "unit" field ("km" or "mi") — use that unit in your reply.
    Strict rule: only mention facts present in the JSON. Never invent paces, splits, dates, or activity names.
    If the week is empty, encourage starting; if the goal is reached, congratulate; if a race is < 30 days, weave it in briefly.
    """

    /// Construit le user message JSON + une instruction de formatage.
    public static func userPrompt(context: CoachContext) -> String {
        let json = (try? Self.encoder.encode(context)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
        Facts (JSON):
        \(json)

        Write the coaching message now.
        """
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
}
