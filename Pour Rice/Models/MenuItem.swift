//
//  MenuItem.swift
//  Pour Rice
//
//  Menu item model representing dishes available at restaurants
//  Supports bilingual names, descriptions, and dietary information
//

import Foundation

/// Represents a menu item available at a restaurant
/// Includes pricing, description, and dietary information
struct MenuItem: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the menu item
    let id: String

    /// Restaurant ID this menu item belongs to
    let restaurantId: String

    /// Dish name in both British English and Traditional Chinese
    let name: BilingualText

    /// Detailed description of the dish
    let description: BilingualText

    /// Price in local currency (HKD)
    let price: Double

    /// Menu category (Appetiser, Main Course, Dessert, Beverage)
    let category: MenuCategory

    /// Image URL for the dish (optional)
    let imageURL: String?

    /// Dietary information tags
    let dietaryInfo: [DietaryTag]

    /// Indicates if the item is currently available
    let isAvailable: Bool

    /// Spice level for dishes (0 = not spicy, 1-5 = increasing spiciness)
    let spiceLevel: Int?

    // MARK: - Computed Properties

    /// Returns formatted price with currency symbol
    var priceDisplay: String {
        return String(format: "HK$%.2f", price)
    }

    /// Returns dietary tags as comma-separated string
    var dietaryInfoDisplay: String {
        return dietaryInfo.map { $0.rawValue }.joined(separator: ", ")
    }

    /// Returns spice level as emoji indicators
    var spiceLevelDisplay: String? {
        guard let level = spiceLevel, level > 0 else { return nil }
        return String(repeating: "🌶️", count: min(level, 5))
    }

    // MARK: - Custom Decoding

    enum CodingKeys: String, CodingKey {
        case id = "menuItemId"
        case restaurantId
        case name
        case description
        case price
        case category
        case imageURL = "imageUrl"
        case dietaryInfo
        case isAvailable
        case spiceLevel
    }
}

// MARK: - Menu Category

/// Enumeration of menu item categories
enum MenuCategory: String, Codable, CaseIterable {
    /// Starters and small dishes
    case appetiser = "Appetiser"

    /// Main dishes
    case mainCourse = "Main Course"

    /// Desserts and sweet dishes
    case dessert = "Dessert"

    /// Drinks and beverages
    case beverage = "Beverage"

    /// Side dishes
    case side = "Side"

    /// Returns localised category name for display
    var localised: String {
        switch self {
        case .appetiser:
            return String(localized: "menu_category_appetiser")
        case .mainCourse:
            return String(localized: "menu_category_main")
        case .dessert:
            return String(localized: "menu_category_dessert")
        case .beverage:
            return String(localized: "menu_category_beverage")
        case .side:
            return String(localized: "menu_category_side")
        }
    }
}

// MARK: - Dietary Tags

/// Enumeration of dietary restriction and preference tags
enum DietaryTag: String, Codable, CaseIterable {
    /// Suitable for vegetarians
    case vegetarian = "Vegetarian"

    /// Suitable for vegans
    case vegan = "Vegan"

    /// Does not contain gluten
    case glutenFree = "Gluten-Free"

    /// Does not contain dairy
    case dairyFree = "Dairy-Free"

    /// Does not contain nuts
    case nutFree = "Nut-Free"

    /// Certified halal
    case halal = "Halal"

    /// Contains seafood
    case seafood = "Seafood"

    /// Spicy dish
    case spicy = "Spicy"

    /// Returns localised tag name for display
    var localised: String {
        switch self {
        case .vegetarian:
            return String(localized: "dietary_vegetarian")
        case .vegan:
            return String(localized: "dietary_vegan")
        case .glutenFree:
            return String(localized: "dietary_gluten_free")
        case .dairyFree:
            return String(localized: "dietary_dairy_free")
        case .nutFree:
            return String(localized: "dietary_nut_free")
        case .halal:
            return String(localized: "dietary_halal")
        case .seafood:
            return String(localized: "dietary_seafood")
        case .spicy:
            return String(localized: "dietary_spicy")
        }
    }
}

// MARK: - API Response Wrapper

/// Response wrapper for menu items API calls
struct MenuItemListResponse: Codable {
    let menuItems: [MenuItem]
}
