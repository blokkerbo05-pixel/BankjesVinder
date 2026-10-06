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

    /// Alle servers worden tegelijk gevraagd; de snelste wint.
    private static let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]

    /// Haalt alle bankjes van één tegel op.
    static func benches(in tile: TileKey) async throws -> [Bench] {
        let query = "[out:json][timeout:20];node[\"amenity\"=\"bench\"](\(tile.south),\(tile.west),\(tile.north),\(tile.east));out body;"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = "data=" + (query.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")

        return try await withThrowingTaskGroup(of: Result<[Bench], Error>.self) { group in
            for endpoint in endpoints {
                group.addTask {
                    do { return .success(try await fetch(endpoint: endpoint, body: body)) }
                    catch { return .failure(error) }
                }
            }
            var lastError: Error = URLError(.badServerResponse)
            for try await result in group {
                switch result {
                case .success(let found):
                    group.cancelAll()   // de rest hoeft niet meer
                    // Een bankje hoort bij precies één tegel, zodat randen niet dubbel tellen.
                    return found.filter { bench in
                        guard let lat = bench.lat, let lon = bench.lon else { return false }
                        return TileKey.containing(lat: lat, lon: lon) == tile
                    }
                case .failure(let error):
                    lastError = error
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
        return decoded.elements.compactMap(makeBench)
    }

    private static func makeBench(_ element: Element) -> Bench? {
        guard let lat = element.lat, let lon = element.lon else { return nil }
        let tags = element.tags ?? [:]

        var features: [String] = []
        if tags["backrest"] == "yes" { features.append("Rugleuning") }
        if tags["armrest"] == "yes" { features.append("Armleuning") }
        if tags["covered"] == "yes" { features.append("Overdekt") }

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

    static func loadAll() -> [CachedTile] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        return files.compactMap { file in
            guard file.pathExtension == "json",
                  let data = try? Data(contentsOf: file) else { return nil }
            return try? decoder.decode(CachedTile.self, from: data)
        }
    }
}
