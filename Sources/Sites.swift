import Foundation

/// One tab in the app: a display name, an SF Symbol for the tab bar, and the URL to load
/// first. Add an entry here to add a new tab (e.g. the cafeteria menu site later on).
struct Site {
    let title: String
    let symbolName: String
    let startURL: URL
}

enum Sites {
    static let all: [Site] = [
        Site(
            title: "LETUS",
            symbolName: "book.closed",
            startURL: URL(string: "https://letus.ed.tus.ac.jp/")!
        ),
        Site(
            title: "CLASS",
            symbolName: "building.columns",
            // Campus Life Assist System TUS. Root login gate; students/faculty follow its
            // own Shibboleth SSO link from here (same IdP session LETUS uses).
            startURL: URL(string: "https://class.admin.tus.ac.jp/uprx/")!
        ),
    ]
}
