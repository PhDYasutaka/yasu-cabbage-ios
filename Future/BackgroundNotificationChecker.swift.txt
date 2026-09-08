import Foundation
import WebKit
import UserNotifications
import BackgroundTasks

/// Periodically checks LETUS for new notifications using the session cookie already
/// stored in WKWebsiteDataStore (from the user's normal login in MainViewController),
/// and the last-seen `sesskey` cached after each page load. No server of our own is
/// involved: this calls the same internal Moodle endpoint the site's own bell icon uses.
class BackgroundNotificationChecker {

    static let shared = BackgroundNotificationChecker()

    private static let dashboardURL = URL(string: "https://letus.ed.tus.ac.jp/my/")!
    private static let lastNotificationIDKey = "letus.lastNotificationID"

    func handle(task: BGAppRefreshTask) {
        AppDelegate.shared?.scheduleBackgroundRefresh()

        let operation = Task {
            await self.checkForNewNotifications()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            operation.cancel()
        }
    }

    @MainActor
    private func checkForNewNotifications() async {
        guard let sesskey = await fetchSesskey() else { return }

        var request = URLRequest(
            url: URL(string: "https://letus.ed.tus.ac.jp/lib/ajax/service.php?sesskey=\(sesskey)&info=message_popup_get_popup_notifications")!
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = [[
            "index": 0,
            "methodname": "message_popup_get_popup_notifications",
            "args": ["useridto": 0, "newestfirst": 1, "limit": 20]
        ]] as [[String: Any]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        // Session cookies are attached automatically by URLSession's shared cookie storage
        // as long as WKWebsiteDataStore.default() shares the same underlying cookie store,
        // which is the case for the default configuration used in MainViewController.
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let entry = json.first,
              entry["error"] == nil,
              let entryData = entry["data"] as? [String: Any],
              let notifications = entryData["notifications"] as? [[String: Any]] else { return }

        let defaults = UserDefaults.standard
        let lastSeenID = defaults.integer(forKey: Self.lastNotificationIDKey)
        var newestID = lastSeenID

        for item in notifications {
            guard let id = item["id"] as? Int else { continue }
            if id > lastSeenID {
                let subject = (item["subject"] as? String) ?? "LETUSから新しい通知"
                let body = (item["fullmessage"] as? String) ?? ""
                postNotification(title: subject, body: body)
            }
            newestID = max(newestID, id)
        }

        defaults.set(newestID, forKey: Self.lastNotificationIDKey)
    }

    /// Loads the dashboard once in an off-screen WKWebView purely to read `M.cfg.sesskey`
    /// out of the page; the actual notification fetch itself uses a plain URLSession call.
    @MainActor
    private func fetchSesskey() async -> String? {
        await withCheckedContinuation { continuation in
            let webView = WKWebView(frame: .zero)
            let navigationHelper = SesskeyNavigationHelper(webView: webView) { sesskey in
                continuation.resume(returning: sesskey)
            }
            webView.navigationDelegate = navigationHelper
            objc_setAssociatedObject(webView, &AssociatedKeys.helper, navigationHelper, .OBJC_ASSOCIATION_RETAIN)
            webView.load(URLRequest(url: Self.dashboardURL))
        }
    }

    private func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

private enum AssociatedKeys {
    static var helper = "helper"
}

/// Small helper object that extracts `M.cfg.sesskey` once the dashboard page finishes loading.
private class SesskeyNavigationHelper: NSObject, WKNavigationDelegate {
    private weak var webView: WKWebView?
    private let completion: (String?) -> Void
    private var didComplete = false

    init(webView: WKWebView, completion: @escaping (String?) -> Void) {
        self.webView = webView
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("(typeof M !== 'undefined' && M.cfg) ? M.cfg.sesskey : null") { [weak self] result, _ in
            guard let self = self, !self.didComplete else { return }
            self.didComplete = true
            self.completion(result as? String)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !didComplete else { return }
        didComplete = true
        completion(nil)
    }
}
