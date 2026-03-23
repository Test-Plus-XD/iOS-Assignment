//
//  BookingsViewModel.swift
//  Pour Rice
//
//  ViewModel for the diner's bookings list
//  Manages fetching, filtering, and cancellation of bookings
//

import Foundation

/// ViewModel for the BookingsView — manages the diner's booking list
@MainActor @Observable
final class BookingsViewModel {

    // MARK: - Properties

    /// All bookings fetched from the API
    private(set) var bookings: [Booking] = []

    /// Whether a fetch is in progress
    private(set) var isLoading = false

    /// Current error, if any
    var error: Error?

    /// Currently selected filter tab
    var selectedTab: BookingTab = .all

    // MARK: - Filter Tabs

    enum BookingTab: String, CaseIterable, Identifiable {
        case all
        case upcoming
        case past

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all:      return String(localized: "bookings_tab_all", bundle: L10n.bundle)
            case .upcoming: return String(localized: "bookings_tab_upcoming", bundle: L10n.bundle)
            case .past:     return String(localized: "bookings_tab_past", bundle: L10n.bundle)
            }
        }
    }

    // MARK: - Computed Properties

    /// Bookings filtered by the selected tab
    var filteredBookings: [Booking] {
        switch selectedTab {
        case .all:
            return bookings.sorted { $0.dateTime > $1.dateTime }
        case .upcoming:
            return bookings.filter { $0.isUpcoming }.sorted { $0.dateTime < $1.dateTime }
        case .past:
            return bookings.filter { $0.isPast }.sorted { $0.dateTime > $1.dateTime }
        }
    }

    // MARK: - Dependencies

    private var bookingService: BookingService?

    // MARK: - Actions

    /// Loads all bookings for the authenticated diner.
    func loadBookings(service: BookingService) async {
        self.bookingService = service
        isLoading = true
        error = nil

        do {
            bookings = try await service.fetchBookings()
        } catch {
            self.error = error
            print("❌ BookingsViewModel: Failed to load bookings: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Refreshes the booking list.
    func refresh() async {
        guard let service = bookingService else { return }
        await loadBookings(service: service)
    }

    /// Cancels a pending booking.
    func cancelBooking(id: String) async {
        guard let service = bookingService else { return }

        do {
            try await service.cancelBooking(id: id)
            // Update local state
            if let index = bookings.firstIndex(where: { $0.id == id }) {
                let old = bookings[index]
                bookings[index] = Booking(
                    id: old.id,
                    userId: old.userId,
                    restaurantId: old.restaurantId,
                    restaurantName: old.restaurantName,
                    dateTime: old.dateTime,
                    numberOfGuests: old.numberOfGuests,
                    status: .cancelled,
                    specialRequests: old.specialRequests,
                    declineMessage: old.declineMessage,
                    diner: old.diner,
                    createdAt: old.createdAt,
                    modifiedAt: Date()
                )
            }
        } catch {
            self.error = error
            print("❌ BookingsViewModel: Failed to cancel booking: \(error.localizedDescription)")
        }
    }
}
