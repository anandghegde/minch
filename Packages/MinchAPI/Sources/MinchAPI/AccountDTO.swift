import Foundation

/// One row from `GET /user/subscriptions`. TorBox stores billing details
/// outside the app's purview — we surface only plan/status/timestamps for the
/// read-only Account view.
public struct Subscription: Decodable, Sendable, Equatable, Identifiable {
    public let subscriptionCode: String
    public let planName: String?
    public let planCode: String?
    public let status: String?
    public let gateway: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public var id: String { subscriptionCode }

    public init(subscriptionCode: String, planName: String?, planCode: String?, status: String?, gateway: String?, createdAt: Date?, updatedAt: Date?) {
        self.subscriptionCode = subscriptionCode
        self.planName = planName
        self.planCode = planCode
        self.status = status
        self.gateway = gateway
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// `GET /user/stats?general=true` payload. We only request `general` to keep
/// the response small; bandwidth-over-time isn't shown in v1.
public struct UserStats: Decodable, Sendable, Equatable {
    public let general: General?

    public struct General: Decodable, Sendable, Equatable {
        public let totalDownloaded: Int64?
        public let totalUploaded: Int64?
        public let ratio: Double?
        public let totalItemsDownloaded: Int?
    }

    public init(general: General?) {
        self.general = general
    }
}
