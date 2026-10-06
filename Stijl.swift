import SwiftUI

// Gedeelde stijlonderdelen: knopstijl die indeukt, zwevende elementen en zachte schaduwen.
// De waarden zelf (hoeken, schaduwen, materiaal) staan in KaartStijl.swift.

/// Knopstijl: de knop deukt licht in als je hem indrukt (niet bij Beperk beweging).
struct IndrukStijl: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !Animaties.beperkt ? Animaties.indrukSchaal : 1)
            .animation(Animaties.indruk, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == IndrukStijl {
    static var indruk: IndrukStijl { IndrukStijl() }
}

extension View {
    /// Achtergrond voor zwevende elementen (knoppen, balken, pilletjes): doorzichtig materiaal, dun randje, zachte schaduw.
    func zwevendeAchtergrond<S: Shape>(_ vorm: S) -> some View {
        self
            .background(KaartStijl.zwevendMateriaal, in: vorm)
            .overlay(vorm.stroke(KaartStijl.zwevendRand, lineWidth: 1))
            .shadow(color: .black.opacity(KaartStijl.schaduwZachtOpacity),
                    radius: KaartStijl.schaduwZachtRadius, y: KaartStijl.schaduwZachtY)
    }

    /// Zachte schaduw voor kleine losse elementen.
    func zachteSchaduw() -> some View {
        shadow(color: .black.opacity(KaartStijl.schaduwZachtOpacity),
               radius: KaartStijl.schaduwZachtRadius, y: KaartStijl.schaduwZachtY)
    }

    /// Zachte schaduw voor grotere kaarten.
    func kaartSchaduw() -> some View {
        shadow(color: .black.opacity(KaartStijl.schaduwKaartOpacity),
               radius: KaartStijl.schaduwKaartRadius, y: KaartStijl.schaduwKaartY)
    }
}
