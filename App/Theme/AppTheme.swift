import SwiftUI

enum AppTheme {
    enum Colors {
        static let primary = Color(hex: 0x4B8DF8)
        static let background = Color(hex: 0xF3F5F9)
        static let card = Color.white
        static let textPrimary = Color(hex: 0x1E293B)
        static let textSecondary = Color(hex: 0x64748B)
        static let textMuted = Color(hex: 0x94A3B8)
        static let success = Color(hex: 0x22C55E)
        static let warning = Color(hex: 0xF59E0B)
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let chip: CGFloat = 999
    }

    enum Spacing {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
    }

    static let shadow = ShadowStyle(color: .black.opacity(0.08), radius: 20, x: 0, y: 6)
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func appCard() -> some View {
        shadow(
            color: AppTheme.shadow.color,
            radius: AppTheme.shadow.radius,
            x: AppTheme.shadow.x,
            y: AppTheme.shadow.y
        )
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
