import Foundation

/// ─────────────────────────────────────────────────────────────
///  BINNENKORT: de lijst met toekomstige functies in Instellingen.
///  Wil je er een toevoegen, weghalen of een andere naam geven?
///  Pas dan alleen deze lijst aan. Het icoon is een SF Symbol-naam.
/// ─────────────────────────────────────────────────────────────
struct BinnenkortItem: Identifiable {
    let titel: String
    let icoon: String
    var id: String { titel }
}

enum Binnenkort {
    static let items: [BinnenkortItem] = [
        BinnenkortItem(titel: "Delen met vrienden", icoon: "person.2")
    ]
}
