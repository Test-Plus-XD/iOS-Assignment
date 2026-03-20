//
//  CreateBookingView.swift
//  Pour Rice
//
//  Sheet for creating a new table reservation
//  Presented from RestaurantView with date picker, guest count, and special requests
//

import SwiftUI

/// Booking creation form presented as a sheet
struct CreateBookingView: View {

    // MARK: - Parameters

    let restaurantId: String
    let restaurantName: String

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services

    // MARK: - State

    @State private var viewModel = CreateBookingViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Restaurant info
                Section {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.accent)
                        Text(restaurantName)
                            .fontWeight(.medium)
                    }
                }

                // Date & time
                Section(String(localized: "booking_date_time")) {
                    DatePicker(
                        String(localized: "booking_date_label"),
                        selection: $viewModel.selectedDate,
                        in: viewModel.minimumDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                // Number of guests
                Section(String(localized: "booking_guests_section")) {
                    Stepper(
                        "\(viewModel.numberOfGuests) \(String(localized: "booking_guests_label"))",
                        value: $viewModel.numberOfGuests,
                        in: 1...20
                    )
                }

                // Special requests
                Section(String(localized: "booking_requests_section")) {
                    TextField(
                        String(localized: "booking_requests_placeholder"),
                        text: $viewModel.specialRequests,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                // Submit
                Section {
                    Button {
                        Task {
                            await viewModel.createBooking(
                                restaurantId: restaurantId,
                                restaurantName: restaurantName,
                                service: services.bookingService
                            )
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSubmitting {
                                ProgressView()
                            } else {
                                Label(String(localized: "booking_submit"), systemImage: "checkmark.circle.fill")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .navigationTitle(String(localized: "booking_create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) {
                        dismiss()
                    }
                }
            }
            .onChange(of: viewModel.didCreate) { _, didCreate in
                if didCreate {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    dismiss()
                }
            }
            .errorAlert(error: $viewModel.error)
        }
    }
}
