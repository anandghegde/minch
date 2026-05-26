import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers
import MinchKit
import MinchAPI
import MinchUI
import MinchPersistence

struct LibraryView: View {
    @Bindable var model: AppModel
    let account: UserAccount

    @State private var selection: LibrarySection = .active
    @State private var paletteOpen: Bool = false
    @State private var paletteRequestedTarget: PlaybackTarget?
    @State private var focusMagnet: Bool = false
    @State private var searchQuery: String = ""
    @State private var showAccount: Bool = false

    @Query(sort: \StoredTransfer.addedAt, order: .reverse)
    private var rows: [StoredTransfer]

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(
                account: account,
                selection: $selection,
                activeCount: rows.lazy.filter { $0.statusRaw != "done" }.count,
                downloadedCount: rows.lazy.filter { $0.statusRaw == "done" }.count,
                videoCount: smartCount(.videos),
                audioCount: smartCount(.audio),
                recentCount: recentRows.count,
                isRefreshing: model.isRefreshing,
                refresh: { Task { await model.refresh() } },
                signOut: { Task { await model.signOut() } },
                openAccount: { showAccount = true }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            LibraryContent(
                model: model,
                selection: selection,
                rows: filteredRows,
                searchQuery: $searchQuery,
                paletteTarget: $paletteRequestedTarget,
                focusMagnet: $focusMagnet
            )
        }
        .preferredColorScheme(.dark)
        .task {
            if rows.isEmpty { await model.refresh() }
        }
        .background(
            Button("") { paletteOpen = true }
                .keyboardShortcut("k", modifiers: [.command])
                .hidden()
        )
        .background(
            Button("") { Task { await model.refresh() } }
                .keyboardShortcut("r", modifiers: [.command])
                .hidden()
        )
        .background(
            Button("") { focusMagnet = true }
                .keyboardShortcut("n", modifiers: [.command])
                .hidden()
        )
        .sheet(isPresented: $paletteOpen) {
            CommandPalette(
                onAction: handlePaletteAction,
                onDismiss: { paletteOpen = false }
            )
        }
        .sheet(isPresented: $showAccount) {
            AccountView(model: model, account: account, onDismiss: { showAccount = false })
        }
    }

    private var filteredRows: [StoredTransfer] {
        let base: [StoredTransfer]
        switch selection {
        case .active:
            base = rows.filter { $0.statusRaw != "done" }
        case .downloaded:
            base = rows.filter { $0.statusRaw == "done" }
        case .videos:
            base = rows.filter { hasMedia($0, kind: .video) }
        case .audio:
            base = rows.filter { hasMedia($0, kind: .audio) }
        case .recent:
            base = recentRows
        case .settings:
            return []
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { row in
            row.name.lowercased().contains(q)
                || row.tagNames.contains(where: { $0.lowercased().contains(q) })
                || row.files.contains(where: { $0.name.lowercased().contains(q) })
        }
    }

    private var recentRows: [StoredTransfer] {
        let cutoff = Date().addingTimeInterval(-60 * 60 * 24 * 7)
        return rows.filter { $0.addedAt > cutoff }
    }

    private func smartCount(_ section: LibrarySection) -> Int {
        switch section {
        case .videos: rows.filter { hasMedia($0, kind: .video) }.count
        case .audio: rows.filter { hasMedia($0, kind: .audio) }.count
        default: 0
        }
    }

    private func hasMedia(_ row: StoredTransfer, kind: MediaKind) -> Bool {
        row.files.contains { MediaKind.detect(name: $0.name, mime: $0.mime) == kind }
    }

    private func handlePaletteAction(_ action: CommandPalette.Action) {
        switch action {
        case .refresh:
            Task { await model.refresh() }
        case .addMagnet:
            selection = .active
            focusMagnet = true
        case .signOut:
            Task { await model.signOut() }
        case .openTransfer(let transferID):
            if let row = rows.first(where: { $0.id == transferID }) {
                selection = row.statusRaw == "done" ? .downloaded : .active
            }
        case .playFile(let transferID, let fileID):
            guard
                let transfer = rows.first(where: { $0.id == transferID }),
                let file = transfer.files.first(where: { $0.id == fileID }),
                let path = file.localPath
            else { return }
            paletteRequestedTarget = PlaybackTarget(
                id: file.id,
                file: file,
                url: URL(fileURLWithPath: path),
                title: file.name,
                kind: MediaKind.detect(name: file.name, mime: file.mime)
            )
        case .revealFile(let transferID, let fileID):
            guard
                let transfer = rows.first(where: { $0.id == transferID }),
                let file = transfer.files.first(where: { $0.id == fileID }),
                let path = file.localPath
            else { return }
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }
}

// MARK: - Sidebar

private struct LibrarySidebar: View {
    let account: UserAccount
    @Binding var selection: LibrarySection
    let activeCount: Int
    let downloadedCount: Int
    let videoCount: Int
    let audioCount: Int
    let recentCount: Int
    let isRefreshing: Bool
    let refresh: () -> Void
    let signOut: () -> Void
    let openAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openAccount) {
                AccountChip(account: account)
            }
            .buttonStyle(.plain)
            .help("View account details")
            .padding(.horizontal, MinchSpacing.m)
            .padding(.top, MinchSpacing.l)
            .padding(.bottom, MinchSpacing.m)

            List(selection: $selection) {
                ForEach(LibrarySection.Group.allCases, id: \.self) { group in
                    Section(group.title) {
                        ForEach(LibrarySection.allCases.filter { $0.group == group }) { section in
                            MinchSidebarRow(
                                systemImage: section.systemImage,
                                title: section.title,
                                count: count(for: section)
                            )
                            .tag(section)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider().background(Color.minchHairline)

            HStack(spacing: MinchSpacing.s) {
                if isRefreshing {
                    ProgressView().controlSize(.small)
                }
                Button("Refresh", action: refresh)
                    .buttonStyle(.minch(.ghost))
                    .disabled(isRefreshing)

                Spacer()

                Button("Sign out", action: signOut)
                    .buttonStyle(.minch(.ghost))
            }
            .padding(MinchSpacing.s)
        }
        .background(Color.minchSurfacePrimary)
    }

    private func count(for section: LibrarySection) -> Int {
        switch section {
        case .active: activeCount
        case .downloaded: downloadedCount
        case .videos: videoCount
        case .audio: audioCount
        case .recent: recentCount
        case .settings: 0
        }
    }
}

private struct AccountChip: View {
    let account: UserAccount

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Circle()
                .fill(LinearGradient(
                    colors: [.minchBolt, .minchCurrent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(initial)
                        .font(.minchCaption.bold())
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 0) {
                Text(account.planName)
                    .font(.minchHeadline)
                    .foregroundStyle(.primary)
                if let email = account.email, !email.isEmpty {
                    Text(email)
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var initial: String {
        if let email = account.email, let first = email.first {
            return String(first).uppercased()
        }
        return "M"
    }

    private var accessibilityLabel: String {
        if let email = account.email, !email.isEmpty {
            return "\(account.planName) plan, signed in as \(email)"
        }
        return "\(account.planName) plan"
    }
}

// MARK: - Content

private struct LibraryContent: View {
    @Bindable var model: AppModel
    let selection: LibrarySection
    let rows: [StoredTransfer]
    @Binding var searchQuery: String
    @Binding var paletteTarget: PlaybackTarget?
    @Binding var focusMagnet: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.minchSurfacePrimary, Color.minchSurfaceElevated],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if selection == .settings {
                SettingsView(model: model)
            } else {
                VStack(spacing: 0) {
                    ContentHeader(title: selection.title, count: rows.count)

                    SearchBar(query: $searchQuery)

                    if selection == .active {
                        AddMagnetBar(model: model, focusRequested: $focusMagnet)
                    }

                    if let message = model.refreshError {
                        ErrorBanner(
                            message: message,
                            retryTitle: "Retry",
                            onRetry: { Task { await model.refresh() } },
                            onDismiss: { model.refreshError = nil }
                        )
                        .padding(.horizontal, MinchSpacing.xxl)
                        .padding(.vertical, MinchSpacing.s)
                    }

                    if let message = model.infoBanner {
                        InfoBanner(
                            message: message,
                            onDismiss: { model.infoBanner = nil }
                        )
                        .padding(.horizontal, MinchSpacing.xxl)
                        .padding(.vertical, MinchSpacing.s)
                        .task(id: message) {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            if model.infoBanner == message {
                                model.infoBanner = nil
                            }
                        }
                    }

                    if rows.isEmpty {
                        LibraryEmpty(selection: selection)
                    } else {
                        LibraryList(rows: rows, model: model, externalPlaybackTarget: $paletteTarget)
                    }
                }
            }
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    let retryTitle: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.minchDanger)
            Text(message)
                .font(.minchCallout)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(retryTitle, action: onRetry)
                .buttonStyle(.minch(.secondary))
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(MinchSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.m)
                .fill(Color.minchDanger.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.m)
                .stroke(Color.minchDanger.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct InfoBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.minchSuccess)
            Text(message)
                .font(.minchCallout)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(MinchSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.m)
                .fill(Color.minchSuccess.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.m)
                .stroke(Color.minchSuccess.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct SearchBar: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search transfers, files, tags…", text: $query)
                .textFieldStyle(.plain)
                .font(.minchBody)
                .foregroundStyle(.primary)
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, MinchSpacing.l)
        .padding(.vertical, MinchSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.m)
                .fill(Color.minchSurfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.m)
                .stroke(Color.minchHairline, lineWidth: 1)
        )
        .padding(.horizontal, MinchSpacing.xxl)
        .padding(.bottom, MinchSpacing.s)
    }
}

private struct ContentHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Text(title)
                .font(.minchTitle)
                .foregroundStyle(.primary)
            Text("\(count)")
                .font(.minchCallout.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, MinchSpacing.xxl)
        .padding(.top, MinchSpacing.l)
        .padding(.bottom, MinchSpacing.s)
    }
}

private struct AddMagnetBar: View {
    @Bindable var model: AppModel
    @Binding var focusRequested: Bool
    @FocusState private var magnetFocused: Bool
    @State private var showOptions: Bool = false
    @State private var importingFile: Bool = false
    @State private var showHosters: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.xs) {
            HStack(spacing: MinchSpacing.s) {
                Image(systemName: "link.badge.plus")
                    .foregroundStyle(.secondary)
                TextField("Paste a magnet or download link…", text: $model.pendingMagnet)
                    .textFieldStyle(.plain)
                    .font(.minchBody)
                    .foregroundStyle(.primary)
                    .disabled(model.isAdding || model.pendingTorrentFile != nil)
                    .focused($magnetFocused)
                    .onSubmit { Task { await submit() } }
                    .onChange(of: focusRequested) { _, requested in
                        if requested {
                            magnetFocused = true
                            focusRequested = false
                        }
                    }
                    .onChange(of: model.pendingMagnet) { _, _ in
                        Task { await model.preflightCache() }
                    }

                if model.pendingCachedHash != nil {
                    Label("Cached", systemImage: "bolt.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.minchCaption.bold())
                        .foregroundStyle(Color.minchBolt)
                }

                if model.isAdding {
                    ProgressView().controlSize(.small)
                }

                Button {
                    importingFile = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .buttonStyle(.plain)
                .help("Add a .torrent file")
                .disabled(model.isAdding)

                Button {
                    showHosters.toggle()
                } label: {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Supported file hosts")
                .disabled(model.isAdding || model.hosters.isEmpty)
                .popover(isPresented: $showHosters, arrowEdge: .bottom) {
                    HostersPopover(hosters: model.hosters)
                }

                Button {
                    showOptions.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(showOptions ? Color.minchBolt : .secondary)
                }
                .buttonStyle(.plain)
                .help("Add options")
                .disabled(model.isAdding)

                Button("Add", action: { Task { await submit() } })
                    .buttonStyle(.minch(.primary))
                    .disabled(model.isAdding || !canSubmit)
            }
            .padding(.horizontal, MinchSpacing.l)
            .padding(.vertical, MinchSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: MinchRadius.m)
                    .fill(Color.minchSurfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MinchRadius.m)
                    .stroke(Color.minchHairline, lineWidth: 1)
            )

            if let draft = model.pendingTorrentFile {
                HStack(spacing: MinchSpacing.xs) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(Color.minchBolt)
                    Text(draft.filename)
                        .font(.minchCaption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        model.pendingTorrentFile = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, MinchSpacing.s)
            }

            if showOptions {
                HStack(spacing: MinchSpacing.m) {
                    TextField("Custom name (optional)", text: $model.pendingName)
                        .textFieldStyle(.roundedBorder)
                        .font(.minchCaption)
                        .disabled(model.isAdding)
                    Toggle(isOn: $model.pendingCacheOnly) {
                        Text("Cached only")
                            .font(.minchCaption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .disabled(model.isAdding)
                }
            }

            if let message = model.addError {
                Text(message)
                    .font(.minchCaption)
                    .foregroundStyle(Color.minchDanger)
            }
        }
        .padding(.horizontal, MinchSpacing.xxl)
        .padding(.bottom, MinchSpacing.s)
        .fileImporter(
            isPresented: $importingFile,
            allowedContentTypes: [.init(filenameExtension: "torrent") ?? .data]
        ) { result in
            switch result {
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                model.loadTorrentFile(at: url)
            case .failure:
                break
            }
        }
    }

    private var canSubmit: Bool {
        if model.pendingTorrentFile != nil { return true }
        return !model.pendingMagnet.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() async {
        if model.pendingTorrentFile != nil {
            await model.addTorrentFile()
        } else {
            // Magnet vs. http(s) routing happens here so AppModel keeps a
            // single, validated entry point per surface. Anything that isn't
            // a magnet falls through to webdl.
            let trimmed = model.pendingMagnet.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("magnet:") {
                await model.addMagnet()
            } else {
                await model.addWebDownload()
            }
        }
    }
}

private struct HostersPopover: View {
    let hosters: [Hoster]

    var body: some View {
        let visible = hosters.filter { $0.nsfw != true }
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("Supported file hosts")
                .font(.minchHeadline)
            Text("Paste a direct link from any of these into the Add bar.")
                .font(.minchCaption)
                .foregroundStyle(.secondary)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: MinchSpacing.xs) {
                    ForEach(visible.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })) { hoster in
                        HStack(alignment: .firstTextBaseline, spacing: MinchSpacing.s) {
                            Text(hoster.name)
                                .font(.minchCaption.bold())
                            Text(hoster.domains.first ?? "")
                                .font(.minchCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if hoster.status == true {
                                Text("issues")
                                    .font(.minchCaption)
                                    .foregroundStyle(Color.minchDanger)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(MinchSpacing.l)
        .frame(width: 320)
    }
}

private struct LibraryEmpty: View {
    let selection: LibrarySection

    var body: some View {
        VStack(spacing: MinchSpacing.m) {
            Spacer()
            Image(systemName: selection.systemImage)
                .font(.system(size: 44))
                .foregroundStyle(Color.minchBolt.opacity(0.6))
                .padding(MinchSpacing.l)
                .background(
                    Circle().fill(Color.minchSurfaceSunken)
                )
            Text(title)
                .font(.minchTitle)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.minchCallout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(MinchSpacing.xxl)
    }

    private var title: String {
        switch selection {
        case .active: "Nothing in flight"
        case .downloaded: "No completed transfers"
        case .videos: "No video files"
        case .audio: "No audio files"
        case .recent: "Nothing added recently"
        case .settings: ""
        }
    }

    private var subtitle: String {
        switch selection {
        case .active: "Paste a magnet above and it will appear here."
        case .downloaded: "Finished transfers will show up here once they complete in TorBox."
        case .videos: "Video files across your transfers will land here."
        case .audio: "Audio files across your transfers will land here."
        case .recent: "Transfers added in the last 7 days will appear here."
        case .settings: ""
        }
    }
}

private struct PlaybackTarget: Identifiable {
    let id: String
    let file: StoredTransferFile
    let url: URL
    let title: String
    let kind: MediaKind
}

private struct LibraryList: View {
    let rows: [StoredTransfer]
    @Bindable var model: AppModel
    @Binding var externalPlaybackTarget: PlaybackTarget?
    @State private var expandedID: String?
    @State private var playbackTarget: PlaybackTarget?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MinchSpacing.s) {
                ForEach(rows) { row in
                    TransferDisclosure(
                        row: row,
                        model: model,
                        isExpanded: expandedID == row.id,
                        toggle: {
                            expandedID = expandedID == row.id ? nil : row.id
                        },
                        onPlay: { target in playbackTarget = target }
                    )
                }
            }
            .padding(.horizontal, MinchSpacing.xxl)
            .padding(.bottom, MinchSpacing.xxl)
        }
        .onChange(of: externalPlaybackTarget?.id) { _, _ in
            if let target = externalPlaybackTarget {
                playbackTarget = target
                externalPlaybackTarget = nil
            }
        }
        .fullScreenCoverIfAvailable(item: $playbackTarget) { target in
            PlayerView(
                file: target.file,
                url: target.url,
                title: target.title,
                kind: target.kind,
                onClose: { playbackTarget = nil }
            )
        }
    }
}

private extension View {
    @ViewBuilder
    func fullScreenCoverIfAvailable<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        // macOS lacks fullScreenCover; use a sheet that fills the parent window.
        self.sheet(item: item) { value in
            content(value)
                .frame(minWidth: 800, minHeight: 500)
        }
    }
}

private struct TransferDisclosure: View {
    let row: StoredTransfer
    @Bindable var model: AppModel
    let isExpanded: Bool
    let toggle: () -> Void
    let onPlay: (PlaybackTarget) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var tagDraft: String = ""
    @State private var editingTags: Bool = false
    @State private var confirmingDelete: Bool = false
    @State private var renaming: Bool = false
    @State private var renameDraft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                MinchTransferRow(
                    content: .init(
                        name: row.name,
                        phase: MinchStatusPhase(transferStatusRaw: row.statusRaw),
                        sizeBytes: row.sizeBytes,
                        downloadSpeed: row.downloadSpeed,
                        progress: row.progress,
                        seeds: row.seeds,
                        peers: row.peers
                    ),
                    isExpanded: isExpanded,
                    onToggle: toggle
                )
                .contextMenu {
                    Button("Rename…") {
                        renameDraft = row.name
                        renaming = true
                    }
                    Button(editingTags ? "Hide tag editor" : "Edit tags…") {
                        editingTags.toggle()
                    }
                    Divider()
                    Button("Delete from TorBox", role: .destructive) {
                        confirmingDelete = true
                    }
                    .disabled(model.deletingTransferIDs.contains(row.id))
                }

                Button {
                    confirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.minchDanger.opacity(0.8))
                        .padding(MinchSpacing.s)
                }
                .buttonStyle(.plain)
                .help("Delete from TorBox")
                .accessibilityLabel("Delete from TorBox")
                .disabled(model.deletingTransferIDs.contains(row.id))
            }
            .confirmationDialog(
                "Delete this transfer from TorBox?",
                isPresented: $confirmingDelete
            ) {
                Button("Delete", role: .destructive) {
                    Task { await model.deleteTransfer(row.id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\"\(row.name)\" will be removed from your TorBox cache. Already-downloaded local files will stay on disk.")
            }

            if renaming {
                RenameRow(
                    draft: $renameDraft,
                    save: {
                        let clean = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty, clean != row.name else {
                            renaming = false
                            return
                        }
                        Task { await model.renameTransfer(row.id, to: clean) }
                        renaming = false
                    },
                    cancel: { renaming = false }
                )
                .padding(.horizontal, MinchSpacing.l)
                .padding(.bottom, MinchSpacing.s)
            }

            if !row.tagNames.isEmpty || editingTags {
                TagRow(
                    tags: row.tagNames,
                    editing: editingTags,
                    draft: $tagDraft,
                    add: addTag,
                    remove: removeTag
                )
                .padding(.horizontal, MinchSpacing.l)
                .padding(.bottom, MinchSpacing.s)
            }

            if isExpanded {
                FileList(row: row, model: model, onPlay: onPlay)
                    .padding(.horizontal, MinchSpacing.l)
                    .padding(.bottom, MinchSpacing.l)
            }
        }
    }

    private func addTag() {
        let clean = tagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !row.tagNames.contains(clean) else { return }
        row.tagNames.append(clean)
        tagDraft = ""
        try? modelContext.save()
        let tagsSnapshot = row.tagNames
        let transferID = row.id
        Task { await model.syncTags(transferID, tags: tagsSnapshot) }
    }

    private func removeTag(_ tag: String) {
        row.tagNames.removeAll { $0 == tag }
        try? modelContext.save()
        let tagsSnapshot = row.tagNames
        let transferID = row.id
        Task { await model.syncTags(transferID, tags: tagsSnapshot) }
    }
}

private struct RenameRow: View {
    @Binding var draft: String
    let save: () -> Void
    let cancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: "pencil")
                .foregroundStyle(.secondary)
                .font(.minchCaption)
            TextField("New name", text: $draft)
                .textFieldStyle(.plain)
                .font(.minchBody)
                .foregroundStyle(.primary)
                .focused($focused)
                .onSubmit(save)
            Button("Save", action: save)
                .buttonStyle(.minch(.primary))
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", action: cancel)
                .buttonStyle(.minch(.ghost))
        }
        .padding(.horizontal, MinchSpacing.l)
        .padding(.vertical, MinchSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.m)
                .fill(Color.minchSurfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.m)
                .stroke(Color.minchHairline, lineWidth: 1)
        )
        .task { focused = true }
    }
}

private struct TagRow: View {
    let tags: [String]
    let editing: Bool
    @Binding var draft: String
    let add: () -> Void
    let remove: (String) -> Void

    var body: some View {
        HStack(spacing: MinchSpacing.xs) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Text("#\(tag)")
                        .font(.minchCaption)
                        .foregroundStyle(Color.minchBolt)
                    if editing {
                        Button(action: { remove(tag) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MinchSpacing.s)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.minchBolt.opacity(0.12))
                )
            }

            if editing {
                TextField("add tag", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.minchCaption)
                    .onSubmit(add)
                    .frame(maxWidth: 120)
                Button("Add", action: add)
                    .buttonStyle(.minch(.ghost))
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Spacer()
        }
    }
}

private struct FileList: View {
    let row: StoredTransfer
    @Bindable var model: AppModel
    let onPlay: (PlaybackTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.xs) {
            if row.files.isEmpty {
                Text("No files yet")
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(row.files.sorted(by: { $0.name < $1.name })) { file in
                    FileRow(transfer: row, file: file, model: model, onPlay: onPlay)
                }
            }
        }
        .padding(.leading, MinchSpacing.xl)
    }
}

private struct FileRow: View {
    let transfer: StoredTransfer
    let file: StoredTransferFile
    @Bindable var model: AppModel
    let onPlay: (PlaybackTarget) -> Void
    @State private var isStreaming = false

    private var mediaKind: MediaKind {
        MediaKind.detect(name: file.name, mime: file.mime)
    }

    private var hasLocalFile: Bool {
        guard file.isDownloaded, let path = file.localPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private var playable: Bool {
        hasLocalFile && mediaKind != .other
    }

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: iconName)
                .foregroundStyle(file.isDownloaded ? Color.minchSuccess : .secondary)
                .font(.minchCaption)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.minchCallout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if playable, let path = file.localPath {
                Button("Play") {
                    onPlay(PlaybackTarget(
                        id: file.id,
                        file: file,
                        url: URL(fileURLWithPath: path),
                        title: file.name,
                        kind: mediaKind
                    ))
                }
                .buttonStyle(.minch(.primary))
            }
            if hasLocalFile, let path = file.localPath {
                Button("Reveal") { reveal(path: path) }
                    .buttonStyle(.minch(.secondary))
            } else if model.inflightFileIDs.contains(file.id) {
                let progress = model.downloadProgress[file.id]
                ProgressView(value: progress ?? 0)
                    .progressViewStyle(.linear)
                    .tint(Color.minchBolt)
                    .frame(width: 80)
                if let progress {
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.minchMono)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button("Cancel") {
                    model.cancelDownload(fileID: file.id)
                }
                .buttonStyle(.minch(.destructive))
            } else {
                if mediaKind != .other {
                    Button(isStreaming ? "Opening…" : "Stream") {
                        Task {
                            isStreaming = true
                            let url = await model.streamURL(transferID: transfer.id, fileID: file.id)
                            isStreaming = false
                            if let url {
                                onPlay(PlaybackTarget(
                                    id: file.id,
                                    file: file,
                                    url: url,
                                    title: file.name,
                                    kind: mediaKind
                                ))
                            }
                        }
                    }
                    .buttonStyle(.minch(.secondary))
                    .disabled(isStreaming)
                }
                Button("Download") {
                    Task {
                        await model.downloadFile(
                            transferID: transfer.id,
                            fileID: file.id,
                            transferName: transfer.name,
                            fileName: file.name
                        )
                    }
                }
                .buttonStyle(.minch(.primary))
            }
            Button {
                Task {
                    await model.copyDownloadLink(transferID: transfer.id, fileID: file.id)
                }
            } label: {
                Image(systemName: "link")
            }
            .buttonStyle(.minch(.ghost))
            .help("Copy download link")
            .accessibilityLabel("Copy download link")
            .disabled(model.copyingFileIDs.contains(file.id))
        }
        .padding(.vertical, MinchSpacing.xs)
    }

    private var iconName: String {
        if file.isDownloaded { return "checkmark.circle.fill" }
        switch mediaKind {
        case .video: return "film"
        case .audio: return "music.note"
        case .other: return "doc"
        }
    }

    private func reveal(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
