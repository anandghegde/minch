import Foundation
import AppKit
import UserNotifications

public actor Notifier {
    public static let completedCategory = "minch.download.completed"
    public static let failedCategory = "minch.download.failed"
    public static let revealAction = "minch.reveal"

    private var didRegister = false

    public init() {}

    public func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await registerCategoriesIfNeeded(center: center)
    }

    private func registerCategoriesIfNeeded(center: UNUserNotificationCenter) async {
        guard !didRegister else { return }
        didRegister = true
        let reveal = UNNotificationAction(
            identifier: Self.revealAction,
            title: "Reveal in Finder",
            options: [.foreground]
        )
        let completed = UNNotificationCategory(
            identifier: Self.completedCategory,
            actions: [reveal],
            intentIdentifiers: [],
            options: []
        )
        let failed = UNNotificationCategory(
            identifier: Self.failedCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([completed, failed])
    }

    public func completed(name: String, path: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Download complete"
        content.body = name
        content.categoryIdentifier = Self.completedCategory
        content.userInfo = ["path": path]
        content.threadIdentifier = "minch.downloads"
        await deliver(content)
    }

    public func failed(name: String, reason: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Download failed"
        content.body = "\(name) — \(reason)"
        content.categoryIdentifier = Self.failedCategory
        content.threadIdentifier = "minch.downloads"
        await deliver(content)
    }

    private func deliver(_ content: UNNotificationContent) async {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

public enum NotifierActions {
    public static func handle(response: UNNotificationResponse) {
        if response.actionIdentifier == Notifier.revealAction,
           let path = response.notification.request.content.userInfo["path"] as? String {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
