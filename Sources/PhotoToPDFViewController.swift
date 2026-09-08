import UIKit
import PhotosUI
import PDFKit

class PhotoToPDFViewController: UIViewController {

    /// Called with the generated PDF's file URL, or nil if the user cancelled.
    var onComplete: ((URL?) -> Void)?

    private var images: [UIImage] = []

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 88, height: 88)
        layout.minimumInteritemSpacing = 8
        layout.scrollDirection = .horizontal
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseID)
        return cv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "カメラまたはギャラリーから写真を追加してください"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let createButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "PDFを作成してアップロード"
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "写真をPDFにまとめる"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(handleCancel)
        )

        collectionView.dataSource = self
        collectionView.delegate = self

        let cameraButton = makeActionButton(title: "カメラで撮影", action: #selector(handleCamera))
        let galleryButton = makeActionButton(title: "ギャラリーから追加", action: #selector(handleGallery))
        let buttonRow = UIStackView(arrangedSubviews: [cameraButton, galleryButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        createButton.addTarget(self, action: #selector(handleCreatePDF), for: .touchUpInside)

        view.addSubview(emptyLabel)
        view.addSubview(collectionView)
        view.addSubview(buttonRow)
        view.addSubview(createButton)

        NSLayoutConstraint.activate([
            emptyLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.heightAnchor.constraint(equalToConstant: 96),

            buttonRow.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 24),
            buttonRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            createButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        updateEmptyState()
    }

    private func makeActionButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.title = title
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !images.isEmpty
        collectionView.isHidden = images.isEmpty
        createButton.isEnabled = !images.isEmpty
        collectionView.reloadData()
    }

    @objc private func handleCancel() {
        onComplete?(nil)
    }

    @objc private func handleCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func handleGallery() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // unlimited
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func handleCreatePDF() {
        guard !images.isEmpty else { return }
        createButton.isEnabled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let pdfURL = Self.renderPDF(from: self.images) else {
                DispatchQueue.main.async { self.createButton.isEnabled = true }
                return
            }
            DispatchQueue.main.async {
                self.onComplete?(pdfURL)
            }
        }
    }

    /// Renders each image as one A4 page, scaled to fit with JPEG-quality compression
    /// baked in via UIGraphicsPDFRenderer so the resulting PDF stays a reasonable size.
    private static func renderPDF(from images: [UIImage]) -> URL? {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload_\(Int(Date().timeIntervalSince1970)).pdf")

        do {
            try renderer.writePDF(to: outputURL) { context in
                for image in images {
                    context.beginPage()
                    let scale = min(pageWidth / image.size.width, pageHeight / image.size.height)
                    let drawWidth = image.size.width * scale
                    let drawHeight = image.size.height * scale
                    let origin = CGPoint(x: (pageWidth - drawWidth) / 2, y: (pageHeight - drawHeight) / 2)
                    image.draw(in: CGRect(origin: origin, size: CGSize(width: drawWidth, height: drawHeight)))
                }
            }
            return outputURL
        } catch {
            return nil
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension PhotoToPDFViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseID, for: indexPath) as! PhotoCell
        cell.configure(image: images[indexPath.item]) { [weak self] in
            guard let self = self else { return }
            self.images.remove(at: indexPath.item)
            self.updateEmptyState()
        }
        return cell
    }
}

// MARK: - UIImagePickerControllerDelegate (camera capture)

extension PhotoToPDFViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            images.append(image)
            updateEmptyState()
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate (gallery multi-select)

extension PhotoToPDFViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        let group = DispatchGroup()
        var loaded: [UIImage] = []
        let lock = NSLock()

        for result in results {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    lock.lock()
                    loaded.append(image)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.images.append(contentsOf: loaded)
            self?.updateEmptyState()
        }
    }
}

// MARK: - PhotoCell

private class PhotoCell: UICollectionViewCell {
    static let reuseID = "PhotoCell"

    private let imageView = UIImageView()
    private let removeButton = UIButton(type: .system)
    private var onRemove: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .white
        removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        removeButton.layer.cornerRadius = 10
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        contentView.addSubview(removeButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            removeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            removeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(image: UIImage, onRemove: @escaping () -> Void) {
        imageView.image = image
        self.onRemove = onRemove
    }

    @objc private func removeTapped() {
        onRemove?()
    }
}
