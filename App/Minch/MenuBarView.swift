import SwiftUI
import AppKit
import SwiftData
import MinchKit
import MinchUI
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
            header

            switch model.state {
            case .signedIn:
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
                signInPrompt
                updaterRow
            }
        }
        .padding(MinchSpacing.m)
        .frame(width: 360)
        .background(isTargeted ? Color.minchSurfaceSunken : Color.minchSurfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                .stroke(isTargeted ? Color.minchBolt : Color.clear, lineWidth: 2)
        )
        .preferredColorScheme(.dark)
        .onDrop(of: [.fileURL, .text], isTargeted: $isTargeted) { providers in
            Task {
                _ = await model.ingestDroppedProviders(providers)
            }
            return true
        }
    }

    private var header: some View {
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

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.xs) {
            HStack(spacing: MinchSpacing.s) {
                Image(systemName: "link.badge.plus")
                    .foregroundStyle(.secondary)
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
                    .fill(Color.minchSurfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MinchRadius.s)
                    .stroke(Color.minchHairline, lineWidth: 1)
            )

            if let message = model.addError {
                Text(message)
                    .font(.minchCaption)
                    .foregroundStyle(Color.minchDanger)
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
                    MenuBarTransferRow(row: row)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: MinchSpacing.s) {
            Button("Open Minch", action: openMainWindow)
                .buttonStyle(.minch(.secondary))
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
                MenuBarLocalDownloadRow(download: download)
            }
        }
    }
}

private struct MenuBarTransferRow: View {
    let row: StoredTransfer

    var body: some View {
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
            Text(String(format: "%.0f%%", max(0, min(row.progress, 1)) * 100))
                .font(.minchMono)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct MenuBarLocalDownloadRow: View {
    let download: AppModel.InflightDownload

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
            Text(String(format: "%.0f%%", max(0, min(download.progress, 1)) * 100))
                .font(.minchMono)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
