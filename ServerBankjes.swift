import Foundation
import UIKit
import Supabase

/// Een rij in de tabel `benches` (zie supabase/schema.sql).
struct BenchRij: Codable {
    var id: UUID
    var createdBy: UUID?
    var name: String
    var place: String
    var lat: Double
    var lon: Double
    var tags: [String]
    var rating: Int
    var note: String
    var photoPath: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, place, lat, lon, tags, rating, note
        case createdBy = "created_by"
        case photoPath = "photo_path"
        case createdAt = "created_at"
    }

    func alsBankje(bron: BenchSource) -> Bench {
        Bench(id: id.uuidString, name: name, place: place, lat: lat, lon: lon, tags: tags,
              rating: rating, note: note, createdAt: createdAt ?? Date(), source: bron, photoPath: photoPath)
    }
}

/// Een rij in `keur_status`.
struct StatusRij: Codable {
    var benchID: String
    var status: String
    var aantalStemmen: Int
    var aantalGoed: Int
    var reden: String?

    enum CodingKeys: String, CodingKey {
        case status, reden
        case benchID = "bench_id"
        case aantalStemmen = "aantal_stemmen"
        case aantalGoed = "aantal_goed"
    }
}

extension Bench {
    /// Het ID zoals de database het bewaart (kleine letters).
    var serverID: String { id.lowercased() }
}

/// Alle gesprekken met de online database over bankjes en foto's.
enum ServerBankjes {
    private static var client: SupabaseClient { SupabaseConfig.client }

    static func haalBankjesOp() async throws -> [BenchRij] {
        try await client.from("benches").select().limit(1000).execute().value
    }

    static func haalStatussenOp() async throws -> [StatusRij] {
        try await client.from("keur_status").select().limit(5000).execute().value
    }

    /// Zet een bankje (en zijn foto, als die er is) online.
    /// Geeft het pad van de foto terug.
    @discardableResult
    static func zetOnline(_ bench: Bench, gebruiker: UUID) async throws -> String? {
        var pad: String? = bench.photoPath
        if let image = BankjesFotos.afbeelding(voor: bench.id),
           let data = image.jpegData(compressionQuality: KaartStijl.fotoJpegKwaliteit) {
            let nieuwPad = "\(gebruiker.uuidString.lowercased())/\(bench.serverID).jpg"
            try await client.storage.from(SupabaseConfig.fotoBucket)
                .upload(nieuwPad, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
            pad = nieuwPad
        }
        guard let uuid = UUID(uuidString: bench.id), let lat = bench.lat, let lon = bench.lon else { return pad }
        let rij = BenchRij(id: uuid, createdBy: nil, name: bench.name, place: bench.place, lat: lat, lon: lon,
                           tags: bench.tags, rating: bench.rating, note: bench.note,
                           photoPath: pad, createdAt: bench.createdAt)
        try await client.from("benches").upsert(rij, onConflict: "id").execute()
        return pad
    }

    static func verwijder(_ bench: Bench) async throws {
        if let uuid = UUID(uuidString: bench.id) {
            try await client.from("benches").delete().eq("id", value: uuid.uuidString.lowercased()).execute()
        }
        if let pad = bench.photoPath {
            _ = try? await client.storage.from(SupabaseConfig.fotoBucket).remove(paths: [pad])
        }
    }

    /// Het web-adres van een foto in de opslag.
    static func fotoURL(_ pad: String) -> URL? {
        try? client.storage.from(SupabaseConfig.fotoBucket).getPublicURL(path: pad)
    }
}

/// Haalt de foto van een bankje: eerst van de iPhone zelf, anders van internet (en onthoudt hem).
@MainActor
final class FotoCache {
    static let shared = FotoCache()
    private let cache = NSCache<NSString, UIImage>()

    func afbeelding(voor bench: Bench) async -> UIImage? {
        if let lokaal = BankjesFotos.afbeelding(voor: bench.id) { return lokaal }
        guard let pad = bench.photoPath else { return nil }
        let sleutel = pad as NSString
        if let bewaard = cache.object(forKey: sleutel) { return bewaard }
        guard let url = ServerBankjes.fotoURL(pad),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: sleutel)
        return image
    }
}
