import SwiftUI

public enum MinchSpacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum MinchRadius {
    public static let s: CGFloat = 6
    public static let m: CGFloat = 10
    public static let l: CGFloat = 16
}

public extension Color {
    static let minchBolt = Color(red: 0.24, green: 0.48, blue: 1.00)
    static let minchCurrent = Color(red: 0.36, green: 0.89, blue: 0.97)
    static let minchSuccess = Color(red: 0.30, green: 0.78, blue: 0.45)
    static let minchWarning = Color(red: 0.95, green: 0.69, blue: 0.20)
    static let minchDanger = Color(red: 0.95, green: 0.34, blue: 0.36)

    // Surface ramp (v2 — opaque z-stack from window to overlay).
    static let minchSurfaceWindow     = Color(white: 0.05)
    static let minchSurfaceSidebar    = Color(white: 0.06)
    static let minchSurfacePrimary    = Color(white: 0.08)
    static let minchSurfaceCard       = Color(white: 0.10)
    static let minchSurfaceCardHover  = Color(white: 0.13)
    static let minchSurfaceOverlay    = Color(white: 0.14)

    static let minchSurfaceSunken     = Color.white.opacity(0.04)
    static let minchHairline          = Color.white.opacity(0.06)
    static let minchSelection         = Color.minchBolt.opacity(0.18)
}

public extension Font {
    static let minchDisplay   = Font.system(size: 28, weight: .bold)
    static let minchTitle     = Font.system(size: 20, weight: .bold)
    static let minchHeadline  = Font.system(size: 15, weight: .semibold)
    static let minchBody      = Font.system(size: 13, weight: .regular)
    static let minchMetadata  = Font.system(size: 11, weight: .medium)
    static let minchCallout   = Font.system(size: 12, weight: .regular)
    static let minchCaption   = Font.system(size: 11, weight: .regular)
    static let minchMono      = Font.system(size: 12, weight: .regular, design: .monospaced)
}

public enum MinchMotion {
    public static let snap: Animation   = .snappy(duration: 0.20, extraBounce: 0)
    public static let smooth: Animation = .smooth(duration: 0.30, extraBounce: 0)
}

public struct MinchElevation: Sendable {
    public let background: Color
    public let borderColor: Color
    public let borderWidth: CGFloat
    public let shadowColor: Color
    public let shadowRadius: CGFloat
    public let shadowY: CGFloat
}

public extension MinchElevation {
    static let resting = MinchElevation(
        background: .minchSurfaceCard,
        borderColor: .minchHairline,
        borderWidth: 1,
        shadowColor: .clear,
        shadowRadius: 0,
        shadowY: 0
    )

    static let hover = MinchElevation(
        background: .minchSurfaceCardHover,
        borderColor: Color.white.opacity(0.10),
        borderWidth: 1,
        shadowColor: Color.black.opacity(0.18),
        shadowRadius: 6,
        shadowY: 1
    )
}
