import Foundation
import CoreLocation

/// Houdt alle bankjes bij: je eigen bankjes (opgeslagen op je iPhone)
/// en de bankjes uit OpenStreetMap rond je locatie.
@MainActor
final class BenchStore: ObservableObject {
    @Published private(set) var own: [Bench] = []
    @Published private(set) var osm: [Bench] = []
    @Published private(set) var isLoadingOSM = false
    @Published var osmError: String?
    @Published private(set) var lastOSMCenter: CLLocationCoordinate2D?
    var didAutoLoad = false

    var all: [Bench] { own + osm }

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bankjes.json")
    }

    init() { load() }

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

    func loadOSM(near center: CLLocationCoordinate2D) async {
        guard !isLoadingOSM else { return }
        isLoadingOSM = true
        osmError = nil
        do {
            let found = try await OSMService.benches(near: center)
            // Bankjes van eerdere plekken bewaren, nieuwe erbij.
            var byID = Dictionary(uniqueKeysWithValues: osm.map { ($0.id, $0) })
            for bench in found { byID[bench.id] = bench }
            osm = Array(byID.values)
            lastOSMCenter = center
        } catch {
            osmError = "Bankjes in de buurt laden lukte niet. Check je internet en probeer het opnieuw."
        }
        isLoadingOSM = false
    }
}
