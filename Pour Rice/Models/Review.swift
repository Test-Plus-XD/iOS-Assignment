//
//  Review.swift
//  Pour Rice
//
//  Review model for restaurant ratings and comments
//  Supports photo attachments and user attribution
//

import Foundation

/// Represents a customer review for a restaurant
/// Includes rating, comment, photos, and user information
struct Review: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the review
    let id: String

    /// ID of the restaurant being reviewed
    let restaurantId: String

    /// ID of the user who wrote the review
    let userId: String

    /// Display name of the reviewer
    /// Decoded from API field "userDisplayName"
    let userName: String

    /// Profile photo URL of the reviewer (optional)
    let userPhotoURL: String?

    /// Rating from 1 to 5 stars
    let rating: Int

    /// Written comment about the restaurant
    let comment: String

    /// URLs of photos attached to the review.
    /// The API returns a single "imageUrl" string; it is wrapped in an array
    /// here so the rest of the app can iterate over photos uniformly.
    let photoURLs: [String]

    /// The date and time of the dining visit (user-supplied, ISO 8601).
    /// Optional because older reviews pre-dating this field may omit it.
    let dateTime: Date?

    /// Date when the review was created in the database
    let createdAt: Date

    /// Date when the review was last updated (optional).
    /// Decoded from API field "modifiedAt".
    let updatedAt: Date?

    // MARK: - Computed Properties

    /// Returns a star rating string for display (e.g., "⭐⭐⭐⭐⭐")
    var starRating: String {
        return String(repeating: "⭐", count: rating)
    }

    /// Returns a formatted relative date string (e.g., "2 days ago")
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    // MARK: - Validation

    /// Validates if the rating is within acceptable range
    var isValidRating: Bool {
        return rating >= 1 && rating <= 5
    }

    /// Validates if the comment meets minimum length requirement
    var isValidComment: Bool {
        return comment.count >= 10
    }

    // MARK: - Custom Decoding

    /// Maps API field names to Swift property names.
    ///
    /// Key corrections vs. the previous version:
    ///   • "reviewId"        → "id"              (API always returns "id")
    ///   • "userDisplayName" → userName           (API field name)
    ///   • "imageUrl"        → photoURLs proxy    (API returns a single String,
    ///                         not an array — handled in init(from:) below)
    ///   • "modifiedAt"      → updatedAt          (API field name)
    ///   • dateTime added    (ISO 8601 visit timestamp required by API)
    private enum CodingKeys: String, CodingKey {
        case id                              // API: "id"  (was "reviewId")
        case restaurantId
        case userId
        case userName        = "userDisplayName"   // API: "userDisplayName"
        case userPhotoURL
        case rating
        case comment
        case imageUrl                              // mapped to photoURLs array in init
        case dateTime                              // ISO 8601 visit timestamp
        case createdAt
        case updatedAt       = "modifiedAt"        // API: "modifiedAt"
    }

    /// Custom decoder.  Handles the API's single-string imageUrl field by
    /// wrapping it in an array for photoURLs, and maps renamed API fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id           = try  container.decode(String.self, forKey: .id)
        restaurantId = try  container.decode(String.self, forKey: .restaurantId)
        userId       = try  container.decode(String.self, forKey: .userId)
        userName     = try  container.decode(String.self, forKey: .userName)
        userPhotoURL = try? container.decode(String.self, forKey: .userPhotoURL)
        rating       = try  container.decode(Int.self,    forKey: .rating)
        comment      = try  container.decode(String.self, forKey: .comment)
        dateTime     = try? container.decode(Date.self,   forKey: .dateTime)
        createdAt    = try  container.decode(Date.self,   forKey: .createdAt)
        updatedAt    = try? container.decode(Date.self,   forKey: .updatedAt)

        // API returns a single optional imageUrl string; wrap it in [String]
        // so the rest of the app can iterate over photos uniformly.
        let singleURL = try? container.decode(String.self, forKey: .imageUrl)
        photoURLs     = singleURL.map { [$0] } ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(restaurantId, forKey: .restaurantId)
        try container.encode(userId, forKey: .userId)
        try container.encode(userName, forKey: .userName)
        if let userPhotoURL {
            try container.encode(userPhotoURL, forKey: .userPhotoURL)
        }
        try container.encode(rating, forKey: .rating)
        try container.encode(comment, forKey: .comment)
        if let dateTime {
            try container.encode(dateTime, forKey: .dateTime)
        }
        try container.encode(createdAt, forKey: .createdAt)
        if let updatedAt {
            try container.encode(updatedAt, forKey: .updatedAt)
        }
        if let firstImage = photoURLs.first {
            try container.encode(firstImage, forKey: .imageUrl)
        }
    }
}

// MARK: - Review Request Models

/// Request model for submitting a new review.
///
/// API endpoint: POST /API/Reviews
/// Required fields: restaurantId, rating, comment, dateTime (ISO 8601)
struct ReviewRequest: Codable {
    /// ID of the restaurant being reviewed
    let restaurantId: String

    /// Rating from 1 to 5 stars
    let rating: Int

    /// Written comment about the restaurant
    let comment: String

    /// The date and time of the dining visit (ISO 8601).
    /// Required by the API — previously omitted, causing 400 Bad Request responses.
    /// Defaults to the current time so callers that omit it still compile cleanly.
    let dateTime: Date

    /// URLs of photos to attach (optional).
    /// Note: the API does not currently process this field on submission.
    /// Photo uploads should use POST /API/Images/upload separately.
    let photoURLs: [String]?

    // MARK: - Initialisation

    /// Creates a new review request.
    /// - Parameters:
    ///   - restaurantId: ID of the restaurant being reviewed
    ///   - rating: Star rating from 1 to 5
    ///   - comment: Written comment (minimum 10 characters)
    ///   - dateTime: Date and time of the dining visit (defaults to now)
    ///   - photoURLs: Optional photo URLs (not currently processed by the API)
    init(
        restaurantId: String,
        rating: Int,
        comment: String,
        dateTime: Date = Date(),
        photoURLs: [String]? = nil
    ) {
        self.restaurantId = restaurantId
        self.rating       = rating
        self.comment      = comment
        self.dateTime     = dateTime
        self.photoURLs    = photoURLs
    }

    // MARK: - Validation

    /// Validates the review request before submission
    /// - Returns: true if all fields are valid, false otherwise
    func validate() -> Bool {
        return rating >= 1 && rating <= 5 && comment.count >= 10
    }

    /// Returns validation error message if invalid
    /// - Returns: Localised error message or nil if valid
    func validationError() -> String? {
        if rating < 1 || rating > 5 {
            return String(localized: "error_invalid_rating", bundle: L10n.bundle)
        }
        if comment.count < 10 {
            return String(localized: "error_review_too_short", bundle: L10n.bundle)
        }
        return nil
    }
}

/// Response wrapper for review list API calls.
///
/// The API returns { "count": N, "data": [...] }; CodingKeys map
/// "data" → reviews and "count" → totalCount so the property names
/// remain semantically clear throughout the app.
struct ReviewListResponse: Codable {
    let reviews: [Review]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case reviews    = "data"    // API key: "data"
        case totalCount = "count"   // API key: "count"
    }
}
