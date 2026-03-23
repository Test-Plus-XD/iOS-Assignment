//
//  Menu.swift
//  Pour Rice
//
//  Menu item model representing dishes available at restaurants
//  Supports bilingual names, descriptions, and dietary information
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  Similar to a MenuItem or Dish model in a food delivery app.
//  Contains nested enums for categories and dietary tags.
//  Includes computed properties for formatted display strings.
//  ============================================================================
//

import Foundation  // For Date, formatting, and basic types

/// Represents a menu item available at a restaurant
// Complete model for a single dish/item on a restaurant's menu
// Includes pricing, dietary info, availability, and localization
//
// FLUTTER EQUIVALENT:
// class Menu {
//   final String id;
//   final String restaurantId;
//   final BilingualText name;
//   final double price;
//   // ... etc
// }
struct Menu: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the menu item
    // Used to identify specific dishes when ordering or favoriting
    let id: String

    /// Restaurant ID this menu item belongs to
    // Links the menu item back to its restaurant
    // Used for querying all menu items for a specific restaurant
    let restaurantId: String

    /// Dish name in both British English and Traditional Chinese
    // Automatically displays in correct language based on user's locale
    // Example: { EN: "Fried Rice", TC: "炒飯" }
    let name: BilingualText

    /// Detailed description of the dish
    // Explains ingredients, cooking style, flavor profile
    // Also bilingual for proper localization
    let description: BilingualText

    /// Price in local currency (HKD)
    //
    // WHAT IS Double:
    // 64-bit floating point number for precise decimal values
    // Used for money to handle cents/decimal places accurately
    //
    // EXAMPLE: 88.50 = HK$88.50
    let price: Double

    /// Menu category (Appetiser, Main Course, Dessert, Beverage)
    // Enum type defined below - restricts to valid category values
    // Used for organizing menu into sections
    let category: MenuCategory

    /// Image URL for the dish (optional)
    //
    // OPTIONAL (String?):
    // Can be nil if no image is available for this dish
    // Most items should have images for better user experience
    let imageURL: String?

    /// Dietary information tags
    //
    // ARRAY OF ENUM:
    // [DietaryTag] = Array of dietary restriction tags
    // Example: [.vegetarian, .glutenFree, .spicy]
    // Used for filtering and displaying dietary information
    let dietaryInfo: [DietaryTag]

    /// Indicates if the item is currently available
    // false = sold out or temporarily unavailable
    // true = can be ordered right now
    // Used to gray out unavailable items in UI
    let isAvailable: Bool

    /// Spice level for dishes (0 = not spicy, 1-5 = increasing spiciness)
    //
    // OPTIONAL INT:
    // Int? means it can be nil for non-spicy dishes
    // 0 = not spicy (but still has a value)
    // nil = spice level not applicable (e.g., desserts)
    // 1-5 = increasing spiciness levels
    let spiceLevel: Int?

    // MARK: - Computed Properties
    //
    // DISPLAY FORMATTERS:
    // These properties format raw data into user-friendly display strings
    // They're computed on-the-fly (not stored), similar to getters in Dart/Kotlin

    /// Returns formatted price with currency symbol
    //
    // FORMATTING:
    // "HK$%.2f" means: "HK$" followed by a number with 2 decimal places
    // %.2f = format as floating point with exactly 2 decimals
    //
    // EXAMPLES:
    // price = 88 → "HK$88.00"
    // price = 88.5 → "HK$88.50"
    // price = 88.999 → "HK$89.00" (rounds)
    //
    // FLUTTER EQUIVALENT:
    // String get priceDisplay => 'HK\$${price.toStringAsFixed(2)}';
    var priceDisplay: String {
        return String(format: "HK$%.2f", price)
    }

    /// Returns dietary tags as comma-separated string
    //
    // WHAT THIS DOES:
    // Converts array of enum values to a readable string
    // [.vegetarian, .glutenFree] → "Vegetarian, Gluten-Free"
    //
    // HOW IT WORKS:
    // 1. .map { $0.rawValue } → Convert each tag to its String value
    // 2. .joined(separator: ", ") → Join with commas
    //
    // FLUTTER EQUIVALENT:
    // String get dietaryInfoDisplay => dietaryInfo.map((e) => e.name).join(', ');
    var dietaryInfoDisplay: String {
        return dietaryInfo.map { $0.rawValue }.joined(separator: ", ")
    }

    /// Returns spice level as emoji indicators
    //
    // RETURNS:
    // nil if not spicy or spice level not set
    // 🌶️ for level 1
    // 🌶️🌶️ for level 2
    // 🌶️🌶️🌶️ for level 3, etc. (max 5)
    //
    // WHAT IS guard let:
    // Unwraps optional and checks condition
    // If spiceLevel is nil OR level <= 0, return nil
    // Otherwise, continue with unwrapped 'level' value
    //
    // WHAT IS String(repeating:count:):
    // Creates a string by repeating a character/string
    // Similar to '*' operator in Python: '🌶️' * 3
    //
    // WHAT IS min(level, 5):
    // Ensures we never display more than 5 chili peppers
    // If level = 10, we still only show 5 peppers
    var spiceLevelDisplay: String? {
        guard let level = spiceLevel, level > 0 else { return nil }
        return String(repeating: "🌶️", count: min(level, 5))
    }

    // MARK: - Custom Decoding

    /// Maps API field names to Swift property names.
    ///
    /// The API returns bilingual text as flat _EN / _TC top-level keys and
    /// uses "image" for the item photo URL rather than "imageUrl".
    ///
    /// Fields absent from the API response (restaurantId, category, dietaryInfo,
    /// isAvailable, spiceLevel) are assigned safe defaults in init(from:).
    private enum CodingKeys: String, CodingKey {
        case id                           // API key: "id"  (was "menuItemId")

        // Flat bilingual name fields
        case nameEN      = "Name_EN"
        case nameTC      = "Name_TC"

        // Flat bilingual description fields
        case descEN      = "Description_EN"
        case descTC      = "Description_TC"

        case price                        // API key: "price" (unchanged)
        case imageURL    = "image"        // API key: "image"  (was "imageUrl")
    }

    /// Custom decoder that maps the API's flat bilingual fields into
    /// BilingualText values and applies safe defaults for fields the API
    /// does not return (restaurantId, category, dietaryInfo, isAvailable,
    /// spiceLevel).
    ///
    /// restaurantId is absent from the menu item body (it lives in the URL path).
    /// It defaults to "" here and should be set by the caller if required.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id    = try container.decode(String.self, forKey: .id)
        price = (try? container.decode(Double.self, forKey: .price)) ?? 0.0

        // Build BilingualText from flat EN / TC keys
        let nameEN = (try? container.decode(String.self, forKey: .nameEN)) ?? ""
        let nameTC = (try? container.decode(String.self, forKey: .nameTC)) ?? nameEN
        name       = BilingualText(en: nameEN, tc: nameTC)

        let descEN  = (try? container.decode(String.self, forKey: .descEN)) ?? ""
        let descTC  = (try? container.decode(String.self, forKey: .descTC)) ?? descEN
        description = BilingualText(en: descEN, tc: descTC)

        imageURL = try? container.decode(String.self, forKey: .imageURL)

        // Fields not returned by the API — safe defaults
        restaurantId = ""          // API omits this from the response body
        category     = .mainCourse // default; API does not return this field
        dietaryInfo  = []          // API does not return this field
        isAvailable  = true        // API does not return this field
        spiceLevel   = nil         // API does not return this field
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name.en, forKey: .nameEN)
        try container.encode(name.tc, forKey: .nameTC)
        try container.encode(description.en, forKey: .descEN)
        try container.encode(description.tc, forKey: .descTC)
        try container.encode(price, forKey: .price)
        if let imageURL {
            try container.encode(imageURL, forKey: .imageURL)
        }
    }
}

// MARK: - Menu Category
//
// ENUM FOR CATEGORIES:
// Restricts menu items to valid categories only
// Provides type safety - can't accidentally use invalid category
//
// FLUTTER EQUIVALENT:
// enum MenuCategory {
//   appetiser,
//   mainCourse,
//   dessert,
//   beverage,
//   side
// }

/// Enumeration of menu item categories
//
// PROTOCOL CONFORMANCE:
// - String: Each case has a String raw value (e.g., "Appetiser")
// - Codable: Automatically handles JSON encoding/decoding
// - CaseIterable: Enables .allCases to get all possible categories
//
// USAGE:
// let category: MenuCategory = .appetiser
// let categories = MenuCategory.allCases  // Get all 5 categories
enum MenuCategory: String, Codable, CaseIterable {

    /// Starters and small dishes
    // Raw value is "Appetiser" (British English spelling)
    // This is what gets stored in JSON
    case appetiser = "Appetiser"

    /// Main dishes
    // Raw value has a space - "Main Course"
    // Demonstrates that raw values can be any string
    case mainCourse = "Main Course"

    /// Desserts and sweet dishes
    // Sweet items served after main course
    case dessert = "Dessert"

    /// Drinks and beverages
    // Hot and cold drinks, alcoholic and non-alcoholic
    case beverage = "Beverage"

    /// Side dishes
    // Accompaniments to main dishes (rice, bread, vegetables, etc.)
    case side = "Side"

    /// Returns localised category name for display
    //
    // COMPUTED PROPERTY:
    // Returns the category name in the user's language
    // Uses string localization to support English and Chinese
    //
    // HOW IT WORKS:
    // 1. Switch on self (the current enum case)
    // 2. For each case, return localized string
    // 3. String(localized:) looks up the translation
    //
    // LOCALIZATION:
    // "menu_category_appetiser" → looks up in Localizable.strings file
    // en: "Appetiser"
    // zh-Hant: "前菜"
    //
    // FLUTTER EQUIVALENT:
    // String get localized {
    //   switch (this) {
    //     case MenuCategory.appetiser:
    //       return AppLocalizations.of(context).appetiser;
    //   }
    // }
    var localised: String {
        switch self {
        case .appetiser:
            return String(localized: "menu_category_appetiser", bundle: L10n.bundle)
        case .mainCourse:
            return String(localized: "menu_category_main", bundle: L10n.bundle)
        case .dessert:
            return String(localized: "menu_category_dessert", bundle: L10n.bundle)
        case .beverage:
            return String(localized: "menu_category_beverage", bundle: L10n.bundle)
        case .side:
            return String(localized: "menu_category_side", bundle: L10n.bundle)
        }
    }
}

// MARK: - Dietary Tags
//
// DIETARY RESTRICTIONS ENUM:
// Tags for filtering menu items by dietary requirements
// Users can filter for vegetarian, gluten-free, etc.
//
// FLUTTER EQUIVALENT:
// enum DietaryTag {
//   vegetarian,
//   vegan,
//   glutenFree,
//   // ... etc
// }

/// Enumeration of dietary restriction and preference tags
//
// USAGE:
// A menu item can have multiple tags:
// dietaryInfo: [.vegetarian, .glutenFree, .nutFree]
//
// CaseIterable allows iteration over all possible tags for filter UI
enum DietaryTag: String, Codable, CaseIterable {

    /// Suitable for vegetarians
    // No meat, but may contain dairy, eggs, honey
    case vegetarian = "Vegetarian"

    /// Suitable for vegans
    // No animal products whatsoever (stricter than vegetarian)
    case vegan = "Vegan"

    /// Does not contain gluten
    // Safe for celiac disease and gluten sensitivity
    // No wheat, barley, rye
    case glutenFree = "Gluten-Free"

    /// Does not contain dairy
    // No milk, cheese, butter, cream
    // Safe for lactose intolerance
    case dairyFree = "Dairy-Free"

    /// Does not contain nuts
    // Safe for nut allergies
    // Includes tree nuts and peanuts
    case nutFree = "Nut-Free"

    /// Certified halal
    // Prepared according to Islamic dietary laws
    // No pork, alcohol; meat must be halal-certified
    case halal = "Halal"

    /// Contains seafood
    // Important for people with seafood allergies
    // Or those who avoid seafood for other reasons
    case seafood = "Seafood"

    /// Spicy dish
    // Contains hot peppers or spicy seasonings
    // Helps users who can't tolerate spicy food
    case spicy = "Spicy"

    /// Returns localised tag name for display
    //
    // LOCALIZATION:
    // Converts enum cases to user-friendly, localized strings
    // Supports both English and Traditional Chinese
    //
    // EXAMPLE:
    // .vegetarian → "Vegetarian" (English) or "素食" (Chinese)
    //
    // WHY A SWITCH:
    // Could use .rawValue, but we want localization support
    // Switch lets us map each case to a localized string key
    var localised: String {
        switch self {
        case .vegetarian:
            return String(localized: "dietary_vegetarian", bundle: L10n.bundle)
        case .vegan:
            return String(localized: "dietary_vegan", bundle: L10n.bundle)
        case .glutenFree:
            return String(localized: "dietary_gluten_free", bundle: L10n.bundle)
        case .dairyFree:
            return String(localized: "dietary_dairy_free", bundle: L10n.bundle)
        case .nutFree:
            return String(localized: "dietary_nut_free", bundle: L10n.bundle)
        case .halal:
            return String(localized: "dietary_halal", bundle: L10n.bundle)
        case .seafood:
            return String(localized: "dietary_seafood", bundle: L10n.bundle)
        case .spicy:
            return String(localized: "dietary_spicy", bundle: L10n.bundle)
        }
    }
}

// MARK: - API Response Wrapper
//
// WHY THIS EXISTS:
// Same reason as RestaurantListResponse
// API returns { "menuItems": [...] } not just [...]

/// Response wrapper for menu items API calls
//
// USAGE:
// When fetching menu for a restaurant, API returns this structure
// We extract the menuItems array from it
//
// ACTUAL API RESPONSE FORMAT:
// {
//   "count": 2,
//   "data": [
//     { "id": "1", "Name_EN": "Fried Rice", "Name_TC": "炒飯", "price": 88.0, ... },
//     { "id": "2", "Name_EN": "Spring Rolls", "Name_TC": "春卷", "price": 45.5, ... }
//   ]
// }
struct MenuItemListResponse: Codable {
    let menuItems: [Menu]

    enum CodingKeys: String, CodingKey {
        case menuItems = "data"    // API key: "data"  (was "menuItems")
    }
}

