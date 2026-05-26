import SwiftUI

public struct MinchButtonStyle: ButtonStyle {
    public enum Variant: Sendable { case primary, secondary, ghost, destructive }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let variant: Variant
    public init(_ variant: Variant = .primary) { self.variant = variant }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.minchHeadline)
            .padding(.horizontal, MinchSpacing.m)
            .padding(.vertical, MinchSpacing.s)
            .background(background(pressed: configuration.isPressed))
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [.minchBolt, .minchCurrent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            Color.secondary.opacity(0.15)
        case .ghost:
            Color.clear
        case .destructive:
            Color.minchDanger.opacity(0.85)
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .destructive: .white
        case .secondary, .ghost: .primary
        }
    }
}

public extension ButtonStyle where Self == MinchButtonStyle {
    static func minch(_ variant: MinchButtonStyle.Variant = .primary) -> MinchButtonStyle {
        MinchButtonStyle(variant)
    }
}
