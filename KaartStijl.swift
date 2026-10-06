import SwiftUI
import MapKit

/// ─────────────────────────────────────────────────────────────
///  KAARTSTIJL: hier staat ALLES over hoe de kaart eruitziet.
///  Wil je later kleuren, groottes of de stijl aanpassen?
///  Verander dan alleen de waarden in dit bestand.
/// ─────────────────────────────────────────────────────────────
enum KaartStijl {

    // MARK: Kleuren (de kleurnamen zelf staan in Theme.swift)
    static let bankjeKleur      = Color.leaf     // stipje van een bankje uit OpenStreetMap
    static let eigenBankjeKleur = Color.wood     // stipje van een zelf toegevoegd bankje
    static let randKleur        = Color.surface  // witte rand om een stipje
    static let icoonKleur       = Color.surface  // bankje-icoontje in het stipje
    static let knopAchtergrond  = Color.surface  // achtergrond van de knop "naar mijn locatie"
    static let knopIcoonKleur   = Color.leaf     // pijltje in die knop

    // MARK: Groottes (in punten)
    static let stipGrootte: CGFloat              = 28
    static let geselecteerdeStipGrootte: CGFloat = 38
    static let icoonGrootte: CGFloat             = 13
    static let geselecteerdIcoonGrootte: CGFloat = 17
    static let randDikte: CGFloat                = 2.5
    static let locatieKnopGrootte: CGFloat       = 48

    // MARK: Clusters (bolletje met een getal als bankjes dicht bij elkaar staan)
    static let clusterKleur      = bankjeKleur   // zelfde groen als een bankje
    static let clusterTekstKleur = Color.surface // kleur van het getal
    static let clusterGrootte: CGFloat      = 38 // bolletje met 2 t/m 9 bankjes
    static let clusterGrootteGroot: CGFloat = 46 // bolletje met 10 of meer bankjes
    static let clusterTekstGrootte: CGFloat = 16
    /// Bankjes die op het scherm dichter dan dit (in punten) bij elkaar staan, worden samengevoegd.
    static let clusterAfstand: CGFloat = 44
    /// Is de kaart zo ver ingezoomd (hoogte van het scherm in meters), dan staat alles los.
    static let clusterUitBijMeters: Double = 150
    /// Hoe ruim er wordt ingezoomd als je op een cluster tikt (groter = minder ver inzoomen).
    static let clusterZoomRuimte: Double = 2.2

    // MARK: Laad-indicator (klein pilletje bovenaan terwijl bankjes laden)
    static let laadAchtergrond  = Color.surface
    static let laadTekstKleur   = Color.ink
    static let laadTekstGrootte: CGFloat = 13

    // MARK: Bankjes laden (OpenStreetMap)
    /// Zoveel kaarttegels worden tegelijk opgehaald.
    static let maxTegelsTegelijk = 2
    /// Zoveel seconden wachten op één server voordat de volgende erbij wordt gevraagd.
    static let serverStaffelSeconden: Double = 3

    // MARK: Stijl
    static let bankjeIcoon = "chair.lounge.fill"   // SF Symbol-naam
    static let locatieIcoon = "location.fill"
    static let schaduw: Double = 0.25              // 0 = geen schaduw, 1 = heel donker
    /// Het kaarttype. Alternatieven: .standard, .imagery (satelliet), .hybrid
    static var kaartType: MapStyle { .standard(pointsOfInterest: .excludingAll) }

    // MARK: Startpositie en zoom
    /// Waar de kaart begint zolang je locatie nog niet bekend is (Amersfoort).
    static let startRegio = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.1561, longitude: 5.3878),
        latitudinalMeters: 3000, longitudinalMeters: 3000)
    /// Hoe ver ingezoomd (in meters) als de kaart naar jou toe springt.
    static let zoomOpJezelf: CLLocationDistance = 1000
    /// Hoe ver ingezoomd (in meters) als je een bankje kiest.
    static let zoomOpBankje: CLLocationDistance = 600
}
