import Foundation
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DeepLinkHandler
//
// Handles incoming URLs of the form:
//   pilotmirror://feedback/{token}          ← URL scheme (MVP)
//   https://pilotmirror.app/feedback/{token} ← Universal Link (production)
//
// Usage in PilotMirrorApp:
//   .onOpenURL { url in DeepLinkHandler.shared.handle(url) }
//
// Usage in RootView:
//   @ObservedObject var deepLink = DeepLinkHandler.shared
//   if let token = deepLink.pendingFeedbackToken { ... }
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    /// Set when a feedback link URL is opened. Cleared after survey is shown.
    @Published var pendingFeedbackToken: String?

    private init() {}

    func handle(_ url: URL) {
        // pilotmirror://feedback/abc123
        if url.scheme == "pilotmirror", url.host == "feedback" {
            let token = url.pathComponents.filter { $0 != "/" }.first
                ?? String(url.path.dropFirst())
            if !token.isEmpty { pendingFeedbackToken = token }
            return
        }

        // https://pilotmirror.app/feedback/abc123
        if let host = url.host, host.contains("pilotmirror.app") {
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count >= 2, parts[0] == "feedback" {
                pendingFeedbackToken = parts[1]
            }
        }
    }

    func clearPendingToken() {
        pendingFeedbackToken = nil
    }
}
