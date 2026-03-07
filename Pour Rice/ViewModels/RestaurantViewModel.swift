//
//  RestaurantViewModel.swift
//  Pour Rice
//
//  ViewModel for the restaurant detail screen
//  Fetches restaurant details, reviews, and menu preview in parallel
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  Like HomeViewModel, this uses async let for parallel fetching.
//  Three API calls happen simultaneously instead of one-by-one:
//  1. Restaurant details (if not already available from navigation)
//  2. Customer reviews + stats
//  3. Menu preview (first few items)
//
//  FLUTTER EQUIVALENT:
//  await Future.wait([
//    fetchRestaurant(id),
//    fetchReviews(restaurantId: id),
//    fetchMenu(restaurantId: id),
//  ]);
//  ============================================================================
//

import Foundation
import Observation

// MARK: - Restaurant View Model

/// ViewModel for the RestaurantView detail screen
/// Loads and manages all data for a single restaurant
@MainActor
@Observable
final class RestaurantViewModel {

    // MARK: - State

    /// The detailed restaurant object (may be pre-loaded from navigation)
    var restaurant: Restaurant?

    /// All reviews for this restaurant
    var reviews: [Review] = []

    /// Preview of menu items (first few items to show in the detail screen)
    var menuPreview: [Menu] = []

    /// Whether data is being loaded
    var isLoading = false

    /// Error message if loading failed
    var errorMessage: String?

    /// Whether the user has already submitted a review
    /// Used to show/hide the "Write a Review" button
    var userHasReviewed = false

    /// Whether the review submission sheet is presented
    var showingReviewSheet = false

    /// Calculated average rating from loaded reviews
    var averageRating: Double {
        guard !reviews.isEmpty else { return restaurant?.rating ?? 0 }
        return reviewService.calculateAverageRating(for: reviews)
    }

    // MARK: - Dependencies

    private let restaurantService: RestaurantService
    private let reviewService: ReviewService
    private let menuService: MenuService
    private let authService: AuthService

    // MARK: - Initialisation

    /// - Parameters:
    ///   - restaurant: Pre-loaded restaurant from navigation (avoids extra API call)
    ///   - restaurantService: Service for restaurant API
    ///   - reviewService: Service for review API
    ///   - menuService: Service for menu API
    ///   - authService: Auth service for checking if user is logged in
    init(
        restaurant: Restaurant? = nil,
        restaurantService: RestaurantService,
        reviewService: ReviewService,
        menuService: MenuService,
        authService: AuthService
    ) {
        self.restaurant = restaurant
        self.restaurantService = restaurantService
        self.reviewService = reviewService
        self.menuService = menuService
        self.authService = authService
    }

    // MARK: - Data Loading

    /// Loads all data for the given restaurant ID
    ///
    /// Fetches reviews and menu preview in parallel.
    /// If restaurant details weren't passed via navigation, fetches them too.
    ///
    /// - Parameter restaurantId: The unique ID of the restaurant to display
    func loadData(restaurantId: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            if restaurant == nil {
                // Restaurant not passed via navigation — fetch it
                // async let starts this fetch concurrently with others below
                async let restaurantTask = restaurantService.fetchRestaurant(id: restaurantId)
                async let reviewsTask = reviewService.fetchReviews(restaurantId: restaurantId, limit: 20)
                async let menuTask = menuService.fetchMenuItems(restaurantId: restaurantId, limit: 6)

                // Wait for all three in parallel
                let (fetchedRestaurant, fetchedReviews, fetchedMenu) = try await (
                    restaurantTask, reviewsTask, menuTask
                )

                restaurant = fetchedRestaurant
                reviews = fetchedReviews
                menuPreview = Array(fetchedMenu.prefix(6))  // Show max 6 items preview

            } else {
                // Restaurant already available — only fetch reviews and menu
                async let reviewsTask = reviewService.fetchReviews(restaurantId: restaurantId, limit: 20)
                async let menuTask = menuService.fetchMenuItems(restaurantId: restaurantId, limit: 6)

                let (fetchedReviews, fetchedMenu) = try await (reviewsTask, menuTask)

                reviews = fetchedReviews
                menuPreview = Array(fetchedMenu.prefix(6))
            }

            // Check if current user has already reviewed this restaurant
            checkIfUserHasReviewed(restaurantId: restaurantId)

        } catch {
            errorMessage = error.localizedDescription
            print("❌ RestaurantViewModel: Failed to load — \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Refreshes all data for the current restaurant
    func refresh(restaurantId: String) async {
        reviews = []
        menuPreview = []
        await loadData(restaurantId: restaurantId)
    }

    // MARK: - Review Submission

    /// Submits a new review for the restaurant
    ///
    /// - Parameters:
    ///   - restaurantId: ID of the restaurant being reviewed
    ///   - rating: Star rating (1-5)
    ///   - comment: Written review text
    /// - Returns: true if submission succeeded
    func submitReview(restaurantId: String, rating: Int, comment: String) async -> Bool {
        let request = ReviewRequest(
            restaurantId: restaurantId,
            rating: rating,
            comment: comment
        )

        // Validate the review before submitting
        guard request.validate() else {
            errorMessage = request.validationError() ?? String(localized: "review_validation_error")
            return false
        }

        do {
            // Submit review via review service
            try await reviewService.submitReview(request)

            // After submitting, reload reviews to show the new one
            await loadData(restaurantId: restaurantId)
            showingReviewSheet = false
            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Private Helpers

    /// Checks if the currently logged-in user has already reviewed this restaurant
    private func checkIfUserHasReviewed(restaurantId: String) {
        guard let userId = authService.currentUser?.id else {
            userHasReviewed = false
            return
        }
        userHasReviewed = reviews.contains { $0.userId == userId }
    }
}
