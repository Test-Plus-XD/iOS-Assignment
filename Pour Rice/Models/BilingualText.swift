//
//  BilingualText.swift
//  Pour Rice
//
//  Bilingual text model supporting British English and Traditional Chinese
//  Automatically returns the localised version based on app language settings
//

import Foundation

/// Represents text content in both British English and Traditional Chinese
/// Used throughout the app for restaurant names, descriptions, and other bilingual content
/// Automatically selects the appropriate language based on user's current locale
struct BilingualText: Codable, Hashable, Sendable {

    // MARK: - Properties

    /// British English text content
    let en: String

    /// Traditional Chinese text content
    let tc: String

    // MARK: - Computed Properties

    /// Returns the localised text based on the current app language setting
    /// - Returns: Traditional Chinese if locale is zh or zh-Hant, otherwise British English
    var localized: String {
        // Get current language code from the app's locale
        let language = Locale.current.language.languageCode?.identifier ?? "en"

        // Return Traditional Chinese for Chinese locales, otherwise British English
        return language.hasPrefix("zh") ? tc : en
    }

    // MARK: - Initialisation

    /// Creates a bilingual text instance with both language versions
    /// - Parameters:
    ///   - en: British English text
    ///   - tc: Traditional Chinese text
    init(en: String, tc: String) {
        self.en = en
        self.tc = tc
    }

    /// Creates a bilingual text instance with the same text for both languages
    /// Useful for names or terms that don't require translation
    /// - Parameter text: Text to use for both languages
    init(uniform text: String) {
        self.en = text
        self.tc = text
    }
}

// MARK: - String Conversion

extension BilingualText: CustomStringConvertible {
    /// Provides automatic string representation using the localised version
    var description: String {
        return localized
    }
}

// MARK: - Coding Keys

extension BilingualText {
    /// Custom coding keys to handle various API response formats
    /// Supports both uppercase and lowercase variations from the backend
    enum CodingKeys: String, CodingKey {
        case en = "EN"
        case tc = "TC"
    }

    /// Custom decoder to handle various API response formats
    /// Supports field names with _EN/_TC suffixes or standalone EN/TC keys
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Attempt to decode using standard keys
        if let enValue = try? container.decode(String.self, forKey: .en),
           let tcValue = try? container.decode(String.self, forKey: .tc) {
            self.en = enValue
            self.tc = tcValue
        } else {
            // Fallback: try lowercase keys
            let dynamicContainer = try decoder.singleValueContainer()
            let dict = try dynamicContainer.decode([String: String].self)

            self.en = dict["en"] ?? dict["EN"] ?? ""
            self.tc = dict["tc"] ?? dict["TC"] ?? ""
        }
    }
}
