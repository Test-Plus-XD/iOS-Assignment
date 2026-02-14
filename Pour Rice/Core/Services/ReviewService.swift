//
//  ReviewService.swift
//  Pour Rice
//
//  Service for fetching and submitting restaurant reviews
//  Handles review CRUD operations and validation
//

import Foundation

/// Service responsible for all review-related operations
/// Provides methods to fetch reviews and submit new reviews
@MainActor
final class ReviewService {

    // MARK: - Properties

    /// API client for network requests
    private let apiClient: APIClient

    // MARK: - Initialisation

    /// Creates a new review service instance
    /// - Parameter apiClient: API client for network requests
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch Reviews

    /// Fetches reviews for a specific restaurant
    /// - Parameters:
    ///   - restaurantId: Unique restaurant identifier
    ///   - limit: Maximum number of reviews to return (optional)
    /// - Returns: Array of reviews sorted by date (newest first)
    /// - Throws: APIError for network or decoding failures
    func fetchReviews(restaurantId: String, limit: Int? = nil) async throws -> [Review] {

        print("🔍 Fetching reviews for restaurant: \(restaurantId)")

        let endpoint = APIEndpoint.fetchReviews(restaurantId: restaurantId, limit: limit)

        let response = try await apiClient.request(
            endpoint,
            responseType: ReviewListResponse.self
        )

        print("✅ Fetched \(response.reviews.count) reviews")

        return response.reviews
    }

    // MARK: - Submit Review

    /// Submits a new review for a restaurant
    /// Validates review data before submission
    /// - Parameter request: Review data including rating and comment
    /// - Returns: Created review with ID and timestamp
    /// - Throws: Validation errors or APIError for network failures
    func submitReview(_ request: ReviewRequest) async throws -> Review {

        // Validate review data before sending
        guard request.validate() else {
            if let errorMessage = request.validationError() {
                print("❌ Review validation failed: \(errorMessage)")
                throw ValidationError.invalidReview(errorMessage)
            }
            throw ValidationError.invalidReview("Invalid review data")
        }

        print("📝 Submitting review for restaurant: \(request.restaurantId)")
        print("   Rating: \(request.rating)/5")
        print("   Comment length: \(request.comment.count) characters")

        let endpoint = APIEndpoint.submitReview(request)

        let review = try await apiClient.request(endpoint, responseType: Review.self)

        print("✅ Review submitted successfully with ID: \(review.id)")

        return review
    }

    // MARK: - Review Statistics

    /// Calculates average rating from an array of reviews
    /// - Parameter reviews: Array of reviews to analyse
    /// - Returns: Average rating from 0.0 to 5.0
    func calculateAverageRating(from reviews: [Review]) -> Double {
        guard !reviews.isEmpty else { return 0.0 }

        let totalRating = reviews.reduce(0) { $0 + $1.rating }
        return Double(totalRating) / Double(reviews.count)
    }

    /// Counts reviews by rating value
    /// - Parameter reviews: Array of reviews to analyse
    /// - Returns: Dictionary mapping rating (1-5) to count
    func countReviewsByRating(from reviews: [Review]) -> [Int: Int] {
        var counts: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]

        for review in reviews {
            if review.isValidRating {
                counts[review.rating, default: 0] += 1
            }
        }

        return counts
    }
}

// MARK: - Validation Error

/// Errors that can occur during review validation
enum ValidationError: LocalizedError {

    /// Review data is invalid
    case invalidReview(String)

    var errorDescription: String? {
        switch self {
        case .invalidReview(let message):
            return message
        }
    }
}
