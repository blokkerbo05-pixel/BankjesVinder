import Foundation
import CoreLocation

/// ─────────────────────────────────────────────────────────────
///  KEURINSTELLINGEN: alle instellingen van het keuren staan hier.
///  Wil je iets aanpassen (aantal stemmen, drempel, testmodus)?
///  Verander dan alleen de waarden in dit bestand.
///  (Hoe de Keuren-tab eruitziet staat in KaartStijl.swift.)
/// ─────────────────────────────────────────────────────────────
enum KeurInstellingen {

    /// Zoveel stemmen heeft een bankje nodig voor de eindbeoordeling.
    static let aantalStemmenNodig = 5

    /// Aandeel "goed bankje" (0 t/m 1) waarbij het bankje wordt goedgekeurd. 0,7 = 70%.
    static let goedkeurDrempel = 0.7

    /// Testmodus: 1 stem is genoeg (handig zolang jij de enige gebruiker bent).
    /// Zet op `false` als er meer gebruikers zijn.
    static let testModus = true

    /// Zoveel stemmen zijn echt nodig, rekening houdend met de testmodus.
    static var stemmenNodig: Int { testModus ? 1 : aantalStemmenNodig }

    /// Laat afgekeurde bankjes ook op de kaart zien? Zet op `false` om ze te verbergen.
    static let toonAfgekeurdeBankjes = true

    /// In de Keuren-tab komen alleen bankjes binnen deze afstand (in meters) van jou.
    static let keurStraalMeters: CLLocationDistance = 3000

    // MARK: Kenmerken van bankjes (geen stemmen, maar wel een instelling)

    /// Een bankje uit OpenStreetMap krijgt automatisch het kenmerk "Prullenbak"
    /// als er binnen deze afstand (in meters) een prullenbak staat.
    static let prullenbakAfstandMeters: Double = 20
}
