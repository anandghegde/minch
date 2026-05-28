import SwiftUI

/// A 24pt phase-aware progress ring with the existing 8pt `MinchStatusGlyph`
/// centered inside it. The dot is reused verbatim; phase drives ring tint and
/// dot motion. Sits in a 28pt visual slot so it balances the icon cluster on
/// the right of `MinchTransferRow`.
public struct MinchTransferProgressRing: View {
    private let phase: MinchStatusPhase
    private let progress: Double

    private static let diameter: CGFloat = 24
    private static let strokeWidth: CGFloat = 2

    public init(phase: MinchStatusPhase, progress: Double) {
        self.phase = phase
        self.progress = MinchTransferRow.clampedProgress(progress)
    }

    @State private var pulseOpacity: Double = 1.0
    @State private var shakeOffset: CGFloat = 0

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.minchHairline, lineWidth: Self.strokeWidth)
                .frame(width: Self.diameter, height: Self.diameter)

            if shouldShowFill {
                Circle()
                    .trim(from: 0, to: trimEnd)
                    .stroke(ringTint, style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: Self.diameter, height: Self.diameter)
            }

            MinchStatusGlyph(phase)
                .opacity(phase == .active ? pulseOpacity : 1.0)
                .offset(x: shakeOffset)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
        .onAppear { applyMotionForCurrentPhase() }
        .onChange(of: phase) { _, _ in applyMotionForCurrentPhase() }
    }

    private func applyMotionForCurrentPhase() {
        pulseOpacity = 1.0
        shakeOffset = 0
        switch phase {
        case .active:
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.7
            }
        case .error:
            withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
                shakeOffset = 2
            }
        default:
            break
        }
    }

    private var trimEnd: CGFloat {
        switch phase {
        case .done: return 1
        default: return CGFloat(progress)
        }
    }

    private var shouldShowFill: Bool {
        switch phase {
        case .done: return true
        default: return progress > 0
        }
    }

    private var ringTint: Color {
        switch phase {
        case .active: return .minchCurrent
        case .done: return .minchSuccess
        case .paused: return .minchWarning
        case .error: return .minchDanger
        case .queued: return .secondary
        case .idle: return .white.opacity(0.4)
        }
    }
}

#Preview {
    HStack(spacing: MinchSpacing.l) {
        ForEach(MinchStatusPhase.allCases, id: \.self) { phase in
            VStack(spacing: 4) {
                MinchTransferProgressRing(phase: phase, progress: 0.62)
                Text(phase.label).font(.minchCaption).foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .background(Color.minchSurfacePrimary)
    .preferredColorScheme(.dark)
}
