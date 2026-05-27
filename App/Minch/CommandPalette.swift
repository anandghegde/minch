import SwiftUI
import SwiftData
import AppKit
import MinchKit
import MinchUI
import MinchPersistence

/// PRD §3.6 — Command palette (⌘K). Fuzzy-matches transfers, files, and a
/// short list of built-in actions. Open/dismiss is owned by the parent;
/// selection invokes a callback so the parent can route to play/reveal/etc.
struct CommandPalette: View {
    enum Action: Identifiable, Hashable {
        case openTransfer(transferID: String)
        case playFile(transferID: String, fileID: String)
        case revealFile(transferID: String, fileID: String)
        case refresh
        case addMagnet
        case signOut

        var id: String {
            switch self {
            case .openTransfer(let t): "t:\(t)"
            case .playFile(let t, let f): "p:\(t):\(f)"
            case .revealFile(let t, let f): "r:\(t):\(f)"
            case .refresh: "refresh"
            case .addMagnet: "add"
            case .signOut: "signout"
            }
        }
    }

    let initialAction: Action?
    let onAction: (Action) -> Void
    let onDismiss: () -> Void

    init(
        initialAction: Action? = nil,
        onAction: @escaping (Action) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialAction = initialAction
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    @Query(sort: \StoredTransfer.addedAt, order: .reverse)
    private var transfers: [StoredTransfer]

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().background(Color.minchHairline)
            resultsList
        }
        .frame(width: 560, height: 420)
        .background(Color.minchSurfaceOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: MinchRadius.l)
                .stroke(Color.minchHairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: MinchRadius.l))
        .preferredColorScheme(.dark)
        .onAppear {
            if let initialAction, let index = results.firstIndex(where: { $0.action == initialAction }) {
                selectedIndex = index
            } else {
                selectedIndex = 0
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Type a command, transfer name, or file…", text: $query)
                .textFieldStyle(.plain)
                .font(.minchBody)
                .foregroundStyle(.primary)
                .onSubmit { invokeSelected() }
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Close command palette")
        }
        .padding(MinchSpacing.l)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let entries = results
                    if entries.isEmpty {
                        Text("No matches.")
                            .font(.minchCallout)
                            .foregroundStyle(.secondary)
                            .padding(MinchSpacing.l)
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.element.action) { index, entry in
                            CommandRow(entry: entry, isSelected: index == selectedIndex)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture { invoke(action: entry.action) }
                        }
                    }
                }
            }
            .onChange(of: selectedIndex) { _, new in
                proxy.scrollTo(new, anchor: .center)
            }
            .background(KeyHandler(
                onUp: { move(by: -1) },
                onDown: { move(by: 1) },
                onReturn: { invokeSelected() }
            ))
        }
    }

    // MARK: - Result model

    struct Entry: Hashable {
        let action: Action
        let title: String
        let subtitle: String?
        let systemImage: String
    }

    private var results: [Entry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var out: [Entry] = []

        // Built-in actions (always show unless filtered out)
        let builtin: [Entry] = [
            .init(action: .refresh, title: "Refresh transfers", subtitle: "Pull latest from TorBox", systemImage: "arrow.clockwise"),
            .init(action: .addMagnet, title: "Add magnet…", subtitle: "Focus the magnet input", systemImage: "link.badge.plus"),
            .init(action: .signOut, title: "Sign out", subtitle: "Forget the stored API key", systemImage: "rectangle.portrait.and.arrow.right")
        ]
        out.append(contentsOf: builtin.filter { q.isEmpty || $0.title.lowercased().contains(q) })

        for transfer in transfers {
            let transferMatches = q.isEmpty || transfer.name.lowercased().contains(q)
            if transferMatches {
                out.append(.init(
                    action: .openTransfer(transferID: transfer.id),
                    title: transfer.name,
                    subtitle: "Transfer",
                    systemImage: "shippingbox"
                ))
            }
            for file in transfer.files where file.isDownloaded {
                let fileMatches = q.isEmpty
                    ? false
                    : file.name.lowercased().contains(q)
                guard fileMatches || (transferMatches && !q.isEmpty) else { continue }
                let kind = MediaKind.detect(name: file.name, mime: file.mime)
                if kind != .other {
                    out.append(.init(
                        action: .playFile(transferID: transfer.id, fileID: file.id),
                        title: "Play \(file.name)",
                        subtitle: transfer.name,
                        systemImage: kind == .audio ? "music.note" : "play.fill"
                    ))
                }
                out.append(.init(
                    action: .revealFile(transferID: transfer.id, fileID: file.id),
                    title: "Reveal \(file.name)",
                    subtitle: transfer.name,
                    systemImage: "folder"
                ))
            }
            if out.count > 60 { break }
        }
        return out
    }

    private func move(by delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func invokeSelected() {
        let entries = results
        guard entries.indices.contains(selectedIndex) else { return }
        invoke(action: entries[selectedIndex].action)
    }

    private func invoke(action: Action) {
        onAction(action)
        onDismiss()
    }
}

private struct CommandRow: View {
    let entry: CommandPalette.Entry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: entry.systemImage)
                .foregroundStyle(isSelected ? Color.minchBolt : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.title)
                    .font(.minchCallout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, MinchSpacing.l)
        .padding(.vertical, MinchSpacing.s)
        .background(isSelected ? Color.minchSelection : Color.clear)
    }
}

/// AppKit bridge for arrow / return handling on the palette.
private struct KeyHandler: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onReturn: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onUp = onUp
        view.onDown = onDown
        view.onReturn = onReturn
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? KeyView else { return }
        view.onUp = onUp
        view.onDown = onDown
        view.onReturn = onReturn
    }

    final class KeyView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onReturn: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 125: onDown?()   // arrow down
            case 126: onUp?()     // arrow up
            case 36, 76: onReturn?() // return / numpad return
            default: super.keyDown(with: event)
            }
        }
    }
}
