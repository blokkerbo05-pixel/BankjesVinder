import Foundation
import Supabase

/// Wie is er ingelogd? Inloggen gaat met e-mail en een 6-cijferige code. Het package bewaart de sessie veilig,
/// dus je blijft ingelogd tot je zelf uitlogt.
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var gebruiker: User?
    /// Wordt waar zolang de app nog uitzoekt of je al ingelogd was.
    @Published private(set) var isLaden = true
    /// Laat het inlogscherm zien.
    @Published var toonLogin = false
    /// Een melding die als alert getoond wordt (bijv. "Geen internet").
    @Published var melding: String?

    var isIngelogd: Bool { gebruiker != nil }
    var email: String? { gebruiker?.email }
    var userID: UUID? { gebruiker?.id }

    private var client: SupabaseClient { SupabaseConfig.client }

    init() {
        Task { await volgSessie() }
    }

    /// Houdt `gebruiker` bij op de sessie (bij het starten, inloggen, uitloggen en verversen).
    private func volgSessie() async {
        for await (_, sessie) in client.auth.authStateChanges {
            gebruiker = sessie?.user
            isLaden = false
        }
    }

    // MARK: Inloggen

    /// Stuurt een code naar dit e-mailadres.
    func stuurCode(naar email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }

    /// Controleert de code. Is die goed, dan ben je ingelogd.
    func controleer(code: String, voor email: String) async throws {
        try await client.auth.verifyOTP(email: email, token: code, type: .email)
    }

    func logUit() async {
        do {
            try await client.auth.signOut()
        } catch {
            melding = Netwerk.melding(voor: error, standaard: "Uitloggen lukte niet. Probeer het opnieuw.")
        }
    }

    // MARK: Gebruiken

    /// Voert een actie uit die een account en internet nodig heeft (toevoegen, stemmen, foto's).
    /// Niet ingelogd: het inlogscherm. Geen internet: een melding.
    func metAccount(_ actie: () -> Void) {
        guard Netwerk.gedeeld.isOnline else {
            melding = Netwerk.geenInternet
            return
        }
        guard isIngelogd else {
            toonLogin = true
            return
        }
        actie()
    }
}
