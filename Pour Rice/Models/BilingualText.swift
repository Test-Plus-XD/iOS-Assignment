//
//  BilingualText.swift
//  Pour Rice
//
//  Bilingual text model supporting British English and Traditional Chinese
//  Automatically returns the localised version based on app language settings
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is a custom localization solution for API data (not UI text).
//  Unlike Flutter's intl package (which handles UI strings), this handles
//  restaurant data that comes from the backend in both languages.
//  ============================================================================
//

import Foundation  // For Locale and language detection

/// Represents text content in both British English and Traditional Chinese
//
// PURPOSE:
// Our backend API stores all restaurant data in both languages
// This struct holds both versions and automatically picks the right one
//
// WHY NOT USE FLUTTER'S APPROACH:
// Flutter's AppLocalizations works for static UI strings
// But restaurant names/descriptions come from API in real-time
// This struct handles dynamic bilingual content from backend
//
// EXAMPLE:
// Restaurant name in JSON:
// "name": { "EN": "Golden Dragon", "TC": "金龍餐廳" }
// Gets decoded to:
// BilingualText(en: "Golden Dragon", tc: "金龍餐廳")
//
// When displayed, it automatically shows the right language
struct BilingualText: Codable, Hashable, Sendable {

    // MARK: - Properties

    /// British English text content
    // 'en' is the standard ISO language code for English
    // We specifically use British English for proper localization
    let en: String

    /// Traditional Chinese text content
    // 'tc' = Traditional Chinese (used in Hong Kong, Taiwan)
    // NOT Simplified Chinese (which would be 'sc')
    let tc: String

    // MARK: - Computed Properties

    /// Returns the localised text based on the current app language setting
    //
    // HOW IT WORKS:
    // 1. Check user's device language
    // 2. If Chinese → return .tc
    // 3. Otherwise → return .en
    //
    // AUTOMATIC SELECTION:
    // User doesn't choose manually
    // App automatically uses their device's language setting
    //
    // FLUTTER EQUIVALENT:
    // String get localized {
    //   final locale = Localizations.localeOf(context);
    //   return locale.languageCode.startsWith('zh') ? tc : en;
    // }
    //
    // - Returns: Traditional Chinese if locale is zh or zh-Hant, otherwise British English
    var localized: String {
        // Get current language code from the app's locale
        //
        // WHAT IS Locale.current:
        // System-provided locale based on user's device settings
        // Contains language, region, calendar, etc.
        //
        // WHAT IS .language.languageCode?.identifier:
        // - .language: The language component of the locale
        // - .languageCode?: Optional language code (might be nil)
        // - ?.identifier: Unwrap optional and get the code string
        //
        // WHAT IS ?? "en":
        // Nil coalescing operator - if languageCode is nil, use "en" as default
        // Similar to ?? in Dart or ?: in Kotlin
        let language = Locale.current.language.languageCode?.identifier ?? "en"

        // Return Traditional Chinese for Chinese locales, otherwise British English
        //
        // TERNARY OPERATOR:
        // condition ? valueIfTrue : valueIfFalse
        // Same as in Dart/Kotlin/JavaScript
        //
        // WHAT IS hasPrefix("zh"):
        // Checks if string starts with "zh"
        // Matches "zh", "zh-Hant", "zh-Hans", etc.
        // Similar to startsWith() in Dart/Kotlin
        return language.hasPrefix("zh") ? tc : en
    }

    // MARK: - Initialisation

    /// Creates a bilingual text instance with both language versions
    //
    // STANDARD CONSTRUCTOR:
    // Use this when you have different text for each language
    //
    // EXAMPLE:
    // let name = BilingualText(en: "Fried Rice", tc: "炒飯")
    //
    // - Parameters:
    ///   - en: British English text
    ///   - tc: Traditional Chinese text
    init(en: String, tc: String) {
        self.en = en
        self.tc = tc
    }

    /// Creates a bilingual text instance with the same text for both languages
    //
    // CONVENIENCE CONSTRUCTOR:
    // Use this for names/terms that don't need translation
    //
    // WHEN TO USE:
    // - Brand names: "KFC", "Starbucks"
    // - Proper nouns that stay the same in both languages
    // - Numbers or codes: "Table 5", "Room 302"
    //
    // EXAMPLE:
    // let brand = BilingualText(uniform: "McDonald's")
    // brand.en → "McDonald's"
    // brand.tc → "McDonald's" (same)
    //
    // WHY 'uniform':
    // Parameter label makes it clear both languages get same value
    // Without it, init(text:) would be ambiguous
    //
    // - Parameter text: Text to use for both languages
    init(uniform text: String) {
        self.en = text
        self.tc = text
    }
}

// MARK: - String Conversion
//
// PROTOCOL EXTENSION:
// Extends BilingualText to conform to CustomStringConvertible
// This protocol requires a 'description' property
//
// WHY THIS IS USEFUL:
// When you print() a BilingualText or use string interpolation,
// it automatically uses the localized version
//
// EXAMPLE:
// let name = BilingualText(en: "Rice", tc: "飯")
// print(name)  // Prints "Rice" or "飯" based on language
// let text = "Dish: \(name)"  // Uses localized version automatically

extension BilingualText: CustomStringConvertible {
    /// Provides automatic string representation using the localised version
    //
    // WHAT IS description:
    // Required property for CustomStringConvertible protocol
    // Similar to toString() in Dart/Kotlin or __str__ in Python
    //
    // FLUTTER EQUIVALENT:
    // @override
    // String toString() => localized;
    var description: String {
        return localized  // Return the localized text (en or tc)
    }
}

// MARK: - Coding Keys
//
// CUSTOM JSON DECODING:
// This extension handles converting API JSON to BilingualText
// Supports multiple JSON formats from the backend

extension BilingualText {
    /// Custom coding keys to handle various API response formats
    // Supports both uppercase and lowercase variations from the backend
    //
    // BACKEND API FORMAT:
    // API returns: { "EN": "English text", "TC": "中文" }
    // We map these to: BilingualText.en and BilingualText.tc
    enum CodingKeys: String, CodingKey {
        case en = "EN"  // JSON key "EN" → Swift property "en"
        case tc = "TC"  // JSON key "TC" → Swift property "tc"
    }

    /// Custom decoder to handle various API response formats
    // Supports field names with _EN/_TC suffixes or standalone EN/TC keys
    //
    // WHY CUSTOM DECODING:
    // Backend might return different formats:
    // Format 1: { "EN": "...", "TC": "..." }
    // Format 2: { "en": "...", "tc": "..." }
    // This handles both automatically
    //
    // WHAT IS init(from decoder:):
    // Special initializer called when decoding from JSON
    // Part of the Codable protocol
    init(from decoder: Decoder) throws {
        // Try to decode using our CodingKeys (uppercase EN/TC)
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Attempt to decode using standard keys (EN/TC)
        //
        // WHAT IS if let ... try?:
        // - if let: Unwrap optionals if both succeed
        // - try?: Don't throw error if decoding fails, just return nil
        //
        // If both EN and TC are successfully decoded, use them
        if let enValue = try? container.decode(String.self, forKey: .en),
           let tcValue = try? container.decode(String.self, forKey: .tc) {
            self.en = enValue
            self.tc = tcValue
        } else {
            // Fallback: try lowercase keys or other formats
            //
            // WHAT IS singleValueContainer:
            // Different decoding strategy - treats the JSON as a single value
            // Allows us to decode the entire object as a dictionary
            let dynamicContainer = try decoder.singleValueContainer()

            // Decode as a string-to-string dictionary
            // [String: String] means keys and values are both Strings
            let dict = try dynamicContainer.decode([String: String].self)

            // Try multiple key variations with nil coalescing
            //
            // LOGIC:
            // Try "en" first, if nil try "EN", if nil use empty string
            // ?? is the nil coalescing operator (like ?? in Dart)
            //
            // EXAMPLE:
            // If dict = { "en": "Hello", "tc": "你好" }
            // Then dict["en"] succeeds → "Hello"
            //
            // If dict = { "EN": "Hello", "TC": "你好" }
            // Then dict["en"] is nil, dict["EN"] succeeds → "Hello"
            self.en = dict["en"] ?? dict["EN"] ?? ""
            self.tc = dict["tc"] ?? dict["TC"] ?? ""
        }
    }
}
