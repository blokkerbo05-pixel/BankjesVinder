import SwiftUI
import MapKit
import UIKit

/// De kaart: jouw blauwe stip, alle bankjes als speldjes en onderaan de dichtstbijzijnde.
struct MapScreen: View {
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var location: LocationManager

    // Begint op Amersfoort; zodra je locatie bekend is springt de kaart naar jou.
    @State private var position: MapCameraPosition = .region(KaartStijl.startRegio)
    @State private var didCenterOnUser = false
    @State private var showLocationHelp = false
    @State private var selectedID: String?
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var showAdd = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var clustered = ClusterResult()
    /// De 10 bankjes die het dichtst bij jou staan (alleen opnieuw berekend als dat nodig is).
    @State private var nearest: [Bench] = []

    private var mapped: [Bench] { store.all.filter { $0.coordinate != nil } }

    private var selected: Bench? { store.all.first { $0.id == selectedID } }

    var body: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()
                ForEach(clustered.singles) { bench in
                    Annotation(bench.name, coordinate: bench.coordinate!, anchor: .center) {
                        Button {
                            select(bench)
                        } label: {
                            BenchPin(isOwn: bench.source == .eigen, isSelected: bench.id == selectedID)
                        }
                        .buttonStyle(.plain)
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(clustered.clusters) { cluster in
                    Annotation("\(cluster.count) bankjes", coordinate: cluster.coordinate, anchor: .center) {
                        Button {
                            zoom(into: cluster)
                        } label: {
                            ClusterPin(count: cluster.count)
                        }
                        .buttonStyle(.plain)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(KaartStijl.kaartType)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                mapCenter = context.region.center
                visibleRegion = context.region
                recluster()
                store.loadTiles(in: context.region)
            }
            .onChange(of: store.all.count) {
                recluster()
                refreshNearest()
            }
            .onChange(of: location.location) { refreshNearest() }
            .onChange(of: selectedID) { recluster() }
            .onAppear {
                recluster()
                refreshNearest()
            }

            VStack(spacing: 10) {
                topBar
                Spacer()
                HStack {
                    Spacer()
                    locationButton
                }
                .padding(.horizontal, 16)
                bottomPanel
            }
        }
        .onReceive(location.$location) { newLocation in
            // De eerste keer dat we weten waar je bent: kaart naar jou toe.
            guard let newLocation, !didCenterOnUser else { return }
            didCenterOnUser = true
            withAnimation(.easeInOut(duration: 0.6)) {
                position = .region(MKCoordinateRegion(center: newLocation.coordinate,
                                                      latitudinalMeters: KaartStijl.zoomOpJezelf,
                                                      longitudinalMeters: KaartStijl.zoomOpJezelf))
            }
        }
        .alert("Locatie staat uit", isPresented: $showLocationHelp) {
            Button("Open Instellingen") { openSettings() }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Bankjesvinder mag je locatie nog niet gebruiken. Ga naar Instellingen → Bankjes → Locatie en kies 'Bij gebruik van app'. Staat het daar al goed? Check dan Instellingen → Privacy en beveiliging → Locatievoorzieningen.")
        }
        .sheet(isPresented: $showAdd) {
            AddBenchSheet(start: location.location?.coordinate ?? mapCenter)
                .environmentObject(store)
                .environmentObject(location)
        }
    }

    // MARK: - Bovenkant

    private var topBar: some View {
        VStack(spacing: 8) {
            if location.isDenied {
                banner("Je locatie staat uit. Zet hem aan via Instellingen → Bankjes → Locatie → 'Bij gebruik van app'.", button: "Instellingen") {
                    openSettings()
                }
            }
            if let error = store.osmError {
                banner(error, button: "Opnieuw") { retryLoading() }
            }
            if store.isLoadingOSM {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Bankjes laden…")
                        .font(.system(size: KaartStijl.laadTekstGrootte, weight: .semibold))
                        .foregroundStyle(KaartStijl.laadTekstKleur)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(KaartStijl.laadAchtergrond))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }

    private func banner(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(text).font(.system(size: 14)).foregroundStyle(Color.ink)
            Spacer(minLength: 0)
            Button(button, action: action)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.leaf)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.woodSoft))
    }

    // MARK: - Knop: naar mijn locatie

    private var locationButton: some View {
        Button { centerOnUser() } label: {
            Image(systemName: KaartStijl.locatieIcoon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(KaartStijl.knopIcoonKleur)
                .frame(width: KaartStijl.locatieKnopGrootte, height: KaartStijl.locatieKnopGrootte)
                .background(Circle().fill(KaartStijl.knopAchtergrond))
                .overlay(Circle().stroke(Color.line, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Naar mijn locatie")
    }

    private func centerOnUser() {
        if location.isDenied {
            showLocationHelp = true
            return
        }
        location.start()
        withAnimation(.easeInOut(duration: 0.5)) {
            if let here = location.location {
                position = .region(MKCoordinateRegion(center: here.coordinate,
                                                      latitudinalMeters: KaartStijl.zoomOpJezelf,
                                                      longitudinalMeters: KaartStijl.zoomOpJezelf))
            } else {
                position = .userLocation(fallback: .automatic)
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    // MARK: - Onderkant

    @ViewBuilder
    private var bottomPanel: some View {
        if let bench = selected {
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    selectedID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.surface))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                BenchCard(bench: bench, distance: bench.distance(from: location.location))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            VStack(spacing: 12) {
                if !nearest.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DICHTBIJ")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Color.muted)
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(nearest) { bench in
                                    nearbyTile(bench)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 10)
                    .background(Color.appBg.opacity(0.92))
                }
                AddBenchButton { showAdd = true }
            }
            .padding(.bottom, 12)
        }
    }

    private func nearbyTile(_ bench: Bench) -> some View {
        Button {
            select(bench)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(bench.name)
                    .font(.cardTitle(16))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if let d = bench.distance(from: location.location) {
                    Text(formatDistance(d))
                        .font(.display(22))
                        .monospacedDigit()
                        .foregroundStyle(bench.source == .eigen ? Color.wood : Color.leaf)
                    Text(walkingMinutes(d))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.muted)
                }
            }
            .frame(width: 130, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Acties

    private func select(_ bench: Bench) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedID = bench.id
            if let c = bench.coordinate {
                position = .region(MKCoordinateRegion(center: c, latitudinalMeters: KaartStijl.zoomOpBankje, longitudinalMeters: KaartStijl.zoomOpBankje))
            }
        }
    }

    /// Bepaalt opnieuw welke bankjes los staan en welke een cluster vormen.
    private func recluster() {
        clustered = BenchClustering.make(
            benches: mapped,
            region: visibleRegion ?? KaartStijl.startRegio,
            screen: UIScreen.main.bounds.size,
            keepLooseID: selectedID)
    }

    /// Zoekt de 10 dichtstbijzijnde bankjes, alleen binnen de straal uit KaartStijl (snel, ook bij heel veel bankjes).
    private func refreshNearest() {
        guard let here = location.location else {
            nearest = []
            return
        }
        let radius = KaartStijl.dichtbijStraal
        let dLat = radius / 111_000
        let dLon = dLat / max(cos(here.coordinate.latitude * .pi / 180), 0.01)
        var close: [(bench: Bench, distance: CLLocationDistance)] = []
        for bench in store.all {
            guard let lat = bench.lat, let lon = bench.lon,
                  abs(lat - here.coordinate.latitude) <= dLat,
                  abs(lon - here.coordinate.longitude) <= dLon,
                  let distance = bench.distance(from: here), distance <= radius else { continue }
            close.append((bench, distance))
        }
        close.sort { $0.distance < $1.distance }
        nearest = close.prefix(10).map { $0.bench }
    }

    /// Tik op een cluster: zoom in tot de bankjes los staan.
    private func zoom(into cluster: BenchCluster) {
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .region(BenchClustering.zoomRegion(for: cluster, screen: UIScreen.main.bounds.size))
        }
    }

    /// Na een fout: probeer de bankjes van het beeld opnieuw te laden.
    private func retryLoading() {
        guard let region = visibleRegion else { return }
        store.loadTiles(in: region, force: true)
    }
}
