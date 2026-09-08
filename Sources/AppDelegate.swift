import UIKit
import UserNotifications
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static weak var shared: AppDelegate?
    static let backgroundTaskIdentifier = "yasu.cabbage.refresh-notifications"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AppDelegate.shared = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.backgroundTaskIdentifier,
            using: nil
        ) { task in
            BackgroundNotificationChecker.shared.handle(task: task as! BGAppRefreshTask)
        }

        scheduleBackgroundRefresh()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundRefresh()
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppDelegate.backgroundTaskIdentifier)
        // iOS treats this as a hint, not a guarantee; actual runs may be spaced further apart
        // depending on the user's usage pattern and system conditions.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
