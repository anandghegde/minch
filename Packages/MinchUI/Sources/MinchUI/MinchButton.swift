import SwiftUI

public struct MinchButtonStyle: ButtonStyle {
    public enum Variant: Sendable { case primary, secondary, ghost, destructive }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let variant: Variant
    public init(_ variant: Variant = .primary) { self.variant = variant }

    public func makeBody(configuration: Configuration) -> some View {
        let base = configuration.label
            .font(.minchHeadline)
            .padding(.horizontal, MinchSpacing.m)
            .padding(.vertical, MinchSpacing.s)
            .foregroundStyle(foreground)

        return composedBackground(base: base, configuration: configuration)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(reduceMotion ? nil : MinchMotion.snap, value: configuration.isPressed)
    }

    @ViewBuilder
    private func composedBackground<V: View>(base: V, configuration: Configuration) -> some View {
        switch variant {
        case .secondary:
            base.minchHoverable(cornerRadius: MinchRadius.m)
        case .primary, .ghost, .destructive:
            base
                .background(background(pressed: configuration.isPressed))
                .clipShape(RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous))
        }
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
        case .ghost:
            Color.clear
        case .destructive:
            Color.minchDanger.opacity(0.85)
        case .secondary:
            EmptyView()
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
