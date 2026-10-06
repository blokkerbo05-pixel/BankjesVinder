import SwiftUI
import MapKit
import UIKit

/// De kaart: jouw blauwe stip, alle bankjes als speldjes en onderaan de dichtstbijzijnde.
struct MapScreen: View {
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var location: LocationManager

    // Start op je eigen locatie; zonder locatie op Amersfoort.
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.1561, longitude: 5.3878),
            latitudinalMeters: 3000, longitudinalMeters: 3000))
    )
    @State private var selectedID: String?
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var showAdd = false

    private var mapped: [Bench] { store.all.filter { $0.coordinate != nil } }

    private var selected: Bench? { store.all.first { $0.id == selectedID } }

    /// De 10 bankjes die het dichtst bij jou staan.
    private var nearest: [Bench] {
        guard let here = location.location else { return [] }
        return Array(mapped
            .sorted { ($0.distance(from: here) ?? .infinity) < ($1.distance(from: here) ?? .infinity) }
            .prefix(10))
    }

    /// Laat de knop "Zoek hier" zien als je de kaart een eind hebt verschoven.
    private var showSearchHere: Bool {
        guard let mapCenter else { return false }
        guard let last = store.lastOSMCenter else { return true }
        let a = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
        let b = CLLocation(latitude: last.latitude, longitude: last.longitude)
        return a.distance(from: b) > 700
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()
                ForEach(mapped) { bench in
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
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                mapCenter = context.region.center
            }

            VStack(spacing: 10) {
                topBar
                Spacer()
                bottomPanel
            }
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
                banner("Zet locatie aan om bankjes bij jou in de buurt te zien.", button: "Instellingen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            if let error = store.osmError {
                banner(error, button: "Opnieuw") { searchHere() }
            }
            if store.isLoadingOSM {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Bankjes zoeken…").font(.system(size: 15, weight: .bold))
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(Color.surface))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            } else if showSearchHere {
                Button { searchHere() } label: {
                    Label("Zoek hier naar bankjes", systemImage: "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(Color.surface))
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
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
                position = .region(MKCoordinateRegion(center: c, latitudinalMeters: 600, longitudinalMeters: 600))
            }
        }
    }

    private func searchHere() {
        guard let center = mapCenter ?? location.location?.coordinate else { return }
        Task { await store.loadOSM(near: center) }
    }
}
