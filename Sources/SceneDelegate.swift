import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let letusVC = SiteWebViewController(title: Sites.letus.title, startURL: Sites.letus.startURL)
        letusVC.tabBarItem = UITabBarItem(title: Sites.letus.title, image: UIImage(systemName: Sites.letus.symbolName), tag: 0)

        let classVC = SiteWebViewController(title: Sites.classSite.title, startURL: Sites.classSite.startURL)
        classVC.tabBarItem = UITabBarItem(title: Sites.classSite.title, image: UIImage(systemName: Sites.classSite.symbolName), tag: 1)

        let diningVC = DiningViewController()
        diningVC.tabBarItem = UITabBarItem(title: "食堂", image: UIImage(systemName: "fork.knife"), tag: 2)

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [letusVC, classVC, diningVC]

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBarController
        self.window = window
        window.makeKeyAndVisible()
    }
}
