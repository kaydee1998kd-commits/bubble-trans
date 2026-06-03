import UIKit

final class SettingsViewController: UIViewController {
    private let providerControl = UISegmentedControl(items: ["MyMemory", "Libre"])
    private let endpointField = UITextField()
    private let apiKeyField = UITextField()
    private let sourceField = UITextField()
    private let targetField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = UIColor(red: 0.96, green: 0.965, blue: 0.95, alpha: 1)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(save)
        )
        configureForm()
        loadSettings()
    }

    private func configureForm() {
        providerControl.selectedSegmentIndex = 0

        configureField(endpointField, placeholder: "Endpoint URL")
        configureField(apiKeyField, placeholder: "API key")
        configureField(sourceField, placeholder: "Source")
        configureField(targetField, placeholder: "Target")

        let stack = UIStackView(arrangedSubviews: [
            label("Provider"),
            providerControl,
            label("Endpoint"),
            endpointField,
            label("API Key"),
            apiKeyField,
            label("Source Language"),
            sourceField,
            label("Target Language"),
            targetField
        ])
        stack.axis = .vertical
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18)
        ])
    }

    private func configureField(_ field: UITextField, placeholder: String) {
        field.borderStyle = .roundedRect
        field.placeholder = placeholder
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.clearButtonMode = .whileEditing
        field.backgroundColor = .white
    }

    private func label(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        return label
    }

    private func loadSettings() {
        let settings = SettingsStore.shared.settings
        providerControl.selectedSegmentIndex = settings.provider == .libreTranslate ? 1 : 0
        endpointField.text = settings.endpoint
        apiKeyField.text = settings.apiKey
        sourceField.text = settings.sourceLanguage
        targetField.text = settings.targetLanguage
    }

    @objc private func save() {
        let provider: TranslationProvider = providerControl.selectedSegmentIndex == 1 ? .libreTranslate : .myMemory
        let defaults = TranslationSettings.defaultSettings(provider: provider)

        let settings = TranslationSettings(
            provider: provider,
            endpoint: endpointField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? defaults.endpoint,
            apiKey: apiKeyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            sourceLanguage: sourceField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? defaults.sourceLanguage,
            targetLanguage: targetField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? defaults.targetLanguage
        )

        SettingsStore.shared.settings = settings
        dismiss(animated: true)
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

