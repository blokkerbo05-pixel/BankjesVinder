import Foundation
import CoreLocation

/// Haalt bestaande bankjes op uit OpenStreetMap (gratis, open kaartdata).
enum OSMService {
    private struct Response: Decodable { let elements: [Element] }
    private struct Element: Decodable {
        let id: Int64
        let lat: Double?
        let lon: Double?
        let tags: [String: String]?
    }

    private static let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter"
    ]

    static func benches(near center: CLLocationCoordinate2D, radius: Int = 1500) async throws -> [Bench] {
        let query = "[out:json][timeout:25];node[\"amenity\"=\"bench\"](around:\(radius),\(center.latitude),\(center.longitude));out body;"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = "data=" + (query.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")

        var lastError: Error = URLError(.badServerResponse)
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("Bankjesvinder/1.0 (iPhone)", forHTTPHeaderField: "User-Agent")
            request.httpBody = body.data(using: .utf8)
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                return decoded.elements.compactMap(makeBench)
            } catch {
                lastError = error
            }
        }
        throw lastError
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
