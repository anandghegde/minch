import SwiftUI
import AppKit
import SwiftData
import MinchKit
import MinchUI
import MinchAPI
import MinchPersistence
import UniformTypeIdentifiers

/// Menu bar popover content (PRD §13 sprint 6). Shows the top active transfers
/// and a quick-add magnet field; falls back to a "sign in" affordance when
/// the user hasn't connected their TorBox key yet.
struct MenuBarView: View {
    @Bindable var model: AppModel

    @State private var isTargeted = false

    @Query(
        filter: #Predicate<StoredTransfer> { $0.statusRaw != "done" },
        sort: \StoredTransfer.addedAt,
        order: .reverse
    )
    private var active: [StoredTransfer]

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            switch model.state {
            case .signedIn(let account):
                header(for: account)
                quickAdd
                Divider().background(Color.minchHairline)
                activeList
                if !model.inflightFileIDs.isEmpty {
                    Divider().background(Color.minchHairline)
                    localDownloadsList
                }
                Divider().background(Color.minchHairline)
                footer
                updaterRow
            default:
                defaultHeader
                signInPrompt
                updaterRow
            }
        }
        .padding(MinchSpacing.m)
        .frame(width: 360)
        .background(isTargeted ? Color.minchSurfaceSunken : Color.minchSurfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                .stroke(isTargeted ? Color.minchBolt : Color.minchHairline, lineWidth: 2)
        )
        .preferredColorScheme(.dark)
        .onDrop(of: [.fileURL, .text], isTargeted: $isTargeted) { providers in
            Task {
                _ = await model.ingestDroppedProviders(providers)
            }
            return true
        }
    }

    private var defaultHeader: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Color.minchBolt)
            Text("Minch")
                .font(.minchHeadline)
                .foregroundStyle(.primary)
            Spacer()
            if model.isRefreshing {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func header(for account: UserAccount) -> some View {
        HStack(spacing: MinchSpacing.s) {
            HStack(spacing: MinchSpacing.xs) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.minchBolt)
                Text("Minch")
                    .font(.minchHeadline)
                    .foregroundStyle(.primary)
            }
            if model.isRefreshing {
                ProgressView().controlSize(.small)
            }
            Spacer()
            HStack(spacing: MinchSpacing.xs) {
                Circle()
                    .fill(MinchAccountChip.statusDotColor(isSubscribed: account.isSubscribed ?? false))
                    .frame(width: 6, height: 6)
                Text(account.planName)
                    .font(.minchCaption.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, MinchSpacing.s)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.minchSurfaceSunken))
            .overlay(Capsule().stroke(Color.minchHairline, lineWidth: 1))
        }
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.xs) {
            VStack(spacing: MinchSpacing.m) {
                VStack(spacing: MinchSpacing.xs) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(isTargeted ? Color.minchBolt : Color.secondary)
                        .symbolEffect(.pulse, options: .repeating, value: isTargeted)
                    Text("Drag & drop .torrent/magnet or paste link")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, MinchSpacing.s)

                HStack(spacing: MinchSpacing.s) {
                    TextField("Paste magnet…", text: $model.pendingMagnet)
                        .textFieldStyle(.plain)
                        .font(.minchCallout)
                        .foregroundStyle(.primary)
                        .disabled(model.isAdding)
                        .onSubmit { Task { await model.addMagnet() } }

                    if model.isAdding {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Add") { Task { await model.addMagnet() } }
                            .buttonStyle(.minch(.primary))
                            .disabled(model.pendingMagnet.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal, MinchSpacing.s)
                .padding(.vertical, MinchSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: MinchRadius.s)
                        .fill(Color.minchSurfaceCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MinchRadius.s)
                        .stroke(Color.minchHairline, lineWidth: 1)
                )
            }
            .padding(MinchSpacing.m)
            .background(Color.minchSurfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                    .strokeBorder(isTargeted ? Color.minchBolt : Color.minchHairline, style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, lineCap: .round, lineJoin: .round, dash: isTargeted ? [] : [4, 4]))
            )
            .shadow(color: isTargeted ? Color.minchBolt.opacity(0.15) : Color.clear, radius: 8)

            if let message = model.addError {
                Text(message)
                    .font(.minchCaption)
                    .foregroundStyle(Color.minchDanger)
                    .padding(.horizontal, MinchSpacing.xs)
            }
        }
    }

    @ViewBuilder
    private var activeList: some View {
        if active.isEmpty {
            Text("Nothing in flight.")
                .font(.minchCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, MinchSpacing.xs)
        } else {
            VStack(spacing: MinchSpacing.xs) {
                ForEach(active.prefix(5)) { row in
                    MenuBarTransferRow(row: row, model: model)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: MinchSpacing.s) {
            Button("Open Minch", action: openMainWindow)
                .buttonStyle(.minch(.primary))
            Spacer()
            Button("Refresh") { Task { await model.refresh() } }
                .buttonStyle(.minch(.ghost))
                .disabled(model.isRefreshing)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.minch(.ghost))
        }
    }

    @ViewBuilder
    private var updaterRow: some View {
        HStack(spacing: MinchSpacing.xs) {
            Button(action: { model.updater.checkForUpdates() }) {
                HStack(spacing: MinchSpacing.xs) {
                    if case .checking = model.updater.state {
                        ProgressView().controlSize(.mini)
                    }
                    Text(updaterLabel)
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(model.updater.state == .checking)
            Spacer()
            if case let .updateAvailable(_, url) = model.updater.state {
                Button("Download") { NSWorkspace.shared.open(url) }
                    .buttonStyle(.minch(.ghost))
                    .font(.minchCaption)
            }
        }
    }

    private var updaterLabel: String {
        switch model.updater.state {
        case .idle: "Check for updates…"
        case .checking: "Checking for updates…"
        case .upToDate: "Minch is up to date"
        case .updateAvailable(let v, _): "Update available: \(v)"
        case .error(let msg): "Update check failed: \(msg)"
        }
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("Sign in to Minch")
                .font(.minchHeadline)
                .foregroundStyle(.primary)
            Text("Open the main window to connect your TorBox key.")
                .font(.minchCaption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Minch", action: openMainWindow)
                    .buttonStyle(.minch(.primary))
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.minch(.ghost))
            }
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    @ViewBuilder
    private var localDownloadsList: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.xs) {
            Text("Local Downloads")
                .font(.minchCaption.bold())
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            ForEach(model.activeLocalDownloads) { download in
                MenuBarLocalDownloadRow(download: download, model: model)
            }
        }
    }
}

private struct MenuBarTransferRow: View {
    let row: StoredTransfer
    let model: AppModel

    @State private var isHovered = false

    var body: some View {
        if row.modelContext == nil {
            EmptyView()
        } else {
            HStack(spacing: MinchSpacing.s) {
                MinchStatusGlyph(MinchStatusPhase(transferStatusRaw: row.statusRaw))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.minchCallout)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    ProgressView(value: max(0, min(row.progress, 1)))
                        .progressViewStyle(.linear)
                        .tint(Color.minchBolt)
                }

                Spacer()

                if isHovered {
                    HStack(spacing: MinchSpacing.m) {
                        Button(action: {
                            Task {
                                await model.controlTransfer(row.id, op: row.statusRaw == "paused" ? .resume : .pause)
                            }
                        }) {
                            Image(systemName: row.statusRaw == "paused" ? "play.fill" : "pause.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.minchBolt)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task {
                                await model.deleteTransfer(row.id)
                            }
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.minchDanger)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                } else {
                    let infoParts = buildInfoParts()
                    Text(infoParts.joined(separator: " • "))
                        .font(.minchMono)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .transition(.opacity)
                }
            }
            .padding(.vertical, MinchSpacing.xs)
            .padding(.horizontal, MinchSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: MinchRadius.s)
                    .fill(isHovered ? Color.minchSurfaceCardHover : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.snappy(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }

    private func buildInfoParts() -> [String] {
        var infoParts: [String] = []
        infoParts.append(String(format: "%.0f%%", max(0, min(row.progress, 1)) * 100))
        if let speedStr = speedText(row.downloadSpeed) {
            infoParts.append(speedStr)
        }
        if let eta = row.eta, let etaStr = etaText(Int(eta)) {
            infoParts.append(etaStr)
        }
        return infoParts
    }

    private func speedText(_ bytesPerSecond: Int64) -> String? {
        guard bytesPerSecond > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytesPerSecond, countStyle: .binary) + "/s"
    }

    private func etaText(_ seconds: Int) -> String? {
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

private struct MenuBarLocalDownloadRow: View {
    let download: AppModel.InflightDownload
    let model: AppModel

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Color.minchBolt)
            VStack(alignment: .leading, spacing: 2) {
                Text(download.fileName)
                    .font(.minchCallout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressView(value: max(0, min(download.progress, 1)))
                    .progressViewStyle(.linear)
                    .tint(Color.minchBolt)
            }

            Spacer()

            if isHovered {
                Button(action: {
                    model.cancelDownload(fileID: download.fileID)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.minchDanger)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.0f%%", max(0, min(download.progress, 1)) * 100))
                        .font(.minchMono)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("Downloading locally…")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, MinchSpacing.xs)
        .padding(.horizontal, MinchSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.s)
                .fill(isHovered ? Color.minchSurfaceCardHover : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
