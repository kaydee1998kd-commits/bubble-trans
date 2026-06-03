import PhotosUI
import UIKit

final class MainViewController: UIViewController {
    private let ocrService = OCRService()
    private let translator = Translator()

    private let imageView = UIImageView()
    private let resultTextView = UITextView()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let translateButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)

    private var selectedImage: UIImage?
    private var translatedText = ""
    private var currentTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "XiBubble"
        view.backgroundColor = UIColor(red: 0.96, green: 0.965, blue: 0.95, alpha: 1)
        configureNavigation()
        configureViews()
    }

    deinit {
        currentTask?.cancel()
    }

    private func configureNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
    }

    private func configureViews() {
        let pickButton = makeActionButton(title: "Pick Screenshot", systemImage: "photo.on.rectangle", action: #selector(pickScreenshot))
        let pasteButton = makeActionButton(title: "Paste Image", systemImage: "doc.on.clipboard", action: #selector(pasteImage))

        translateButton.setTitle("Translate", for: .normal)
        translateButton.setImage(UIImage(systemName: "text.bubble"), for: .normal)
        translateButton.tintColor = .white
        translateButton.backgroundColor = UIColor(red: 0.06, green: 0.38, blue: 0.56, alpha: 1)
        translateButton.layer.cornerRadius = 8
        translateButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        translateButton.addTarget(self, action: #selector(translateSelectedImage), for: .touchUpInside)
        translateButton.isEnabled = false
        translateButton.alpha = 0.55

        copyButton.setTitle("Copy", for: .normal)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = UIColor(red: 0.06, green: 0.38, blue: 0.56, alpha: 1)
        copyButton.addTarget(self, action: #selector(copyTranslation), for: .touchUpInside)
        copyButton.isEnabled = false

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.layer.cornerRadius = 8
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor(white: 0.82, alpha: 1).cgColor
        imageView.clipsToBounds = true

        resultTextView.isEditable = false
        resultTextView.backgroundColor = .white
        resultTextView.layer.cornerRadius = 8
        resultTextView.layer.borderWidth = 1
        resultTextView.layer.borderColor = UIColor(white: 0.82, alpha: 1).cgColor
        resultTextView.font = UIFont.preferredFont(forTextStyle: .body)
        resultTextView.adjustsFontForContentSizeCategory = true
        resultTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        resultTextView.text = "Choose a Xianyu screenshot."

        statusLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 2
        statusLabel.text = "Ready"

        activityIndicator.hidesWhenStopped = true

        let buttonRow = UIStackView(arrangedSubviews: [pickButton, pasteButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 10
        buttonRow.distribution = .fillEqually

        let statusRow = UIStackView(arrangedSubviews: [statusLabel, activityIndicator, copyButton])
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [buttonRow, imageView, translateButton, statusRow, resultTextView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.28),
            translateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 46)
        ])
    }

    private func makeActionButton(title: String, systemImage: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.tintColor = UIColor(red: 0.08, green: 0.26, blue: 0.36, alpha: 1)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(white: 0.82, alpha: 1).cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 11, left: 10, bottom: 11, right: 10)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func pickScreenshot() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func pasteImage() {
        guard let image = UIPasteboard.general.image else {
            showAlert(title: "No Image", message: "The clipboard does not contain an image.")
            return
        }
        setImage(image)
    }

    @objc private func translateSelectedImage() {
        guard let image = selectedImage else { return }
        currentTask?.cancel()
        setBusy(true, status: "Reading screenshot")

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let lines = try await self.ocrService.recognizeText(in: image)
                try Task.checkCancellation()
                let recognizedText = lines.joined(separator: "\n")
                guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    await self.finishWith(text: "No readable text found.", status: "No text found", canCopy: false)
                    return
                }

                await self.updateStatus("Translating")
                let translated = try await self.translator.translate(
                    recognizedText,
                    settings: SettingsStore.shared.settings
                )
                try Task.checkCancellation()

                let output = "Original\n\(recognizedText)\n\nTranslation\n\(translated)"
                await self.finishWith(text: output, status: "Done", canCopy: true)
                await MainActor.run {
                    self.translatedText = translated
                }
            } catch is CancellationError {
                await self.updateStatus("Cancelled")
            } catch {
                await self.finishWith(text: error.localizedDescription, status: "Failed", canCopy: false)
            }
        }
    }

    @objc private func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        UIPasteboard.general.string = translatedText
        statusLabel.text = "Copied"
    }

    @objc private func openSettings() {
        let settingsViewController = SettingsViewController()
        let navigationController = UINavigationController(rootViewController: settingsViewController)
        present(navigationController, animated: true)
    }

    private func setImage(_ image: UIImage) {
        selectedImage = image
        imageView.image = image
        translatedText = ""
        resultTextView.text = "Ready to translate."
        statusLabel.text = "Screenshot loaded"
        translateButton.isEnabled = true
        translateButton.alpha = 1
        copyButton.isEnabled = false
    }

    @MainActor
    private func updateStatus(_ status: String) {
        statusLabel.text = status
    }

    @MainActor
    private func finishWith(text: String, status: String, canCopy: Bool) {
        resultTextView.text = text
        copyButton.isEnabled = canCopy
        setBusy(false, status: status)
    }

    @MainActor
    private func setBusy(_ busy: Bool, status: String) {
        statusLabel.text = status
        translateButton.isEnabled = !busy && selectedImage != nil
        translateButton.alpha = translateButton.isEnabled ? 1 : 0.55
        busy ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension MainViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.showAlert(title: "Image Error", message: error.localizedDescription)
                    } else if let image = object as? UIImage {
                        self?.setImage(image)
                    }
                }
            }
        }
    }
}

