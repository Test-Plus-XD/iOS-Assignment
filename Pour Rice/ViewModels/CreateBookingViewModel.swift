//
//  CreateBookingViewModel.swift
//  Pour Rice
//
//  ViewModel for the booking creation form
//  Handles validation and submission of new table reservations
//

import Foundation

/// ViewModel for CreateBookingView — manages booking form state and submission
@MainActor @Observable
final class CreateBookingViewModel {

    // MARK: - Form State

    /// Selected reservation date and time (defaults to tomorrow at 19:00)
    var selectedDate: Date = {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 19
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }()

    /// Number of guests (1–20)
    var numberOfGuests: Int = 2

    /// Special requests from the diner
    var specialRequests: String = ""

    // MARK: - State

    /// Whether the booking is being submitted
    private(set) var isSubmitting = false

    /// Whether the booking was successfully created
    private(set) var didCreate = false

    /// Current error, if any
    var error: Error?

    // MARK: - Validation

    /// The earliest selectable date (tomorrow)
    var minimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    /// Whether the form is valid for submission
    var isValid: Bool {
        selectedDate > Date() && numberOfGuests >= 1 && numberOfGuests <= 20
    }

    // MARK: - Actions

    /// Creates a new booking for the given restaurant.
    func createBooking(restaurantId: String, restaurantName: String, service: BookingService) async {
        guard isValid else { return }

        isSubmitting = true
        error = nil

        do {
            let request = CreateBookingRequest(
                restaurantId: restaurantId,
                restaurantName: restaurantName,
                dateTime: selectedDate,
                numberOfGuests: numberOfGuests,
                specialRequests: specialRequests.isEmpty ? nil : specialRequests
            )

            _ = try await service.createBooking(request)
            didCreate = true
        } catch {
            self.error = error
            print("❌ CreateBookingVM: Failed to create booking: \(error.localizedDescription)")
        }

        isSubmitting = false
    }
}
