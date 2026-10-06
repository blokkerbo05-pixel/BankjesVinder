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
                KeurKaart(bench: item.element,
                          afstand: item.element.distance(from: location.location),
                          aantalStemmen: keur.aantalStemmen(for: item.element.id))
                    .scaleEffect(1 - 0.04 * CGFloat(item.offset))
                    .offset(y: 12 * CGFloat(item.offset))
                    .allowsHitTesting(item.offset == 0)
            }
        }
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity)
    }

    private var knoppen: some View {
        HStack(spacing: 28) {
            rondeKnop("xmark", kleur: KaartStijl.keurSlechtKleur, grootte: KaartStijl.keurKnopGrootte,
                      label: "Geen goed bankje") { stem(goed: false) }
            rondeKnop("arrow.uturn.backward", kleur: KaartStijl.keurOngedaanKleur, grootte: KaartStijl.keurKleineKnopGrootte,
                      label: "Laatste stem ongedaan maken") { maakOngedaan() }
                .opacity(keur.kanOngedaanMaken ? 1 : 0.35)
                .disabled(!keur.kanOngedaanMaken)
            rondeKnop("checkmark", kleur: KaartStijl.keurGoedKleur, grootte: KaartStijl.keurKnopGrootte,
                      label: "Goed bankje") { stem(goed: true) }
        }
    }

    private func rondeKnop(_ icoon: String, kleur: Color, grootte: CGFloat, label: String, actie: @escaping () -> Void) -> some View {
        Button(action: actie) {
            Image(systemName: icoon)
                .font(.system(size: grootte * 0.4, weight: .bold))
                .foregroundStyle(kleur)
                .frame(width: grootte, height: grootte)
                .background(Circle().fill(Color.surface))
                .overlay(Circle().stroke(kleur.opacity(0.5), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
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

    // MARK: Acties

    private func stem(goed: Bool) {
        guard let bench = stapel.first else { return }
        keur.stem(op: bench, goed: goed)   // de stapel wordt daarna vanzelf ververst
    }

    private func maakOngedaan() {
        guard let id = keur.maakLaatsteStemOngedaan(),
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
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

/// Kaartbeeld van de plek van het bankje, met een speldje in het midden.
struct KaartBeeld: View {
    let bench: Bench
    @State private var beeld: UIImage?

    var body: some View {
        ZStack {
            KaartStijl.keurAfbeeldingPlaceholder
            if let beeld {
                Image(uiImage: beeld)
                    .resizable()
                    .scaledToFill()
                BenchPin(isOwn: bench.source == .eigen, isSelected: false)
            } else {
                ProgressView()
            }
        }
        .task(id: bench.id) {
            beeld = await KaartBeeldCache.shared.beeld(voor: bench)
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
