import Foundation

/// Top-level filter selection in the Library window. Each case maps to a
/// pill in the filter bar (PRD §3.2 + 2026-05-28 sidebar-removal redesign).
enum LibrarySection: Hashable, Identifiable, CaseIterable {
    case active
    case downloaded
    case videos
    case audio
    case recent

    var id: String {
        switch self {
        case .active: "active"
        case .downloaded: "downloaded"
        case .videos: "videos"
        case .audio: "audio"
        case .recent: "recent"
        }
    }

    var title: String {
        switch self {
        case .active: "Active"
        case .downloaded: "Downloaded"
        case .videos: "Videos"
        case .audio: "Audio"
        case .recent: "Recent"
        }
    }

    var systemImage: String {
        switch self {
        case .active: "bolt.fill"
        case .downloaded: "tray.full"
        case .videos: "film"
        case .audio: "music.note"
        case .recent: "clock"
        }
    }

    var group: Group {
        switch self {
        case .active, .downloaded: .library
        case .videos, .audio, .recent: .smart
        }
    }

    enum Group: String, CaseIterable {
        case library
        case smart

        var title: String {
            switch self {
            case .library: "Library"
            case .smart: "Smart Collections"
            }
        }
    }
}
