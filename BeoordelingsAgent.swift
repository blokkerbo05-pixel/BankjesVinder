import Foundation

/// De eindbeoordeling van een bankje, nadat genoeg mensen hebben gestemd.
///
/// Dit is een inplugbaar onderdeel: alles wat dit protocol volgt kan de beoordeling doen.
/// Nu is dat de `RegelAgent` (een simpele rekenregel). Later kan hier een echte AI-agent komen.
protocol BeoordelingsAgent {
    /// Krijgt het bankje en alle stemmen en geeft een oordeel (goedgekeurd of afgekeurd, met een korte reden).
    func beoordeel(_ bench: Bench, stemmen: [Stem]) async -> Oordeel
}

/// Tijdelijke beoordelaar: goedgekeurd als het aandeel "goed" minstens de drempel haalt.
struct RegelAgent: BeoordelingsAgent {
    func beoordeel(_ bench: Bench, stemmen: [Stem]) async -> Oordeel {
        guard !stemmen.isEmpty else {
            return Oordeel(goedgekeurd: false, reden: "Geen stemmen")
        }
        let goed = stemmen.filter(\.goed).count
        let aandeel = Double(goed) / Double(stemmen.count)
        let procent = Int((aandeel * 100).rounded())
        if aandeel >= KeurInstellingen.goedkeurDrempel {
            return Oordeel(goedgekeurd: true, reden: "\(procent)% vond dit een goed bankje (\(goed) van \(stemmen.count))")
        }
        return Oordeel(goedgekeurd: false, reden: "Slechts \(procent)% vond dit een goed bankje (\(goed) van \(stemmen.count))")
    }
}

/// ─────────────────────────────────────────────────────────────
///  HIER KOMT LATER JE EIGEN AI-AGENT.
///  1. Maak een type dat `BeoordelingsAgent` volgt (bijv. `MijnAIAgent`).
///  2. Vervang hieronder `RegelAgent()` door `MijnAIAgent()`.
///  Verder hoeft er nergens iets te veranderen.
/// ─────────────────────────────────────────────────────────────
enum KeurAgent {
    static let actief: BeoordelingsAgent = RegelAgent()
}
