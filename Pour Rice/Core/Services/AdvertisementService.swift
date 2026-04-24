//
//  AdvertisementService.swift
//  Pour Rice
//
//  CRUD service for the /API/Advertisements endpoints.
//  Also handles the Stripe checkout session creation for ad payments.
//

import Foundation

// MARK: - Advertisement Payment Errors

/// Errors raised when a returned Stripe Checkout session is not valid for opening the ad form.
enum AdvertisementPaymentError: LocalizedError {
    case invalidSession
    case unpaid
    case wrongPaymentType
    case wrongRestaurant

    var errorDescription: String? {
        switch self {
        case .invalidSession:
            return "The payment session is invalid. Please start the payment again."
        case .unpaid:
            return "Payment was not completed. The advertisement form will stay closed."
        case .wrongPaymentType:
            return "This payment session is not for an advertisement placement."
        case .wrongRestaurant:
            return "This payment belongs to a different restaurant."
        }
    }
}

// MARK: - Advertisement Service

/// Service responsible for advertisement CRUD operations and Stripe payment initiation.
/// All mutations require Firebase authentication (handled transparently by APIClient).
@MainActor
final class AdvertisementService {

    // MARK: - Properties

    private let apiClient: APIClient

    // MARK: - Initialisation

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch

    /// Fetches all advertisements, optionally filtered to a single restaurant.
    /// Corresponds to GET /API/Advertisements (optional ?restaurantId=X).
    /// - Parameter restaurantId: If non-nil, only ads for that restaurant are returned.
    func fetchAdvertisements(restaurantId: String? = nil) async throws -> [Advertisement] {
        print("📢 AdvertisementService: Fetching ads (restaurantId=\(restaurantId ?? "all"))")

        let response = try await apiClient.request(
            .fetchAdvertisements(restaurantId: restaurantId),
            responseType: AdvertisementListResponse.self,
            callerService: "AdvertisementService"
        )

        print("✅ AdvertisementService: Fetched \(response.advertisements.count) ads")
        return response.advertisements
    }

    // MARK: - Create

    /// Creates a new advertisement for the authenticated user's restaurant.
    /// Corresponds to POST /API/Advertisements (auth required).
    /// - Parameter request: The ad content fields (restaurantId is required).
    /// - Returns: The newly created advertisement's ID.
    func createAdvertisement(_ request: CreateAdvertisementRequest) async throws -> String {
        print("📢 AdvertisementService: Creating ad for restaurant \(request.restaurantId)")

        // The API returns { id: "..." } on successful creation
        let response = try await apiClient.request(
            .createAdvertisement(request),
            responseType: CreateAdvertisementResponse.self,
            callerService: "AdvertisementService"
        )

        print("✅ AdvertisementService: Ad created with id=\(response.id)")
        return response.id
    }

    // MARK: - Update

    /// Updates an existing advertisement (e.g. toggling active/inactive status).
    /// Corresponds to PUT /API/Advertisements/:id (ownership verified by backend).
    func updateAdvertisement(id: String, request: UpdateAdvertisementRequest) async throws {
        print("📢 AdvertisementService: Updating ad id=\(id)")

        try await apiClient.requestVoid(
            .updateAdvertisement(id: id, request),
            callerService: "AdvertisementService"
        )

        print("✅ AdvertisementService: Ad updated id=\(id)")
    }

    // MARK: - Delete

    /// Deletes an advertisement by ID.
    /// Corresponds to DELETE /API/Advertisements/:id (ownership verified by backend).
    func deleteAdvertisement(id: String) async throws {
        print("📢 AdvertisementService: Deleting ad id=\(id)")

        try await apiClient.requestVoid(
            .deleteAdvertisement(id: id),
            callerService: "AdvertisementService"
        )

        print("✅ AdvertisementService: Ad deleted id=\(id)")
    }

    // MARK: - Stripe

    /// Creates a Stripe Checkout session for a HK$10 advertisement placement.
    /// Corresponds to POST /API/Stripe/create-ad-checkout-session (auth required).
    /// - Returns: A StripeCheckoutResponse with the session ID and redirect URL.
    func createStripeCheckoutSession(
        restaurantId: String,
        successURL: String,
        cancelURL: String
    ) async throws -> StripeCheckoutResponse {
        print("💳 AdvertisementService: Creating Stripe session for restaurant \(restaurantId)")

        let request = StripeCheckoutRequest(
            restaurantId: restaurantId,
            successUrl: successURL,
            cancelUrl: cancelURL
        )

        let response = try await apiClient.request(
            .createStripeCheckoutSession(request),
            responseType: StripeCheckoutResponse.self,
            callerService: "AdvertisementService"
        )

        print("✅ AdvertisementService: Stripe session created, id=\(response.sessionId)")
        return response
    }

    /// Fetches the latest status of a Stripe Checkout session after Safari returns to the app.
    /// The backend verifies the session belongs to the authenticated user before returning it.
    func fetchStripeCheckoutSession(id sessionId: String) async throws -> StripeCheckoutSessionStatus {
        print("💳 AdvertisementService: Fetching Stripe session status id=\(sessionId)")

        let response = try await apiClient.request(
            .fetchStripeCheckoutSession(id: sessionId),
            responseType: StripeCheckoutSessionStatus.self,
            callerService: "AdvertisementService"
        )

        print("✅ AdvertisementService: Stripe session status=\(response.status), paymentStatus=\(response.paymentStatus)")
        return response
    }

    /// Confirms that a Checkout session is a paid advertisement payment for the current restaurant.
    func verifyPaidAdvertisementSession(
        sessionId: String,
        restaurantId: String
    ) async throws -> StripeCheckoutSessionStatus {
        guard sessionId.range(of: #"^cs_[A-Za-z0-9_]+$"#, options: .regularExpression) != nil else {
            throw AdvertisementPaymentError.invalidSession
        }

        let session = try await fetchStripeCheckoutSession(id: sessionId)

        guard session.isPaid else {
            throw AdvertisementPaymentError.unpaid
        }

        guard session.paymentType == "advertisement" || session.metadata?["paymentType"] == "advertisement" else {
            throw AdvertisementPaymentError.wrongPaymentType
        }

        guard session.metadata?["restaurantId"] == restaurantId else {
            throw AdvertisementPaymentError.wrongRestaurant
        }

        return session
    }
}

// MARK: - Private Response Types

/// Internal response wrapper for the POST /API/Advertisements create response.
private struct CreateAdvertisementResponse: Codable {
    let id: String
}
