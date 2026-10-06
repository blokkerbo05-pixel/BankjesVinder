import Foundation
import CoreLocation
import MapKit

/// Houdt alle bankjes bij: je eigen bankjes (opgeslagen op je iPhone)
/// en de bankjes uit OpenStreetMap rond je locatie.
@MainActor
final class BenchStore: ObservableObject {
    @Published private(set) var own: [Bench] = []
    @Published private(set) var osm: [Bench] = []
    @Published private(set) var isLoadingOSM = false
    @Published var osmError: String?
    var didAutoLoad = false

    // Bankjes uit OpenStreetMap, per tegel (stukje kaart).
    private var osmByTile: [TileKey: [Bench]] = [:]
    private var tileLoadedAt: [TileKey: Date] = [:]
    private var tileFailedAt: [TileKey: Date] = [:]
    private var pendingTiles: [TileKey] = []     // wachtrij, dichtstbijzijnde eerst
    private var activeTiles = Set<TileKey>()     // nu bezig met ophalen
    private var cacheLoaded = false
    private var regionWaitingForCache: MKCoordinateRegion?

    private let maxTilesPerRequest = 12          // niet meer tegels tegelijk aanvragen, ook niet als je ver uitzoomt
    private let cacheMaxAge: TimeInterval = 7 * 24 * 3600   // na een week opnieuw ophalen
    private let retryAfterFailure: TimeInterval = 20

    var all: [Bench] { own + osm }

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

    func delete(_ bench: Bench) {
        own.removeAll { $0.id == bench.id }
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
            tileLoadedAt[tile.key] = tile.fetchedAt
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

    /// Haalt de bankjes op voor het stuk kaart dat in beeld is. Dichtstbijzijnde tegels eerst.
    func loadTiles(in region: MKCoordinateRegion, force: Bool = false) {
        // Wacht even tot de bewaarde tegels binnen zijn, anders halen we onnodig alles opnieuw op.
        guard cacheLoaded else {
            regionWaitingForCache = region
            return
        }
        if force { tileFailedAt.removeAll() }

        let center = region.center
        let minLat = center.latitude - region.span.latitudeDelta / 2
        let maxLat = center.latitude + region.span.latitudeDelta / 2
        let minLon = center.longitude - region.span.longitudeDelta / 2
        let maxLon = center.longitude + region.span.longitudeDelta / 2
        let first = TileKey.containing(lat: minLat, lon: minLon)
        let last = TileKey.containing(lat: maxLat, lon: maxLon)
        guard last.x >= first.x, last.y >= first.y else { return }

        // Ver uitgezoomd? Dan kijken we maar naar een venster rond het midden.
        let centerTile = TileKey.containing(lat: center.latitude, lon: center.longitude)
        let xLow = max(first.x, centerTile.x - 10), xHigh = min(last.x, centerTile.x + 10)
        let yLow = max(first.y, centerTile.y - 10), yHigh = min(last.y, centerTile.y + 10)
        guard xLow <= xHigh, yLow <= yHigh else { return }

        let cosLat = cos(center.latitude * .pi / 180)
        func distance(_ key: TileKey) -> Double {
            let dx = (key.center.longitude - center.longitude) * cosLat
            let dy = key.center.latitude - center.latitude
            return dx * dx + dy * dy
        }

        var inView: [TileKey] = []
        for x in xLow...xHigh { for y in yLow...yHigh { inView.append(TileKey(x: x, y: y)) } }
        let nearest = inView.sorted { distance($0) < distance($1) }.prefix(maxTilesPerRequest)

        let now = Date()
        let needed = nearest.filter { key in
            if activeTiles.contains(key) { return false }
            if let failed = tileFailedAt[key], now.timeIntervalSince(failed) < retryAfterFailure { return false }
            if let loaded = tileLoadedAt[key], now.timeIntervalSince(loaded) < cacheMaxAge { return false }
            return true
        }
        // Oude wachtrij vervangen: je hebt de kaart verschoven, dus de nieuwe plek gaat voor.
        pendingTiles = Array(needed)
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
