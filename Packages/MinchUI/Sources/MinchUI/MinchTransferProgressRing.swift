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
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    private var trimEnd: CGFloat {
        switch phase {
        case .done: return 1
        case .paused, .error, .active: return CGFloat(progress)
        case .queued, .idle: return 0
        }
    }

    private var shouldShowFill: Bool {
        switch phase {
        case .done: return true
        case .active, .paused, .error: return progress > 0
        case .queued, .idle: return false
        }
    }

    private var ringTint: Color {
        switch phase {
        case .active: return .minchCurrent
        case .done: return .minchSuccess
        case .paused: return .minchWarning
        case .error: return .minchDanger
        case .queued, .idle: return .minchHairline
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
