//
//  StoreBookingsView.swift
//  Pour Rice
//
//  Booking management view for restaurant owners
//  Allows accepting, declining, and completing bookings
//

import SwiftUI

/// Restaurant owner's booking management view
struct StoreBookingsView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel = StoreViewModel()
    @State private var selectedTab: Tab = .pending
    @State private var declineBookingId: String?
    @State private var declineReason = ""
    @State private var showDeclineSheet = false

    enum Tab: String, CaseIterable, Identifiable {
        case pending, accepted, all
        var id: String { rawValue }

        var label: String {
            switch self {
            case .pending:  return "store_bookings_pending"
            case .accepted: return "store_bookings_accepted"
            case .all:      return "store_bookings_all"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            let filtered = filteredBookings
            if filtered.isEmpty {
                ContentUnavailableView(
                    "store_bookings_empty",
                    systemImage: "calendar.badge.checkmark"
                )
            } else {
                List(filtered) { booking in
                    storeBookingRow(booking)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("store_manage_bookings")
        .task {
            if let restaurantId = authService.currentUser?.restaurantId {
                await viewModel.loadDashboard(
                    restaurantId: restaurantId,
                    storeService: services.storeService,
                    bookingService: services.bookingService,
                    menuService: services.menuService
                )
            }
        }
        .sheet(isPresented: $showDeclineSheet) {
            declineSheet
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .toast(message: viewModel.toastMessage, style: viewModel.toastStyle, isPresented: Binding(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        ))
    }

    // MARK: - Filtered Bookings

    private var filteredBookings: [Booking] {
        switch selectedTab {
        case .pending:  return viewModel.pendingBookings
        case .accepted: return viewModel.acceptedBookings
        case .all:      return viewModel.bookings.sorted { $0.dateTime > $1.dateTime }
        }
    }

    // MARK: - Booking Row

    private func storeBookingRow(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.diner?.displayName ?? "store_unknown_diner")
                        .font(.headline)
                    if let email = booking.diner?.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                StatusBadgeView(status: booking.status)
            }

            HStack(spacing: 16) {
                Label(booking.formattedDate, systemImage: "calendar")
                Label(booking.formattedTime, systemImage: "clock")
                Label("\(booking.numberOfGuests)", systemImage: "person.2")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let requests = booking.specialRequests, !requests.isEmpty {
                Text(requests)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Action buttons
            if booking.status == .pending {
                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.acceptBooking(id: booking.id) }
                    } label: {
                        Label("store_accept", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)

                    Button {
                        declineBookingId = booking.id
                        declineReason = ""
                        showDeclineSheet = true
                    } label: {
                        Label("store_decline", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .font(.subheadline)
            } else if booking.status == .accepted {
                Button {
                    Task { await viewModel.completeBooking(id: booking.id) }
                } label: {
                    Label("store_complete", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Decline Sheet

    private var declineSheet: some View {
        NavigationStack {
            Form {
                Section("store_decline_reason_title") {
                    TextField("store_decline_reason_placeholder", text: $declineReason, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(role: .destructive) {
                        if let id = declineBookingId {
                            Task {
                                await viewModel.declineBooking(
                                    id: id,
                                    reason: declineReason.isEmpty ? nil : declineReason
                                )
                            }
                        }
                        showDeclineSheet = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("store_decline_confirm")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("store_decline_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        showDeclineSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
