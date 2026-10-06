import Foundation
import CoreLocation

enum BenchSource: String, Codable {
    case eigen   // zelf toegevoegd
    case osm     // uit OpenStreetMap
}

struct Bench: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var place: String
    var lat: Double?
    var lon: Double?
    var tags: [String]
    var rating: Int
    var note: String
    var createdAt: Date
    var source: BenchSource

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location, let lat, let lon else { return nil }
        return location.distance(from: CLLocation(latitude: lat, longitude: lon))
    }
}

enum BenchTags {
    static let all = ["Rugleuning", "Armleuning", "Schaduw", "Uitzicht", "Bij water", "Rustig", "Picknicktafel", "Overdekt"]
}

func formatDistance(_ meters: CLLocationDistance) -> String {
    if meters < 1000 {
        let rounded = Int((meters / 10).rounded()) * 10
        return "\(max(rounded, 10)) m"
    }
    let km = String(format: "%.1f", meters / 1000).replacingOccurrences(of: ".", with: ",")
    return "\(km) km"
}

/// Een minuut of twee lopen: ~80 meter per minuut.
func walkingMinutes(_ meters: CLLocationDistance) -> String {
    let minutes = max(1, Int((meters / 80).rounded()))
    return "\(minutes) min lopen"
}
