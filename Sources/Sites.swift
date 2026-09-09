import Foundation

/// A single WebView-backed destination: a display name, an SF Symbol, and the URL to load first.
struct Site {
    let title: String
    let symbolName: String
    let startURL: URL
}

enum Sites {
    static let letus = Site(
        title: "LETUS",
        symbolName: "book.closed",
        startURL: URL(string: "https://letus.ed.tus.ac.jp/")!
    )

    static let classSite = Site(
        title: "CLASS",
        symbolName: "building.columns",
        // Campus Life Assist System TUS. Root login gate; students/faculty follow its own
        // Shibboleth SSO link from here (same IdP session LETUS uses).
        startURL: URL(string: "https://class.admin.tus.ac.jp/uprx/")!
    )

    // 1F 学生食堂 / 2F Cafeteria のモバイルオーダーサイト。運営会社が異なるため別ドメイン。
    static let dining1F = Site(
        title: "1F 学生食堂",
        symbolName: "fork.knife",
        startURL: URL(string: "https://tus-dining.starpayorder.com/shops/shp_107fa915bbc4e3360d40a5a")!
    )

    static let dining2F = Site(
        title: "2F Cafeteria",
        symbolName: "fork.knife",
        startURL: URL(string: "https://tbs-dining.oneqr.io/shops/shp_f6d383481636f98d242a52f")!
    )
}
