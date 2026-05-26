import Foundation
import Observation

/// PRD §13 sprint 14 — Sparkle skeleton.
///
/// This is intentionally a stub: wiring real Sparkle requires the EdDSA signing
/// key (SUPublicEDKey in Info.plist), a hosted appcast.xml, and notarized
/// builds — all of which depend on infrastructure outside the repo.
///
/// To finish the integration:
///   1. Add `.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")`
///      to Package.swift and the `Sparkle` product to the Minch target.
///   2. Replace `manualState` with a real `SPUStandardUpdaterController`.
///   3. Set `SUFeedURL` and `SUPublicEDKey` in the app's Info.plist.
///   4. Publish docs/appcast.xml to the URL referenced in SUFeedURL.
@MainActor
@Observable
final class UpdaterController {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, url: URL)
        case error(String)
    }

    var state: State = .idle

    func checkForUpdates() {
        guard state != .checking else { return }
        state = .checking
        // Real implementation: updater.checkForUpdates()
        // Stub: pretend we hit the appcast and there are no updates.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            state = .upToDate
        }
    }
}
