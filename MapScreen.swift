import SwiftUI
import MapKit
import UIKit

/// De kaart: jouw blauwe stip, alle bankjes als speldjes en onderaan de dichtstbijzijnde.
struct MapScreen: View {
    @EnvironmentObject var store: BenchStore
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var keur: KeurStore
    @EnvironmentObject var favorieten: FavorietenStore
    @EnvironmentObject var account: AccountStore
    let geheugen: KaartGeheugen

    init(geheugen: KaartGeheugen) {
        self.geheugen = geheugen
        // Waar de kaart het laatst stond (bijv. voor een themawissel), anders Amersfoort.
        _position = State(initialValue: .region(geheugen.regio ?? KaartStijl.startRegio))
        _didCenterOnUser = State(initialValue: geheugen.gecentreerd)
    }

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
    /// Aan: alleen favoriete bankjes op de kaart.
    @State private var alleenFavorieten = false

    /// Bankjes met een plek op de kaart. Afgekeurde bankjes alleen als KeurInstellingen dat toestaat.
    private var mapped: [Bench] {
        store.all.filter { bench in
            guard bench.coordinate != nil else { return false }
            if alleenFavorieten && !favorieten.isFavoriet(bench.id) { return false }
            return KeurInstellingen.toonAfgekeurdeBankjes || keur.status(of: bench.id) != .afgekeurd
        }
    }

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
                            BenchPin(isOwn: bench.source == .eigen, isSelected: bench.id == selectedID,
                                     isFavoriet: favorieten.isFavoriet(bench.id))
                        }
                        .buttonStyle(.indruk)
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
                        .buttonStyle(.indruk)
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
                geheugen.regio = context.region
                recluster()
                // Alleen automatisch laden als je niet te ver uitgezoomd bent.
                if context.region.span.latitudeDelta * 111_000 < KaartStijl.autoLaadMaxMeters {
                    store.loadTiles(in: context.region)
                }
            }
            .onChange(of: store.all.count) {
                recluster()
                refreshNearest()
            }
            .onChange(of: location.location) { refreshNearest() }
            .onChange(of: store.toonAlle) {
                // Terug naar Open: meteen de bankjes van dit kaartbeeld ophalen (als je niet te ver uitgezoomd bent).
                if store.toonAlle, let region = visibleRegion,
                   region.span.latitudeDelta * 111_000 < KaartStijl.autoLaadMaxMeters {
                    store.loadTiles(in: region)
                }
            }
            .onChange(of: keur.data.records.count) {
                recluster()
                refreshNearest()
            }
            .onChange(of: selectedID) { recluster() }
            .onChange(of: alleenFavorieten) {
                recluster()
                refreshNearest()
            }
            .onChange(of: favorieten.aantal) {
                guard alleenFavorieten else { return }
                recluster()
                refreshNearest()
            }
            .onAppear {
                recluster()
                refreshNearest()
            }

            if !store.toonAlle && store.own.isEmpty {
                leegKaartKaart
                    .transition(Animaties.verschijn)
            }

            VStack(spacing: 10) {
                topBar
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        addButton
                        favorietFilterButton
                        locationButton
                    }
                }
                .padding(.horizontal, 16)
                bottomPanel
            }
        }
        .onReceive(location.$location) { newLocation in
            // De eerste keer dat we weten waar je bent: kaart naar jou toe.
            guard let newLocation, !didCenterOnUser else { return }
            didCenterOnUser = true
            geheugen.gecentreerd = true
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
            if store.toonAlle, let error = store.osmError {
                banner(error, button: "Opnieuw") { retryLoading() }
            }
            if store.toonAlle && store.isLoadingOSM {
                pill {
                    ProgressView()
                        .controlSize(.small)
                    Text("Bankjes laden…")
                }
            } else if store.toonAlle, let region = visibleRegion,
                      region.span.latitudeDelta * 111_000 >= KaartStijl.autoLaadMaxMeters {
                // Ver uitgezoomd: niet automatisch laden, maar met een knop (of een melding als het gebied te groot is).
                if store.tileCount(in: region) > KaartStijl.maxTegelsPerGebied {
                    pill {
                        Image(systemName: KaartStijl.inzoomMeldingIcoon)
                        Text("Zoom verder in om bankjes te laden")
                    }
                } else if store.hasUnloadedTiles(in: region) {
                    Button {
                        store.loadTiles(in: region, force: true)
                    } label: {
                        pill {
                            Image(systemName: KaartStijl.gebiedKnopIcoon)
                            Text("Laad bankjes in dit gebied")
                        }
                    }
                    .buttonStyle(.indruk)
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }

    /// Klein pilletje bovenaan (laden, knop of melding).
    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 6) { content() }
            .font(.system(size: KaartStijl.laadTekstGrootte, weight: .semibold))
            .foregroundStyle(KaartStijl.laadTekstKleur)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .zwevendeAchtergrond(Capsule())
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
        .background(RoundedRectangle(cornerRadius: KaartStijl.hoekMiddel).fill(Color.woodSoft))
    }

    // MARK: - Lege kaart (Journey)

    private var leegKaartKaart: some View {
        VStack(spacing: 10) {
            Image(systemName: KaartStijl.journeyIcoon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.wood)
            Text("Jouw kaart is nog leeg")
                .font(.cardTitle(20))
                .foregroundStyle(Color.ink)
            Text("Hier verschijnen de bankjes die jij toevoegt. Voeg je eerste bankje toe om je verzameling te beginnen.")
                .font(.system(size: 14))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
            Button {
                Haptiek.licht()
                account.metAccount { showAdd = true }
            } label: {
                Text("Voeg je eerste bankje toe")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.appBg)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(Color.wood))
            }
            .buttonStyle(.indruk)
        }
        .padding(20)
        .frame(maxWidth: 300)
        .zwevendeAchtergrond(RoundedRectangle(cornerRadius: KaartStijl.leegKaartHoek))
    }

    // MARK: - Knop: alleen favorieten

    private var favorietFilterButton: some View {
        Button {
            Haptiek.licht()
            withAnimation(Animaties.veer) { alleenFavorieten.toggle() }
        } label: {
            Image(systemName: alleenFavorieten ? KaartStijl.favorietIcoonGevuld : KaartStijl.favorietIcoon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KaartStijl.favorietKleur)
                .frame(width: KaartStijl.favorietFilterKnopGrootte, height: KaartStijl.favorietFilterKnopGrootte)
                .zwevendeAchtergrond(Circle())
                .overlay(Circle().stroke(KaartStijl.favorietKleur, lineWidth: alleenFavorieten ? 1.5 : 0))
        }
        .buttonStyle(.indruk)
        .accessibilityLabel("Alleen favorieten tonen")
        .accessibilityAddTraits(alleenFavorieten ? .isSelected : [])
    }

    // MARK: - Knop: naar mijn locatie

    private var locationButton: some View {
        Button { centerOnUser() } label: {
            Image(systemName: KaartStijl.locatieIcoon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(KaartStijl.knopIcoonKleur)
                .frame(width: KaartStijl.locatieKnopGrootte, height: KaartStijl.locatieKnopGrootte)
                .zwevendeAchtergrond(Circle())
        }
        .buttonStyle(.indruk)
        .accessibilityLabel("Naar mijn locatie")
    }

    // MARK: - Knop: bankje toevoegen

    private var addButton: some View {
        Button {
            Haptiek.licht()
            account.metAccount { showAdd = true }
        } label: {
            Image(systemName: KaartStijl.toevoegIcoon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(KaartStijl.toevoegKnopKleur)
                .frame(width: KaartStijl.toevoegKnopGrootte, height: KaartStijl.toevoegKnopGrootte)
                .zwevendeAchtergrond(Circle())
                .overlay(Circle().stroke(KaartStijl.toevoegKnopKleur, lineWidth: 1.5))
        }
        .buttonStyle(.indruk)
        .accessibilityLabel("Bankje toevoegen")
    }

    private func centerOnUser() {
        Haptiek.licht()
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
                    Haptiek.licht()
                    withAnimation(Animaties.veer) { selectedID = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 34, height: 34)
                        .zwevendeAchtergrond(Circle())
                }
                .buttonStyle(.indruk)
                BenchCard(bench: bench, distance: bench.distance(from: location.location))
                    .kaartSchaduw()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(Animaties.schuifOnder)
        } else {
            VStack(spacing: 12) {
                if !nearest.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DICHTBIJ")
                            .font(.system(size: KaartStijl.dichtbijKopGrootte, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Color.muted)
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(nearest) { bench in
                                    nearbyTile(bench)
                                        .transition(Animaties.verschijn)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, KaartStijl.dichtbijPaneelPadding)
                    .background(KaartStijl.dichtbijPaneelAchtergrond)
                    .transition(Animaties.schuifOnder)
                }
            }
            .animation(Animaties.veer, value: nearest)
            .transition(Animaties.schuifOnder)
        }
    }

    private func nearbyTile(_ bench: Bench) -> some View {
        Button {
            select(bench)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(bench.name)
                    .font(.system(size: KaartStijl.dichtbijNaamGrootte, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if let d = bench.distance(from: location.location) {
                    Text("\(formatDistance(d)) · \(walkingMinutes(d))")
                        .font(.system(size: KaartStijl.dichtbijInfoGrootte))
                        .monospacedDigit()
                        .foregroundStyle(bench.source == .eigen ? Color.wood : Color.leaf)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: KaartStijl.dichtbijTegelBreedte, alignment: .leading)
            .padding(KaartStijl.dichtbijTegelPadding)
            .background(RoundedRectangle(cornerRadius: KaartStijl.dichtbijTegelHoek).fill(KaartStijl.dichtbijTegelAchtergrond))
            .overlay(RoundedRectangle(cornerRadius: KaartStijl.dichtbijTegelHoek).stroke(KaartStijl.dichtbijTegelRand, lineWidth: 1))
        }
        .buttonStyle(.indruk)
    }

    // MARK: - Acties

    private func select(_ bench: Bench) {
        Haptiek.zacht()
        withAnimation(Animaties.veer) { selectedID = bench.id }
        withAnimation(.easeInOut(duration: 0.3)) {
            if let c = bench.coordinate {
                position = .region(MKCoordinateRegion(center: c, latitudinalMeters: KaartStijl.zoomOpBankje, longitudinalMeters: KaartStijl.zoomOpBankje))
            }
        }
    }

    /// Bepaalt opnieuw welke bankjes los staan en welke een cluster vormen.
    private func recluster() {
        let nieuw = BenchClustering.make(
            benches: mapped,
            region: visibleRegion ?? KaartStijl.startRegio,
            screen: UIScreen.main.bounds.size,
            keepLooseID: selectedID)
        // Speldjes en clusters verschijnen en verdwijnen zacht in plaats van te springen.
        withAnimation(Animaties.veer) { clustered = nieuw }
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
        for bench in mapped {
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
        Haptiek.zacht()
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
