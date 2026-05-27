import SwiftUI

/// A row in the main-window sidebar: SF Symbol, label, optional count badge.
///
/// When `isSelected` is true the row paints a leading 3pt Bolt→Current gradient
/// bar and tints the icon `.minchCurrent`. When false the icon uses the muted
/// sidebar icon color. The macOS list style still owns the row highlight; this
/// view layers the brand affordance on top.
public struct MinchSidebarRow: View {
    private let systemImage: String
    private let title: String
    private let count: Int?
    private let isSelected: Bool

    public init(
        systemImage: String,
        title: String,
        count: Int? = nil,
        isSelected: Bool = false
    ) {
        self.systemImage = systemImage
        self.title = title
        self.count = count
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: systemImage)
                .font(.minchBody)
                .foregroundStyle(Self.iconColor(isSelected: isSelected))
                .frame(width: 18)

            Text(title)
                .font(.minchBody)
                .foregroundStyle(.primary)

            Spacer(minLength: MinchSpacing.s)

            if let count, count > 0 {
                Text("\(count)")
                    .font(.minchMetadata)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(Color.minchSurfaceSunken)
                    )
            }
        }
        .padding(.vertical, 2)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(LinearGradient(
                    colors: [.minchBolt, .minchCurrent],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 3)
                .padding(.vertical, 2)
                .opacity(Self.barOpacity(isSelected: isSelected))
                .animation(MinchMotion.snap, value: isSelected)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let count, count > 0 else { return title }
        return "\(title), \(count)"
    }

    // MARK: - Test-facing helpers

    static func iconColor(isSelected: Bool) -> Color {
        isSelected ? .minchCurrent : .minchSidebarIconUnselected
    }

    static func barOpacity(isSelected: Bool) -> Double {
        isSelected ? 1 : 0
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 4) {
        MinchSidebarRow(systemImage: "bolt.fill", title: "Active", count: 3, isSelected: true)
        MinchSidebarRow(systemImage: "tray.full", title: "Downloaded", count: 27, isSelected: false)
        MinchSidebarRow(systemImage: "trash", title: "Trash", isSelected: false)
    }
    .padding()
    .frame(width: 220)
    .background(Color.minchSurfaceSidebar)
    .preferredColorScheme(.dark)
}
