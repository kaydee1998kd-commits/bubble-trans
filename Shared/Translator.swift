import Foundation
import UIKit

enum TranslationError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case emptyTranslation

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "The translation endpoint is not a valid URL."
        case .invalidResponse:
            return "The translation service returned an unreadable response."
        case .emptyTranslation:
            return "The translation service returned no text."
        }
    }
}

final class Translator {
    func translate(_ text: String, settings: TranslationSettings) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        switch settings.provider {
        case .myMemory:
            return try await translateWithMyMemory(trimmed, settings: settings)
        case .libreTranslate:
            return try await translateWithLibre(trimmed, settings: settings)
        }
    }

    private func translateWithMyMemory(_ text: String, settings: TranslationSettings) async throws -> String {
        guard let endpoint = URL(string: settings.endpoint) else {
            throw TranslationError.invalidEndpoint
        }

        var translatedChunks: [String] = []
        for chunk in chunk(text, maxLength: 450) {
            var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "q", value: chunk),
                URLQueryItem(name: "langpair", value: "\(settings.sourceLanguage)|\(settings.targetLanguage)")
            ]

            guard let url = components?.url else {
                throw TranslationError.invalidEndpoint
            }

            let (data, response) = try await URLSession.shared.data(from: url)
            try validate(response: response)

            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let responseData = object["responseData"] as? [String: Any],
                let translated = responseData["translatedText"] as? String
            else {
                throw TranslationError.invalidResponse
            }

            translatedChunks.append(translated.decodedHTML)
            try await Task.sleep(nanoseconds: 180_000_000)
        }

        let result = translatedChunks.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw TranslationError.emptyTranslation }
        return result
    }

    private func translateWithLibre(_ text: String, settings: TranslationSettings) async throws -> String {
        guard let url = URL(string: settings.endpoint) else {
            throw TranslationError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "q": text,
            "source": libreLanguage(settings.sourceLanguage),
            "target": libreLanguage(settings.targetLanguage),
            "format": "text"
        ]

        if !settings.apiKey.isEmpty {
            body["api_key"] = settings.apiKey
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)

        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let translated = object["translatedText"] as? String
        else {
            throw TranslationError.invalidResponse
        }

        let result = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw TranslationError.emptyTranslation }
        return result
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TranslationError.invalidResponse
        }
    }

    private func libreLanguage(_ language: String) -> String {
        language.lowercased().hasPrefix("zh") ? "zh" : language
    }

    private func chunk(_ text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var current = ""

        for line in text.components(separatedBy: .newlines) {
            let candidate = current.isEmpty ? line : current + "\n" + line
            if candidate.count <= maxLength {
                current = candidate
            } else {
                if !current.isEmpty {
                    chunks.append(current)
                }
                current = line
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks.isEmpty ? [text] : chunks
    }
}

private extension String {
    var decodedHTML: String {
        guard let data = data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? self
    }
}

