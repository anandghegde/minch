import SwiftUI
import MinchAPI
import MinchUI

/// Read-only account sheet. Shows plan/email from `/user/me`, subscriptions
/// from `/user/subscriptions`, and aggregate usage from `/user/stats`. No
/// billing actions (Minch is free; subscriptions are managed on torbox.app).
struct AccountView: View {
    @Bindable var model: AppModel
    let account: UserAccount
    let onDismiss: () -> Void
    let signOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: MinchSpacing.xl) {
                    planSection
                    usageSection
                    PreferencesSection(model: model)
                    LocalPreferencesSection(model: model)
                    subscriptionsSection
                    APIKeySection(model: model)
                    signOutSection
                    if let error = model.accountLoadError {
                        Text(error)
                            .font(.minchCaption)
                            .foregroundStyle(Color.minchDanger)
                    }
                }
                .padding(MinchSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 520, height: 720)
        .background(Color.minchSurfacePrimary)
        .preferredColorScheme(.dark)
        .task { await model.loadAccount() }
    }

    private var header: some View {
        HStack {
            Text("Account")
                .font(.minchTitle)
            Spacer()
            if model.isLoadingAccount {
                ProgressView().controlSize(.small)
            }
            Button("Done", action: onDismiss)
                .buttonStyle(.minch(.ghost))
        }
        .padding(MinchSpacing.l)
        .background(Color.minchSurfaceCard)
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("Plan")
                .font(.minchHeadline)
            row("Tier", value: account.planName)
            if let email = account.email, !email.isEmpty {
                row("Email", value: email)
            }
            if let isSubscribed = account.isSubscribed {
                row("Active subscription", value: isSubscribed ? "Yes" : "No")
            }
            Button("Manage on torbox.app") {
                if let url = URL(string: "https://torbox.app/subscription") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.minch(.ghost))
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("Usage")
                .font(.minchHeadline)
            if let g = model.stats?.general {
                row("Downloaded", value: Self.bytes(g.totalDownloaded))
                row("Uploaded", value: Self.bytes(g.totalUploaded))
                if let ratio = g.ratio {
                    row("Ratio", value: String(format: "%.2f", ratio))
                }
                if let items = g.totalItemsDownloaded {
                    row("Items downloaded", value: "\(items)")
                }
            } else if !model.isLoadingAccount {
                Text("No usage data available.")
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("Subscriptions")
                .font(.minchHeadline)
            if model.subscriptions.isEmpty {
                if !model.isLoadingAccount {
                    Text("No subscriptions on file.")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(model.subscriptions) { sub in
                    subscriptionRow(sub)
                }
            }
        }
    }

    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("Session")
                .font(.minchHeadline)
            Button("Sign out", role: .destructive) {
                signOut()
                onDismiss()
            }
            .buttonStyle(.minch(.destructive))
        }
    }

    @ViewBuilder
    private func subscriptionRow(_ sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(sub.planName ?? "Plan")
                    .font(.minchCaption.bold())
                Spacer()
                if let status = sub.status {
                    Text(status)
                        .font(.minchCaption)
                        .foregroundStyle(status.lowercased() == "active" ? Color.minchSuccess : .secondary)
                }
            }
            if let gateway = sub.gateway, !gateway.isEmpty {
                Text(gateway)
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)
            }
            if let updated = sub.updatedAt {
                Text("Updated \(updated.formatted(date: .abbreviated, time: .omitted))")
                    .font(.minchCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(MinchSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: MinchRadius.s, style: .continuous)
                .fill(Color.minchSurfaceSunken)
        )
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.minchCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.minchCaption)
                .foregroundStyle(.primary)
        }
    }

    private static func bytes(_ value: Int64?) -> String {
        guard let value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

// MARK: - Preferences (TorBox server-side)

private struct PreferencesSection: View {
    @Bindable var model: AppModel

    /// Keys we expose, in display order. Matches the previous SettingsView allowlist.
    private static let allowedKeys: [String] = [
        "seed_torrents",
        "allow_zipped",
        "download_speed_in_tab",
        "show_tracker_in_torrents"
    ]

    private static let tooltips: [String: String] = [
        "seed_torrents": "Whether your finished torrents keep seeding back to the swarm.",
        "allow_zipped": "Let TorBox bundle multi-file downloads into a single .zip when requested.",
        "download_speed_in_tab": "Show current download speed in the browser tab / window title.",
        "show_tracker_in_torrents": "Display tracker URLs alongside torrent details."
    ]

    /// TorBox `seed_torrents` is a tri-state int (1=Auto, 2=Always, 3=Never).
    private static let seedTorrentsOptions: [(value: Int, label: String)] = [
        (1, "Auto"),
        (2, "Always"),
        (3, "Never")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            HStack(spacing: MinchSpacing.s) {
                Text("Preferences")
                    .font(.minchHeadline)
                Spacer()
                if model.isSavingSettings { ProgressView().controlSize(.small) }
            }

            if model.isLoadingSettings && model.settings == nil {
                ProgressView().controlSize(.small)
            } else if model.settings == nil {
                Text(model.settingsError ?? "Couldn't load preferences.")
                    .font(.minchCaption)
                    .foregroundStyle(Color.minchDanger)
                Button("Retry") { Task { await model.loadSettings() } }
                    .buttonStyle(.minch(.ghost))
            } else {
                ForEach(visibleKeys, id: \.self) { key in
                    fieldView(key: key)
                }
                if let error = model.settingsError {
                    Text(error)
                        .font(.minchCaption)
                        .foregroundStyle(Color.minchDanger)
                }
                HStack {
                    Spacer()
                    Button("Save") { Task { await model.saveSettings() } }
                        .buttonStyle(.minch(.primary))
                        .disabled(model.isSavingSettings || !model.hasSettingsChanges)
                }
            }
        }
        .task { await model.loadSettings() }
    }

    private var visibleKeys: [String] {
        Self.allowedKeys.filter { model.settings?[$0] != nil }
    }

    private func label(for key: String) -> String {
        key.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    @ViewBuilder
    private func fieldView(key: String) -> some View {
        if let value = model.settings?[key] {
            let tooltip = Self.tooltips[key] ?? ""
            if key == "seed_torrents" {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label(for: key))
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: seedTorrentsBinding()) {
                        ForEach(Self.seedTorrentsOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
                .help(tooltip)
            } else {
                switch value {
                case .bool:
                    HStack {
                        Toggle(isOn: boolBinding(key)) {
                            Text(label(for: key))
                                .font(.minchCaption)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        Spacer()
                    }
                    .help(tooltip)
                case .string, .null:
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label(for: key))
                            .font(.minchCaption)
                            .foregroundStyle(.secondary)
                        TextField(label(for: key), text: stringBinding(key))
                            .textFieldStyle(.roundedBorder)
                            .font(.minchCaption)
                    }
                    .help(tooltip)
                case .number:
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label(for: key))
                            .font(.minchCaption)
                            .foregroundStyle(.secondary)
                        TextField(label(for: key), text: numberBinding(key))
                            .textFieldStyle(.roundedBorder)
                            .font(.minchCaption)
                    }
                    .help(tooltip)
                }
            }
        }
    }

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { model.settings?[key]?.boolValue ?? false },
            set: { model.updateSetting(key: key, value: .bool($0)) }
        )
    }

    private func stringBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { model.settings?[key]?.stringValue ?? "" },
            set: { model.updateSetting(key: key, value: .string($0)) }
        )
    }

    private func seedTorrentsBinding() -> Binding<Int> {
        Binding(
            get: {
                let raw = model.settings?["seed_torrents"]?.numberStringValue.flatMap(Int.init) ?? 1
                return Self.seedTorrentsOptions.contains { $0.value == raw } ? raw : 1
            },
            set: { model.updateSetting(key: "seed_torrents", value: .number(Double($0))) }
        )
    }

    private func numberBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { model.settings?[key]?.numberStringValue ?? "" },
            set: { raw in
                if raw.isEmpty {
                    model.updateSetting(key: key, value: .null)
                } else if let value = Double(raw) {
                    model.updateSetting(key: key, value: .number(value))
                }
            }
        )
    }
}

// MARK: - API Key

private struct APIKeySection: View {
    @Bindable var model: AppModel

    @State private var isEditing: Bool = false
    @State private var draftKey: String = ""
    @State private var inFlight: Bool = false
    @State private var localError: String?
    @State private var maskedDisplay: String = "••••••••"

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("TorBox API key")
                .font(.minchHeadline)

            if isEditing {
                SecureField("Paste your TorBox API key", text: $draftKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(inFlight)
                if let localError {
                    Text(localError)
                        .font(.minchCaption)
                        .foregroundStyle(Color.minchDanger)
                }
                HStack {
                    Spacer()
                    Button("Cancel") {
                        isEditing = false
                        draftKey = ""
                        localError = nil
                    }
                    .buttonStyle(.minch(.ghost))
                    .disabled(inFlight)
                    Button("Save") { Task { await save() } }
                        .buttonStyle(.minch(.primary))
                        .disabled(inFlight || draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                HStack {
                    Text(maskedDisplay)
                        .font(.minchCaption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Replace…") { isEditing = true }
                        .buttonStyle(.minch(.ghost))
                }
                Text("Stored locally in your macOS Keychain. Generate a new one at torbox.app/settings.")
                    .font(.minchMetadata)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await refreshMasked() }
    }

    private func refreshMasked() async {
        let suffix = await model.currentAPIKeyLast4() ?? ""
        maskedDisplay = suffix.isEmpty ? "••••••••" : "••••••••\(suffix)"
    }

    private func save() async {
        inFlight = true
        localError = nil
        do {
            try await model.replaceAPIKey(draftKey)
            isEditing = false
            draftKey = ""
            await refreshMasked()
        } catch {
            localError = model.friendlyAPIKeyError(error)
        }
        inFlight = false
    }
}

// MARK: - Local Preferences

private struct LocalPreferencesSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text("Local Preferences")
                .font(.minchHeadline)

            VStack(alignment: .leading, spacing: MinchSpacing.xs) {
                Text("Download Location")
                    .font(.minchCaption)
                    .foregroundStyle(.secondary)

                HStack(spacing: MinchSpacing.s) {
                    Text(model.customDownloadFolderURL.path)
                        .font(.minchCaption.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .padding(.horizontal, MinchSpacing.s)
                        .padding(.vertical, MinchSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: MinchRadius.s, style: .continuous)
                                .fill(Color.minchSurfaceSunken)
                        )

                    Button("Choose…") {
                        selectFolder()
                    }
                    .buttonStyle(.minch(.secondary))
                }
            }
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = model.customDownloadFolderURL

        if panel.runModal() == .OK, let url = panel.url {
            model.updateDownloadFolder(url)
        }
    }
}
