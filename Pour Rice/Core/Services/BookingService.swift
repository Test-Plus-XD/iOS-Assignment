//
//  BookingService.swift
//  Pour Rice
//
//  Service for managing table bookings/reservations
//  Handles CRUD operations for both diner and restaurant owner perspectives
//

import Foundation

/// Service responsible for all booking-related API operations
@MainActor
final class BookingService {

    // MARK: - Properties

    private let apiClient: APIClient

    // MARK: - Initialisation

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Diner Operations

    /// Fetches all bookings for the authenticated diner.
    /// Returns bookings enriched with restaurant data.
    func fetchBookings() async throws -> [Booking] {
        print("🔍 Fetching user bookings")

        let response = try await apiClient.request(
            .fetchBookings,
            responseType: BookingListResponse.self,
            callerService: "BookingService"
        )

        print("✅ Fetched \(response.bookings.count) bookings")
        return response.bookings
    }

    /// Fetches a single booking by ID.
    func fetchBooking(id: String) async throws -> Booking {
        print("🔍 Fetching booking: \(id)")

        let booking = try await apiClient.request(
            .fetchBooking(id: id),
            responseType: Booking.self,
            callerService: "BookingService"
        )

        print("✅ Fetched booking: \(booking.id)")
        return booking
    }

    /// Creates a new booking (status defaults to 'pending').
    /// - Returns: The ID of the created booking.
    func createBooking(_ request: CreateBookingRequest) async throws -> String {
        print("📝 Creating booking for restaurant: \(request.restaurantId)")

        let response = try await apiClient.request(
            .createBooking(request),
            responseType: CreateBookingResponse.self,
            callerService: "BookingService"
        )

        print("✅ Created booking: \(response.id)")
        return response.id
    }

    /// Cancels a pending booking (diner action).
    func cancelBooking(id: String) async throws {
        print("❌ Cancelling booking: \(id)")

        let request = UpdateBookingRequest(status: "cancelled")
        try await apiClient.requestVoid(
            .updateBooking(id: id, request),
            callerService: "BookingService"
        )

        print("✅ Cancelled booking: \(id)")
    }

    /// Updates booking details (diner: date/guests/requests when pending).
    func updateBooking(id: String, request: UpdateBookingRequest) async throws {
        print("📝 Updating booking: \(id)")

        try await apiClient.requestVoid(
            .updateBooking(id: id, request),
            callerService: "BookingService"
        )

        print("✅ Updated booking: \(id)")
    }

    /// Deletes a booking (only allowed if 30+ days old).
    func deleteBooking(id: String) async throws {
        print("🗑️ Deleting booking: \(id)")

        try await apiClient.requestVoid(
            .deleteBooking(id: id),
            callerService: "BookingService"
        )

        print("✅ Deleted booking: \(id)")
    }

    // MARK: - Restaurant Owner Operations

    /// Fetches all bookings for a restaurant (owner perspective).
    /// Returns bookings enriched with diner contact information.
    func fetchRestaurantBookings(restaurantId: String) async throws -> [Booking] {
        print("🔍 Fetching bookings for restaurant: \(restaurantId)")

        let response = try await apiClient.request(
            .fetchRestaurantBookings(restaurantId: restaurantId),
            responseType: BookingListResponse.self,
            callerService: "BookingService"
        )

        print("✅ Fetched \(response.bookings.count) restaurant bookings")
        return response.bookings
    }

    /// Accepts a pending booking (restaurant owner action).
    func acceptBooking(id: String) async throws {
        let request = UpdateBookingRequest(status: "accepted")
        try await apiClient.requestVoid(
            .updateBooking(id: id, request),
            callerService: "BookingService"
        )
        print("✅ Accepted booking: \(id)")
    }

    /// Declines a pending booking with an optional reason (restaurant owner action).
    func declineBooking(id: String, reason: String? = nil) async throws {
        let request = UpdateBookingRequest(status: "declined", declineMessage: reason)
        try await apiClient.requestVoid(
            .updateBooking(id: id, request),
            callerService: "BookingService"
        )
        print("✅ Declined booking: \(id)")
    }

    /// Marks an accepted booking as completed (restaurant owner action).
    func completeBooking(id: String) async throws {
        let request = UpdateBookingRequest(status: "completed")
        try await apiClient.requestVoid(
            .updateBooking(id: id, request),
            callerService: "BookingService"
        )
        print("✅ Completed booking: \(id)")
    }
}
