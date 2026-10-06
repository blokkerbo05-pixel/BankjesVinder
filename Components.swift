import SwiftUI
import MapKit
import UIKit
import PhotosUI

/// Zet kleine knopjes (chips) naast elkaar en laat ze doorlopen naar de volgende regel.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct Chip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? Color.appBg : Color.ink)
                .background(Capsule().fill(isOn ? Color.leaf : Color.surface))
                .overlay(Capsule().stroke(isOn ? Color.leaf : Color.line, lineWidth: 1.5))
        }
        .buttonStyle(.indruk)
    }
}

/// De drie houten latjes onder de titel.
struct Slats: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach([1.0, 0.75, 0.5], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.wood.opacity(opacity))
                    .frame(width: 84, height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

struct Stars: View {
    let rating: Int
    var body: some View {
        Text(String(repeating: "★", count: rating) + String(repeating: "☆", count: max(0, 5 - rating)))
            .font(.system(size: 17))
            .foregroundStyle(Color.wood)
            .accessibilityLabel("\(rating) van 5 sterren")
    }
}

struct TagPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.leaf)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.leafSoft))
    }
}

/// De oranje knop onderaan.
struct AddBenchButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("+ Bankje toevoegen")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.appBg)
                .padding(.horizontal, 26)
                .padding(.vertical, 15)
                .background(Capsule().fill(Color.wood))
                .kaartSchaduw()
        }
        .buttonStyle(.indruk)
    }
}

/// Speld op de kaart: hout-kleur voor bankjes die mensen zelf toevoegden, groen voor OpenStreetMap.
/// Kleuren en groottes komen uit KaartStijl.swift.
struct BenchPin: View {
    let isOwn: Bool
    let isSelected: Bool
    var isFavoriet = false
    @State private var getoond = false
    var body: some View {
        let size = isSelected ? KaartStijl.geselecteerdeStipGrootte : KaartStijl.stipGrootte
        ZStack {
            Circle()
                .fill(isOwn ? KaartStijl.eigenBankjeKleur : KaartStijl.bankjeKleur)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(KaartStijl.randKleur, lineWidth: KaartStijl.randDikte))
                .shadow(color: .black.opacity(KaartStijl.schaduw), radius: 3, y: 2)
            Image(systemName: KaartStijl.bankjeIcoon)
                .font(.system(size: isSelected ? KaartStijl.geselecteerdIcoonGrootte : KaartStijl.icoonGrootte, weight: .bold))
                .foregroundStyle(KaartStijl.icoonKleur)
            if isFavoriet {
                Image(systemName: KaartStijl.favorietIcoonGevuld)
                    .font(.system(size: KaartStijl.favorietPinIcoon, weight: .bold))
                    .foregroundStyle(KaartStijl.favorietKleur)
                    .frame(width: KaartStijl.favorietPinGrootte, height: KaartStijl.favorietPinGrootte)
                    .background(Circle().fill(KaartStijl.randKleur))
                    .offset(x: size / 2.4, y: -size / 2.4)
            }
        }
        // Veert op bij selecteren en groeit zacht in als het speldje voor het eerst verschijnt.
        .animation(Animaties.opveer, value: isSelected)
        .scaleEffect(getoond || Animaties.beperkt ? 1 : Animaties.verschijnSchaal)
        .onAppear { withAnimation(Animaties.opveer ?? Animaties.fade) { getoond = true } }
    }
}

/// Groen bolletje met het aantal bankjes erin.
struct ClusterPin: View {
    let count: Int
    @State private var getoond = false
    var body: some View {
        let size = count >= 10 ? KaartStijl.clusterGrootteGroot : KaartStijl.clusterGrootte
        Text("\(count)")
            .font(.system(size: KaartStijl.clusterTekstGrootte, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(KaartStijl.clusterTekstKleur)
            .frame(width: size, height: size)
            .background(Circle().fill(KaartStijl.clusterKleur))
            .overlay(Circle().stroke(KaartStijl.randKleur, lineWidth: KaartStijl.randDikte))
            .shadow(color: .black.opacity(KaartStijl.schaduw), radius: 3, y: 2)
            // Groeit zacht in als het bolletje verschijnt (bijv. als bankjes samenkomen).
            .scaleEffect(getoond || Animaties.beperkt ? 1 : Animaties.verschijnSchaal)
            .onAppear { withAnimation(Animaties.opveer ?? Animaties.fade) { getoond = true } }
    }
}

enum MapsOpener {
    static func openInAppleMaps(_ bench: Bench) {
        if let coordinate = bench.coordinate {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = bench.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        } else if let url = URL(string: "https://maps.apple.com/?q=" + (bench.place.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")) {
            UIApplication.shared.open(url)
        }
    }

    static func googleMapsURL(_ bench: Bench) -> URL? {
        let query: String
        if let lat = bench.lat, let lon = bench.lon {
            query = "\(lat),\(lon)"
        } else {
            query = bench.place.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        }
        return URL(string: "https://www.google.com/maps/dir/?api=1&travelmode=walking&destination=\(query)")
    }
}

/// Kaartje met alle info over één bankje (zelfde stijl als de web-versie).
struct BenchCard: View {
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var keur: KeurStore
    @EnvironmentObject var favorieten: FavorietenStore
    @EnvironmentObject var account: AccountStore
    @EnvironmentObject var fotos: FotoStore
    let bench: Bench
    let distance: CLLocationDistance?
    @State private var confirmDelete = false
    @State private var gekozenFoto: PhotosPickerItem?
    @State private var verschenen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FotoGalerij(bench: bench, hoogte: KaartStijl.fotoDetailHoogte)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bench.name)
                        .font(.cardTitle(20))
                        .foregroundStyle(Color.ink)
                    Text(bench.place)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.muted)
                }
                Spacer(minLength: 0)
                if bench.rating > 0 { Stars(rating: bench.rating) }
                FavorietHartje(isAan: favorieten.isFavoriet(bench.id)) { favorieten.wissel(bench.id) }
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
            }

            keurStatus

            if account.isIngelogd {
                PhotosPicker(selection: $gekozenFoto, matching: .images) { fotoKnopLabel }
            } else {
                Button {
                    account.toonLogin = true
                } label: { fotoKnopLabel }
                .buttonStyle(.plain)
            }

            if let distance {
                Text("\(formatDistance(distance)) · \(walkingMinutes(distance))")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.muted)
            }

            HStack(spacing: 8) {
                Button {
                    MapsOpener.openInAppleMaps(bench)
                } label: {
                    Text("Apple Kaarten")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.appBg)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.leaf))
                }
                .buttonStyle(.plain)

                if let url = MapsOpener.googleMapsURL(bench) {
                    Link(destination: url) {
                        Text("Google Maps")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.line, lineWidth: 1.5))
                    }
                }

                Spacer(minLength: 0)

                if bench.source == .eigen {
                    Button(confirmDelete ? "Zeker weten?" : "Verwijderen") {
                        if confirmDelete {
                            store.delete(bench)
                        } else {
                            confirmDelete = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { confirmDelete = false }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.danger)
                    .buttonStyle(.plain)
                }
            }

            Text(bench.source == .osm ? "Bron: OpenStreetMap" : "Toegevoegd \(bench.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 13))
                .foregroundStyle(Color.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).fill(Color.surface))
        .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).stroke(Color.line, lineWidth: 1.5))
        .opacity(verschenen ? 1 : 0)
        .onAppear { withAnimation(Animaties.fade) { verschenen = true } }
        .task(id: bench.id) { await fotos.laad(bench) }
        .onChange(of: gekozenFoto) {
            guard let item = gekozenFoto else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await fotos.voegToe(image, aan: bench)
                }
                gekozenFoto = nil
            }
        }
    }

    private var fotoKnopLabel: some View {
        Label("Foto toevoegen", systemImage: KaartStijl.fotoKnopIcoon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.wood)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.wood.opacity(0.5), lineWidth: 1.5))
    }
}

extension BenchCard {
    /// Klein label met de keurstatus ("2/5 stemmen", "Goedgekeurd ✓", "Afgekeurd") en de reden van de agent.
    @ViewBuilder
    fileprivate var keurStatus: some View {
        let status = keur.status(of: bench.id)
        let tekst: String = {
            switch status {
            case .nieuw, .stemmen:
                let stemmen = "\(keur.aantalStemmen(for: bench.id))/\(KeurInstellingen.stemmenNodig) stemmen"
                return bench.source == .eigen ? "In keuring · \(stemmen)" : stemmen
            case .inBeoordeling: return bench.source == .eigen ? "In keuring…" : "In beoordeling…"
            case .goedgekeurd: return "Goedgekeurd ✓"
            case .afgekeurd: return "Afgekeurd"
            }
        }()
        let kleur: Color = {
            switch status {
            case .goedgekeurd: return KaartStijl.keurGoedKleur
            case .afgekeurd: return KaartStijl.keurSlechtKleur
            default: return KaartStijl.keurStatusNeutraalKleur
            }
        }()
        VStack(alignment: .leading, spacing: 2) {
            Text(tekst)
                .font(.system(size: KaartStijl.keurStatusTekstGrootte, weight: .bold))
                .foregroundStyle(kleur)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(kleur.opacity(0.12)))
            if let reden = keur.oordeel(of: bench.id)?.reden {
                Text(reden)
                    .font(.system(size: KaartStijl.keurStatusTekstGrootte))
                    .foregroundStyle(Color.muted)
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.cardTitle(20))
                .foregroundStyle(Color.ink)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).stroke(Color.line, style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
    }
}

/// Hartje-knop: gevuld = favoriet. Veert even op bij aantikken.
struct FavorietHartje: View {
    let isAan: Bool
    let actie: () -> Void
    @State private var puls = false

    var body: some View {
        Button {
            Haptiek.licht()
            actie()
            withAnimation(Animaties.hartVeer) { puls = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(Animaties.hartVeer) { puls = false }
            }
        } label: {
            Image(systemName: isAan ? KaartStijl.favorietIcoonGevuld : KaartStijl.favorietIcoon)
                .font(.system(size: KaartStijl.favorietIcoonGrootte, weight: .semibold))
                .foregroundStyle(isAan ? KaartStijl.favorietKleur : Color.muted)
                .scaleEffect(puls ? Animaties.hartSchaal : 1)
                .frame(width: KaartStijl.favorietKnopGrootte, height: KaartStijl.favorietKnopGrootte)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAan ? "Verwijder uit favorieten" : "Voeg toe aan favorieten")
    }
}
