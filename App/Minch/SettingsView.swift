import SwiftUI
import MinchAPI
import MinchUI

/// Inline settings tab. Only renders a curated allowlist of TorBox keys — other
/// server-side settings are intentionally hidden so the surface stays focused.
struct SettingsView: View {
    @Bindable var model: AppModel

    /// Keys we expose, in the order they should appear.
    private static let allowedKeys: [String] = [
        "seed_torrents",
        "allow_zipped",
        "download_speed_in_tab",
        "show_tracker_in_torrent"
    ]

    /// Tooltip copy shown on hover via `.help(_:)`.
    private static let tooltips: [String: String] = [
        "seed_torrents": "Whether your finished torrents keep seeding back to the swarm.",
        "allow_zipped": "Let TorBox bundle multi-file downloads into a single .zip when requested.",
        "download_speed_in_tab": "Show current download speed in the browser tab / window title.",
        "show_tracker_in_torrent": "Display tracker URLs alongside torrent details."
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            if model.isLoadingSettings && model.settings == nil {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.settings == nil {
                VStack(spacing: MinchSpacing.s) {
                    Text("Couldn't load settings.")
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                    if let error = model.settingsError {
                        Text(error)
                            .font(.minchCaption)
                            .foregroundStyle(Color.minchDanger)
                    }
                    Button("Retry") { Task { await model.loadSettings() } }
                        .buttonStyle(.minch(.ghost))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: MinchSpacing.m) {
                        ForEach(visibleKeys, id: \.self) { key in
                            fieldView(key: key)
                        }
                        if let error = model.settingsError {
                            Text(error)
                                .font(.minchCaption)
                                .foregroundStyle(Color.minchDanger)
                        }
                    }
                    .padding(.horizontal, MinchSpacing.xxl)
                    .padding(.vertical, MinchSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                HStack {
                    Spacer()
                    Button("Save") {
                        Task { await model.saveSettings() }
                    }
                    .buttonStyle(.minch(.primary))
                    .disabled(model.isSavingSettings || !model.hasSettingsChanges)
                }
                .padding(MinchSpacing.m)
            }
        }
        .task { await model.loadSettings() }
    }

    private var header: some View {
        HStack(spacing: MinchSpacing.s) {
            Text("Settings")
                .font(.minchTitle)
                .foregroundStyle(.primary)
            Spacer()
            if model.isSavingSettings { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, MinchSpacing.xxl)
        .padding(.top, MinchSpacing.l)
        .padding(.bottom, MinchSpacing.s)
    }

    /// Only render allowlisted keys that the server actually returned.
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
            case .string:
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
            case .null:
                VStack(alignment: .leading, spacing: 4) {
                    Text(label(for: key))
                        .font(.minchCaption)
                        .foregroundStyle(.secondary)
                    TextField(label(for: key), text: stringBinding(key))
                        .textFieldStyle(.roundedBorder)
                        .font(.minchCaption)
                }
                .help(tooltip)
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
