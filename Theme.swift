import SwiftUI
import UIKit

// De kleuren van de app. Welke kleurenset gebruikt wordt (Bos, Nacht, Zand, Zee) staat in Themas.swift.
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

    init(hex: UInt32) {
        self.init(UIColor(hex: hex))
    }

    /// Een kleur die meeverandert met het gekozen thema (Themas.swift) en met licht/donker.
    static func themed(_ pick: @escaping (Palet) -> UInt32) -> Color {
        Color(UIColor { traits in
            let thema = Themas.huidig
            return UIColor(hex: pick(traits.userInterfaceStyle == .dark ? thema.donker : thema.licht))
        })
    }

    static let appBg    = themed { $0.appBg }
    static let surface  = themed { $0.surface }
    static let ink      = themed { $0.ink }
    static let muted    = themed { $0.muted }
    static let line     = themed { $0.line }
    static let wood     = themed { $0.wood }
    static let woodSoft = themed { $0.woodSoft }
    static let leaf     = themed { $0.leaf }
    static let leafSoft = themed { $0.leafSoft }
    static let danger   = themed { $0.danger }
}

extension Font {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .default) }
    static func cardTitle(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .default) }
}
