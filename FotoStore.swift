import Foundation
import UIKit
import Supabase

/// Een foto van een bankje (tabel `bench_photos`).
struct BenchFoto: Identifiable, Codable, Hashable {
    var id: UUID
    var benchID: String
    var userID: UUID
    var path: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, path
        case benchID = "bench_id"
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

/// Wat er in de galerij van een bankje staat.
enum GalerijItem: Identifiable, Hashable {
    case lokaal(String)        // een foto van vóór het inloggen die nog op de iPhone staat (bankje-ID)
    case online(BenchFoto)

    var id: String {
        switch self {
        case .lokaal(let id): return "lokaal-\(id)"
        case .online(let foto): return foto.id.uuidString
        }
    }
}

/// Gesprekken met de database en opslag over foto's.
enum FotoServer {
    private static var client: SupabaseClient { SupabaseConfig.client }

    static func haalOp(bankje key: String) async throws -> [BenchFoto] {
        try await client.from("bench_photos").select()
            .eq("bench_id", value: key).order("created_at").execute().value
    }

    /// Verkleint, uploadt en schrijft de foto in de database.
    @discardableResult
    static func upload(_ image: UIImage, voorBankje key: String, gebruiker: UUID) async throws -> BenchFoto {
        guard let data = BankjesFotos.jpegData(image) else { throw URLError(.cannotDecodeContentData) }
        let id = UUID()
        let pad = "\(gebruiker.uuidString.lowercased())/\(key)/\(id.uuidString.lowercased()).jpg"
        try await client.storage.from(SupabaseConfig.fotoBucket)
            .upload(pad, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
        let foto = BenchFoto(id: id, benchID: key, userID: gebruiker, path: pad, createdAt: Date())
        do {
            try await client.from("bench_photos").insert(foto).execute()
        } catch {
            _ = try? await client.storage.from(SupabaseConfig.fotoBucket).remove(paths: [pad])
            throw error
        }
        return foto
    }

    static func verwijder(_ foto: BenchFoto) async throws {
        try await client.from("bench_photos").delete().eq("id", value: foto.id.uuidString.lowercased()).execute()
        _ = try? await client.storage.from(SupabaseConfig.fotoBucket).remove(paths: [foto.path])
    }

    struct Melding: Encodable {
        var photoID: UUID
        enum CodingKeys: String, CodingKey { case photoID = "photo_id" }
    }

    static func meld(_ foto: BenchFoto) async throws {
        try await client.from("photo_reports").insert(Melding(photoID: foto.id)).execute()
    }
}

/// Houdt de foto's per bankje bij (opgehaald zodra je een bankje opent).
@MainActor
final class FotoStore: ObservableObject {
    @Published private(set) var fotos: [String: [BenchFoto]] = [:]
    weak var account: AccountStore?

    /// Alles wat in de galerij van dit bankje staat.
    func items(voor bench: Bench) -> [GalerijItem] {
        let online = (fotos[bench.serverID] ?? []).map(GalerijItem.online)
        if online.isEmpty, BankjesFotos.heeftFoto(voor: bench.id) { return [.lokaal(bench.id)] }
        return online
    }

    func laad(_ bench: Bench) async {
        guard let lijst = try? await FotoServer.haalOp(bankje: bench.serverID) else { return }
        fotos[bench.serverID] = lijst
    }

    func voegToe(_ image: UIImage, aan bench: Bench) async {
        guard let account, Netwerk.gedeeld.isOnline else {
            self.account?.melding = Netwerk.geenInternet
            return
        }
        guard let gebruiker = account.userID else {
            account.toonLogin = true
            return
        }
        do {
            let foto = try await FotoServer.upload(image, voorBankje: bench.serverID, gebruiker: gebruiker)
            fotos[bench.serverID, default: []].append(foto)
            Haptiek.licht()
        } catch {
            account.melding = Netwerk.melding(voor: error, standaard: "De foto toevoegen lukte niet. Probeer het opnieuw.")
        }
    }

    func verwijder(_ foto: BenchFoto) async {
        guard Netwerk.gedeeld.isOnline else {
            account?.melding = Netwerk.geenInternet
            return
        }
        do {
            try await FotoServer.verwijder(foto)
            fotos[foto.benchID]?.removeAll { $0.id == foto.id }
        } catch {
            account?.melding = Netwerk.melding(voor: error, standaard: "De foto verwijderen lukte niet. Probeer het opnieuw.")
        }
    }

    func meld(_ foto: BenchFoto) async {
        guard Netwerk.gedeeld.isOnline else {
            account?.melding = Netwerk.geenInternet
            return
        }
        do {
            try await FotoServer.meld(foto)
            fotos[foto.benchID]?.removeAll { $0.id == foto.id }   // gemeld = meteen verborgen
        } catch {
            account?.melding = Netwerk.melding(voor: error, standaard: "De foto melden lukte niet. Probeer het opnieuw.")
        }
    }
}

/// Haalt foto's van internet (of van de iPhone) en onthoudt ze.
@MainActor
final class FotoCache {
    static let shared = FotoCache()
    private let cache = NSCache<NSString, UIImage>()

    func afbeelding(voor item: GalerijItem) async -> UIImage? {
        switch item {
        case .lokaal(let id):
            return BankjesFotos.afbeelding(voor: id)
        case .online(let foto):
            let sleutel = foto.path as NSString
            if let bewaard = cache.object(forKey: sleutel) { return bewaard }
            guard let url = ServerBankjes.fotoURL(foto.path),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: sleutel)
            return image
        }
    }
}
