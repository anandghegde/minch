import SwiftUI

/// The Minch wordmark — used in onboarding, about screen, splash.
public struct MinchWordmark: View {
    private let size: CGFloat
    public init(size: CGFloat = 48) { self.size = size }

    public var body: some View {
        HStack(spacing: size * 0.12) {
            Image(systemName: "bolt.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.minchBolt, .minchCurrent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .font(.system(size: size, weight: .semibold))
            Text("Minch")
                .font(.system(size: size * 0.85, weight: .semibold, design: .default))
                .tracking(size * 0.04)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Minch")
    }
}

#Preview("Light") {
    MinchWordmark()
        .padding()
        .background(.background)
}

#Preview("Dark") {
    MinchWordmark()
        .padding()
        .background(.background)
        .preferredColorScheme(.dark)
}
