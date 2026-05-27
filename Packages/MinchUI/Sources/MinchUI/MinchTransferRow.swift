import SwiftUI

/// A 64pt transfer row: status glyph · name + meta + progress · percent · chevron.
///
/// MinchUI stays decoupled from MinchPersistence by taking primitives. Call sites
/// adapt `StoredTransfer` or `Transfer` to these fields.
public struct MinchTransferRow: View {
    public struct Content: Equatable, Sendable {
        public let id: String
        public let name: String
        public let phase: MinchStatusPhase
        public let sizeBytes: Int64
        public let downloadSpeed: Int64
        public let progress: Double
        public let seeds: Int?
        public let peers: Int?
        public let etaSeconds: Int?
        public let queuePosition: Int?
        public let errorMessage: String?
        public let addedAt: Date?
        public let hasPlayableMedia: Bool
        public let files: [File]

        public init(
            id: String = "",
            name: String,
            phase: MinchStatusPhase,
            sizeBytes: Int64,
            downloadSpeed: Int64,
            progress: Double,
            seeds: Int? = nil,
            peers: Int? = nil,
            etaSeconds: Int? = nil,
            queuePosition: Int? = nil,
            errorMessage: String? = nil,
            addedAt: Date? = nil,
            hasPlayableMedia: Bool = false,
            files: [File] = []
        ) {
            self.id = id
            self.name = name
            self.phase = phase
            self.sizeBytes = sizeBytes
            self.downloadSpeed = downloadSpeed
            self.progress = progress
            self.seeds = seeds
            self.peers = peers
            self.etaSeconds = etaSeconds
            self.queuePosition = queuePosition
            self.errorMessage = errorMessage
            self.addedAt = addedAt
            self.hasPlayableMedia = hasPlayableMedia
            self.files = files
        }

        public struct File: Equatable, Sendable, Identifiable {
            public let id: String
            public let name: String
            public let sizeBytes: Int64
            public let isPlayable: Bool
            public let isDownloaded: Bool
            public let canStream: Bool
            public let downloadProgress: Double?
            public let isCopyingLink: Bool

            public init(
                id: String,
                name: String,
                sizeBytes: Int64,
                isPlayable: Bool,
                isDownloaded: Bool = false,
                canStream: Bool = false,
                downloadProgress: Double? = nil,
                isCopyingLink: Bool = false
            ) {
                self.id = id
                self.name = name
                self.sizeBytes = sizeBytes
                self.isPlayable = isPlayable
                self.isDownloaded = isDownloaded
                self.canStream = canStream
                self.downloadProgress = downloadProgress
                self.isCopyingLink = isCopyingLink
            }
        }
    }

    private let content: Content
    private let isExpanded: Bool
    private let onToggle: (() -> Void)?
    private let onPlay: ((Content.File?) -> Void)?
    private let onReveal: ((Content.File?) -> Void)?
    private let onCopyLink: (() -> Void)?
    private let onDelete: (() -> Void)?
    private let onStream: ((Content.File) -> Void)?
    private let onDownload: ((Content.File) -> Void)?
    private let onCancelDownload: ((Content.File) -> Void)?
    private let onCopyFileLink: ((Content.File) -> Void)?

    public init(
        content: Content,
        isExpanded: Bool = false,
        onToggle: (() -> Void)? = nil,
        onPlay: ((Content.File?) -> Void)? = nil,
        onReveal: ((Content.File?) -> Void)? = nil,
        onCopyLink: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onStream: ((Content.File) -> Void)? = nil,
        onDownload: ((Content.File) -> Void)? = nil,
        onCancelDownload: ((Content.File) -> Void)? = nil,
        onCopyFileLink: ((Content.File) -> Void)? = nil
    ) {
        self.content = content
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.onPlay = onPlay
        self.onReveal = onReveal
        self.onCopyLink = onCopyLink
        self.onDelete = onDelete
        self.onStream = onStream
        self.onDownload = onDownload
        self.onCancelDownload = onCancelDownload
        self.onCopyFileLink = onCopyFileLink
    }

    public var body: some View {
        VStack(spacing: 0) {
            collapsedRow

            if isExpanded {
                VStack(spacing: 0) {
                    Divider().background(Color.minchHairline)
                    if content.files.isEmpty {
                        Text("No files yet.")
                            .font(.minchCaption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, MinchSpacing.l)
                            .padding(.vertical, MinchSpacing.s)
                    } else {
                        ForEach(content.files) { file in
                            FileRow(
                                file: file,
                                onPlay: file.isPlayable ? { onPlay?(file) } : nil,
                                onReveal: { onReveal?(file) },
                                onStream: onStream.map { cb in { cb(file) } },
                                onDownload: onDownload.map { cb in { cb(file) } },
                                onCancelDownload: onCancelDownload.map { cb in { cb(file) } },
                                onCopyFileLink: onCopyFileLink.map { cb in { cb(file) } }
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                .fill(Color.minchSurfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                .stroke(Color.minchHairline, lineWidth: 1)
        )
        .animation(MinchMotion.smooth, value: isExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var collapsedRow: some View {
        HStack(spacing: MinchSpacing.l) {
            MinchTransferProgressRing(phase: content.phase, progress: content.progress)

            VStack(alignment: .leading, spacing: 4) {
                Text(MinchTransferRow.nameAttributedString(content.name))
                    .font(.minchHeadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                metaLine
            }

            Spacer()

            actionCluster

            if onToggle != nil {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
        }
        .padding(MinchSpacing.l)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .onTapGesture { onToggle?() }
    }

    private var metaLine: some View {
        Group {
            switch content.phase {
            case .idle:
                Text(MinchTransferRow.sizeText(content.sizeBytes))
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)

            case .queued:
                HStack(spacing: MinchSpacing.s) {
                    Text("Queued")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                    if let q = content.queuePosition {
                        Text("·")
                            .font(.minchCaption)
                            .foregroundStyle(.tertiary)
                        Text("#\(q)")
                            .font(.minchCaption)
                            .foregroundStyle(.secondary)
                    }
                }

            case .active:
                HStack(spacing: MinchSpacing.s) {
                    Text(MinchTransferRow.sizeText(content.sizeBytes))
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                    if let speed = MinchTransferRow.speedText(content.downloadSpeed) {
                        Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                        Text(speed).font(.minchMono).foregroundStyle(Color.minchCurrent)
                    }
                    if let eta = content.etaSeconds.flatMap({ MinchTransferRow.etaText($0) }) {
                        Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                        Text(eta).font(.minchCaption).foregroundStyle(.secondary)
                    }
                }

            case .paused:
                HStack(spacing: MinchSpacing.s) {
                    Text("Paused").font(.minchCaption).foregroundStyle(.secondary)
                    Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                    Text(MinchTransferRow.sizeText(content.sizeBytes))
                        .font(.minchCaption).foregroundStyle(.secondary)
                    Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                    Text(MinchTransferRow.percentText(content.progress))
                        .font(.minchCaption).foregroundStyle(.secondary)
                }

            case .error:
                Text(content.errorMessage ?? "Error")
                    .font(.minchCaption)
                    .foregroundStyle(Color.minchDanger)
                    .lineLimit(1)

            case .done:
                HStack(spacing: MinchSpacing.s) {
                    Text(MinchTransferRow.sizeText(content.sizeBytes))
                        .font(.minchCaption).foregroundStyle(.secondary)
                    if let added = content.addedAt {
                        Text("·").font(.minchCaption).foregroundStyle(.tertiary)
                        Text("added \(MinchTransferRow.relativeAddedShort(from: added)) ago")
                            .font(.minchCaption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var actionCluster: some View {
        let enablement = MinchTransferRow.actionEnablement(
            phase: content.phase, hasPlayableMedia: content.hasPlayableMedia
        )
        let isCancelling = content.phase == .active || content.phase == .queued || content.phase == .paused
        return HStack(spacing: MinchSpacing.s) {
            actionIcon(
                system: "play.fill",
                help: "Play",
                enabled: enablement.play,
                action: { onPlay?(nil) }
            )
            actionIcon(
                system: "folder",
                help: "Reveal in Finder",
                enabled: enablement.reveal,
                action: { onReveal?(nil) }
            )
            actionIcon(
                system: "link",
                help: "Copy link",
                enabled: enablement.copyLink,
                action: { onCopyLink?() }
            )
            actionIcon(
                system: "trash",
                help: isCancelling ? "Cancel" : "Remove",
                enabled: enablement.delete,
                action: { onDelete?() }
            )
        }
    }

    private func actionIcon(
        system: String,
        help: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.minchCaption)
                .foregroundStyle(enabled ? .secondary : .tertiary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(help)
    }

    private var accessibilityLabel: String {
        "\(content.name), \(content.phase.label), \(MinchTransferRow.percentText(content.progress))"
    }

    private struct FileRow: View {
        let file: Content.File
        let onPlay: (() -> Void)?
        let onReveal: (() -> Void)?
        let onStream: (() -> Void)?
        let onDownload: (() -> Void)?
        let onCancelDownload: (() -> Void)?
        let onCopyFileLink: (() -> Void)?

        var body: some View {
            HStack(spacing: MinchSpacing.s) {
                // Leading icon
                Image(systemName: leadingIcon)
                    .foregroundStyle(file.isDownloaded ? Color.minchSuccess : Color.secondary)
                    .font(.minchCaption)

                // Name + size
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.minchCaption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(MinchTransferRow.sizeText(file.sizeBytes))
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Trailing button cluster
                if let onPlay, file.isPlayable {
                    Button("Play", action: onPlay)
                        .buttonStyle(.minch(.primary))
                        .accessibilityLabel("Play \(file.name)")
                }
                if file.isDownloaded, let onReveal {
                    Button("Reveal", action: onReveal)
                        .buttonStyle(.minch(.secondary))
                        .accessibilityLabel("Reveal \(file.name) in Finder")
                } else if let progress = file.downloadProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Color.minchBolt)
                        .frame(width: 80)
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.minchMono)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if let onCancelDownload {
                        Button("Cancel", action: onCancelDownload)
                            .buttonStyle(.minch(.destructive))
                            .accessibilityLabel("Cancel download of \(file.name)")
                    }
                } else {
                    if file.canStream, let onStream {
                        Button("Stream", action: onStream)
                            .buttonStyle(.minch(.secondary))
                            .accessibilityLabel("Stream \(file.name)")
                    }
                    if let onDownload {
                        Button("Download", action: onDownload)
                            .buttonStyle(.minch(.primary))
                            .accessibilityLabel("Download \(file.name)")
                    }
                }

                // Copy-link — always present
                Button {
                    onCopyFileLink?()
                } label: {
                    Image(systemName: "link")
                }
                .buttonStyle(.minch(.ghost))
                .help("Copy download link")
                .accessibilityLabel("Copy download link for \(file.name)")
                .disabled(file.isCopyingLink || onCopyFileLink == nil)
            }
            .padding(.horizontal, MinchSpacing.l)
            .padding(.vertical, MinchSpacing.xs)
        }

        private var leadingIcon: String {
            if file.isDownloaded { return "checkmark.circle.fill" }
            if file.canStream { return "film" }
            return "doc"
        }
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
    /// by `dimmedSeparatorIndices`. Tracking and opacity values come from the
    /// Transfer Card Redesign design spec.
    nonisolated static func nameAttributedString(_ name: String) -> AttributedString {
        var attr = AttributedString(name)
        attr.tracking = -0.2 // Per Transfer Card Redesign spec
        let dims = dimmedSeparatorIndices(name)
        guard !dims.isEmpty else { return attr }
        let chars = Array(name)
        let dimColor = Color.primary.opacity(0.45) // Per Transfer Card Redesign spec
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
        MinchTransferRow(
            content: .init(
                id: "t1",
                name: "The.Matrix.1999.2160p.UHD.BluRay.mkv",
                phase: .active,
                sizeBytes: 2_400_000_000,
                downloadSpeed: 18_000_000,
                progress: 0.62,
                etaSeconds: 195,
                hasPlayableMedia: false,
                files: []
            ),
            onToggle: {},
            onPlay: { _ in },
            onReveal: { _ in },
            onCopyLink: {},
            onDelete: {}
        )

        MinchTransferRow(
            content: .init(
                id: "t2",
                name: "Solaris.1972.Criterion.2160p.mkv",
                phase: .done,
                sizeBytes: 18_300_000_000,
                downloadSpeed: 0,
                progress: 1.0,
                addedAt: Date().addingTimeInterval(-7_200),
                hasPlayableMedia: true,
                files: [
                    .init(id: "f1", name: "Solaris.mkv", sizeBytes: 18_300_000_000, isPlayable: true)
                ]
            ),
            isExpanded: true,
            onToggle: {},
            onPlay: { _ in },
            onReveal: { _ in },
            onCopyLink: {},
            onDelete: {}
        )

        MinchTransferRow(
            content: .init(
                id: "t3",
                name: "Mishandled.tracker.torrent",
                phase: .error,
                sizeBytes: 1_200_000_000,
                downloadSpeed: 0,
                progress: 0.12,
                errorMessage: "Tracker unreachable"
            )
        )
    }
    .padding()
    .background(Color.minchSurfacePrimary)
    .preferredColorScheme(.dark)
}
