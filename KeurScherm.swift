import SwiftUI
import MapKit
import CoreLocation

/// De tab "Keuren": een stapel kaarten met bankjes in de buurt die jij mag beoordelen.
struct KeurScherm: View {
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var keur: KeurStore
    @EnvironmentObject var location: LocationManager

    /// De bankjes die nog gekeurd moeten worden; het eerste staat bovenaan.
    @State private var stapel: [Bench] = []
    /// Hoever de bovenste kaart op dit moment is versleept.
    @State private var slepen: CGSize = .zero
    @State private var vliegtWeg = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                if location.location == nil {
                    melding(icoon: "location.slash", titel: "Locatie nodig",
                            tekst: "Zet je locatie aan, dan laten we bankjes in de buurt zien om te keuren.")
                } else if stapel.isEmpty {
                    melding(icoon: "checkmark.seal", titel: "Alles in de buurt is gekeurd",
                            tekst: "Kom later terug, of loop een stukje verder voor nieuwe bankjes.")
                } else {
                    kaarten
                    knoppen
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .onAppear { refresh() }
        .onChange(of: store.all.count) { refresh() }
        .onChange(of: keur.data.stemmen.count) { refresh() }
    }

    // MARK: Onderdelen

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Keuren")
                .font(.display(30))
                .foregroundStyle(Color.ink)
            Text("Is dit een goed bankje?")
                .font(.system(size: 15))
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kaarten: some View {
        ZStack {
            // De bovenste kaart ligt voor; de volgende steken er een beetje onder uit.
            ForEach(Array(stapel.prefix(KaartStijl.keurKaartenZichtbaar).enumerated().reversed()), id: \.element.id) { item in
                let isBovenste = item.offset == 0
                KeurKaart(bench: item.element,
                          afstand: item.element.distance(from: location.location),
                          aantalStemmen: keur.aantalStemmen(for: item.element.id),
                          stempel: isBovenste ? voortgang : 0)
                    .scaleEffect(1 - 0.04 * CGFloat(item.offset))
                    .offset(x: isBovenste ? slepen.width : 0,
                            y: 12 * CGFloat(item.offset) + (isBovenste ? slepen.height * 0.3 : 0))
                    .rotationEffect(.degrees(isBovenste ? draaiing : 0))
                    .gesture(sleepGebaar, including: isBovenste ? .all : .none)
            }
        }
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity)
    }

    private var knoppen: some View {
        HStack(spacing: 28) {
            rondeKnop("xmark", kleur: KaartStijl.keurSlechtKleur, grootte: KaartStijl.keurKnopGrootte,
                      label: "Geen goed bankje") { vlieg(goed: false) }
            rondeKnop("arrow.uturn.backward", kleur: KaartStijl.keurOngedaanKleur, grootte: KaartStijl.keurKleineKnopGrootte,
                      label: "Laatste stem ongedaan maken") { maakOngedaan() }
                .opacity(keur.kanOngedaanMaken ? 1 : 0.35)
                .disabled(!keur.kanOngedaanMaken)
            rondeKnop("checkmark", kleur: KaartStijl.keurGoedKleur, grootte: KaartStijl.keurKnopGrootte,
                      label: "Goed bankje") { vlieg(goed: true) }
        }
    }

    private func rondeKnop(_ icoon: String, kleur: Color, grootte: CGFloat, label: String, actie: @escaping () -> Void) -> some View {
        Button(action: actie) {
            Image(systemName: icoon)
                .font(.system(size: grootte * 0.4, weight: .bold))
                .foregroundStyle(kleur)
                .frame(width: grootte, height: grootte)
                .zwevendeAchtergrond(Circle())
                .overlay(Circle().stroke(kleur.opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(.indruk)
        .accessibilityLabel(label)
    }

    private func melding(icoon: String, titel: String, tekst: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icoon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.leaf)
            Text(titel)
                .font(.cardTitle(20))
                .foregroundStyle(Color.ink)
            Text(tekst)
                .font(.system(size: 15))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: Slepen en wegvliegen

    /// -1 (helemaal naar links) tot 1 (helemaal naar rechts); bij 1 is de drempel gehaald.
    private var voortgang: Double {
        max(-1, min(1, Double(slepen.width / KaartStijl.keurDrempelWeg)))
    }

    private var draaiing: Double { voortgang * KaartStijl.keurDraaiHoek }

    private var sleepGebaar: some Gesture {
        DragGesture()
            .onChanged { waarde in
                guard !vliegtWeg else { return }
                slepen = waarde.translation
            }
            .onEnded { waarde in
                guard !vliegtWeg else { return }
                if abs(waarde.translation.width) > KaartStijl.keurDrempelWeg {
                    vlieg(goed: waarde.translation.width > 0)
                } else {
                    // Niet ver genoeg: terugveren.
                    withAnimation(Animaties.terugveer) { slepen = .zero }
                }
            }
    }

    /// Laat de bovenste kaart wegvliegen (links of rechts) en brengt daarna de stem uit.
    private func vlieg(goed: Bool) {
        guard !vliegtWeg, !stapel.isEmpty else { return }
        vliegtWeg = true
        Haptiek.licht()
        withAnimation(Animaties.wegvlieg) {
            slepen = CGSize(width: goed ? KaartStijl.keurWegvliegAfstand : -KaartStijl.keurWegvliegAfstand,
                            height: slepen.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Animaties.wegvliegWachttijd) {
            stem(goed: goed)
            // De volgende kaart staat al klaar: zonder animatie terug naar het midden.
            var zonderAnimatie = Transaction()
            zonderAnimatie.disablesAnimations = true
            withTransaction(zonderAnimatie) { slepen = .zero }
            vliegtWeg = false
        }
    }

    // MARK: Acties

    private func stem(goed: Bool) {
        guard let bench = stapel.first else { return }
        keur.stem(op: bench, goed: goed)   // de stapel wordt daarna vanzelf ververst
    }

    private func maakOngedaan() {
        Haptiek.selectie()
        guard !vliegtWeg, let id = keur.maakLaatsteStemOngedaan(),
              let bench = store.all.first(where: { $0.id == id }) else { return }
        refresh(vooraan: bench)   // dat bankje komt weer bovenaan
    }

    /// Bouwt de stapel opnieuw op. Wat al in de stapel zat, behoudt zijn plek (de kaarten springen niet om).
    private func refresh(vooraan: Bench? = nil) {
        guard let here = location.location else {
            stapel = []
            return
        }
        let straal = KeurInstellingen.keurStraalMeters
        func geschikt(_ bench: Bench) -> Bool {
            guard let afstand = bench.distance(from: here), afstand <= straal else { return false }
            return !keur.heeftGestemd(op: bench.id) && !keur.isBeoordeeld(bench.id)
        }

        var nieuw = stapel.filter(geschikt)
        let alInStapel = Set(nieuw.map(\.id))
        let erbij = store.all
            .filter { !alInStapel.contains($0.id) && geschikt($0) }
            .sorted { ($0.distance(from: here) ?? .infinity) < ($1.distance(from: here) ?? .infinity) }
        nieuw.append(contentsOf: erbij)

        if let vooraan, geschikt(vooraan) {
            nieuw.removeAll { $0.id == vooraan.id }
            nieuw.insert(vooraan, at: 0)
        }
        stapel = Array(nieuw.prefix(KaartStijl.keurMaxKaarten))
    }
}

/// Eén kaart in de stapel: beeld, naam, afstand, kenmerken, notitie en aantal stemmen.
struct KeurKaart: View {
    let bench: Bench
    let afstand: CLLocationDistance?
    let aantalStemmen: Int
    /// -1 tot 1: hoe ver de kaart naar links (niet goed) of rechts (goed) is gesleept; bepaalt de stempel.
    var stempel: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            KaartBeeld(bench: bench)
                .frame(height: KaartStijl.keurAfbeeldingHoogte)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(bench.name)
                    .font(.cardTitle(22))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                if let afstand {
                    Text("\(formatDistance(afstand)) · \(walkingMinutes(afstand))")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color.muted)
                }
                if !bench.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(bench.tags, id: \.self) { TagPill(text: $0) }
                    }
                }
                if !bench.note.isEmpty {
                    Text(bench.note)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.ink)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Text("\(aantalStemmen) van \(KeurInstellingen.stemmenNodig) stemmen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(KaartStijl.keurKaartAchtergrond)
        .clipShape(RoundedRectangle(cornerRadius: KaartStijl.keurKaartHoek))
        .overlay(RoundedRectangle(cornerRadius: KaartStijl.keurKaartHoek).stroke(KaartStijl.keurKaartRand, lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            stempelLabel("GOED BANKJE", kleur: KaartStijl.keurGoedKleur, hoek: -14)
                .opacity(max(0, stempel))
        }
        .overlay(alignment: .topTrailing) {
            stempelLabel("GEEN GOED BANKJE", kleur: KaartStijl.keurSlechtKleur, hoek: 14)
                .opacity(max(0, -stempel))
        }
        .kaartSchaduw()
    }

    private func stempelLabel(_ tekst: String, kleur: Color, hoek: Double) -> some View {
        Text(tekst)
            .font(.system(size: KaartStijl.keurStempelGrootte, weight: .heavy))
            .tracking(1)
            .foregroundStyle(kleur)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.surface.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(kleur, lineWidth: KaartStijl.keurStempelRand))
            .rotationEffect(.degrees(hoek))
            .padding(22)
    }
}

/// Kaartbeeld van de plek van het bankje, met een speldje in het midden.
struct KaartBeeld: View {
    @EnvironmentObject var store: BenchStore
    let bench: Bench
    @State private var beeld: UIImage?
    @State private var foto: UIImage?

    var body: some View {
        ZStack {
            KaartStijl.keurAfbeeldingPlaceholder
            if let foto {
                // Eigen foto van het bankje, als die er is.
                Image(uiImage: foto)
                    .resizable()
                    .scaledToFill()
            } else if let beeld {
                Image(uiImage: beeld)
                    .resizable()
                    .scaledToFill()
                BenchPin(isOwn: bench.source == .eigen, isSelected: false)
            } else {
                ProgressView()
            }
        }
        .task(id: "\(bench.id)-\(store.fotoVersie)") {
            foto = bench.source == .eigen ? BankjesFotos.afbeelding(voor: bench.id) : nil
            if foto == nil {
                beeld = await KaartBeeldCache.shared.beeld(voor: bench)
            }
        }
    }
}

/// Maakt kaartbeelden (MKMapSnapshotter) en onthoudt ze, zodat ze niet steeds opnieuw gemaakt worden.
@MainActor
final class KaartBeeldCache {
    static let shared = KaartBeeldCache()
    private let cache = NSCache<NSString, UIImage>()

    func beeld(voor bench: Bench) async -> UIImage? {
        guard let coordinate = bench.coordinate else { return nil }
        let sleutel = bench.id as NSString
        if let bewaard = cache.object(forKey: sleutel) { return bewaard }

        let opties = MKMapSnapshotter.Options()
        opties.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 160, longitudinalMeters: 160)
        opties.size = CGSize(width: 400, height: KaartStijl.keurAfbeeldingHoogte)
        opties.pointOfInterestFilter = .excludingAll
        guard let snapshot = try? await MKMapSnapshotter(options: opties).start() else { return nil }
        cache.setObject(snapshot.image, forKey: sleutel)
        return snapshot.image
    }
}
