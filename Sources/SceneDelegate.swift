import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = Sites.all.enumerated().map { index, site in
            let controller = SiteWebViewController(title: site.title, startURL: site.startURL)
            controller.tabBarItem = UITabBarItem(title: site.title, image: UIImage(systemName: site.symbolName), tag: index)
            return controller
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBarController
        self.window = window
        window.makeKeyAndVisible()
    }
}
