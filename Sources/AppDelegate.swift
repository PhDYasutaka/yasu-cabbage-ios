import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static weak var shared: AppDelegate?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AppDelegate.shared = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        // Background auto-refresh (BGTaskScheduler) is intentionally not wired up yet: it needs a
        // Background Modes capability that a free/personal-team sideload cannot provision, and was
        // causing a crash on launch. See BackgroundNotificationChecker.swift for the logic once a
        // paid Apple Developer Program account is available to properly entitle it.
        return true
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
