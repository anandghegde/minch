import Foundation
import Observation
import AppKit
import SwiftData
import MinchKit
import MinchAPI
import MinchPersistence
import MinchDownloads

@MainActor
@Observable
final class AppModel {
    struct TorrentFileDraft: Equatable {
        let filename: String
        let data: Data
    }

    enum AuthState: Equatable {
        case unknown
        case signedOut(message: String?)
        case validating
        case signedIn(UserAccount)
    }

    var state: AuthState = .unknown
    var pendingKey: String = ""
    var isRefreshing: Bool = false
    var refreshError: String?
    var pendingMagnet: String = ""
    var pendingTorrentFile: TorrentFileDraft?
    var pendingName: String = ""
    var pendingCacheOnly: Bool = false
    var pendingCachedHash: String?
    var isAdding: Bool = false
    var addError: String?
    var inflightFileIDs: Set<String> = []
    var downloadProgress: [String: Double] = [:]
    var copyingFileIDs: Set<String> = []
    var deletingTransferIDs: Set<String> = []
    var infoBanner: String?
    var hosters: [Hoster] = []
    var subscriptions: [Subscription] = []
    var stats: UserStats?
    var accountLoadError: String?
    var isLoadingAccount: Bool = false
    var settings: [String: Endpoint.SettingValue]?
    var originalSettings: [String: Endpoint.SettingValue]?
    var isLoadingSettings: Bool = false
    var isSavingSettings: Bool = false
    var settingsError: String?
    var hasSettingsChanges: Bool {
        guard let settings, let originalSettings else { return false }
        return settings != originalSettings
    }

    let container: ModelContainer
    let notifier: Notifier
    let downloads: DownloadManager
    let updater = UpdaterController()

    private let secretStore: any SecretStore
    private let clientFactory: @Sendable (any APIKeyProvider) -> TorBoxClient
    private var client: TorBoxClient?
    private var syncEngine: SyncEngine?
    private var pollTask: Task<Void, Never>?
    private var preflightTask: Task<Void, Never>?
    private var rateLimitedUntil: Date?
    private var notificationsRequested = false

    init(
        secretStore: any SecretStore = KeychainStore(),
        clientFactory: @escaping @Sendable (any APIKeyProvider) -> TorBoxClient = { TorBoxClient(keyProvider: $0) }
    ) {
        self.secretStore = secretStore
        self.clientFactory = clientFactory
        let container = (try? PersistenceController.makeContainer()) ?? Self.fallbackContainer()
        self.container = container
        self.notifier = Notifier()
        self.downloads = DownloadManager(container: container, notifier: notifier)
        self.downloads.onFinish = { [weak self] fileID in
            Task { @MainActor in
                self?.inflightFileIDs.remove(fileID)
                self?.downloadProgress.removeValue(forKey: fileID)
            }
        }
        self.downloads.onProgress = { [weak self] fileID, progress in
            Task { @MainActor in
                self?.downloadProgress[fileID] = progress
            }
        }
    }

    func bootstrap() async {
        do {
            guard let key = try await secretStore.read(SecretKey.torboxAPIKey), !key.isEmpty else {
                state = .signedOut(message: nil)
                return
            }
            try await validate(key: key, persistOnSuccess: false)
        } catch {
            state = .signedOut(message: nil)
        }
    }

    func connect() async {
        let key = pendingKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            state = .signedOut(message: "Enter your TorBox API key to continue.")
            return
        }
        do {
            try await validate(key: key, persistOnSuccess: true)
            pendingKey = ""
        } catch let error as APIError {
            state = .signedOut(message: friendlyMessage(for: error))
        } catch {
            state = .signedOut(message: "Couldn't reach TorBox. Check your connection and try again.")
        }
    }

    func signOut() async {
        try? await secretStore.delete(SecretKey.torboxAPIKey)
        stopPolling()
        client = nil
        syncEngine = nil
        state = .signedOut(message: nil)
    }

    func addMagnet() async {
        guard let client else { return }
        let magnet = pendingMagnet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard magnet.hasPrefix("magnet:") else {
            addError = "Paste a magnet link starting with magnet:"
            return
        }
        let name = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheOnly = pendingCacheOnly
        isAdding = true
        addError = nil
        do {
            try await client.addMagnet(magnet, name: name.isEmpty ? nil : name, cacheOnly: cacheOnly)
            resetAddSheet()
            isAdding = false
            await refresh()
        } catch let error as APIError {
            isAdding = false
            addError = friendlyMessage(for: error)
        } catch {
            isAdding = false
            addError = "Couldn't add magnet."
        }
    }

    /// Submits a direct/file-host link via `POST /webdl/createwebdownload`.
    /// Validation matches `addMagnet`: caller must hand us an http(s) URL —
    /// the Add bar's branching logic filters magnet/torrent-file cases first.
    func addWebDownload() async {
        guard let client else { return }
        let link = pendingMagnet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: link), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            addError = "Paste a magnet, .torrent file, or http(s) download link."
            return
        }
        let name = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
        isAdding = true
        addError = nil
        do {
            try await client.addWebDownload(link, name: name.isEmpty ? nil : name)
            resetAddSheet()
            isAdding = false
            await refresh()
        } catch let error as APIError {
            isAdding = false
            addError = friendlyMessage(for: error)
        } catch {
            isAdding = false
            addError = "Couldn't add that download link."
        }
    }

    /// Reads a `.torrent` file off disk and uploads it via the file-form variant
    /// of `/torrents/createtorrent`. Honors the same name/cache-only overrides
    /// as `addMagnet`.
    func addTorrentFile() async {
        guard let client, let draft = pendingTorrentFile else { return }
        let name = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheOnly = pendingCacheOnly
        isAdding = true
        addError = nil
        do {
            try await client.addTorrentFile(
                draft.data,
                filename: draft.filename,
                name: name.isEmpty ? nil : name,
                cacheOnly: cacheOnly
            )
            resetAddSheet()
            isAdding = false
            await refresh()
        } catch let error as APIError {
            isAdding = false
            addError = friendlyMessage(for: error)
        } catch {
            isAdding = false
            addError = "Couldn't add that .torrent file."
        }
    }

    /// Loads a `.torrent` file from disk into `pendingTorrentFile`, surfacing
    /// parse errors via `addError`.
    func loadTorrentFile(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard data.count > 0, data.count < 8 * 1024 * 1024 else {
                addError = "That file looks empty or unreasonably large."
                return
            }
            pendingTorrentFile = TorrentFileDraft(filename: url.lastPathComponent, data: data)
            pendingMagnet = ""
            pendingCachedHash = nil
            addError = nil
        } catch {
            addError = "Couldn't read that .torrent file."
        }
    }

    /// Runs `checkcached` against the BTIH in the pending magnet so the Add
    /// sheet can show "Already cached — will be instant" before the user
    /// commits. Best-effort, debounced; failures are swallowed.
    func preflightCache() async {
        // Real debounce: cancel any pending check so fast typing collapses
        // into a single API call.
        preflightTask?.cancel()
        let magnet = pendingMagnet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client, let hash = Self.btihHash(in: magnet) else {
            pendingCachedHash = nil
            return
        }
        preflightTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            do {
                let hits = try await client.checkCached(hashes: [hash])
                if Task.isCancelled { return }
                await MainActor.run {
                    self?.pendingCachedHash = hits.contains(hash.lowercased()) ? hash.lowercased() : nil
                }
            } catch {
                // advisory — ignore
            }
        }
    }

    func resetAddSheet() {
        pendingMagnet = ""
        pendingTorrentFile = nil
        pendingName = ""
        pendingCacheOnly = false
        pendingCachedHash = nil
        addError = nil
    }

    /// Pulls the 40-char hex BTIH out of a magnet URI's `xt=urn:btih:...`
    /// parameter. Base32 hashes (32 chars) are returned as-is — callers
    /// compare lowercased.
    static func btihHash(in magnet: String) -> String? {
        guard let url = URL(string: magnet),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        for item in comps.queryItems ?? [] where item.name == "xt" {
            guard let value = item.value, value.lowercased().hasPrefix("urn:btih:") else { continue }
            let raw = String(value.dropFirst("urn:btih:".count))
            return raw.isEmpty ? nil : raw
        }
        return nil
    }

    /// Accepts a magnet (or `minch://addmagnet?url=...`) from external sources
    /// like URL schemes, the Services menu, or watch folders (PRD §3.8).
    func ingestExternalMagnet(_ raw: String) async {
        guard client != nil else { return }
        let candidate: String
        if let url = URL(string: raw), url.scheme == "minch" {
            candidate = url.queryItem(named: "url")
                ?? url.queryItem(named: "magnet")
                ?? ""
        } else {
            candidate = raw
        }
        let magnet = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard magnet.hasPrefix("magnet:") else {
            addError = "Could not parse an external magnet link."
            return
        }
        pendingMagnet = magnet
        await addMagnet()
    }

    func refresh() async {
        guard let engine = syncEngine else { return }
        isRefreshing = true
        refreshError = nil
        do {
            try await engine.refresh()
        } catch let error as APIError {
            refreshError = friendlyMessage(for: error)
        } catch {
            refreshError = "Couldn't refresh transfers."
        }
        isRefreshing = false
    }

    func downloadFile(transferID: String, fileID: String, transferName: String, fileName: String) async {
        guard let client else { return }
        guard !inflightFileIDs.contains(fileID) else { return }
        inflightFileIDs.insert(fileID)
        do {
            let url = try await client.requestDownloadURL(transferID: transferID, fileID: fileID)
            downloads.start(
                url: url,
                fileID: fileID,
                transferName: transferName,
                fileName: fileName
            )
        } catch let error as APIError {
            inflightFileIDs.remove(fileID)
            refreshError = friendlyMessage(for: error)
        } catch {
            inflightFileIDs.remove(fileID)
            refreshError = "Couldn't request a download URL."
        }
    }

    func cancelDownload(fileID: String) {
        downloads.cancel(fileID: fileID)
        inflightFileIDs.remove(fileID)
    }

    func streamURL(transferID: String, fileID: String) async -> URL? {
        guard let client else { return nil }
        // Prefer the direct redirect URL so AVPlayer can begin transport setup
        // immediately instead of waiting on a JSON round-trip.
        if let direct = await client.directDownloadURL(transferID: transferID, fileID: fileID) {
            return direct
        }
        do {
            return try await client.requestDownloadURL(transferID: transferID, fileID: fileID)
        } catch let error as APIError {
            refreshError = friendlyMessage(for: error)
            return nil
        } catch {
            refreshError = "Couldn't open the stream."
            return nil
        }
    }

    func copyDownloadLink(transferID: String, fileID: String) async {
        guard let client else { return }
        guard !copyingFileIDs.contains(fileID) else { return }
        copyingFileIDs.insert(fileID)
        defer { copyingFileIDs.remove(fileID) }
        do {
            let url = try await client.requestDownloadURL(transferID: transferID, fileID: fileID)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
            infoBanner = "Download link copied."
        } catch let error as APIError {
            refreshError = friendlyMessage(for: error)
        } catch {
            refreshError = "Couldn't request a download URL."
        }
    }

    func deleteTransfer(_ transferID: String) async {
        guard let client else { return }
        guard !deletingTransferIDs.contains(transferID) else { return }
        deletingTransferIDs.insert(transferID)
        defer { deletingTransferIDs.remove(transferID) }
        do {
            try await client.controlTransfer(id: transferID, op: .delete)
            removeLocalTransfer(id: transferID)
            infoBanner = "Removed from TorBox."
        } catch let error as APIError {
            refreshError = friendlyMessage(for: error)
        } catch {
            refreshError = "Couldn't delete that transfer."
        }
    }

    /// Renames a transfer server-side via `PUT /torrents/edittorrent` and
    /// updates the local SwiftData row to match on success.
    func renameTransfer(_ transferID: String, to newName: String) async {
        guard let client else { return }
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try await client.editTransfer(id: transferID, name: clean)
            updateLocalTransferName(id: transferID, name: clean)
            infoBanner = "Renamed on TorBox."
        } catch let error as APIError {
            refreshError = friendlyMessage(for: error)
        } catch {
            refreshError = "Couldn't rename that transfer."
        }
    }

    /// Pushes the current local tag list for a transfer up to TorBox so it
    /// stays in sync across clients.
    func syncTags(_ transferID: String, tags: [String]) async {
        guard let client else { return }
        do {
            try await client.editTransfer(id: transferID, tags: tags)
        } catch {
            // Tag sync is best-effort — local tags already saved. Surface the
            // failure quietly so the user knows the cloud copy may diverge.
            refreshError = "Couldn't sync tags to TorBox."
        }
    }

    private func removeLocalTransfer(id: String) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<StoredTransfer>(predicate: #Predicate { $0.id == id })
        guard let row = try? context.fetch(descriptor).first else { return }
        context.delete(row)
        try? context.save()
    }

    private func updateLocalTransferName(id: String, name: String) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<StoredTransfer>(predicate: #Predicate { $0.id == id })
        guard let row = try? context.fetch(descriptor).first else { return }
        row.name = name
        try? context.save()
    }

    private func validate(key: String, persistOnSuccess: Bool) async throws {
        state = .validating
        let provider = StaticAPIKeyProvider(key)
        let candidate = clientFactory(provider)
        let account = try await candidate.me()
        if persistOnSuccess {
            try await secretStore.write(key, for: SecretKey.torboxAPIKey)
        }
        activate(client: candidate, signedInAs: account)
    }

    /// Wires up a freshly-validated client + sync engine and resumes polling.
    /// Shared by the initial sign-in path and `replaceAPIKey`.
    private func activate(client: TorBoxClient, signedInAs account: UserAccount) {
        self.client = client
        self.syncEngine = SyncEngine(container: container) { [client] in
            // Torrents and webdl share the SyncEngine's `[Transfer]` list and
            // its delete-absent reconciliation, so a fetch failure on either
            // surface MUST abort the merge — otherwise the failing surface's
            // rows get wiped from local storage.
            async let torrents = client.listTransfers()
            async let webdls = client.listWebDownloads()
            return try await torrents + webdls
        }
        state = .signedIn(account)
        startPolling()
        if !notificationsRequested {
            notificationsRequested = true
            Task { await notifier.requestAuthorizationIfNeeded() }
        }
        Task { await loadHosters() }
    }

    /// Validates a candidate key against `/user/me`, writes it to Keychain,
    /// swaps in the new client + sync engine, and keeps the existing local
    /// SwiftData rows. Throws on validation failure or empty input — the
    /// previous client and stored key are left untouched in that case.
    func replaceAPIKey(_ newKey: String) async throws {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIError.validation("API key cannot be empty.")
        }
        let provider = StaticAPIKeyProvider(trimmed)
        let candidate = clientFactory(provider)
        let account = try await candidate.me()
        try await secretStore.write(trimmed, for: SecretKey.torboxAPIKey)
        stopPolling()
        activate(client: candidate, signedInAs: account)
    }

    /// Best-effort fetch of supported file hosts. Cached for the session; used
    /// by the Add bar to render a "Supported hosts" hint.
    func loadHosters() async {
        guard let client else { return }
        guard hosters.isEmpty else { return }
        do {
            let result = try await client.listHosters()
            hosters = result
        } catch {
            // Advisory data — silent failure is fine.
        }
    }

    /// Pulls subscriptions + usage stats for the Account view. Both calls run
    /// in parallel; partial failure surfaces a single user-facing message but
    /// still shows whatever data did arrive.
    func loadAccount() async {
        guard let client else { return }
        isLoadingAccount = true
        accountLoadError = nil
        async let subs = client.subscriptions()
        async let usage = client.stats()
        do {
            let (s, u) = try await (subs, usage)
            subscriptions = s
            stats = u
        } catch let error as APIError {
            accountLoadError = friendlyMessage(for: error)
        } catch {
            accountLoadError = "Couldn't load account details."
        }
        isLoadingAccount = false
    }

    /// Reads `/user/me?settings=true` and caches both the working copy and a
    /// pristine snapshot so the form can diff against the original on save.
    func loadSettings() async {
        guard let client else { return }
        isLoadingSettings = true
        settingsError = nil
        do {
            let result = try await client.loadUserSettings()
            settings = result
            originalSettings = result
        } catch let error as APIError {
            settingsError = friendlyMessage(for: error)
        } catch {
            settingsError = "Couldn't load settings."
        }
        isLoadingSettings = false
    }

    func updateSetting(key: String, value: Endpoint.SettingValue) {
        guard settings != nil else { return }
        settings?[key] = value
    }

    /// Writes only the keys that diverge from `originalSettings`. After a
    /// successful save the pristine snapshot becomes the new baseline so the
    /// "Save" button correctly disables itself.
    func saveSettings() async {
        guard let client, let working = settings, let original = originalSettings else { return }
        var changed: [String: Endpoint.SettingValue] = [:]
        for (key, value) in working where original[key] != value {
            changed[key] = value
        }
        guard !changed.isEmpty else { return }
        isSavingSettings = true
        settingsError = nil
        do {
            try await client.updateSettings(changed)
            originalSettings = working
        } catch let error as APIError {
            settingsError = friendlyMessage(for: error)
        } catch {
            settingsError = "Couldn't save settings."
        }
        isSavingSettings = false
    }

    private func friendlyMessage(for error: APIError) -> String {
        switch error {
        case .auth(let detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("HTTP ") {
                return "That key was rejected by TorBox. Double-check it and try again."
            }
            return "TorBox rejected this request: \(trimmed)"
        case .quota(let detail):
            // The client packs `retry-after=Ns remaining=M` into the detail so
            // we can show the user roughly how long to wait. When TorBox also
            // returned a `detail` string, it's prepended in front of the rate
            // info — surface the whole thing.
            return "TorBox is rate-limiting requests (\(detail)). Wait a moment and retry."
        case .transient(let detail):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("HTTP ") {
                return "TorBox is temporarily unavailable. Try again shortly."
            }
            return "TorBox is temporarily unavailable: \(trimmed)"
        case .validation(let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "TorBox didn't accept that request."
                : "TorBox didn't accept that request: \(trimmed)"
        case .decoding: return "Unexpected response from TorBox."
        case .unknown(let status, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Unexpected response (HTTP \(status))."
            }
            return "Unexpected response (HTTP \(status)): \(trimmed)"
        }
    }

    private static func fallbackContainer() -> ModelContainer {
        try! PersistenceController.makeContainer(inMemory: true)
    }

    private func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                // 15s base interval — TorBox free-tier limits make a 5s loop
                // burn budget you'd rather spend on user-initiated calls.
                try? await Task.sleep(for: .seconds(15))
                if Task.isCancelled { return }
                await self?.pollIfActive()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pollIfActive() async {
        guard let engine = syncEngine else { return }
        // Back off entirely if we're known-rate-limited.
        if let until = rateLimitedUntil, until > Date() { return }
        let descriptor = FetchDescriptor<StoredTransfer>(
            predicate: #Predicate { $0.statusRaw != "done" }
        )
        let active = (try? container.mainContext.fetchCount(descriptor)) ?? 0
        guard active > 0 else { return }
        do {
            try await engine.refresh()
        } catch let error as APIError {
            if case .quota = error {
                // Cool off for 60s before the next poll attempt.
                rateLimitedUntil = Date().addingTimeInterval(60)
            }
        } catch {
            // Swallow non-quota errors; surface only on manual refresh.
        }
    }
}

private extension URL {
    func queryItem(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
