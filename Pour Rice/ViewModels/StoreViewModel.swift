//
//  StoreViewModel.swift
//  Pour Rice
//
//  ViewModel for the restaurant owner's store dashboard
//  Manages restaurant info, bookings, menu items, and stats
//

import Foundation
import SwiftUI

/// ViewModel for StoreView — manages the restaurant owner dashboard
@MainActor @Observable
final class StoreViewModel {

    // MARK: - Properties

    /// The restaurant owned by the current user
    private(set) var restaurant: Restaurant?

    /// Incoming bookings for the restaurant
    private(set) var bookings: [Booking] = []

    /// Menu items for the restaurant
    private(set) var menuItems: [Menu] = []

    /// Whether data is loading
    private(set) var isLoading = false

    /// Current error
    var error: Error?

    // MARK: - Dependencies

    private var storeService: StoreService?
    private var bookingService: BookingService?
    private var menuService: MenuService?

    // MARK: - Computed Properties

    /// Today's bookings count
    var todayBookingsCount: Int {
        let calendar = Calendar.current
        return bookings.filter { calendar.isDateInToday($0.dateTime) }.count
    }

    /// Pending bookings count
    var pendingCount: Int {
        bookings.filter { $0.status == .pending }.count
    }

    /// Total bookings count
    var totalCount: Int { bookings.count }

    /// Pending bookings (for store bookings view)
    var pendingBookings: [Booking] {
        bookings.filter { $0.status == .pending }.sorted { $0.dateTime < $1.dateTime }
    }

    /// Accepted bookings
    var acceptedBookings: [Booking] {
        bookings.filter { $0.status == .accepted }.sorted { $0.dateTime < $1.dateTime }
    }

    // MARK: - Actions

    /// Loads the full dashboard: restaurant info, bookings, and menu.
    func loadDashboard(
        restaurantId: String,
        storeService: StoreService,
        bookingService: BookingService,
        menuService: MenuService
    ) async {
        self.storeService = storeService
        self.bookingService = bookingService
        self.menuService = menuService

        isLoading = true
        error = nil

        do {
            // Fetch in parallel
            async let restaurantResult = storeService.fetchRestaurant(id: restaurantId)
            async let bookingsResult = bookingService.fetchRestaurantBookings(restaurantId: restaurantId)
            async let menuResult = menuService.fetchMenuItems(restaurantId: restaurantId)

            restaurant = try await restaurantResult
            bookings = try await bookingsResult
            menuItems = try await menuResult
        } catch {
            self.error = error
            print("❌ StoreViewModel: Failed to load dashboard: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Refreshes all dashboard data.
    func refresh() async {
        guard let restaurant = restaurant,
              let storeService = storeService,
              let bookingService = bookingService,
              let menuService = menuService else { return }

        await loadDashboard(
            restaurantId: restaurant.id,
            storeService: storeService,
            bookingService: bookingService,
            menuService: menuService
        )
    }

    // MARK: - Booking Actions

    /// Accepts a pending booking.
    func acceptBooking(id: String) async {
        guard let service = bookingService else { return }
        do {
            try await service.acceptBooking(id: id)
            await refreshBookings()
        } catch {
            self.error = error
        }
    }

    /// Declines a pending booking with an optional reason.
    func declineBooking(id: String, reason: String?) async {
        guard let service = bookingService else { return }
        do {
            try await service.declineBooking(id: id, reason: reason)
            await refreshBookings()
        } catch {
            self.error = error
        }
    }

    /// Marks a booking as completed.
    func completeBooking(id: String) async {
        guard let service = bookingService else { return }
        do {
            try await service.completeBooking(id: id)
            await refreshBookings()
        } catch {
            self.error = error
        }
    }

    // MARK: - Menu Actions

    /// Creates a new menu item.
    func createMenuItem(_ request: CreateMenuItemRequest) async {
        guard let service = storeService else { return }
        do {
            try await service.createMenuItem(request)
            await refreshMenu()
        } catch {
            self.error = error
        }
    }

    /// Deletes a menu item.
    func deleteMenuItem(id: String) async {
        guard let service = storeService else { return }
        do {
            try await service.deleteMenuItem(id: id)
            menuItems.removeAll { $0.id == id }
        } catch {
            self.error = error
        }
    }

    // MARK: - Restaurant Info

    /// Updates restaurant information.
    func updateRestaurantInfo(request: UpdateRestaurantRequest) async {
        guard let restaurant = restaurant, let service = storeService else { return }
        do {
            try await service.updateRestaurant(id: restaurant.id, request: request)
            // Refresh to get updated data
            self.restaurant = try await service.fetchRestaurant(id: restaurant.id)
        } catch {
            self.error = error
        }
    }

    /// Uploads a restaurant image.
    func uploadImage(imageData: Data) async -> String? {
        guard let restaurant = restaurant, let service = storeService else { return nil }
        do {
            let url = try await service.uploadRestaurantImage(id: restaurant.id, imageData: imageData)
            return url
        } catch {
            self.error = error
            return nil
        }
    }

    // MARK: - Private

    private func refreshBookings() async {
        guard let restaurant = restaurant, let service = bookingService else { return }
        do {
            bookings = try await service.fetchRestaurantBookings(restaurantId: restaurant.id)
        } catch {
            self.error = error
        }
    }

    private func refreshMenu() async {
        guard let restaurant = restaurant, let service = menuService else { return }
        do {
            menuItems = try await service.fetchMenuItems(restaurantId: restaurant.id)
        } catch {
            self.error = error
        }
    }
}
