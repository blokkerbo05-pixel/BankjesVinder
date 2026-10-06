import Foundation

/// Houdt stemmen en statussen van de bankjes bij.
@MainActor
final class KeurStore: ObservableObject {
    @Published private(set) var data: KeurData

    private let opslag: KeurOpslag
    private let agent: BeoordelingsAgent

    /// Zoekt een bankje op via zijn ID (wordt door de app ingesteld). De agent heeft het bankje zelf nodig.
    var zoekBankje: (String) -> Bench? = { _ in nil }

    init(opslag: KeurOpslag = LokaleKeurOpslag(), agent: BeoordelingsAgent = KeurAgent.actief) {
        self.opslag = opslag
        self.agent = agent
        let geladen = opslag.laad()
        data = geladen
        opslag.bewaar(geladen)   // bewaart meteen het gebruikers-ID als dat nieuw is
    }

    var userID: String { data.userID }

    // MARK: Opvragen

    /// Status van een bankje. Zonder gegevens is het `nieuw`.
    func status(of benchID: String) -> KeurStatus {
        data.records[benchID]?.status ?? .nieuw
    }

    /// De uitkomst van de eindbeoordeling, als die er is.
    func oordeel(of benchID: String) -> Oordeel? {
        data.records[benchID]?.oordeel
    }

    func stemmen(for benchID: String) -> [Stem] {
        data.stemmen.filter { $0.benchID == benchID }
    }

    func aantalStemmen(for benchID: String) -> Int {
        stemmen(for: benchID).count
    }

    /// Heeft deze gebruiker al gestemd op dit bankje?
    func heeftGestemd(op benchID: String) -> Bool {
        data.stemmen.contains { $0.benchID == benchID && $0.userID == data.userID }
    }

    /// Is de eindbeoordeling gedaan (of bezig)? Dan hoeft er niet meer gestemd te worden.
    func isBeoordeeld(_ benchID: String) -> Bool {
        switch status(of: benchID) {
        case .inBeoordeling, .goedgekeurd, .afgekeurd: return true
        case .nieuw, .stemmen: return false
        }
    }

    // MARK: Stemmen

    /// Brengt de stem van deze gebruiker uit (een eerdere stem op hetzelfde bankje wordt vervangen).
    func stem(op bench: Bench, goed: Bool) {
        data.stemmen.removeAll { $0.benchID == bench.id && $0.userID == data.userID }
        data.stemmen.append(Stem(benchID: bench.id, userID: data.userID, goed: goed, date: Date()))
        herbereken(bench.id)
    }

    /// Haalt de laatste stem van deze gebruiker terug. Geeft het bankje terug waar die stem op was.
    @discardableResult
    func maakLaatsteStemOngedaan() -> String? {
        let eigen = data.stemmen.filter { $0.userID == data.userID }
        guard let laatste = eigen.max(by: { $0.date < $1.date }) else { return nil }
        data.stemmen.removeAll { $0.id == laatste.id }
        herbereken(laatste.benchID)
        return laatste.benchID
    }

    /// Kan er een stem ongedaan gemaakt worden?
    var kanOngedaanMaken: Bool {
        data.stemmen.contains { $0.userID == data.userID }
    }

    // MARK: Status

    /// Berekent de status van een bankje opnieuw na een wijziging in de stemmen.
    private func herbereken(_ benchID: String) {
        let aantal = aantalStemmen(for: benchID)
        if aantal == 0 {
            data.records[benchID] = nil   // terug naar "nieuw"
        } else if aantal >= KeurInstellingen.stemmenNodig {
            // Genoeg stemmen: eindbeoordeling door de agent.
            zet(benchID, status: .inBeoordeling, oordeel: nil)
            laatBeoordelen(benchID)
        } else {
            zet(benchID, status: .stemmen, oordeel: nil)
        }
        opslag.bewaar(data)
    }

    /// Vraagt de agent om het eindoordeel en zet de status daarna op goedgekeurd of afgekeurd.
    private func laatBeoordelen(_ benchID: String) {
        guard let bench = zoekBankje(benchID) else { return }   // bankje niet bekend: blijft 'inBeoordeling'
        let stemmen = self.stemmen(for: benchID)
        Task {
            let oordeel = await agent.beoordeel(bench, stemmen: stemmen)
            // Alleen toepassen als er intussen niets veranderd is aan de stemmen.
            guard status(of: benchID) == .inBeoordeling, self.stemmen(for: benchID) == stemmen else { return }
            zet(benchID, status: oordeel.goedgekeurd ? .goedgekeurd : .afgekeurd, oordeel: oordeel)
        }
    }

    func zet(_ benchID: String, status: KeurStatus, oordeel: Oordeel?) {
        data.records[benchID] = KeurRecord(benchID: benchID, status: status, oordeel: oordeel, updatedAt: Date())
        opslag.bewaar(data)
    }
}
