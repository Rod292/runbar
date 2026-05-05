import Foundation

/// Credentials Strava saisies par l'utilisateur ("Bring Your Own App").
///
/// Permet aux utilisateurs techniques d'enregistrer leur propre OAuth app
/// sur https://www.strava.com/settings/api et d'utiliser RunBar sans dépendre
/// du quota de l'app partagée — utile tant que l'app principale n'a pas reçu
/// l'augmentation de quota Strava (limite par défaut : 1 athlète, "Single
/// Player Mode").
///
/// - `clientID` est public (apparaît dans l'URL OAuth) → UserDefaults sous la
///   même clé que le fallback Secrets, donc `Secrets.stravaClientID` le
///   ramasse automatiquement.
/// - `clientSecret` est sensible → Keychain.
public enum StravaUserCredentialsStore {
    static let clientIDDefaultsKey = "runbar.strava.clientID"
    static let clientSecretKeychainAccount = "byo_client_secret"

    public static var clientID: String {
        UserDefaults.standard.string(forKey: clientIDDefaultsKey) ?? ""
    }

    public static var clientSecret: String {
        Keychain.get(account: clientSecretKeychainAccount) ?? ""
    }

    /// Vrai si l'utilisateur a configuré sa propre app Strava — la présence
    /// d'un `clientSecret` est le signal canonique (le `clientID` partagé
    /// vit déjà dans le binaire en fallback).
    public static var isUserManaged: Bool {
        !clientSecret.isEmpty
    }

    public static func save(clientID: String, clientSecret: String) throws {
        let cid = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cs  = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cid.isEmpty, !cs.isEmpty else {
            throw StravaUserCredentialsError.empty
        }
        UserDefaults.standard.set(cid, forKey: clientIDDefaultsKey)
        try Keychain.set(cs, account: clientSecretKeychainAccount)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: clientIDDefaultsKey)
        Keychain.remove(account: clientSecretKeychainAccount)
    }
}

public enum StravaUserCredentialsError: LocalizedError {
    case empty

    public var errorDescription: String? {
        switch self {
        case .empty: return "Client ID and Client Secret are both required."
        }
    }
}
