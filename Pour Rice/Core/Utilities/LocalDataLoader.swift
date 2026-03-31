//
//  LocalDataLoader.swift
//  Pour Rice
//
//  Synchronous loader for bundled JSON data files (districts, keywords, payments, weekdays).
//  Reads from Bundle.main at call-site — files are each < 5 KB so synchronous decoding
//  is negligible in cost compared to async complexity overhead.
//
//  ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
//  Flutter equivalent: rootBundle.loadString('assets/weekdays.json') (async).
//  iOS Bundle reads are synchronous because the files are already on-disk in the
//  app bundle — no network or decompression needed. The equivalent in Kotlin is
//  context.assets.open("weekdays.json").bufferedReader().readText().
//  =============================================================
//

import Foundation

// MARK: - LocalDataLoader

/// Namespace for loading bundled static JSON data files.
/// Not instantiable — all members are static.
///
/// Six JSON files live in Resources/ and are auto-bundled via Xcode file-system sync:
///   weekdays.json, districts.json, keywords.json, payments.json,
///   filter_districts.json, filter_keywords.json
enum LocalDataLoader {

    // MARK: - Bilingual Entry

    /// A bilingual EN/TC string pair decoded from a bundled JSON file.
    ///
    /// `id` is derived from `en` — all English values are unique within each
    /// dataset, so no UUID literals are needed in the JSON files.
    ///
    /// Note: lowercase `en`/`tc` keys are intentional (we own this format).
    /// They differ from `BilingualText`'s uppercase `EN`/`TC` CodingKeys, which
    /// map to the backend API response format.
    struct BilingualEntry: Codable, Identifiable {
        let en: String
        let tc: String
        /// Derived identity — stable as long as English values stay unique per file.
        var id: String { en }
    }

    // MARK: - AddRestaurantView datasets

    /// 7 weekdays in Monday-first order (matches the opening-hours form).
    /// For Calendar-indexed lookups (Sunday = 1), use `(weekday + 5) % 7` as the index.
    static func loadWeekdays()   -> [BilingualEntry] { loadBilingual("weekdays")   }

    /// 18 Hong Kong administrative districts (Islands → Wan Chai).
    static func loadDistricts()  -> [BilingualEntry] { loadBilingual("districts")  }

    /// 90 restaurant keywords grouped by category (Core vegan → Ambiance).
    static func loadKeywords()   -> [BilingualEntry] { loadBilingual("keywords")   }

    /// 10 payment methods (Cash → Google Pay).
    static func loadPayments()   -> [BilingualEntry] { loadBilingual("payments")   }

    // MARK: - FilterView / SearchViewModel datasets

    /// 10 search-filter districts shown in FilterView (English values = Algolia filter params).
    static func loadFilterDistricts() -> [BilingualEntry] { loadBilingual("filter_districts") }

    /// 10 search-filter keywords shown in FilterView (English values = Algolia filter params).
    static func loadFilterKeywords()  -> [BilingualEntry] { loadBilingual("filter_keywords")  }

    // MARK: - Private Generic Loader

    private static func loadBilingual(_ filename: String) -> [BilingualEntry] {
        load(filename)
    }

    /// Loads and decodes a JSON array from the app bundle.
    ///
    /// - Parameter filename: Resource name without extension (e.g. `"weekdays"`).
    /// - Returns: Decoded array, or `[]` on any error (file missing or malformed JSON).
    ///   In Debug builds, a diagnostic message is printed to the console.
    private static func load<T: Decodable>(_ filename: String) -> [T] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            #if DEBUG
            print("[LocalDataLoader] ❌ File not found: \(filename).json")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([T].self, from: data)
            #if DEBUG
            print("[LocalDataLoader] ✅ Loaded \(filename).json — \(decoded.count) entries")
            #endif
            return decoded
        } catch {
            #if DEBUG
            print("[LocalDataLoader] ❌ Failed to decode \(filename).json: \(error)")
            #endif
            return []
        }
    }
}
