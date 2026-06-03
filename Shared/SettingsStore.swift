import Foundation

enum TranslationProvider: String, Codable {
    case myMemory
    case libreTranslate
}

struct TranslationSettings: Codable {
    var provider: TranslationProvider
    var endpoint: String
    var apiKey: String
    var sourceLanguage: String
    var targetLanguage: String

    static func defaultSettings(provider: TranslationProvider = .myMemory) -> TranslationSettings {
        switch provider {
        case .myMemory:
            return TranslationSettings(
                provider: .myMemory,
                endpoint: "https://api.mymemory.translated.net/get",
                apiKey: "",
                sourceLanguage: "zh-CN",
                targetLanguage: "en"
            )
        case .libreTranslate:
            return TranslationSettings(
                provider: .libreTranslate,
                endpoint: "https://libretranslate.de/translate",
                apiKey: "",
                sourceLanguage: "zh",
                targetLanguage: "en"
            )
        }
    }
}

final class SettingsStore {
    static let shared = SettingsStore()

    private let key = "translationSettings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var settings: TranslationSettings {
        get {
            guard
                let data = defaults.data(forKey: key),
                let settings = try? JSONDecoder().decode(TranslationSettings.self, from: data)
            else {
                return TranslationSettings.defaultSettings()
            }
            return settings
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: key)
        }
    }
}

