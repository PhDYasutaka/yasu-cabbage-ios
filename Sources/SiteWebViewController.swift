import UIKit
import WebKit
import UniformTypeIdentifiers
import QuickLook

/// A single WebView-backed tab. Each site (LETUS, CLASS, ...) gets its own instance
/// pointed at a different start URL; they all share the default WKWebsiteDataStore, so
/// logging into the university's Shibboleth SSO on one tab carries over to the others.
class SiteWebViewController: UIViewController {

    private let startURL: URL

    private var webView: WKWebView!
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private var progressObservation: NSKeyValueObservation?

    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private var canGoBackObservation: NSKeyValueObservation?
    private var canGoForwardObservation: NSKeyValueObservation?

    private var pendingFileUploadCompletion: (([URL]?) -> Void)?
    private var previewFileURL: URL?

    init(title: String, startURL: URL) {
        self.startURL = startURL
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupWebView()
        setupNavBar()
        setupProgressBar()
        webView.load(URLRequest(url: startURL))
    }

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default() // persistent cookies across launches
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        view.addSubview(webView)

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self = self else { return }
            self.progressBar.progress = Float(webView.estimatedProgress)
            self.progressBar.isHidden = webView.estimatedProgress >= 1.0
        }

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavBar() {
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.addTarget(self, action: #selector(handleGoBack), for: .touchUpInside)
        forwardButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        forwardButton.addTarget(self, action: #selector(handleGoForward), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [backButton, forwardButton])
        stack.axis = .horizontal
        stack.spacing = 28
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])

        canGoBackObservation = webView.observe(\.canGoBack, options: [.new, .initial]) { [weak self] webView, _ in
            self?.backButton.isEnabled = webView.canGoBack
        }
        canGoForwardObservation = webView.observe(\.canGoForward, options: [.new, .initial]) { [weak self] webView, _ in
            self?.forwardButton.isEnabled = webView.canGoForward
        }

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 4)
        ])
    }

    private func setupProgressBar() {
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBar)
        NSLayoutConstraint.activate([
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.topAnchor.constraint(equalTo: webView.topAnchor)
        ])
    }

    @objc private func handlePullToRefresh() {
        webView.reload()
    }

    @objc private func handleGoBack() {
        webView.goBack()
    }

    @objc private func handleGoForward() {
        webView.goForward()
    }
}

// MARK: - WKNavigationDelegate

extension SiteWebViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if url.scheme == "http" || url.scheme == "https" {
            // Let the WebView follow same/different-domain redirects itself; SSO (Shibboleth)
            // hops across the university IdP domain during login and must stay inside the WebView.
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressBar.isHidden = true
        webView.scrollView.refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.refreshControl?.endRefreshing()
    }
}

// MARK: - WKDownloadDelegate (file downloads, e.g. course materials)

extension SiteWebViewController: WKDownloadDelegate {

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let tempDir = FileManager.default.temporaryDirectory
        let destination = tempDir.appendingPathComponent(suggestedFilename)
        try? FileManager.default.removeItem(at: destination)
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = download.progress.fileURL else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if url.pathExtension.lowercased() == "pdf" {
                // Show PDFs straight in Quick Look instead of just handing them to the share
                // sheet; the share sheet is still one tap away from there if the user wants
                // to save it to Files or AirDrop it.
                self.previewFileURL = url
                let preview = QLPreviewController()
                preview.dataSource = self
                self.present(preview, animated: true)
            } else {
                // No single shared "Downloads" folder an app can drop files into the way
                // Android's DownloadManager does, so hand it to the share sheet instead.
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                self.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - QLPreviewControllerDataSource (in-app PDF preview)

extension SiteWebViewController: QLPreviewControllerDataSource {

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewFileURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewFileURL! as NSURL
    }
}

// MARK: - WKUIDelegate (file uploads for assignment submission, target=_blank links)

extension SiteWebViewController: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Moodle occasionally opens links via target="_blank"; load those in the same WebView
        // instead of creating an unmanaged second WebView.
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        pendingFileUploadCompletion = completionHandler

        let alert = UIAlertController(title: "アップロード方法を選択", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "ファイルを選択", style: .default) { [weak self] _ in
            self?.presentDocumentPicker(allowsMultiple: parameters.allowsMultipleSelection)
        })

        alert.addAction(UIAlertAction(title: "写真をPDFにまとめてアップロード", style: .default) { [weak self] _ in
            self?.presentPhotoToPDF()
        })

        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { [weak self] _ in
            self?.pendingFileUploadCompletion?(nil)
            self?.pendingFileUploadCompletion = nil
        })

        // iPad requires a popover source for action sheets.
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func presentDocumentPicker(allowsMultiple: Bool) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = allowsMultiple
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentPhotoToPDF() {
        let photoToPDF = PhotoToPDFViewController()
        photoToPDF.onComplete = { [weak self] pdfURL in
            self?.dismiss(animated: true) {
                if let pdfURL = pdfURL {
                    self?.pendingFileUploadCompletion?([pdfURL])
                } else {
                    self?.pendingFileUploadCompletion?(nil)
                }
                self?.pendingFileUploadCompletion = nil
            }
        }
        let nav = UINavigationController(rootViewController: photoToPDF)
        present(nav, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension SiteWebViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        pendingFileUploadCompletion?(urls)
        pendingFileUploadCompletion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingFileUploadCompletion?(nil)
        pendingFileUploadCompletion = nil
    }
}
