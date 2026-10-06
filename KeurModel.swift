import Foundation

// Het datamodel voor het keuren van bankjes.
//
// Alles heeft een eigen ID (bankje-ID, gebruiker-ID), zodat dit later één-op-één
// naar tabellen in Supabase kan: `stemmen` (bankje + gebruiker + goed/niet goed)
// en `beoordelingen` (status per bankje). Voor nu staat alles lokaal op de iPhone.

/// In welke fase een bankje zit.
enum KeurStatus: String, Codable {
    case nieuw           // nog geen stemmen
    case stemmen         // er zijn stemmen, maar nog niet genoeg
    case inBeoordeling   // genoeg stemmen; de eindbeoordeling loopt
    case goedgekeurd
    case afgekeurd
}

/// Eén stem van één gebruiker op één bankje. Per bankje en gebruiker bestaat maximaal één stem.
struct Stem: Codable, Identifiable, Hashable {
    var benchID: String
    var userID: String
    var goed: Bool          // true = "Goed bankje", false = "Geen goed bankje"
    var date: Date

    /// Eén stem per bankje per gebruiker.
    var id: String { "\(benchID)|\(userID)" }
}

/// De uitkomst van de eindbeoordeling.
struct Oordeel: Codable, Hashable {
    var goedgekeurd: Bool
    var reden: String       // korte uitleg, bijv. "80% vond dit een goed bankje"
}

/// De status van één bankje (in Supabase: een rij in `beoordelingen`).
struct KeurRecord: Codable, Hashable {
    var benchID: String
    var status: KeurStatus
    var oordeel: Oordeel?   // pas gevuld als de eindbeoordeling klaar is
    var updatedAt: Date
}

/// Alles wat bewaard wordt.
struct KeurData: Codable {
    var userID: String = UUID().uuidString   // lokale gebruiker; later het account uit Supabase
    var stemmen: [Stem] = []
    var records: [String: KeurRecord] = [:]  // bankje-ID -> status
}

/// Waar de keurgegevens bewaard worden.
/// Nu: een bestand op de iPhone. Later: een Supabase-versie die ditzelfde protocol volgt.
protocol KeurOpslag {
    func laad() -> KeurData
    func bewaar(_ data: KeurData)
}

/// Bewaart de keurgegevens in een JSON-bestand op de iPhone.
struct LokaleKeurOpslag: KeurOpslag {
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("keuren.json")
    }

    func laad() -> KeurData {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(KeurData.self, from: data) else {
            return KeurData()
        }
        return decoded
    }

    func bewaar(_ data: KeurData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
