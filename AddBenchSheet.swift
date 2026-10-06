import SwiftUI
import MapKit
import CoreLocation

/// Nieuw bankje toevoegen. Je schuift de kaart tot het speldje op het bankje staat.
struct AddBenchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var location: LocationManager

    @State private var name = ""
    @State private var place = ""
    @State private var placeIsAutomatic = true
    @State private var lastAutomaticPlace = ""
    @State private var note = ""
    @State private var tags: Set<String> = []
    @State private var rating = 0
    @State private var error: String?

    @State private var pickPosition: MapCameraPosition
    @State private var pickedCenter: CLLocationCoordinate2D

    private static let fallback = CLLocationCoordinate2D(latitude: 52.1561, longitude: 5.3878)

    init(start: CLLocationCoordinate2D?) {
        let center = start ?? Self.fallback
        _pickPosition = State(initialValue: .region(MKCoordinateRegion(center: center, latitudinalMeters: 250, longitudinalMeters: 250)))
        _pickedCenter = State(initialValue: center)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    locationPicker

                    field("Naam") {
                        TextField("Bijv. Bankje bij de eendenvijver", text: $name)
                            .modifier(InputStyle())
                    }

                    field("Plek") {
                        TextField("Straat, park of wijk + plaats", text: $place)
                            .modifier(InputStyle())
                            .onChange(of: place) { _, newValue in
                                if newValue != lastAutomaticPlace { placeIsAutomatic = false }
                            }
                    }

                    field("Kenmerken") {
                        FlowLayout(spacing: 8) {
                            ForEach(BenchTags.all, id: \.self) { tag in
                                Chip(title: tag, isOn: tags.contains(tag)) {
                                    if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
                                }
                            }
                        }
                    }

                    field("Beoordeling") {
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { i in
                                Button {
                                    rating = (rating == i) ? 0 : i
                                } label: {
                                    Text("★")
                                        .font(.system(size: 32))
                                        .foregroundStyle(i <= rating ? Color.wood : Color.line)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(i) sterren")
                            }
                        }
                    }

                    field("Notitie (optioneel)") {
                        TextField("Bijv. mooi in de avondzon, soms druk met honden", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .modifier(InputStyle())
                    }

                    if let error {
                        Text(error)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.danger)
                    }
                }
                .padding(16)
            }
            .background(Color.appBg.ignoresSafeArea())
            .navigationTitle("Nieuw bankje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") { save() }.fontWeight(.bold)
                }
            }
        }
    }

    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Locatie").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.ink)
            ZStack {
                Map(position: $pickPosition) {
                    UserAnnotation()
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .onMapCameraChange(frequency: .continuous) { context in
                    pickedCenter = context.region.center
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    lookUpPlace(context.region.center)
                }

                // Vast speldje in het midden van de kaart.
                BenchPin(isOwn: true, isSelected: true)
                    .allowsHitTesting(false)
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1.5))

            HStack {
                Text("Schuif de kaart tot het speldje op het bankje staat.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.muted)
                Spacer(minLength: 8)
                if let here = location.location?.coordinate {
                    Button("Mijn locatie") {
                        withAnimation {
                            pickPosition = .region(MKCoordinateRegion(center: here, latitudinalMeters: 250, longitudinalMeters: 250))
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                }
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 14, weight: .bold)).foregroundStyle(Color.ink)
            content()
        }
    }

    /// Vult automatisch de straat en plaats in op basis van waar het speldje staat.
    private func lookUpPlace(_ coordinate: CLLocationCoordinate2D) {
        guard placeIsAutomatic || place.isEmpty else { return }
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { placemarks, _ in
            guard let p = placemarks?.first else { return }
            let parts = [p.thoroughfare, p.locality].compactMap { $0 }
            guard !parts.isEmpty else { return }
            DispatchQueue.main.async {
                let text = parts.joined(separator: ", ")
                lastAutomaticPlace = text
                place = text
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanPlace.isEmpty else {
            error = "Vul een naam en een plek in."
            return
        }
        let bench = Bench(
            id: UUID().uuidString,
            name: cleanName,
            place: cleanPlace,
            lat: (pickedCenter.latitude * 1_000_000).rounded() / 1_000_000,
            lon: (pickedCenter.longitude * 1_000_000).rounded() / 1_000_000,
            tags: BenchTags.all.filter { tags.contains($0) },
            rating: rating,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date(),
            source: .eigen
        )
        store.add(bench)
        dismiss()
    }
}

struct InputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.line, lineWidth: 1.5))
    }
}
