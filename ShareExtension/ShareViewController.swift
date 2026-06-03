import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let ocrService = OCRService()
    private let translator = Translator()

    private let statusLabel = UILabel()
    private let textView = UITextView()
    private let copyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var translatedText = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.965, blue: 0.95, alpha: 1)
        configureViews()
        loadSharedImage()
    }

    private func configureViews() {
        statusLabel.text = "Loading"
        statusLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        statusLabel.numberOfLines = 2

        textView.isEditable = false
        textView.backgroundColor = .white
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor(white: 0.82, alpha: 1).cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.text = "Reading screenshot..."

        copyButton.setTitle("Copy", for: .normal)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.isEnabled = false
        copyButton.addTarget(self, action: #selector(copyTranslation), for: .touchUpInside)

        closeButton.setTitle("Close", for: .normal)
        closeButton.setImage(UIImage(systemName: "xmark.circle"), for: .normal)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)

        activityIndicator.startAnimating()

        let topRow = UIStackView(arrangedSubviews: [statusLabel, activityIndicator])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8

        let buttonRow = UIStackView(arrangedSubviews: [copyButton, closeButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 10
        buttonRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [topRow, textView, buttonRow])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            buttonRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func loadSharedImage() {
        guard
            let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let provider = item.attachments?.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
        else {
            finish(text: "No image was shared.", status: "No image", canCopy: false)
            return
        }

        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.finish(text: error.localizedDescription, status: "Failed", canCopy: false)
                }
                return
            }

            let image = self.image(from: item)
            DispatchQueue.main.async {
                guard let image else {
                    self.finish(text: "The shared image could not be opened.", status: "Failed", canCopy: false)
                    return
                }
                self.process(image)
            }
        }
    }

    private func image(from item: NSSecureCoding?) -> UIImage? {
        if let image = item as? UIImage {
            return image
        }

        if let url = item as? URL, let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }

        if let data = item as? Data {
            return UIImage(data: data)
        }

        return nil
    }

    private func process(_ image: UIImage) {
        statusLabel.text = "Reading"
        activityIndicator.startAnimating()

        Task { [weak self] in
            guard let self else { return }

            do {
                let lines = try await self.ocrService.recognizeText(in: image)
                let recognized = lines.joined(separator: "\n")
                await self.setStatus("Translating")
                let translated = try await self.translator.translate(
                    recognized,
                    settings: TranslationSettings.defaultSettings()
                )

                let output = "Original\n\(recognized)\n\nTranslation\n\(translated)"
                await MainActor.run {
                    self.translatedText = translated
                    self.finish(text: output, status: "Done", canCopy: true)
                }
            } catch {
                await MainActor.run {
                    self.finish(text: error.localizedDescription, status: "Failed", canCopy: false)
                }
            }
        }
    }

    @MainActor
    private func setStatus(_ status: String) {
        statusLabel.text = status
    }

    @MainActor
    private func finish(text: String, status: String, canCopy: Bool) {
        activityIndicator.stopAnimating()
        statusLabel.text = status
        textView.text = text
        copyButton.isEnabled = canCopy
    }

    @objc private func copyTranslation() {
        UIPasteboard.general.string = translatedText
        statusLabel.text = "Copied"
    }

    @objc private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

