//
//  Advertisement.swift
//  Pour Rice
//
//  Model for restaurant advertisements stored in the Firestore Advertisements collection.
//  Maps the API's snake_case / PascalCase fields (Title_EN, etc.) to Swift camelCase.
//

import Foundation

// MARK: - Advertisement Model

/// Represents a restaurant advertisement from the PourRice API.
/// Conforms to Identifiable so it can be used directly in SwiftUI ForEach.
struct Advertisement: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique Firestore document ID
    let id: String

    /// English title (may be nil if only TC is set)
    let titleEN: String?

    /// Traditional Chinese title
    let titleTC: String?

    /// English body text
    let contentEN: String?

    /// Traditional Chinese body text
    let contentTC: String?

    /// URL for the English-language ad image
    let imageEN: String?

    /// URL for the Traditional Chinese ad image
    let imageTC: String?

    /// ID of the restaurant this ad belongs to
    let restaurantId: String?

    /// UID of the user who created the ad (auto-set by backend on POST)
    let userId: String?

    /// "active" or "inactive"
    let status: String?

    /// Creation timestamp (ISO 8601 string decoded as Date)
    let createdAt: Date?

    /// Last-modified timestamp
    let modifiedAt: Date?

    // MARK: - CodingKeys
    // The API uses PascalCase field names (Title_EN, Content_TC, etc.)
    // which are unusual for JSON — map them explicitly here.
    private enum CodingKeys: String, CodingKey {
        case id
        case titleEN    = "Title_EN"
        case titleTC    = "Title_TC"
        case contentEN  = "Content_EN"
        case contentTC  = "Content_TC"
        case imageEN    = "Image_EN"
        case imageTC    = "Image_TC"
        case restaurantId
        case userId
        case status
        case createdAt
        case modifiedAt
    }

    // MARK: - Computed Properties

    /// Returns the bilingual title appropriate for the current app language setting.
    var localizedTitle: String {
        let lang = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "en"
        // Prefer the language-matching field, fall back to the other
        if lang.hasPrefix("zh") {
            return titleTC ?? titleEN ?? ""
        }
        return titleEN ?? titleTC ?? ""
    }

    /// Returns the bilingual image URL for the current app language.
    var localizedImageURL: URL? {
        let lang = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "en"
        let urlString = lang.hasPrefix("zh") ? (imageTC ?? imageEN) : (imageEN ?? imageTC)
        guard let str = urlString, !str.isEmpty, str != "—" else { return nil }
        return URL(string: str)
    }

    /// Returns true when status is "active"
    var isActive: Bool {
        status?.lowercased() == "active"
    }
}

// MARK: - Create Advertisement Request

/// Request body for POST /API/Advertisements (auth required).
/// The backend auto-sets userId from the token — we only send content fields.
struct CreateAdvertisementRequest: Codable, Sendable {
    var titleEN: String?
    var titleTC: String?
    var contentEN: String?
    var contentTC: String?
    var imageEN: String?
    var imageTC: String?
    /// The restaurant this ad belongs to (required by the API)
    let restaurantId: String

    private enum CodingKeys: String, CodingKey {
        case titleEN    = "Title_EN"
        case titleTC    = "Title_TC"
        case contentEN  = "Content_EN"
        case contentTC  = "Content_TC"
        case imageEN    = "Image_EN"
        case imageTC    = "Image_TC"
        case restaurantId
    }
}

// MARK: - Update Advertisement Request

/// Request body for PUT /API/Advertisements/:id (ownership verified by backend).
/// All fields default to nil so callers only need to set what they're changing.
struct UpdateAdvertisementRequest: Codable, Sendable {
    var status: String? = nil
    var titleEN: String? = nil
    var titleTC: String? = nil
    var contentEN: String? = nil
    var contentTC: String? = nil
    var imageEN: String? = nil
    var imageTC: String? = nil

    private enum CodingKeys: String, CodingKey {
        case status
        case titleEN    = "Title_EN"
        case titleTC    = "Title_TC"
        case contentEN  = "Content_EN"
        case contentTC  = "Content_TC"
        case imageEN    = "Image_EN"
        case imageTC    = "Image_TC"
    }
}

// MARK: - Advertisement List Response

/// Wrapper matching the API's { count, data } envelope for advertisement lists.
struct AdvertisementListResponse: Codable {
    let advertisements: [Advertisement]
    let totalCount: Int

    private enum CodingKeys: String, CodingKey {
        case advertisements = "data"
        case totalCount     = "count"
    }
}

// MARK: - Stripe Checkout Models

/// Request body for POST /API/Stripe/create-ad-checkout-session (auth required).
struct StripeCheckoutRequest: Codable, Sendable {
    let restaurantId: String
    let successUrl: String
    let cancelUrl: String
}

/// Response from POST /API/Stripe/create-ad-checkout-session.
struct StripeCheckoutResponse: Codable, Sendable {
    let sessionId: String
    let url: URL
}

// MARK: - Gemini Advertisement Generation Models

/// Request body for POST /API/Gemini/restaurant-advertisement (auth required).
struct GeminiAdvertisementRequest: Codable, Sendable {
    let restaurantId: String
    let name: String?
    let district: String?
    let keywords: [String]?
    let message: String?
}

/// Response from POST /API/Gemini/restaurant-advertisement.
/// Maps the API's PascalCase fields to Swift camelCase.
struct AdvertisementGenerationResponse: Codable, Sendable {
    let titleEN: String
    let titleTC: String
    let contentEN: String
    let contentTC: String

    private enum CodingKeys: String, CodingKey {
        case titleEN    = "Title_EN"
        case titleTC    = "Title_TC"
        case contentEN  = "Content_EN"
        case contentTC  = "Content_TC"
    }
}
