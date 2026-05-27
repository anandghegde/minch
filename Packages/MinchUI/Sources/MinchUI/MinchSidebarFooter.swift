import SwiftUI

/// Pinned bottom row of the main-window sidebar.
///
/// Left: gear cog (opens Settings, ⌘,). Right: Add button (opens command
/// palette in Add mode, ⌘N). Resting icons use the muted sidebar tint;
/// hover lifts them to `.minchCurrent`.
public struct MinchSidebarFooter: View {
    public let onOpenSettings: () -> Void
    public let onAdd: () -> Void

    public init(
        onOpenSettings: @escaping () -> Void,
        onAdd: @escaping () -> Void
    ) {
        self.onOpenSettings = onOpenSettings
        self.onAdd = onAdd
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.minchSurfaceSunken)
                .padding(.horizontal, MinchSpacing.s)

            HStack(spacing: MinchSpacing.s) {
                FooterIconButton(
                    systemImage: "gearshape",
                    accessibilityLabel: "Settings",
                    action: onOpenSettings
                )
                Spacer()
                FooterIconButton(
                    systemImage: "bolt.badge.plus",
                    accessibilityLabel: "Add transfer",
                    action: onAdd
                )
            }
            .padding(MinchSpacing.s)
        }
    }

    // MARK: - Test-facing helpers

    static func iconColor(isHovered: Bool) -> Color {
        isHovered ? .minchCurrent : .minchSidebarIconUnselected
    }
}

private struct FooterIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.minchBody)
                .foregroundStyle(MinchSidebarFooter.iconColor(isHovered: isHovered))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .animation(reduceMotion ? nil : MinchMotion.snap, value: isHovered)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    MinchSidebarFooter(onOpenSettings: {}, onAdd: {})
        .frame(width: 220)
        .background(Color.minchSurfaceSidebar)
        .preferredColorScheme(.dark)
}
