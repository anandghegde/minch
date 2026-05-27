import SwiftUI

public struct MinchHoverableModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false

    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = MinchRadius.m) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let elevation: MinchElevation = isHovered ? .hover : .resting
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background(shape.fill(elevation.background))
            .overlay(shape.strokeBorder(elevation.borderColor, lineWidth: elevation.borderWidth))
            .shadow(color: elevation.shadowColor, radius: elevation.shadowRadius, y: elevation.shadowY)
            .animation(reduceMotion ? nil : MinchMotion.snap, value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

public extension View {
    /// Applies the shared resting/hover elevation treatment.
    /// Consumers must not paint their own background or border on top of this.
    func minchHoverable(cornerRadius: CGFloat = MinchRadius.m) -> some View {
        modifier(MinchHoverableModifier(cornerRadius: cornerRadius))
    }
}
