import Foundation

/// PRD §3.3 — what we know how to play in-app.
enum MediaKind {
    case video
    case audio
    case other

    static func detect(name: String, mime: String?) -> MediaKind {
        if let mime {
            if mime.hasPrefix("video/") { return .video }
            if mime.hasPrefix("audio/") { return .audio }
        }
        let ext = (name as NSString).pathExtension.lowercased()
        if videoExts.contains(ext) { return .video }
        if audioExts.contains(ext) { return .audio }
        return .other
    }

    private static let videoExts: Set<String> = [
        "mp4", "m4v", "mov", "mkv", "webm", "avi", "mpg", "mpeg", "ts", "m2ts"
    ]
    private static let audioExts: Set<String> = [
        "mp3", "m4a", "aac", "flac", "wav", "aiff", "ogg", "opus"
    ]
}
