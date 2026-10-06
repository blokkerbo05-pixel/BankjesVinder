import UIKit

/// Alle trillingen (haptics) van de app lopen hierdoor, zodat één schakelaar in Instellingen ze aan of uit zet.
enum Haptiek {
    /// Sleutel waaronder de keuze op de iPhone bewaard wordt (ook gebruikt door de schakelaar in Instellingen).
    static let sleutel = "trillingenAan"

    /// Staan trillingen aan? Standaard: ja.
    static var aan: Bool {
        UserDefaults.standard.object(forKey: sleutel) as? Bool ?? true
    }

    /// Een lichte tik (bijv. een keuze maken).
    static func licht() {
        guard aan else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Een zachte tik (bijv. een bankje of cluster kiezen).
    static func zacht() {
        guard aan else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Een kleine selectie-tik (bijv. een thema kiezen).
    static func selectie() {
        guard aan else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
