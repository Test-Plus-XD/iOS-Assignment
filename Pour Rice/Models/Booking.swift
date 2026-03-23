//
//  Booking.swift
//  Pour Rice
//
//  Data model for restaurant table bookings/reservations
//  Supports the full booking lifecycle: pending → accepted/declined → completed/cancelled
//

import Foundation
import SwiftUI

/// Represents a table booking at a restaurant
/// Tracks the full lifecycle from creation through to completion or cancellation
struct Booking: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the booking
    let id: String

    /// ID of the user who made the booking
    let userId: String

    /// ID of the restaurant being booked
    let restaurantId: String

    /// Display name of the restaurant
    let restaurantName: String

    /// Date and time of the reservation (ISO 8601)
    let dateTime: Date

    /// Number of guests for the booking
    let numberOfGuests: Int

    /// Current status of the booking
    let status: BookingStatus

    /// Optional special requests from the diner (e.g. dietary needs, seating preference)
    let specialRequests: String?

    /// Optional message from the restaurant owner when declining a booking
    let declineMessage: String?

    /// Diner contact information (only present on restaurant-side booking lists)
    let diner: BookingDiner?

    /// Date when the booking was created
    let createdAt: Date

    /// Date when the booking was last modified
    let modifiedAt: Date?

    // MARK: - Booking Status

    /// Enumeration of possible booking states
    enum BookingStatus: String, Codable, Sendable {
        case pending
        case accepted
        case declined
        case completed
        case cancelled

        /// Display colour for the status badge
        var colour: Color {
            switch self {
            case .pending:   return .orange
            case .accepted:  return .green
            case .declined:  return .red
            case .completed: return .secondary
            case .cancelled: return .secondary
            }
        }

        /// Localised display label
        var label: String {
            switch self {
            case .pending:   return String(localized: "booking_status_pending", bundle: L10n.bundle)
            case .accepted:  return String(localized: "booking_status_accepted", bundle: L10n.bundle)
            case .declined:  return String(localized: "booking_status_declined", bundle: L10n.bundle)
            case .completed: return String(localized: "booking_status_completed", bundle: L10n.bundle)
            case .cancelled: return String(localized: "booking_status_cancelled", bundle: L10n.bundle)
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether this booking can be cancelled by the diner (only pending bookings)
    var canCancel: Bool { status == .pending }

    /// Whether this booking is upcoming (date is in the future)
    var isUpcoming: Bool { dateTime > Date() }

    /// Whether this booking is in the past
    var isPast: Bool { dateTime <= Date() }

    /// Whether this booking is older than 30 days (eligible for deletion)
    var isOlderThan30Days: Bool {
        guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else {
            return false
        }
        return dateTime < thirtyDaysAgo
    }

    /// Formatted date string for display (e.g. "25 Mar 2026")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dateTime)
    }

    /// Formatted time string for display (e.g. "19:30")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: dateTime)
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case restaurantId
        case restaurantName
        case dateTime
        case numberOfGuests
        case status
        case specialRequests
        case declineMessage
        case diner
        case createdAt
        case modifiedAt
    }

    // MARK: - Custom Decoding

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id               = try c.decode(String.self, forKey: .id)
        userId           = try c.decode(String.self, forKey: .userId)
        restaurantId     = try c.decode(String.self, forKey: .restaurantId)
        restaurantName   = try c.decodeIfPresent(String.self, forKey: .restaurantName) ?? ""
        dateTime         = try c.decode(Date.self, forKey: .dateTime)
        numberOfGuests   = try c.decode(Int.self, forKey: .numberOfGuests)
        status           = try c.decode(BookingStatus.self, forKey: .status)
        specialRequests  = try c.decodeIfPresent(String.self, forKey: .specialRequests)
        declineMessage   = try c.decodeIfPresent(String.self, forKey: .declineMessage)
        diner            = try c.decodeIfPresent(BookingDiner.self, forKey: .diner)
        createdAt        = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        modifiedAt       = try? c.decode(Date.self, forKey: .modifiedAt)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        userId: String,
        restaurantId: String,
        restaurantName: String,
        dateTime: Date,
        numberOfGuests: Int,
        status: BookingStatus = .pending,
        specialRequests: String? = nil,
        declineMessage: String? = nil,
        diner: BookingDiner? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.restaurantId = restaurantId
        self.restaurantName = restaurantName
        self.dateTime = dateTime
        self.numberOfGuests = numberOfGuests
        self.status = status
        self.specialRequests = specialRequests
        self.declineMessage = declineMessage
        self.diner = diner
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Booking Diner

/// Contact information for the diner, returned when restaurant owners
/// fetch their bookings via GET /API/Bookings/restaurant/:id
struct BookingDiner: Codable, Hashable, Sendable {
    let displayName: String?
    let email: String?
    let phoneNumber: String?
}

// MARK: - Request Models

/// Request body for POST /API/Bookings
struct CreateBookingRequest: Codable, Sendable {
    let restaurantId: String
    let restaurantName: String
    let dateTime: Date
    let numberOfGuests: Int
    let specialRequests: String?
}

/// Request body for PUT /API/Bookings/:id
struct UpdateBookingRequest: Codable, Sendable {
    let status: String?
    let declineMessage: String?
    let dateTime: Date?
    let numberOfGuests: Int?
    let specialRequests: String?

    init(
        status: String? = nil,
        declineMessage: String? = nil,
        dateTime: Date? = nil,
        numberOfGuests: Int? = nil,
        specialRequests: String? = nil
    ) {
        self.status = status
        self.declineMessage = declineMessage
        self.dateTime = dateTime
        self.numberOfGuests = numberOfGuests
        self.specialRequests = specialRequests
    }
}

// MARK: - Response Models

/// Response wrapper for booking list API calls
/// The API returns { "count": N, "data": [...] }
struct BookingListResponse: Codable, Sendable {
    let bookings: [Booking]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case bookings   = "data"
        case totalCount = "count"
    }
}

/// Response for single booking creation
/// The API returns { "id": "...", "message": "..." }
struct CreateBookingResponse: Codable, Sendable {
    let id: String
    let message: String?
}
