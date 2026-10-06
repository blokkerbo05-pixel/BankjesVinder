import Foundation
import MapKit

/// Een groepje bankjes dat op het scherm zo dicht bij elkaar staat dat we ze als één bolletje met een getal tonen.
struct BenchCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let members: [Bench]
    var count: Int { members.count }
}

/// Wat er op de kaart getekend wordt: losse bankjes en clusters.
struct ClusterResult {
    var singles: [Bench] = []
    var clusters: [BenchCluster] = []
}

enum BenchClustering {
    private struct Cell: Hashable { let x: Int; let y: Int }

    /// Groepeert alleen de bankjes die in beeld zijn. Het gekozen bankje blijft altijd los.
    static func make(benches: [Bench], region: MKCoordinateRegion, screen: CGSize, keepLooseID: String?) -> ClusterResult {
        var result = ClusterResult()

        // Het gekozen bankje altijd los (ook als het net buiten beeld staat).
        var candidates: [Bench] = []
        for bench in benches where bench.coordinate != nil {
            if bench.id == keepLooseID {
                result.singles.append(bench)
            } else {
                candidates.append(bench)
            }
        }

        // Alleen wat in beeld is (met een kleine marge, zodat het bij schuiven niet piept).
        let halfLat = region.span.latitudeDelta / 2 * 1.3
        let halfLon = region.span.longitudeDelta / 2 * 1.3
        let visible = candidates
            .filter { bench in
                guard let lat = bench.lat, let lon = bench.lon else { return false }
                return abs(lat - region.center.latitude) <= halfLat
                    && abs(lon - region.center.longitude) <= halfLon
            }
            .sorted { $0.id < $1.id }   // vaste volgorde, anders wisselen de clusters steeds

        // Ver ingezoomd: alles los.
        let regionMeters = region.span.latitudeDelta * 111_000
        if regionMeters < KaartStijl.clusterUitBijMeters
            || region.span.latitudeDelta <= 0 || region.span.longitudeDelta <= 0
            || screen.width <= 0 || screen.height <= 0 {
            result.singles.append(contentsOf: visible)
            return result
        }

        let distance = KaartStijl.clusterAfstand
        var seedPoints: [CGPoint] = []
        var groups: [[Bench]] = []
        var grid: [Cell: [Int]] = [:]

        for bench in visible {
            guard let lat = bench.lat, let lon = bench.lon else { continue }
            // Plek op het scherm, in punten.
            let x = (lon - region.center.longitude) / region.span.longitudeDelta * Double(screen.width)
            let y = (region.center.latitude - lat) / region.span.latitudeDelta * Double(screen.height)
            let cx = Int((x / Double(distance)).rounded(.down))
            let cy = Int((y / Double(distance)).rounded(.down))

            var joined: Int?
            search: for dx in -1...1 {
                for dy in -1...1 {
                    for index in grid[Cell(x: cx + dx, y: cy + dy)] ?? [] {
                        let seed = seedPoints[index]
                        if hypot(Double(seed.x) - x, Double(seed.y) - y) < Double(distance) {
                            joined = index
                            break search
                        }
                    }
                }
            }

            if let joined {
                groups[joined].append(bench)
            } else {
                seedPoints.append(CGPoint(x: x, y: y))
                groups.append([bench])
                grid[Cell(x: cx, y: cy), default: []].append(groups.count - 1)
            }
        }

        for group in groups {
            if group.count == 1 {
                result.singles.append(group[0])
            } else {
                let lat = group.compactMap(\.lat).reduce(0, +) / Double(group.count)
                let lon = group.compactMap(\.lon).reduce(0, +) / Double(group.count)
                result.clusters.append(BenchCluster(
                    id: "cluster-\(group[0].id)-\(group.count)",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    members: group))
            }
        }
        return result
    }

    /// Het kaartstuk waarop de bankjes van een cluster los van elkaar komen te staan.
    /// Zoomt nooit verder in dan KaartStijl.clusterMaxInzoomMeters schermhoogte.
    static func zoomRegion(for cluster: BenchCluster, screen: CGSize) -> MKCoordinateRegion {
        let lats = cluster.members.compactMap(\.lat)
        let lons = cluster.members.compactMap(\.lon)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max(),
              screen.width > 0, screen.height > 0 else {
            return MKCoordinateRegion(center: cluster.coordinate,
                                      latitudinalMeters: KaartStijl.clusterMaxInzoomMeters,
                                      longitudinalMeters: KaartStijl.clusterMaxInzoomMeters)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let cosLat = max(cos(center.latitude * .pi / 180), 0.01)
        let aspect = Double(screen.width / screen.height)   // breedte gedeeld door hoogte van het scherm

        // De hoogte van het scherm (in graden) moet de bankjes ruim omvatten, zowel in de hoogte als in de breedte.
        let minHeight = KaartStijl.clusterMaxInzoomMeters / 111_000
        let latSpan = max((maxLat - minLat) * KaartStijl.clusterZoomRuimte,
                          (maxLon - minLon) * KaartStijl.clusterZoomRuimte * cosLat / aspect,
                          minHeight)
        let lonSpan = latSpan * aspect / cosLat
        return MKCoordinateRegion(center: center,
                                  span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan))
    }
}
