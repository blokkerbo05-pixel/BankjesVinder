import SwiftUI
import UIKit

/// ─────────────────────────────────────────────────────────────
///  ANIMATIES: alle tijden en veerwaarden van de app staan hier.
///  Staat "Beperk beweging" (Reduce Motion) aan op de iPhone, dan
///  vervalt de beweging: bewegende animaties zijn dan uit en overgangen
///  zijn alleen een rustige fade.
/// ─────────────────────────────────────────────────────────────
enum Animaties {

    // MARK: Waarden (pas hier aan)
    static let veerRespons = 0.38          // lager = sneller
    static let veerDemping = 0.78          // lager = meer veer
    static let opveerRespons = 0.42        // het speldje dat opveert
    static let opveerDemping = 0.55
    static let terugveerRespons = 0.35     // kaart die terugveert (Keuren)
    static let terugveerDemping = 0.6
    static let fadeSeconden = 0.22
    static let indrukSeconden = 0.12
    static let indrukSchaal: CGFloat = 0.94    // zo klein wordt een knop als je hem indrukt
    static let verschijnSchaal: CGFloat = 0.6  // speldjes en clusters beginnen zo klein
    static let hartRespons = 0.28          // het hartje dat opveert
    static let hartDemping = 0.4
    static let hartSchaal: CGFloat = 1.35  // zo groot wordt het hartje even
    static let wegvliegSeconden = KaartStijl.keurWegvliegSeconden

    // MARK: Beperk beweging
    static var beperkt: Bool { UIAccessibility.isReduceMotionEnabled }

    // MARK: Animaties (nil = geen animatie)
    /// Zachte veer voor panelen, kaartjes en clusters.
    static var veer: Animation? {
        beperkt ? nil : .spring(response: veerRespons, dampingFraction: veerDemping)
    }
    /// Speldje dat opveert bij selecteren.
    static var opveer: Animation? {
        beperkt ? nil : .spring(response: opveerRespons, dampingFraction: opveerDemping)
    }
    /// Kaart die terugveert als je loslaat voor de drempel.
    static var terugveer: Animation? {
        beperkt ? nil : .spring(response: terugveerRespons, dampingFraction: terugveerDemping)
    }
    /// Hartje dat opveert bij aantikken.
    static var hartVeer: Animation? {
        beperkt ? nil : .spring(response: hartRespons, dampingFraction: hartDemping)
    }
    /// Kaart die wegvliegt.
    static var wegvlieg: Animation? {
        beperkt ? nil : .easeIn(duration: wegvliegSeconden)
    }
    /// Pure fade (blijft ook bij Beperk beweging, want dat is geen beweging).
    static var fade: Animation { .easeInOut(duration: fadeSeconden) }
    /// Een knop die indeukt.
    static var indruk: Animation? {
        beperkt ? nil : .easeOut(duration: indrukSeconden)
    }

    /// Hoe lang er gewacht moet worden voor een wegvliegende kaart klaar is.
    static var wegvliegWachttijd: Double { beperkt ? 0 : wegvliegSeconden }

    // MARK: Overgangen
    /// Paneel dat van onderen in schuift (of alleen fade bij Beperk beweging).
    static var schuifOnder: AnyTransition {
        beperkt ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
    /// Klein element dat zacht groeit en infade.
    static var verschijn: AnyTransition {
        beperkt ? .opacity : .scale(scale: verschijnSchaal).combined(with: .opacity)
    }
}
