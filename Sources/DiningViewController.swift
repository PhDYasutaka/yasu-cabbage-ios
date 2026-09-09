import UIKit

/// The "食堂" tab: a segmented control switches between the 1F/2F mobile-order sites, each kept
/// alive in its own SiteWebViewController so switching floors preserves scroll/session state.
class DiningViewController: UIViewController {

    private let floor1VC = SiteWebViewController(title: Sites.dining1F.title, startURL: Sites.dining1F.startURL)
    private let floor2VC = SiteWebViewController(title: Sites.dining2F.title, startURL: Sites.dining2F.startURL)

    private lazy var segmentedControl = UISegmentedControl(items: [Sites.dining1F.title, Sites.dining2F.title])

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "食堂"
        view.backgroundColor = .systemBackground

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(floorChanged), for: .valueChanged)
        view.addSubview(segmentedControl)

        addFloor(floor1VC, hidden: false)
        addFloor(floor2VC, hidden: true)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func addFloor(_ floorVC: SiteWebViewController, hidden: Bool) {
        addChild(floorVC)
        floorVC.view.translatesAutoresizingMaskIntoConstraints = false
        floorVC.view.isHidden = hidden
        view.addSubview(floorVC.view)
        floorVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            floorVC.view.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            floorVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            floorVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            floorVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func floorChanged() {
        let showFloor1 = segmentedControl.selectedSegmentIndex == 0
        floor1VC.view.isHidden = !showFloor1
        floor2VC.view.isHidden = showFloor1
    }
}
