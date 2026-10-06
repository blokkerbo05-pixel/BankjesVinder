import Foundation
import Supabase

/// Een stem zoals de database die kent (tabel `votes`).
private struct StemRij: Codable {
    var benchID: String
    var goed: Bool

    enum CodingKeys: String, CodingKey {
        case goed
        case benchID = "bench_id"
    }
}

/// Houdt stemmen en statussen van de bankjes bij. De stemmen staan online (Supabase);
/// de database rekent zelf de status uit. Op de iPhone blijft een kopie bewaard, zodat je ook zonder internet iets ziet.
@MainActor
final class KeurStore: ObservableObject {
    @Published private(set) var data: KeurData
    /// Hoeveel stemmen elk bankje in totaal heeft (van alle gebruikers, uit de database).
    @Published private(set) var serverAantal: [String: Int] = [:]

    private let opslag: KeurOpslag
    /// Wordt door de app ingesteld; hiermee tonen we meldingen (bijv. "Geen internet").
    weak var account: AccountStore?

    private var client: SupabaseClient { SupabaseConfig.client }

    init(opslag: KeurOpslag = LokaleKeurOpslag()) {
        self.opslag = opslag
        data = opslag.laad()
    }

    var userID: String { data.userID }

    /// In de database staan bankje-ID's in kleine letters.
    private func sleutel(_ benchID: String) -> String { benchID.lowercased() }

    // MARK: Opvragen

    /// Status van een bankje. Zonder gegevens is het `nieuw`.
    func status(of benchID: String) -> KeurStatus {
        data.records[sleutel(benchID)]?.status ?? .nieuw
    }

    /// De uitkomst van de eindbeoordeling, als die er is.
    func oordeel(of benchID: String) -> Oordeel? {
        data.records[sleutel(benchID)]?.oordeel
    }

    /// Mijn eigen stemmen op dit bankje.
    func stemmen(for benchID: String) -> [Stem] {
        data.stemmen.filter { $0.benchID == sleutel(benchID) }
    }

    /// Het totaal aantal stemmen op dit bankje (van iedereen).
    func aantalStemmen(for benchID: String) -> Int {
        serverAantal[sleutel(benchID)] ?? stemmen(for: benchID).count
    }

    /// Heeft deze gebruiker al gestemd op dit bankje?
    func heeftGestemd(op benchID: String) -> Bool {
        data.stemmen.contains { $0.benchID == sleutel(benchID) && $0.userID == data.userID }
    }

    /// Is de eindbeoordeling gedaan? Dan hoeft er niet meer gestemd te worden.
    func isBeoordeeld(_ benchID: String) -> Bool {
        switch status(of: benchID) {
        case .goedgekeurd, .afgekeurd: return true
        case .nieuw, .stemmen, .inBeoordeling: return false
        }
    }

    // MARK: Stemmen

    /// Brengt de stem van deze gebruiker uit (een eerdere stem op hetzelfde bankje wordt vervangen).
    func stem(op bench: Bench, goed: Bool) {
        let key = sleutel(bench.id)
        let eerder = data.stemmen.first { $0.benchID == key && $0.userID == data.userID }
        data.stemmen.removeAll { $0.benchID == key && $0.userID == data.userID }
        data.stemmen.append(Stem(benchID: key, userID: data.userID, goed: goed, date: Date()))
        if status(of: key) == .nieuw {
            data.records[key] = KeurRecord(benchID: key, status: .stemmen, oordeel: nil, updatedAt: Date())
        }
        opslag.bewaar(data)

        Task {
            do {
                try await client.from("votes")
                    .upsert(StemRij(benchID: key, goed: goed), onConflict: "bench_id,user_id")
                    .execute()
                await ververs(bankje: key)
            } catch {
                // Het lukte niet: de stem terugdraaien en het melden.
                data.stemmen.removeAll { $0.benchID == key && $0.userID == data.userID }
                if let eerder { data.stemmen.append(eerder) }
                opslag.bewaar(data)
                account?.melding = Netwerk.melding(voor: error, standaard: "Je stem opslaan lukte niet. Probeer het opnieuw.")
            }
        }
    }

    /// Haalt de laatste stem van deze gebruiker terug. Geeft het (kleine-letters-)ID van dat bankje terug.
    @discardableResult
    func maakLaatsteStemOngedaan() -> String? {
        let eigen = data.stemmen.filter { $0.userID == data.userID }
        guard let laatste = eigen.max(by: { $0.date < $1.date }) else { return nil }
        guard Netwerk.gedeeld.isOnline else {
            account?.melding = Netwerk.geenInternet
            return nil
        }
        data.stemmen.removeAll { $0.id == laatste.id }
        opslag.bewaar(data)

        Task {
            do {
                try await client.from("votes").delete().eq("bench_id", value: laatste.benchID).execute()
                await ververs(bankje: laatste.benchID)
            } catch {
                data.stemmen.append(laatste)
                opslag.bewaar(data)
                account?.melding = Netwerk.melding(voor: error, standaard: "Ongedaan maken lukte niet. Probeer het opnieuw.")
            }
        }
        return laatste.benchID
    }

    /// Kan er een stem ongedaan gemaakt worden?
    var kanOngedaanMaken: Bool {
        data.stemmen.contains { $0.userID == data.userID }
    }

    // MARK: Online ophalen

    /// Wordt aangeroepen als je inlogt of uitlogt.
    func accountGewijzigd(_ gebruiker: UUID?) {
        if let gebruiker {
            data.userID = gebruiker.uuidString.lowercased()
        } else {
            data.stemmen = []   // stemmen zijn van een account
        }
        opslag.bewaar(data)
        Task { await ververs() }
    }

    private func record(van rij: StatusRij) -> KeurRecord {
        let status: KeurStatus
        var oordeel: Oordeel?
        switch rij.status {
        case "goedgekeurd":
            status = .goedgekeurd
            oordeel = Oordeel(goedgekeurd: true, reden: rij.reden ?? "")
        case "afgekeurd":
            status = .afgekeurd
            oordeel = Oordeel(goedgekeurd: false, reden: rij.reden ?? "")
        default:
            status = .stemmen
        }
        return KeurRecord(benchID: rij.benchID, status: status, oordeel: oordeel, updatedAt: Date())
    }

    /// Haalt alle statussen en jouw eigen stemmen op. Mislukt het, dan blijft de bewaarde kopie staan.
    func ververs() async {
        do {
            let rijen = try await ServerBankjes.haalStatussenOp()
            var records: [String: KeurRecord] = [:]
            var aantallen: [String: Int] = [:]
            for rij in rijen {
                records[rij.benchID] = record(van: rij)
                aantallen[rij.benchID] = rij.aantalStemmen
            }
            data.records = records
            serverAantal = aantallen

            if account?.isIngelogd == true {
                let eigen: [StemRij] = try await client.from("votes").select().execute().value
                data.stemmen = eigen.map { Stem(benchID: $0.benchID, userID: data.userID, goed: $0.goed, date: Date()) }
            }
            opslag.bewaar(data)
        } catch {
            // Stil: de bewaarde gegevens blijven staan.
        }
    }

    /// Haalt alleen de status van één bankje op (na een stem).
    private func ververs(bankje key: String) async {
        guard let rijen: [StatusRij] = try? await client.from("keur_status").select()
            .eq("bench_id", value: key).execute().value else { return }
        if let rij = rijen.first {
            data.records[key] = record(van: rij)
            serverAantal[key] = rij.aantalStemmen
        } else {
            data.records[key] = nil
            serverAantal[key] = nil
        }
        opslag.bewaar(data)
    }
}
