//
//  BookingsView.swift
//  Pour Rice
//
//  Main bookings tab for diners
//  Shows all/upcoming/past reservations with pull-to-refresh
//

import SwiftUI

/// Tab-level view displaying the diner's booking list with filter tabs
struct BookingsView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel = BookingsViewModel()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $viewModel.selectedTab) {
                ForEach(BookingsViewModel.BookingTab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            if viewModel.isLoading && viewModel.bookings.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if viewModel.filteredBookings.isEmpty {
                emptyState
            } else {
                bookingsList
            }
        }
        .navigationTitle("bookings_title")
        .task {
            await viewModel.loadBookings(service: services.bookingService)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .errorAlert(error: $viewModel.error)
    }

    // MARK: - Subviews

    private var bookingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredBookings) { booking in
                    BookingCardView(
                        booking: booking,
                        onCancel: {
                            Task { await viewModel.cancelBooking(id: booking.id) }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text(emptyTitle)
            } icon: {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
            }
        } description: {
            Text(emptyDescription)
        }
    }

    private var emptyTitle: LocalizedStringKey {
        switch viewModel.selectedTab {
        case .all:      return "bookings_empty_all"
        case .upcoming: return "bookings_empty_upcoming"
        case .past:     return "bookings_empty_past"
        }
    }

    private var emptyDescription: LocalizedStringKey {
        "bookings_empty_description"
    }
}
