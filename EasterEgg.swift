import SwiftUI
import UIKit

// Een kleine verrassing in de lijst-tab. Alle waarden staan hier, bewust nergens anders.

/// De waarden van de verrassing. Wil je iets aanpassen? Verander dan het getal hier.
private enum Verrassing {
    static let fotoNaam = "eran"            // bestand eran.jpg in de app
    static let aantalTikken = 5             // zoveel tikken ...
    static let tikVenster: TimeInterval = 2 // ... binnen zoveel seconden
    static let toonSeconden: TimeInterval = 2   // zo lang blijft de foto staan
    static let fadeIn: Double = 0.15
    static let fadeUit: Double = 0.4
    static let achtergrond = Color.black.opacity(0.92)
    static let titelLetter = Font.display(36)   // moet gelijk zijn aan de titel in de lijst
}

/// Houdt bij of de foto nu getoond wordt en telt de tikken.
@MainActor
final class VerrassingStatus: ObservableObject {
    @Published fileprivate(set) var toon = false
    private var tikken: [Date] = []

    fileprivate func registreerTik() {
        guard !toon else { return }
        let nu = Date()
        tikken = tikken.filter { nu.timeIntervalSince($0) <= Verrassing.tikVenster }
        tikken.append(nu)
        if tikken.count >= Verrassing.aantalTikken {
            tikken = []
            toonFoto()
        }
    }

    private func toonFoto() {
        Haptiek.licht()
        withAnimation(.easeIn(duration: Verrassing.fadeIn)) { toon = true }
        Task {
            try? await Task.sleep(nanoseconds: UInt64((Verrassing.fadeIn + Verrassing.toonSeconden) * 1_000_000_000))
            withAnimation(.easeOut(duration: Verrassing.fadeUit)) { toon = false }
        }
    }
}

/// Legt een onzichtbare, aantikbare "e" over de titel (de e in "vinder"); de titel zelf blijft precies hetzelfde.
private struct VerrassingTik: ViewModifier {
    @EnvironmentObject var status: VerrassingStatus

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            HStack(spacing: 0) {
                Text("Bankjesvind")
                    .font(Verrassing.titelLetter)
                    .foregroundStyle(.clear)
                    .allowsHitTesting(false)
                Text("e")
                    .font(Verrassing.titelLetter)
                    .foregroundStyle(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { status.registreerTik() }
                Spacer(minLength: 0)
            }
            .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Zet dit op de titel "Bankjesvinder".
    func verrassing() -> some View { modifier(VerrassingTik()) }
}

/// De foto over het hele scherm (donkere achtergrond, fade-in en fade-out).
struct VerrassingOverlay: View {
    @ObservedObject var status: VerrassingStatus

    private static let foto: UIImage? = Bundle.main
        .path(forResource: Verrassing.fotoNaam, ofType: "jpg")
        .flatMap { UIImage(contentsOfFile: $0) }

    var body: some View {
        ZStack {
            if status.toon, let foto = Self.foto {
                ZStack {
                    Verrassing.achtergrond.ignoresSafeArea()
                    Image(uiImage: foto)
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                }
                .transition(.opacity)
            }
        }
        .allowsHitTesting(status.toon)
    }
}
