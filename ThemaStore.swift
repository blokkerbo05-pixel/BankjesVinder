import SwiftUI

/// Licht, donker of automatisch (zoals de iPhone zelf).
enum Weergave: String, CaseIterable, Identifiable {
    case licht, donker, automatisch

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .licht: return "Licht"
        case .donker: return "Donker"
        case .automatisch: return "Automatisch"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .licht: return .light
        case .donker: return .dark
        case .automatisch: return nil
        }
    }
}

/// Onthoudt welk thema en welke weergave gekozen zijn (bewaard op de iPhone).
@MainActor
final class ThemaStore: ObservableObject {
    private static let themaSleutel = "gekozenThema"
    private static let weergaveSleutel = "gekozenWeergave"

    @Published var themaID: String {
        didSet {
            UserDefaults.standard.set(themaID, forKey: Self.themaSleutel)
            Themas.huidig = Themas.thema(met: themaID)
        }
    }

    @Published var weergave: Weergave {
        didSet { UserDefaults.standard.set(weergave.rawValue, forKey: Self.weergaveSleutel) }
    }

    init() {
        let bewaardThema = UserDefaults.standard.string(forKey: Self.themaSleutel) ?? Themas.bos.id
        themaID = Themas.thema(met: bewaardThema).id
        weergave = Weergave(rawValue: UserDefaults.standard.string(forKey: Self.weergaveSleutel) ?? "") ?? .automatisch
        Themas.huidig = Themas.thema(met: themaID)
    }
}
