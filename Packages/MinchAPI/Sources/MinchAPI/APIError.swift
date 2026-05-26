import Foundation

public enum APIError: Error, Sendable, Equatable {
    case auth(String)
    case transient(underlying: String)
    case validation(String)
    case quota(String)
    case decoding(String)
    case unknown(status: Int, body: String)

    public var bucket: String {
        switch self {
        case .auth: "auth"
        case .transient: "transient"
        case .validation: "validation"
        case .quota: "quota"
        case .decoding: "decoding"
        case .unknown: "unknown"
        }
    }
}
