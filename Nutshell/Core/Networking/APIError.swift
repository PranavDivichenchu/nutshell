import Foundation

/// Failures the app can explain to someone in plain language.
enum APIError: LocalizedError, Equatable {
    /// No usable network connection.
    case offline
    /// The client is being throttled. Open Food Facts documents 10 requests a minute on
    /// search and states that exceeding it can get the IP banned, so this is explicitly
    /// NOT retried — backing off is the whole point.
    case rateLimited
    /// Open Food Facts is rate-limiting or down. Its search endpoint does this often,
    /// answering with an HTML maintenance page instead of JSON.
    case serviceUnavailable
    /// The response arrived but did not match the expected shape.
    case unreadableResponse
    case timedOut
    case unexpected(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .offline: "You're offline"
        case .rateLimited: "Too many searches"
        case .serviceUnavailable: "Open Food Facts is busy"
        case .unreadableResponse: "Unexpected response"
        case .timedOut: "The search timed out"
        case .unexpected: "Something went wrong"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .offline: "Check your connection and try again."
        case .rateLimited: "Open Food Facts limits how often it can be searched. Wait a moment before trying again."
        case .serviceUnavailable: "Their servers are rate-limiting requests right now. Give it a moment and retry."
        case .unreadableResponse: "The server sent back data this app couldn't read."
        case .timedOut: "The server took too long to respond."
        case .unexpected(let code): "The server responded with status \(code)."
        }
    }

    /// Whether the same request is worth sending again. Only failures caused by the
    /// server being momentarily overloaded qualify — never a bad response shape.
    var isTransient: Bool {
        switch self {
        case .serviceUnavailable, .timedOut: true
        case .offline, .rateLimited, .unreadableResponse, .unexpected: false
        }
    }

    var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .serviceUnavailable, .timedOut: "clock.badge.exclamationmark"
        case .rateLimited: "hourglass"
        case .unreadableResponse, .unexpected: "exclamationmark.triangle"
        }
    }
}
