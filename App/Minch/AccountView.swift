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

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: MinchSpacing.xl) {
                    planSection
                    usageSection
                    subscriptionsSection
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
        .frame(width: 520, height: 560)
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
