import SwiftUI

/// A row in the main-window sidebar: SF Symbol, label, optional count badge.
///
/// Selection state is handled by the enclosing `List(selection:)` — this view
/// renders the row only. The macOS list style provides the highlight.
public struct MinchSidebarRow: View {
    private let systemImage: String
    private let title: String
    private let count: Int?

    public init(systemImage: String, title: String, count: Int? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.count = count
    }

    public var body: some View {
        HStack(spacing: MinchSpacing.s) {
            Image(systemName: systemImage)
                .font(.minchBody)
                .foregroundStyle(Color.minchCurrent)
                .frame(width: 18)

            Text(title)
                .font(.minchBody)
                .foregroundStyle(.primary)

            Spacer(minLength: MinchSpacing.s)

            if let count, count > 0 {
                Text("\(count)")
                    .font(.minchCaption)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let count, count > 0 else { return title }
        return "\(title), \(count)"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 4) {
        MinchSidebarRow(systemImage: "bolt.fill", title: "Active", count: 3)
        MinchSidebarRow(systemImage: "tray.full", title: "Downloaded", count: 27)
        MinchSidebarRow(systemImage: "trash", title: "Trash")
    }
    .padding()
    .frame(width: 220)
    .background(Color.minchSurfacePrimary)
    .preferredColorScheme(.dark)
}
