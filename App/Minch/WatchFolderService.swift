import Foundation

/// PRD §3.8 — watch folder automation. Observes a directory, surfaces any
/// new `.torrent` / `.magnet` files via the callback, and dedupes by URL.
/// File ingestion (turning the .torrent into a magnet/upload) is the caller's
/// responsibility; this service stays focused on the filesystem half.
@MainActor
final class WatchFolderService {
    enum Discovery {
        case torrentFile(URL)
        case magnetTextFile(URL, magnet: String)
    }

    var onDiscover: ((Discovery) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var fileDescriptor: Int32 = -1
    private var seen: Set<URL> = []

    func start(watching url: URL) {
        stop()
        let path = url.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd
        watchedURL = url

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.scan()
        }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        src.resume()
        source = src
        scan()
    }

    func stop() {
        source?.cancel()
        source = nil
        watchedURL = nil
        seen.removeAll()
    }

    deinit {
        if fileDescriptor >= 0 { close(fileDescriptor) }
    }

    private func scan() {
        guard let watchedURL else { return }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: watchedURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for entry in contents where !seen.contains(entry) {
            switch entry.pathExtension.lowercased() {
            case "torrent":
                seen.insert(entry)
                onDiscover?(.torrentFile(entry))
            case "magnet", "txt":
                if let body = try? String(contentsOf: entry, encoding: .utf8),
                   let line = body.split(separator: "\n").first(where: { $0.hasPrefix("magnet:") }) {
                    seen.insert(entry)
                    onDiscover?(.magnetTextFile(entry, magnet: String(line)))
                }
            default:
                break
            }
        }
    }
}
