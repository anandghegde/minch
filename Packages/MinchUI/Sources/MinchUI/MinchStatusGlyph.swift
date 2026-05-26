import SwiftUI

/// Logical phase a transfer is in, decoupled from MinchKit so MinchUI stays leaf-level.
public enum MinchStatusPhase: String, Sendable, CaseIterable {
    case idle
    case queued
    case active
    case paused
    case error
    case done
}

public extension MinchStatusPhase {
    /// Map a `TransferStatus.rawValue` string to a glyph phase.
    init(transferStatusRaw raw: String) {
        switch raw {
        case "queued": self = .queued
        case "downloading", "seeding": self = .active
        case "paused": self = .paused
        case "error": self = .error
        case "done": self = .done
        default: self = .idle
        }
    }

    var tint: Color {
        switch self {
        case .idle: Color.white.opacity(0.4)
        case .queued: Color.secondary
        case .active: .minchCurrent
        case .paused: .minchWarning
        case .error: .minchDanger
        case .done: .minchSuccess
        }
    }

    var label: String {
        switch self {
        case .idle: "Idle"
        case .queued: "Queued"
        case .active: "Downloading"
        case .paused: "Paused"
        case .error: "Error"
        case .done: "Done"
        }
    }
}

/// A small status indicator dot used in transfer rows and the menu bar extra.
public struct MinchStatusGlyph: View {
    private let phase: MinchStatusPhase

    public init(_ phase: MinchStatusPhase) { self.phase = phase }

    public var body: some View {
        Circle()
            .fill(phase.tint)
            .frame(width: 8, height: 8)
            .accessibilityLabel(phase.label)
    }
}

#Preview {
    HStack {
        ForEach(MinchStatusPhase.allCases, id: \.self) { phase in
            VStack(spacing: 4) {
                MinchStatusGlyph(phase)
                Text(phase.label).font(.minchCaption).foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .background(Color.minchSurfacePrimary)
    .preferredColorScheme(.dark)
}
