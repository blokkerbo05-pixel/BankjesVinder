import Foundation

/// Eén favoriet bankje. Hoort bij een bankje-ID, dus blijft staan ook als de kaartgegevens opnieuw worden opgehaald.
struct Favoriet: Codable, Hashable {
    var benchID: String
    var date: Date
}

/// Alle favorieten van deze gebruiker.
struct FavorietenData: Codable {
    var favorieten: [Favoriet] = []
}

/// Waar de favorieten bewaard worden. Nu op de iPhone; later kan hier een online versie
/// (gekoppeld aan het account) voor in de plaats komen zonder dat de schermen veranderen.
protocol FavorietenOpslag {
    func laad() -> FavorietenData
    func bewaar(_ data: FavorietenData)
}

/// Bewaart de favorieten in een JSON-bestand op de iPhone.
struct LokaleFavorietenOpslag: FavorietenOpslag {
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("favorieten.json")
    }

    func laad() -> FavorietenData {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(FavorietenData.self, from: data) else {
            return FavorietenData()
        }
        return decoded
    }

    func bewaar(_ data: FavorietenData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}

/// Houdt bij welke bankjes favoriet zijn.
@MainActor
final class FavorietenStore: ObservableObject {
    @Published private(set) var data: FavorietenData
    private let opslag: FavorietenOpslag

    init(opslag: FavorietenOpslag = LokaleFavorietenOpslag()) {
        self.opslag = opslag
        data = opslag.laad()
    }

    func isFavoriet(_ benchID: String) -> Bool {
        data.favorieten.contains { $0.benchID == benchID }
    }

    var aantal: Int { data.favorieten.count }

    /// Zet een bankje aan of uit als favoriet.
    func wissel(_ benchID: String) {
        if isFavoriet(benchID) {
            data.favorieten.removeAll { $0.benchID == benchID }
        } else {
            data.favorieten.append(Favoriet(benchID: benchID, date: Date()))
        }
        opslag.bewaar(data)
    }
}
