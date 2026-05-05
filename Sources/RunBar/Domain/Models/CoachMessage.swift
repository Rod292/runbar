import Foundation

/// Message court généré par l'assistant IA. Affiché en italique serif dans le
/// popover, 2 à 4 lignes max. Persiste un jour pour éviter de rappeler le LLM
/// à chaque ouverture.
public struct CoachMessage: Codable, Equatable, Sendable {
    public let text: String
    public let providerLabel: String
    public let generatedAt: Date
    /// Hash du contexte qui a produit ce message — sert à invalider quand les
    /// faits changent (nouvelle séance, target modifié).
    public let contextHash: String

    public init(text: String, providerLabel: String, generatedAt: Date, contextHash: String) {
        self.text = text
        self.providerLabel = providerLabel
        self.generatedAt = generatedAt
        self.contextHash = contextHash
    }
}
