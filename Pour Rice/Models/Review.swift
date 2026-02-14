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
    let userName: String

    /// Profile photo URL of the reviewer (optional)
    let userPhotoURL: String?

    /// Rating from 1 to 5 stars
    let rating: Int

    /// Written comment about the restaurant
    let comment: String

    /// URLs of photos attached to the review
    let photoURLs: [String]

    /// Date when the review was created
    let createdAt: Date

    /// Date when the review was last updated (optional)
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

    enum CodingKeys: String, CodingKey {
        case id = "reviewId"
        case restaurantId
        case userId
        case userName
        case userPhotoURL
        case rating
        case comment
        case photoURLs
        case createdAt
        case updatedAt
    }
}

// MARK: - Review Request Models

/// Request model for submitting a new review
struct ReviewRequest: Codable {
    /// ID of the restaurant being reviewed
    let restaurantId: String

    /// Rating from 1 to 5 stars
    let rating: Int

    /// Written comment about the restaurant
    let comment: String

    /// URLs of photos to attach (optional)
    let photoURLs: [String]?

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
            return String(localized: "error_invalid_rating")
        }
        if comment.count < 10 {
            return String(localized: "error_review_too_short")
        }
        return nil
    }
}

/// Response wrapper for review list API calls
struct ReviewListResponse: Codable {
    let reviews: [Review]
    let totalCount: Int
}
