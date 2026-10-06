import Foundation
import CoreLocation

/// Een stukje kaart (tegel) van vast formaat. Bankjes worden per tegel opgehaald en bewaard.
struct TileKey: Hashable, Codable {
    let x: Int
    let y: Int

    // Een tegel is ongeveer 2,2 km hoog en 2 km breed (in Nederland).
    static let hoogte = 0.02   // graden breedtegraad
    static let breedte = 0.03  // graden lengtegraad

    var south: Double { Double(y) * Self.hoogte }
    var north: Double { Double(y + 1) * Self.hoogte }
    var west: Double { Double(x) * Self.breedte }
    var east: Double { Double(x + 1) * Self.breedte }
    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (south + north) / 2, longitude: (west + east) / 2)
    }

    /// De tegel waarin een plek op de kaart valt.
    static func containing(lat: Double, lon: Double) -> TileKey {
        TileKey(x: Int((lon / breedte).rounded(.down)), y: Int((lat / hoogte).rounded(.down)))
    }
}

/// Haalt bestaande bankjes op uit OpenStreetMap (gratis, open kaartdata).
enum OSMService {
    private struct Response: Decodable {
        let elements: [Element]
        let remark: String?
    }
    private struct Element: Decodable {
        let id: Int64
        let lat: Double?
        let lon: Double?
        let tags: [String: String]?
    }

    private static let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]

    /// Verhoog dit getal als de gegevens per tegel veranderen (bijv. een nieuw kenmerk).
    /// Tegels met een lager nummer blijven zichtbaar, maar worden eenmalig opnieuw opgehaald.
    /// 1 = bankjes, 2 = bankjes met prullenbak-kenmerk.
    static let cacheVersie = 2

    /// De server die de vorige keer het snelst was; die vragen we als eerste.
    private static let fastestKey = "osmSnelsteServer"

    private static var orderedEndpoints: [String] {
        guard let fastest = UserDefaults.standard.string(forKey: fastestKey),
              endpoints.contains(fastest) else { return endpoints }
        return [fastest] + endpoints.filter { $0 != fastest }
    }

    private enum Outcome {
        case done(String, Result<[Bench], Error>)
        case tick(Int)   // de wachttijd na server nummer ... is om
    }

    /// Haalt alle bankjes van één tegel op.
    /// Eerst vragen we één server. Komt er binnen een paar seconden geen antwoord,
    /// dan vragen we de volgende erbij (en zo verder). Het eerste goede antwoord wint.
    static func benches(in tile: TileKey) async throws -> [Bench] {
        // Eén aanvraag voor bankjes én prullenbakken. Prullenbakken zoeken we iets ruimer dan de tegel,
        // zodat een bankje aan de rand ook een prullenbak aan de overkant van de rand "ziet".
        let marge = KeurInstellingen.prullenbakAfstandMeters / 111_000 * 1.2
        let margeLon = marge / max(cos(tile.center.latitude * .pi / 180), 0.01)
        let query = "[out:json][timeout:20];("
            + "node[\"amenity\"=\"bench\"](\(tile.south),\(tile.west),\(tile.north),\(tile.east));"
            + "node[\"amenity\"=\"waste_basket\"](\(tile.south - marge),\(tile.west - margeLon),\(tile.north + marge),\(tile.east + margeLon));"
            + ");out body;"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = "data=" + (query.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        let servers = orderedEndpoints
        let waitNanoseconds = UInt64(KaartStijl.serverStaffelSeconden * 1_000_000_000)

        return try await withThrowingTaskGroup(of: Outcome.self) { group in
            var launched = 0
            var needLaunch = true
            var lastError: Error = URLError(.badServerResponse)

            while true {
                if needLaunch && launched < servers.count {
                    let endpoint = servers[launched]
                    let number = launched
                    launched += 1
                    group.addTask {
                        do { return .done(endpoint, .success(try await fetch(endpoint: endpoint, body: body))) }
                        catch { return .done(endpoint, .failure(error)) }
                    }
                    if launched < servers.count {
                        group.addTask {
                            try? await Task.sleep(nanoseconds: waitNanoseconds)
                            return .tick(number)
                        }
                    }
                }
                needLaunch = false

                guard let outcome = try await group.next() else { break }
                switch outcome {
                case .done(let endpoint, .success(let found)):
                    group.cancelAll()   // de rest hoeft niet meer
                    UserDefaults.standard.set(endpoint, forKey: fastestKey)
                    // Een bankje hoort bij precies één tegel, zodat randen niet dubbel tellen.
                    return found.filter { bench in
                        guard let lat = bench.lat, let lon = bench.lon else { return false }
                        return TileKey.containing(lat: lat, lon: lon) == tile
                    }
                case .done(_, .failure(let error)):
                    lastError = error
                    needLaunch = true   // deze server lukte niet: meteen de volgende proberen
                case .tick(let number):
                    // Alleen de wachttijd van de laatst gevraagde server telt.
                    if number == launched - 1 { needLaunch = true }
                }
            }
            throw lastError
        }
    }

    private static func fetch(endpoint: String, body: String) async throws -> [Bench] {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Bankjesvinder/1.0 (iPhone)", forHTTPHeaderField: "User-Agent")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        // Een overbelaste server geeft soms "ok" met een foutmelding en niets erin: dat telt als mislukt.
        if decoded.elements.isEmpty, decoded.remark != nil {
            throw URLError(.cannotParseResponse)
        }

        let bins: [(lat: Double, lon: Double)] = decoded.elements.compactMap { element in
            guard element.tags?["amenity"] == "waste_basket", let lat = element.lat, let lon = element.lon else { return nil }
            return (lat, lon)
        }
        return decoded.elements
            .filter { $0.tags?["amenity"] == "bench" }
            .compactMap { makeBench($0, bins: bins) }
    }

    /// Staat er een prullenbak binnen de ingestelde afstand van deze plek?
    private static func hasBinNearby(lat: Double, lon: Double, bins: [(lat: Double, lon: Double)]) -> Bool {
        let meters = KeurInstellingen.prullenbakAfstandMeters
        let dLat = meters / 111_000
        let dLon = dLat / max(cos(lat * .pi / 180), 0.01)
        let here = CLLocation(latitude: lat, longitude: lon)
        for bin in bins {
            // Eerst een goedkope controle, dan pas de echte afstand.
            guard abs(bin.lat - lat) <= dLat, abs(bin.lon - lon) <= dLon else { continue }
            if here.distance(from: CLLocation(latitude: bin.lat, longitude: bin.lon)) <= meters { return true }
        }
        return false
    }

    private static func makeBench(_ element: Element, bins: [(lat: Double, lon: Double)]) -> Bench? {
        guard let lat = element.lat, let lon = element.lon else { return nil }
        let tags = element.tags ?? [:]

        var features: [String] = []
        if tags["backrest"] == "yes" { features.append("Rugleuning") }
        if tags["armrest"] == "yes" { features.append("Armleuning") }
        if tags["covered"] == "yes" { features.append("Overdekt") }
        if hasBinNearby(lat: lat, lon: lon, bins: bins) { features.append(BenchTags.prullenbak) }

        var notes: [String] = []
        let materials = ["wood": "hout", "metal": "metaal", "stone": "steen", "concrete": "beton", "plastic": "kunststof"]
        if let material = tags["material"] {
            notes.append("Materiaal: \(materials[material] ?? material)")
        }
        if let seats = tags["seats"] { notes.append("\(seats) zitplaatsen") }

        return Bench(
            id: "osm-\(element.id)",
            name: tags["name"] ?? "Bankje",
            place: "Uit OpenStreetMap",
            lat: lat,
            lon: lon,
            tags: features,
            rating: 0,
            note: notes.joined(separator: " · "),
            createdAt: .distantPast,
            source: .osm
        )
    }
}

/// Bewaart de opgehaalde tegels op de iPhone, zodat de app bij de volgende start meteen bankjes toont.
struct CachedTile: Codable {
    let key: TileKey
    let fetchedAt: Date
    let benches: [Bench]
    /// Met welke versie van OSMService.cacheVersie deze tegel is opgehaald. Oude tegels (zonder dit veld) zijn versie 0.
    let versie: Int

    init(key: TileKey, fetchedAt: Date, benches: [Bench], versie: Int = OSMService.cacheVersie) {
        self.key = key
        self.fetchedAt = fetchedAt
        self.benches = benches
        self.versie = versie
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(TileKey.self, forKey: .key)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        benches = try container.decode([Bench].self, forKey: .benches)
        versie = try container.decodeIfPresent(Int.self, forKey: .versie) ?? 0
    }
}

enum TileCache {
    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("osm-tegels", isDirectory: true)
    }

    static func save(_ tile: CachedTile) {
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(tile) else { return }
        let file = folder.appendingPathComponent("\(tile.key.x)_\(tile.key.y).json")
        try? data.write(to: file, options: .atomic)
    }

    /// Leest alle bewaarde tegels en ruimt meteen op: te oude tegels en tegels boven het maximum (oudste eerst) gaan weg.
    static func loadAndPrune(maxAge: TimeInterval, maxCount: Int) -> [CachedTile] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        let now = Date()

        var kept: [(tile: CachedTile, file: URL)] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let tile = try? decoder.decode(CachedTile.self, from: data),
                  now.timeIntervalSince(tile.fetchedAt) < maxAge else {
                try? fm.removeItem(at: file)   // kapot of te oud
                continue
            }
            kept.append((tile, file))
        }

        kept.sort { $0.tile.fetchedAt > $1.tile.fetchedAt }   // nieuwste eerst
        if kept.count > maxCount {
            for old in kept[maxCount...] { try? fm.removeItem(at: old.file) }
            kept = Array(kept[..<maxCount])
        }
        return kept.map { $0.tile }
    }
}
