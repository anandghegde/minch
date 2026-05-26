import SwiftUI
import AVKit
import MediaPlayer
import SwiftData
import MinchUI
import MinchPersistence

/// PRD §3.5 — Player Mode. Built-in AVKit player with resume position and
/// Now Playing integration.
struct PlayerView: View {
    let file: StoredTransferFile
    let url: URL
    let title: String
    let kind: MediaKind
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var player: AVPlayer?
    @State private var observer: Any?
    @State private var lastSavedAt: Date = .distantPast

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                PlayerSurface(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView().controlSize(.large)
            }

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(MinchSpacing.s)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityLabel("Close player")
                    Spacer()
                    Text(title)
                        .font(.minchHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, MinchSpacing.s)
                    Spacer()
                    Spacer().frame(width: 40)
                }
                .padding(MinchSpacing.s)
                .background(LinearGradient(
                    colors: [.black.opacity(0.55), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        let player = AVPlayer(url: url)
        if let resume = file.playbackPositionSec, resume > 1 {
            player.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
        }
        player.play()

        let interval = CMTime(seconds: 1.0, preferredTimescale: 1)
        observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            let duration = player.currentItem?.duration.seconds
            Task { @MainActor in
                persistPosition(seconds)
                updateNowPlaying(seconds: seconds, duration: duration)
            }
        }

        self.player = player
        configureNowPlaying()
    }

    private func stop() {
        if let player, let observer {
            player.removeTimeObserver(observer)
        }
        if let seconds = player?.currentTime().seconds, seconds.isFinite {
            persistPosition(seconds, force: true)
        }
        player?.pause()
        player = nil
        observer = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    private func persistPosition(_ seconds: Double, force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastSavedAt) > 5 else { return }
        lastSavedAt = now
        file.playbackPositionSec = seconds
        file.playedAt = now
        try? modelContext.save()
    }

    private func configureNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyMediaType: (kind == .audio
                ? MPNowPlayingInfoMediaType.audio.rawValue
                : MPNowPlayingInfoMediaType.video.rawValue)
        ]
        if let duration = player?.currentItem?.duration.seconds, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    private func updateNowPlaying(seconds: Double, duration: Double?) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        if let duration, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

/// AppKit AVPlayerView wrapper. SwiftUI's `VideoPlayer` crashes at launch in
/// our SwiftPM-bundled app (`_AVKit_SwiftUI` generic-metadata fatalError), so
/// we host the AppKit view directly, which avoids that code path.
private struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.allowsPictureInPicturePlayback = true
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player { nsView.player = player }
    }
}
