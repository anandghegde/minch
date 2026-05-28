import SwiftUI

/// Top-of-sidebar account pill. Renders a gradient avatar with a status dot,
/// the plan name on top, and the email below. Hover dims toward
/// `minchSurfaceCardHover`; tap fires `action`.
///
/// Quota intentionally absent — `UserAccount` does not surface remaining quota
/// from the TorBox API, and PRD §14.2's quota slot is deferred until it does.
public struct MinchAccountChip: View {
    private let name: String
    private let email: String?
    private let planName: String
    private let isSubscribed: Bool
    private let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        name: String,
        email: String?,
        planName: String,
        isSubscribed: Bool,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.email = email
        self.planName = planName
        self.isSubscribed = isSubscribed
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: MinchSpacing.s) {
                avatar
                VStack(alignment: .leading, spacing: MinchSpacing.xs) {
                    Text(planName)
                        .font(.minchBody)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let email, !email.isEmpty {
                        Text(email)
                            .font(.minchMetadata)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(MinchSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                    .fill(isHovered ? Color.minchSurfaceCardHover : Color.clear)
            )
            .animation(reduceMotion ? nil : MinchMotion.snap, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var avatar: some View {
        Circle()
            .fill(LinearGradient(
                colors: [.minchBolt, .minchCurrent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 28, height: 28)
            .overlay(
                Text(Self.initial(name: name))
                    .font(.minchBody.bold())
                    .foregroundStyle(.white)
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Self.statusDotColor(isSubscribed: isSubscribed))
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.minchSurfaceSidebar, lineWidth: 1)
                    )
                    .offset(x: 1, y: -1)
            }
    }

    private var accessibilityLabel: String {
        let status = isSubscribed ? "active" : "inactive"
        if let email, !email.isEmpty {
            return "\(planName) plan, \(status), signed in as \(email)"
        }
        return "\(planName) plan, \(status)"
    }

    // MARK: - Test-facing helpers

    public nonisolated static func statusDotColor(isSubscribed: Bool) -> Color {
        isSubscribed ? .minchSuccess : .minchWarning
    }

    nonisolated static func initial(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}

#Preview {
    VStack(spacing: 12) {
        MinchAccountChip(
            name: "anand@example.com",
            email: "anand@example.com",
            planName: "Pro",
            isSubscribed: true,
            action: {}
        )
        MinchAccountChip(
            name: "free@example.com",
            email: "free@example.com",
            planName: "Free",
            isSubscribed: false,
            action: {}
        )
    }
    .padding()
    .frame(width: 220)
    .background(Color.minchSurfaceSidebar)
    .preferredColorScheme(.dark)
}
