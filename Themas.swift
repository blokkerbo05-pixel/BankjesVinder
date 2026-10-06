import SwiftUI

// ─────────────────────────────────────────────────────────────
//  THEMA'S: elke kleurenset ("preset") staat hier als één blok.
//  Een nieuw thema toevoegen? Kopieer een blok, geef het een nieuwe naam
//  en kleuren, en zet het in de lijst `Themas.alle` onderaan.
//  Elk thema heeft een lichte en een donkere kleurenset.
// ─────────────────────────────────────────────────────────────

/// De kleuren van één thema in één stand (licht of donker), als hex-waarden.
struct Palet {
    var appBg: UInt32      // achtergrond van de app
    var surface: UInt32    // kaartjes en knoppen
    var ink: UInt32        // tekst
    var muted: UInt32      // grijzere tekst
    var line: UInt32       // randjes
    var wood: UInt32       // hout-accent (eigen bankjes, plusknop)
    var woodSoft: UInt32   // zachte houtkleur (meldingen)
    var leaf: UInt32       // hoofdkleur (knoppen, bankjes)
    var leafSoft: UInt32   // zachte hoofdkleur (labels)
    var danger: UInt32     // waarschuwing / niet goed
}

struct Thema: Identifiable {
    let id: String
    let naam: String
    let licht: Palet
    let donker: Palet
}

enum Themas {

    // MARK: Bos (de oorspronkelijke kleuren)
    static let bos = Thema(
        id: "bos", naam: "Bos",
        licht: Palet(appBg: 0xEEF1EC, surface: 0xFFFFFF, ink: 0x1E2B22, muted: 0x5D6B61, line: 0xD3DACF,
                     wood: 0xA3561C, woodSoft: 0xF3E3D3, leaf: 0x2F6B45, leafSoft: 0xDDEBE0, danger: 0xA3352B),
        donker: Palet(appBg: 0x141A16, surface: 0x1D2520, ink: 0xE6ECE7, muted: 0x9AA79E, line: 0x2E3A32,
                      wood: 0xE39A5C, woodSoft: 0x3A2A1C, leaf: 0x7FC398, leafSoft: 0x1F3427, danger: 0xF08A7E))

    // MARK: Nacht (diepblauw en indigo)
    static let nacht = Thema(
        id: "nacht", naam: "Nacht",
        licht: Palet(appBg: 0xE9EAF4, surface: 0xFFFFFF, ink: 0x1B1F3A, muted: 0x5A5F80, line: 0xCFD2E6,
                     wood: 0xB5651D, woodSoft: 0xF6E8CF, leaf: 0x4352C4, leafSoft: 0xDFE2F8, danger: 0xB03A48),
        donker: Palet(appBg: 0x0E1020, surface: 0x171A30, ink: 0xE7E9F8, muted: 0x9A9FC4, line: 0x2A2E4F,
                      wood: 0xF0B35A, woodSoft: 0x3A2D17, leaf: 0x8E9BFF, leafSoft: 0x22264A, danger: 0xFF8A96))

    // MARK: Zand (warm beige met terracotta)
    static let zand = Thema(
        id: "zand", naam: "Zand",
        licht: Palet(appBg: 0xF6EFE4, surface: 0xFFFDF8, ink: 0x3A2E22, muted: 0x7A6A58, line: 0xE3D6C2,
                     wood: 0xB5532A, woodSoft: 0xF6DFD0, leaf: 0x66742F, leafSoft: 0xEAEBCF, danger: 0xA83A2B),
        donker: Palet(appBg: 0x1D1812, surface: 0x28211A, ink: 0xF1E8DA, muted: 0xB3A28C, line: 0x3C3227,
                      wood: 0xE59A6A, woodSoft: 0x3F2A1D, leaf: 0xB7C46A, leafSoft: 0x2C3017, danger: 0xF08A7E))

    // MARK: Zee (blauw en teal)
    static let zee = Thema(
        id: "zee", naam: "Zee",
        licht: Palet(appBg: 0xE7F1F4, surface: 0xFFFFFF, ink: 0x12303A, muted: 0x4F6D77, line: 0xC6DCE2,
                     wood: 0xC4623A, woodSoft: 0xF8E2D6, leaf: 0x0E7C86, leafSoft: 0xD5EEF0, danger: 0xB3392F),
        donker: Palet(appBg: 0x0B1A20, surface: 0x12262E, ink: 0xE1F2F5, muted: 0x8FB0B9, line: 0x21404A,
                      wood: 0xF0A07A, woodSoft: 0x3A2418, leaf: 0x5FD0D8, leafSoft: 0x12363B, danger: 0xF08A7E))

    /// Alle thema's, in de volgorde waarin ze in Instellingen staan.
    static let alle: [Thema] = [bos, nacht, zand, zee]

    /// Het thema dat nu gekozen is. De kleuren in Theme.swift kijken hier steeds naar.
    static var huidig: Thema = bos

    static func thema(met id: String) -> Thema {
        alle.first { $0.id == id } ?? bos
    }
}
