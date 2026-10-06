import Foundation
import Supabase

/// ─────────────────────────────────────────────────────────────
///  SUPABASEINSTELLINGEN: waar de online database zit.
///  De publishable key is bedoeld om in een app te staan; de beveiliging
///  zit in de regels (Row Level Security) in supabase/schema.sql.
///  Zet hier NOOIT een "secret" key neer.
/// ─────────────────────────────────────────────────────────────
enum SupabaseConfig {
    static let url = URL(string: "https://pbpvshsdbxxoxybxccqa.supabase.co")!
    static let publishableKey = "sb_publishable_qciB-uDQc-3btY_FONrRZA_oJa27uq5"

    /// Naam van de opslagmap voor foto's (zie schema.sql).
    static let fotoBucket = "bankjes-fotos"

    /// Eén gedeelde verbinding voor de hele app. De ingelogde sessie wordt door het package veilig bewaard.
    static let client = SupabaseClient(supabaseURL: url, supabaseKey: publishableKey)
}
