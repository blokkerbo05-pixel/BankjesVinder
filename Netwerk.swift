import Foundation
import Network

/// Weet of de iPhone internet heeft, en vertaalt fouten naar een duidelijke Nederlandse melding.
@MainActor
final class Netwerk: ObservableObject {
    static let gedeeld = Netwerk()

    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    static let geenInternet = "Geen internet. Probeer het later opnieuw."

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "netwerk-monitor"))
    }

    /// Is deze fout een verbindingsprobleem?
    nonisolated static func isVerbindingsfout(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .cannotFindHost, .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff:
            return true
        default:
            return false
        }
    }

    /// Een melding voor de gebruiker bij een fout.
    nonisolated static func melding(voor error: Error, standaard: String) -> String {
        isVerbindingsfout(error) ? geenInternet : standaard
    }
}
