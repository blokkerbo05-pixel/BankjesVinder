import SwiftUI
import UIKit

// Dezelfde kleuren als de web-versie: bosgroen, verweerd hout en groengrijs.
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    static let appBg    = dynamic(0xEEF1EC, 0x141A16)
    static let surface  = dynamic(0xFFFFFF, 0x1D2520)
    static let ink      = dynamic(0x1E2B22, 0xE6ECE7)
    static let muted    = dynamic(0x5D6B61, 0x9AA79E)
    static let line     = dynamic(0xD3DACF, 0x2E3A32)
    static let wood     = dynamic(0xA3561C, 0xE39A5C)
    static let woodSoft = dynamic(0xF3E3D3, 0x3A2A1C)
    static let leaf     = dynamic(0x2F6B45, 0x7FC398)
    static let leafSoft = dynamic(0xDDEBE0, 0x1F3427)
    static let danger   = dynamic(0xA3352B, 0xF08A7E)
}

extension Font {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .default) }
    static func cardTitle(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .default) }
}
