import SwiftUI

/// A 64pt transfer row: status glyph · name + meta + progress · percent · chevron.
///
/// MinchUI stays decoupled from MinchPersistence by taking primitives. Call sites
/// adapt `StoredTransfer` or `Transfer` to these fields.
public struct MinchTransferRow: View {
    public struct Content: Equatable, Sendable {
        public let name: String
        public let phase: MinchStatusPhase
        public let sizeBytes: Int64
        public let downloadSpeed: Int64
        public let progress: Double
        public let seeds: Int?
        public let peers: Int?

        public init(name: String, phase: MinchStatusPhase, sizeBytes: Int64, downloadSpeed: Int64, progress: Double, seeds: Int? = nil, peers: Int? = nil) {
            self.name = name
            self.phase = phase
            self.sizeBytes = sizeBytes
            self.downloadSpeed = downloadSpeed
            self.progress = progress
            self.seeds = seeds
            self.peers = peers
        }
    }

    private let content: Content
    private let isExpanded: Bool
    private let onToggle: (() -> Void)?

    public init(content: Content, isExpanded: Bool = false, onToggle: (() -> Void)? = nil) {
        self.content = content
        self.isExpanded = isExpanded
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: { onToggle?() }) {
            HStack(spacing: MinchSpacing.l) {
                MinchStatusGlyph(content.phase)

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.name)
                        .font(.minchHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: MinchSpacing.s) {
                        Text(content.phase.label)
                            .font(.minchCaption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.minchCaption)
                            .foregroundStyle(.tertiary)
                        Text(MinchTransferRow.sizeText(content.sizeBytes))
                            .font(.minchCaption)
                            .foregroundStyle(.secondary)
                        if let speed = MinchTransferRow.speedText(content.downloadSpeed) {
                            Text("·")
                                .font(.minchCaption)
                                .foregroundStyle(.tertiary)
                            Text(speed)
                                .font(.minchMono)
                                .foregroundStyle(Color.minchCurrent)
                        }
                        if let swarm = MinchTransferRow.swarmText(seeds: content.seeds, peers: content.peers, phase: content.phase) {
                            Text("·")
                                .font(.minchCaption)
                                .foregroundStyle(.tertiary)
                            Text(swarm)
                                .font(.minchCaption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ProgressView(value: MinchTransferRow.clampedProgress(content.progress))
                        .progressViewStyle(.linear)
                        .tint(content.phase == .done ? Color.minchSuccess : Color.minchBolt)
                }

                Spacer()

                Text(MinchTransferRow.percentText(content.progress))
                    .font(.minchMono)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if onToggle != nil {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(MinchSpacing.l)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                .fill(Color.minchSurfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                .stroke(Color.minchHairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        "\(content.name), \(content.phase.label), \(MinchTransferRow.percentText(content.progress))"
    }
}

// MARK: - Formatting helpers (exposed for tests)

public extension MinchTransferRow {
    static func clampedProgress(_ value: Double) -> Double {
        max(0, min(value, 1))
    }

    static func percentText(_ progress: Double) -> String {
        let p = clampedProgress(progress) * 100
        return String(format: "%.0f%%", p)
    }

    static func sizeText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Returns `nil` when there is no useful download speed to display.
    static func speedText(_ bytesPerSecond: Int64) -> String? {
        guard bytesPerSecond > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytesPerSecond, countStyle: .binary) + "/s"
    }

    /// Returns "12 seeders · 3 peers" only when seeds is known and the
    /// transfer is in an active (downloading/seeding) phase. webdl rows
    /// pass `nil` and are skipped entirely.
    static func swarmText(seeds: Int?, peers: Int?, phase: MinchStatusPhase) -> String? {
        guard let seeds, phase == .active else { return nil }
        var parts = ["\(seeds) seeders"]
        if let peers, peers > 0 { parts.append("\(peers) peers") }
        return parts.joined(separator: " · ")
    }

    /// Returns "3m left" / "<1m left" / "1h 15m left". `nil` when omitted.
    static func etaText(_ seconds: Int) -> String? {
        guard seconds > 0 else { return nil }
        if seconds < 60 { return "<1m left" }
        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m left" }
        if minutes == 0 { return "\(hours)h left" }
        return "\(hours)h \(minutes)m left"
    }
}

#Preview {
    VStack(spacing: MinchSpacing.s) {
        MinchTransferRow(content: .init(
            name: "The.Big.Lebowski.1998.1080p.BluRay.x264.mkv",
            phase: .active,
            sizeBytes: 8_500_000_000,
            downloadSpeed: 12_500_000,
            progress: 0.62
        ), onToggle: {})

        MinchTransferRow(content: .init(
            name: "Solaris.1972.Criterion.2160p.mkv",
            phase: .done,
            sizeBytes: 18_300_000_000,
            downloadSpeed: 0,
            progress: 1.0
        ))

        MinchTransferRow(content: .init(
            name: "Mishandled.tracker.torrent",
            phase: .error,
            sizeBytes: 1_200_000_000,
            downloadSpeed: 0,
            progress: 0.12
        ))
    }
    .padding()
    .background(Color.minchSurfacePrimary)
    .preferredColorScheme(.dark)
}
