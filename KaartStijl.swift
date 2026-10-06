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
    static let toevoegKnopKleur = Color.wood     // plusje (en dun randje) van de knop "bankje toevoegen"

    // MARK: Groottes (in punten)
    static let stipGrootte: CGFloat              = 28
    static let geselecteerdeStipGrootte: CGFloat = 38
    static let icoonGrootte: CGFloat             = 13
    static let geselecteerdIcoonGrootte: CGFloat = 17
    static let randDikte: CGFloat                = 2.5
    static let locatieKnopGrootte: CGFloat       = 48
    static let toevoegKnopGrootte: CGFloat       = 40   // rond plusknopje boven de locatieknop

    // MARK: Clusters (bolletje met een getal als bankjes dicht bij elkaar staan)
    static let clusterKleur      = bankjeKleur   // zelfde groen als een bankje
    static let clusterTekstKleur = Color.surface // kleur van het getal
    static let clusterGrootte: CGFloat      = 38 // bolletje met 2 t/m 9 bankjes
    static let clusterGrootteGroot: CGFloat = 46 // bolletje met 10 of meer bankjes
    static let clusterTekstGrootte: CGFloat = 16
    /// Bankjes die op het scherm dichter dan dit (in punten) bij elkaar staan, worden samengevoegd.
    static let clusterAfstand: CGFloat = 44
    /// Tik op een cluster: de kaart zoomt nooit verder in dan dit (hoogte van het scherm in meters).
    static let clusterMaxInzoomMeters: Double = 200
    /// Is de kaart zo ver ingezoomd (hoogte van het scherm in meters), dan staat alles los,
    /// ook als bankjes heel dicht bij elkaar staan. Iets ruimer dan de maximale inzoom hierboven.
    static let clusterUitBijMeters: Double = clusterMaxInzoomMeters * 1.15
    /// Nooit meer dan dit aantal speldjes + bolletjes tegelijk tekenen (ver uitgezoomd wordt er dan ruimer samengevoegd).
    static let maxZichtbareBolletjes = 60
    /// Hoe ruim er wordt ingezoomd als je op een cluster tikt (groter = minder ver inzoomen).
    static let clusterZoomRuimte: Double = 2.2

    // MARK: Laad-indicator (klein pilletje bovenaan terwijl bankjes laden)
    static let laadAchtergrond  = Color.surface
    static let laadTekstKleur   = Color.ink
    static let laadTekstGrootte: CGFloat = 13

    // MARK: Bankjes laden (OpenStreetMap)
    /// Automatisch laden alleen als de kaart minder dan dit (hoogte in meters) toont. Verder uitgezoomd: knop.
    static let autoLaadMaxMeters: Double = 3000
    /// Is het gebied groter dan dit aantal tegels, dan vragen we om verder in te zoomen.
    static let maxTegelsPerGebied = 12
    static let gebiedKnopIcoon = "arrow.down.circle"      // icoon van "Laad bankjes in dit gebied"
    static let inzoomMeldingIcoon = "plus.magnifyingglass"
    /// Zoveel kaarttegels worden tegelijk opgehaald.
    static let maxTegelsTegelijk = 2
    /// Zoveel seconden wachten op één server voordat de volgende erbij wordt gevraagd.
    static let serverStaffelSeconden: Double = 3

    // MARK: "Dichtbij"-paneel onderaan de kaart (compact en halfdoorzichtig)
    static let dichtbijPaneelAchtergrond: Material = .ultraThinMaterial   // kaart schemert erdoorheen
    static let dichtbijTegelAchtergrond = Color.surface.opacity(0.55)
    static let dichtbijTegelRand        = Color.line
    static let dichtbijTegelBreedte: CGFloat    = 128
    static let dichtbijTegelPadding: CGFloat    = 8
    static let dichtbijTegelHoek: CGFloat       = 10
    static let dichtbijNaamGrootte: CGFloat     = 12   // naam van het bankje
    static let dichtbijInfoGrootte: CGFloat     = 11   // afstand en looptijd
    static let dichtbijKopGrootte: CGFloat      = 11   // het woord DICHTBIJ
    static let dichtbijPaneelPadding: CGFloat   = 6    // ruimte boven en onder in het paneel

    // MARK: Keuren (de Keuren-tab met kaarten)
    static let keurKaartAchtergrond = Color.surface
    static let keurKaartRand        = Color.line
    static let keurKaartHoek: CGFloat           = 22
    static let keurAfbeeldingHoogte: CGFloat    = 240   // kaartbeeld of foto bovenaan de kaart
    static let keurAfbeeldingPlaceholder        = Color.leafSoft
    static let keurGoedKleur                    = Color.leaf     // "Goed bankje"
    static let keurSlechtKleur                  = Color.danger   // "Geen goed bankje"
    static let keurOngedaanKleur                = Color.muted    // knop "ongedaan maken"
    static let keurKnopGrootte: CGFloat         = 62    // de grote ronde knoppen (goed / niet goed)
    static let keurKleineKnopGrootte: CGFloat   = 46    // de kleine knop (ongedaan maken)
    static let keurDrempelWeg: CGFloat         = 110    // zo ver (in punten) slepen en de kaart vliegt weg
    static let keurDraaiHoek: Double           = 14     // graden dat de kaart meedraait bij de drempel
    static let keurWegvliegAfstand: CGFloat    = 650    // hoe ver de kaart wegvliegt
    static let keurWegvliegSeconden: Double    = 0.25
    static let keurStempelGrootte: CGFloat     = 22     // tekst van de stempel (GOED BANKJE / GEEN GOED BANKJE)
    static let keurStempelRand: CGFloat        = 3
    static let keurMaxKaarten                   = 25    // zoveel bankjes tegelijk in de stapel
    static let keurKaartenZichtbaar             = 3     // zoveel kaarten zie je (de rest zit eronder)

    // MARK: Opslag op de iPhone (houdt de app snel)
    /// Bewaarde tegels ouder dan dit aantal dagen worden bij het starten verwijderd.
    static let tegelMaxDagen: Double = 30
    /// Maximaal zoveel tegels bewaren; de oudste gaan eerst weg.
    static let maxBewaardeTegels = 200
    /// De lijst "Dichtbij" kijkt alleen naar bankjes binnen deze afstand (in meters).
    static let dichtbijStraal: CLLocationDistance = 3000

    // MARK: Stijl
    static let bankjeIcoon = "chair.lounge.fill"   // SF Symbol-naam
    static let locatieIcoon = "location.fill"
    static let toevoegIcoon = "plus"
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
