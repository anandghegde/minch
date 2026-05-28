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
                            .padding(.horizontal, MinchSpacing.xs)
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
                .foregroundStyle(.primary)
            Spacer()
            if model.isLoadingAccount {
                ProgressView().controlSize(.small)
                    .padding(.trailing, MinchSpacing.s)
            }
            Button("Done", action: onDismiss)
                .buttonStyle(.minch(.ghost))
        }
        .padding(.horizontal, MinchSpacing.xl)
        .padding(.vertical, MinchSpacing.l)
        .background(Color.minchSurfacePrimary)
        .overlay(
            VStack {
                Spacer()
                Divider().background(Color.minchHairline)
            }
        )
    }

    private var planSection: some View {
        SettingsCard(title: "Plan Details") {
            KeyValueRow(label: "Tier", value: account.planName)
            
            if let email = account.email, !email.isEmpty {
                Divider().background(Color.minchHairline)
                KeyValueRow(label: "Email", value: email)
            }
            
            if let isSubscribed = account.isSubscribed {
                Divider().background(Color.minchHairline)
                KeyValueRow(label: "Active subscription", value: isSubscribed ? "Yes" : "No")
            }
            
            Divider().background(Color.minchHairline)
            HStack {
                Spacer()
                Button("Manage on torbox.app") {
                    if let url = URL(string: "https://torbox.app/subscription") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.minch(.ghost))
            }
            .padding(.horizontal, MinchSpacing.l)
            .padding(.vertical, MinchSpacing.s)
        }
    }

    private var usageSection: some View {
        SettingsCard(title: "Usage Statistics") {
            if let g = model.stats?.general {
                KeyValueRow(label: "Downloaded", value: Self.bytes(g.totalDownloaded))
                Divider().background(Color.minchHairline)
                KeyValueRow(label: "Uploaded", value: Self.bytes(g.totalUploaded))
                
                if let ratio = g.ratio {
                    Divider().background(Color.minchHairline)
                    KeyValueRow(label: "Ratio", value: String(format: "%.2f", ratio))
                }
                
                if let items = g.totalItemsDownloaded {
                    Divider().background(Color.minchHairline)
                    KeyValueRow(label: "Items downloaded", value: "\(items)")
                }
            } else {
                HStack {
                    Text("No usage data available.")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(MinchSpacing.l)
            }
        }
    }

    private var subscriptionsSection: some View {
        SettingsCard(title: "Active Subscriptions") {
            if model.subscriptions.isEmpty {
                HStack {
                    Text("No subscriptions on file.")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(MinchSpacing.l)
            } else {
                VStack(spacing: MinchSpacing.s) {
                    ForEach(model.subscriptions) { sub in
                        subscriptionRow(sub)
                    }
                }
                .padding(MinchSpacing.l)
            }
        }
    }

    @ViewBuilder
    private func subscriptionRow(_ sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(sub.planName ?? "Plan")
                    .font(.minchBody.bold())
                Spacer()
                if let status = sub.status {
                    Text(status.uppercased())
                        .font(.minchCaption.bold())
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
        .padding(MinchSpacing.m)
        .background(Color.minchSurfaceSunken)
        .cornerRadius(MinchRadius.s)
    }

    private var signOutSection: some View {
        SettingsCard(title: "Session") {
            SettingsRow(
                label: "Account Session",
                description: "Sign out of your TorBox account on this device."
            ) {
                Button("Sign out", role: .destructive) {
                    signOut()
                    onDismiss()
                }
                .buttonStyle(.minch(.destructive))
            }
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

    private static let allowedKeys: [String] = [
        "seed_torrents",
        "allow_zipped",
        "download_speed_in_tab",
        "show_tracker_in_torrents"
    ]

    private static let tooltips: [String: String] = [
        "seed_torrents": "Whether finished torrents keep seeding.",
        "allow_zipped": "Bundle multi-file downloads into a single .zip.",
        "download_speed_in_tab": "Show download speed in the browser title.",
        "show_tracker_in_torrents": "Display tracker URLs alongside details."
    ]

    private static let seedTorrentsOptions: [(value: Int, label: String)] = [
        (1, "Auto"),
        (2, "Always"),
        (3, "Never")
    ]

    var body: some View {
        SettingsCard(title: "TorBox Preferences") {
            if model.isLoadingSettings && model.settings == nil {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Spacer()
                }
                .padding(MinchSpacing.xl)
            } else if model.settings == nil {
                VStack(spacing: MinchSpacing.s) {
                    Text(model.settingsError ?? "Couldn't load preferences.")
                        .font(.minchCaption)
                        .foregroundStyle(Color.minchDanger)
                    Button("Retry") { Task { await model.loadSettings() } }
                        .buttonStyle(.minch(.ghost))
                }
                .padding(MinchSpacing.l)
            } else {
                let keys = visibleKeys
                ForEach(0..<keys.count, id: \.self) { idx in
                    let key = keys[idx]
                    if idx > 0 {
                        Divider().background(Color.minchHairline)
                    }
                    fieldView(key: key)
                }

                if let error = model.settingsError {
                    Text(error)
                        .font(.minchCaption)
                        .foregroundStyle(Color.minchDanger)
                        .padding(.horizontal, MinchSpacing.l)
                        .padding(.vertical, MinchSpacing.s)
                }

                Divider().background(Color.minchHairline)
                HStack {
                    Spacer()
                    if model.isSavingSettings {
                        ProgressView().controlSize(.small)
                            .padding(.trailing, MinchSpacing.s)
                    }
                    Button("Save Preferences") { Task { await model.saveSettings() } }
                        .buttonStyle(.minch(.primary))
                        .disabled(model.isSavingSettings || !model.hasSettingsChanges)
                }
                .padding(.horizontal, MinchSpacing.l)
                .padding(.vertical, MinchSpacing.s)
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
            let desc = Self.tooltips[key]
            if key == "seed_torrents" {
                SettingsRow(label: label(for: key), description: desc) {
                    Picker("", selection: seedTorrentsBinding()) {
                        ForEach(Self.seedTorrentsOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 90)
                }
            } else {
                switch value {
                case .bool:
                    SettingsRow(label: label(for: key), description: desc) {
                        Toggle("", isOn: boolBinding(key))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                case .string, .null:
                    SettingsRow(label: label(for: key), description: desc) {
                        TextField("", text: stringBinding(key))
                            .textFieldStyle(.roundedBorder)
                            .font(.minchCaption)
                            .frame(width: 150)
                    }
                case .number:
                    SettingsRow(label: label(for: key), description: desc) {
                        TextField("", text: numberBinding(key))
                            .textFieldStyle(.roundedBorder)
                            .font(.minchCaption)
                            .frame(width: 150)
                    }
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
        SettingsCard(title: "API Authentication") {
            if isEditing {
                VStack(alignment: .leading, spacing: MinchSpacing.s) {
                    SecureField("Paste your TorBox API key", text: $draftKey)
                        .textFieldStyle(.roundedBorder)
                        .disabled(inFlight)
                        .font(.minchCaption)
                    
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
                }
                .padding(MinchSpacing.l)
            } else {
                SettingsRow(
                    label: "TorBox API Key",
                    description: "Stored locally in your macOS Keychain."
                ) {
                    HStack(spacing: MinchSpacing.s) {
                        Text(maskedDisplay)
                            .font(.minchCaption.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, MinchSpacing.s)
                            .padding(.vertical, MinchSpacing.xs)
                            .background(Color.minchSurfaceSunken)
                            .cornerRadius(MinchRadius.s)
                        
                        Button("Replace…") { isEditing = true }
                            .buttonStyle(.minch(.secondary))
                            .controlSize(.small)
                    }
                }
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
        SettingsCard(title: "Local Preferences") {
            SettingsRow(
                label: "Download Location",
                description: "Where completed transfers are saved locally."
            ) {
                HStack(spacing: MinchSpacing.s) {
                    Text(model.customDownloadFolderURL.path)
                        .font(.minchCaption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: 180)
                        .padding(.horizontal, MinchSpacing.s)
                        .padding(.vertical, MinchSpacing.xs)
                        .background(Color.minchSurfaceSunken)
                        .cornerRadius(MinchRadius.s)

                    Button("Choose…") {
                        selectFolder()
                    }
                    .buttonStyle(.minch(.secondary))
                    .controlSize(.small)
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

// MARK: - Helper Layout Components

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MinchSpacing.s) {
            Text(title)
                .font(.minchHeadline)
                .foregroundStyle(.secondary)
                .padding(.leading, MinchSpacing.xs)
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color.minchSurfaceCard)
            .cornerRadius(MinchRadius.m)
            .overlay(
                RoundedRectangle(cornerRadius: MinchRadius.m)
                    .stroke(Color.minchHairline, lineWidth: 1)
            )
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    var description: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: MinchSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.minchBody)
                    .foregroundStyle(.primary)
                if let description {
                    Text(description)
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            content()
        }
        .padding(.horizontal, MinchSpacing.l)
        .padding(.vertical, MinchSpacing.m)
        .frame(minHeight: 48)
    }
}

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.minchBody)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.minchBody)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, MinchSpacing.l)
        .padding(.vertical, MinchSpacing.m)
        .frame(minHeight: 44)
    }
}
