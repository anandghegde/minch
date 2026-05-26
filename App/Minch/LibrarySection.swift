import Foundation

/// Top-level sidebar selection (PRD §3.2). Sprint 5 shipped Active/Downloaded;
/// Sprint 9 adds Smart Collections (videos, audio, recent). Trash arrives later.
enum LibrarySection: Hashable, Identifiable, CaseIterable {
    case active
    case downloaded
    case videos
    case audio
    case recent
    case settings

    var id: String {
        switch self {
        case .active: "active"
        case .downloaded: "downloaded"
        case .videos: "videos"
        case .audio: "audio"
        case .recent: "recent"
        case .settings: "settings"
        }
    }

    var title: String {
        switch self {
        case .active: "Active"
        case .downloaded: "Downloaded"
        case .videos: "Videos"
        case .audio: "Audio"
        case .recent: "Recent"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .active: "bolt.fill"
        case .downloaded: "tray.full"
        case .videos: "film"
        case .audio: "music.note"
        case .recent: "clock"
        case .settings: "gearshape"
        }
    }

    var group: Group {
        switch self {
        case .active, .downloaded: .library
        case .videos, .audio, .recent: .smart
        case .settings: .system
        }
    }

    enum Group: String, CaseIterable {
        case library
        case smart
        case system

        var title: String {
            switch self {
            case .library: "Library"
            case .smart: "Smart"
            case .system: "System"
            }
        }
    }
}
