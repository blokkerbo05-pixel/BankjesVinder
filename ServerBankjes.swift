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

    /// Zet een bankje online. Staat er nog een foto van vóór het inloggen op de iPhone, dan gaat die ook mee.
    static func zetOnline(_ bench: Bench, gebruiker: UUID) async throws {
        guard let uuid = UUID(uuidString: bench.id), let lat = bench.lat, let lon = bench.lon else { return }
        let rij = BenchRij(id: uuid, createdBy: nil, name: bench.name, place: bench.place, lat: lat, lon: lon,
                           tags: bench.tags, rating: bench.rating, note: bench.note,
                           photoPath: nil, createdAt: bench.createdAt)
        try await client.from("benches").upsert(rij, onConflict: "id").execute()
        if let image = BankjesFotos.afbeelding(voor: bench.id) {
            try await FotoServer.upload(image, voorBankje: bench.serverID, gebruiker: gebruiker)
            BankjesFotos.verwijder(voor: bench.id)
        }
    }

    static func verwijder(_ bench: Bench, gebruiker: UUID) async throws {
        // Eerst de eigen foto's uit de opslag halen (best effort), dan het bankje zelf.
        let eigenPrefix = gebruiker.uuidString.lowercased() + "/"
        if let fotos: [BenchFoto] = try? await client.from("bench_photos").select()
            .eq("bench_id", value: bench.serverID).execute().value {
            let paden = fotos.map(\.path).filter { $0.hasPrefix(eigenPrefix) }
            if !paden.isEmpty { _ = try? await client.storage.from(SupabaseConfig.fotoBucket).remove(paths: paden) }
        }
        if let uuid = UUID(uuidString: bench.id) {
            try await client.from("benches").delete().eq("id", value: uuid.uuidString.lowercased()).execute()
        }
    }

    /// Het web-adres van een foto in de opslag.
    static func fotoURL(_ pad: String) -> URL? {
        try? client.storage.from(SupabaseConfig.fotoBucket).getPublicURL(path: pad)
    }
}
