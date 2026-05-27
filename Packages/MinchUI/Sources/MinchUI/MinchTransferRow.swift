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
    nonisolated static func clampedProgress(_ value: Double) -> Double {
        max(0, min(value, 1))
    }

    nonisolated static func percentText(_ progress: Double) -> String {
        let p = clampedProgress(progress) * 100
        return String(format: "%.0f%%", p)
    }

    nonisolated static func sizeText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Returns `nil` when there is no useful download speed to display.
    nonisolated static func speedText(_ bytesPerSecond: Int64) -> String? {
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
    nonisolated static func etaText(_ seconds: Int) -> String? {
        guard seconds > 0 else { return nil }
        if seconds < 60 { return "<1m left" }
        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m left" }
        if minutes == 0 { return "\(hours)h left" }
        return "\(hours)h \(minutes)m left"
    }


    struct ActionEnablement: Equatable, Sendable {
        public let play: Bool
        public let reveal: Bool
        public let copyLink: Bool
        public let delete: Bool

        public init(play: Bool, reveal: Bool, copyLink: Bool, delete: Bool) {
            self.play = play
            self.reveal = reveal
            self.copyLink = copyLink
            self.delete = delete
        }
    }

    /// Per-phase action gating. Icons stay in the cluster either way — `false`
    /// means dimmed (`.tertiary` + `.disabled(true)`) so the row never reflows.
    nonisolated static func actionEnablement(phase: MinchStatusPhase, hasPlayableMedia: Bool) -> ActionEnablement {
        switch phase {
        case .idle:
            return ActionEnablement(play: false, reveal: false, copyLink: false, delete: true)
        case .queued, .active, .paused, .error:
            return ActionEnablement(play: false, reveal: false, copyLink: true, delete: true)
        case .done:
            return ActionEnablement(play: hasPlayableMedia, reveal: true, copyLink: true, delete: true)
        }
    }


    /// Short relative time suffix used after "added " in the done-phase meta line.
    /// Returns "just now" / "3m" / "3h" / "2d".
    nonisolated static func relativeAddedShort(from date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(date)))
        if elapsed < 60 { return "just now" }
        let minutes = elapsed / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }

    /// Plain-text version of the adaptive meta line. The view body builds the
    /// styled HStack from the same inputs; this is the testable kernel.
    nonisolated static func metaPlainText(
        phase: MinchStatusPhase,
        sizeBytes: Int64,
        downloadSpeed: Int64,
        progress: Double,
        etaSeconds: Int?,
        queuePosition: Int?,
        errorMessage: String?,
        addedAt: Date?,
        now: Date = Date()
    ) -> String {
        switch phase {
        case .idle:
            return sizeText(sizeBytes)

        case .queued:
            if let q = queuePosition { return "Queued · #\(q)" }
            return "Queued"

        case .active:
            var parts: [String] = [sizeText(sizeBytes)]
            if let speed = speedText(downloadSpeed) { parts.append(speed) }
            if let eta = etaSeconds.flatMap({ etaText($0) }) { parts.append(eta) }
            return parts.joined(separator: " · ")

        case .paused:
            return "Paused · \(sizeText(sizeBytes)) · \(percentText(progress))"

        case .error:
            return errorMessage ?? "Error"

        case .done:
            if let added = addedAt {
                return "\(sizeText(sizeBytes)) · added \(relativeAddedShort(from: added, now: now)) ago"
            }
            return sizeText(sizeBytes)
        }
    }


    /// Returns the 0-based character indices into `name` of separator
    /// characters (`.`, `_`, `-`) that sit *between* two word characters.
    /// These are the indices the view body renders at reduced opacity.
    nonisolated static func dimmedSeparatorIndices(_ name: String) -> Set<Int> {
        let chars = Array(name)
        guard chars.count >= 3 else { return [] }
        var out: Set<Int> = []
        for i in 1..<(chars.count - 1) {
            let c = chars[i]
            guard c == "." || c == "_" || c == "-" else { continue }
            let prev = chars[i - 1]
            let next = chars[i + 1]
            if MinchTransferRow.isNameWordChar(prev), MinchTransferRow.isNameWordChar(next) {
                out.insert(i)
            }
        }
        return out
    }

    /// Builds an `AttributedString` with `.tracking(-0.2)` and per-character
    /// `.foregroundColor` overrides at 0.45 opacity for any separator returned
    /// by `dimmedSeparatorIndices`.
    nonisolated static func nameAttributedString(_ name: String) -> AttributedString {
        var attr = AttributedString(name)
        attr.tracking = -0.2
        let dims = dimmedSeparatorIndices(name)
        guard !dims.isEmpty else { return attr }
        let chars = Array(name)
        let dimColor = Color.primary.opacity(0.45)
        for index in dims {
            let target = String(chars[index])
            if let range = attr.range(of: target, options: [.literal]) {
                var current = range
                var charsBefore = MinchTransferRow.utf16Distance(from: attr.startIndex, to: current.lowerBound, in: attr)
                while charsBefore != index {
                    let next = attr[current.upperBound..<attr.endIndex].range(of: target, options: [.literal])
                    guard let next else { break }
                    current = next
                    charsBefore = MinchTransferRow.utf16Distance(from: attr.startIndex, to: current.lowerBound, in: attr)
                }
                if charsBefore == index {
                    attr[current].foregroundColor = dimColor
                }
            }
        }
        return attr
    }

    /// Internal — character (not UTF-16) distance between two AttributedString indices.
    nonisolated static func utf16Distance(from start: AttributedString.Index,
                                          to end: AttributedString.Index,
                                          in attr: AttributedString) -> Int {
        attr.characters.distance(from: start, to: end)
    }

    /// Word char for separator-dimming purposes: ASCII letter or digit.
    nonisolated static func isNameWordChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
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
