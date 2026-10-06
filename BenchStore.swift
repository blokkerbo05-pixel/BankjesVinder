import Foundation
import CoreLocation
import MapKit
import UIKit

/// Houdt alle bankjes bij: je eigen bankjes (opgeslagen op je iPhone)
/// en de bankjes uit OpenStreetMap rond je locatie.
@MainActor
final class BenchStore: ObservableObject {
    @Published private(set) var own: [Bench] = []
    @Published private(set) var osm: [Bench] = []
    @Published private(set) var isLoadingOSM = false
    @Published var osmError: String?
    /// Wordt hoger telkens als er een foto is toegevoegd of gewijzigd, zodat schermen hem opnieuw laden.
    @Published private(set) var fotoVersie = 0
    var didAutoLoad = false
    /// Open (aan): eigen bankjes én OpenStreetMap. Journey (uit): alleen eigen bankjes, geen OpenStreetMap-verzoeken.
    @Published var toonAlle: Bool = UserDefaults.standard.object(forKey: "toonAlleBankjes") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(toonAlle, forKey: "toonAlleBankjes")
            if !toonAlle {
                pendingTiles = []   // niets meer ophalen
                osmError = nil
            }
        }
    }

    // Bankjes uit OpenStreetMap, per tegel (stukje kaart).
    private var osmByTile: [TileKey: [Bench]] = [:]
    private var tileLoadedAt: [TileKey: Date] = [:]
    private var tileFailedAt: [TileKey: Date] = [:]
    private var pendingTiles: [TileKey] = []     // wachtrij, dichtstbijzijnde eerst
    private var activeTiles = Set<TileKey>()     // nu bezig met ophalen
    private var cacheLoaded = false
    private var regionWaitingForCache: MKCoordinateRegion?

    private let cacheMaxAge: TimeInterval = 7 * 24 * 3600   // na een week opnieuw ophalen
    private let retryAfterFailure: TimeInterval = 20

    var all: [Bench] { toonAlle ? own + osm : own }

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bankjes.json")
    }

    init() {
        load()
        loadTileCache()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([Bench].self, from: data) else { return }
        own = list
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(own) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func add(_ bench: Bench) {
        own.insert(bench, at: 0)
        save()
    }

    /// Bewaart een foto bij een eigen bankje (verkleind) en laat schermen verversen.
    func bewaarFoto(_ image: UIImage, voor bench: Bench) {
        if BankjesFotos.bewaar(image, voor: bench.id) { fotoVersie += 1 }
    }

    func delete(_ bench: Bench) {
        own.removeAll { $0.id == bench.id }
        BankjesFotos.verwijder(voor: bench.id)
        save()
    }

    // MARK: - OpenStreetMap per tegel

    /// Leest bij de start de bewaarde tegels van de iPhone, zodat de bankjes meteen zichtbaar zijn.
    private func loadTileCache() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let tiles = TileCache.loadAndPrune(
                maxAge: KaartStijl.tegelMaxDagen * 24 * 3600,
                maxCount: KaartStijl.maxBewaardeTegels)
            await self?.finishCacheLoad(tiles)
        }
    }

    private func finishCacheLoad(_ tiles: [CachedTile]) {
        for tile in tiles where osmByTile[tile.key] == nil {
            osmByTile[tile.key] = tile.benches
            // Oudere versie (bijv. zonder prullenbak-info)? Dan tonen we hem wel, maar halen we hem opnieuw op.
            tileLoadedAt[tile.key] = tile.versie >= OSMService.cacheVersie ? tile.fetchedAt : .distantPast
        }
        cacheLoaded = true
        rebuildOSM()
        if let region = regionWaitingForCache {
            regionWaitingForCache = nil
            loadTiles(in: region)
        }
    }

    private func rebuildOSM() {
        osm = osmByTile.values.flatMap { $0 }
    }

    /// Het blok tegels dat het kaartbeeld bedekt.
    private func tileRange(for region: MKCoordinateRegion) -> (x: ClosedRange<Int>, y: ClosedRange<Int>)? {
        let center = region.center
        let first = TileKey.containing(lat: center.latitude - region.span.latitudeDelta / 2,
                                       lon: center.longitude - region.span.longitudeDelta / 2)
        let last = TileKey.containing(lat: center.latitude + region.span.latitudeDelta / 2,
                                      lon: center.longitude + region.span.longitudeDelta / 2)
        guard last.x >= first.x, last.y >= first.y else { return nil }
        return (first.x...last.x, first.y...last.y)
    }

    /// Hoeveel tegels het kaartbeeld bedekken.
    func tileCount(in region: MKCoordinateRegion) -> Int {
        guard let range = tileRange(for: region) else { return 0 }
        return range.x.count * range.y.count
    }

    /// Moet deze tegel (opnieuw) worden opgehaald?
    private func needsLoading(_ key: TileKey, now: Date, ignoreCooldown: Bool = false) -> Bool {
        if activeTiles.contains(key) { return false }
        if !ignoreCooldown, let failed = tileFailedAt[key], now.timeIntervalSince(failed) < retryAfterFailure { return false }
        if let loaded = tileLoadedAt[key], now.timeIntervalSince(loaded) < cacheMaxAge { return false }
        return true
    }

    /// Staat er in dit kaartbeeld nog iets dat geladen kan worden? (Voor de knop "Laad bankjes in dit gebied".)
    func hasUnloadedTiles(in region: MKCoordinateRegion) -> Bool {
        guard toonAlle, cacheLoaded, tileCount(in: region) <= KaartStijl.maxTegelsPerGebied,
              let range = tileRange(for: region) else { return false }
        let now = Date()
        for x in range.x { for y in range.y where needsLoading(TileKey(x: x, y: y), now: now, ignoreCooldown: true) { return true } }
        return false
    }

    /// Haalt de bankjes op voor het stuk kaart dat in beeld is. Dichtstbijzijnde tegels eerst.
    /// Is het gebied te groot (meer tegels dan KaartStijl.maxTegelsPerGebied), dan gebeurt er niets.
    func loadTiles(in region: MKCoordinateRegion, force: Bool = false) {
        guard toonAlle else { return }   // Journey: geen OpenStreetMap
        // Wacht even tot de bewaarde tegels binnen zijn, anders halen we onnodig alles opnieuw op.
        guard cacheLoaded else {
            regionWaitingForCache = region
            return
        }
        guard tileCount(in: region) <= KaartStijl.maxTegelsPerGebied,
              let range = tileRange(for: region) else { return }
        if force { tileFailedAt.removeAll() }

        let center = region.center
        let cosLat = cos(center.latitude * .pi / 180)
        func distance(_ key: TileKey) -> Double {
            let dx = (key.center.longitude - center.longitude) * cosLat
            let dy = key.center.latitude - center.latitude
            return dx * dx + dy * dy
        }

        var inView: [TileKey] = []
        for x in range.x { for y in range.y { inView.append(TileKey(x: x, y: y)) } }

        let now = Date()
        let needed = inView
            .filter { needsLoading($0, now: now) }
            .sorted { distance($0) < distance($1) }
        // Oude wachtrij vervangen: je hebt de kaart verschoven, dus de nieuwe plek gaat voor.
        pendingTiles = needed
        pump()
    }

    /// Haalt tegels van het kaartstuk rond een plek op (bijv. rond jouw locatie).
    func loadTiles(around coordinate: CLLocationCoordinate2D, meters: CLLocationDistance = 3000) {
        loadTiles(in: MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters))
    }

    private func pump() {
        while activeTiles.count < KaartStijl.maxTegelsTegelijk, !pendingTiles.isEmpty {
            let key = pendingTiles.removeFirst()
            activeTiles.insert(key)
            Task { await fetchTile(key) }
        }
        isLoadingOSM = !activeTiles.isEmpty || !pendingTiles.isEmpty
    }

    private func fetchTile(_ key: TileKey) async {
        do {
            let found = try await OSMService.benches(in: key)
            let now = Date()
            osmByTile[key] = found
            tileLoadedAt[key] = now
            tileFailedAt[key] = nil
            osmError = nil
            rebuildOSM()
            let cached = CachedTile(key: key, fetchedAt: now, benches: found)
            Task.detached(priority: .utility) { TileCache.save(cached) }
        } catch {
            tileFailedAt[key] = Date()
            // Alleen melden als we voor dit stukje niets hebben om te laten zien.
            if osmByTile[key] == nil {
                osmError = "Bankjes in de buurt laden lukte niet. Check je internet en probeer het opnieuw."
            }
        }
        activeTiles.remove(key)
        pump()
    }
}
