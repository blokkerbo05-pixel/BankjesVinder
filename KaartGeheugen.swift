import MapKit

/// Onthoudt waar de kaart stond, zodat de kaart niet terugspringt als de app van thema wisselt
/// (dan worden de schermen één keer opnieuw opgebouwd). Wijzigingen hier verversen niets.
final class KaartGeheugen {
    var regio: MKCoordinateRegion?
    var gecentreerd = false
}
