//
//  StoreView.swift
//  Pour Rice
//
//  Dashboard for restaurant owners
//  Shows restaurant info, stats, and quick actions for management
//

import SwiftUI

/// Restaurant owner dashboard with stats and management actions
struct StoreView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel = StoreViewModel()

    /// Controls whether the QR code sheet is presented.
    /// Declared here so dashboardContent can read it via a closure capture.
    @State private var showingQRCode = false

    // MARK: - Body

    var body: some View {
        Group {
            if let restaurantId = authService.currentUser?.restaurantId {
                dashboardContent(restaurantId: restaurantId)
            } else {
                ClaimRestaurantView()
            }
        }
        .navigationTitle("store_title")
        .toast(message: viewModel.toastMessage, style: viewModel.toastStyle, isPresented: Binding(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        ))
    }

    // MARK: - Dashboard

    @ViewBuilder
    private func dashboardContent(restaurantId: String) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Restaurant header card
                if let restaurant = viewModel.restaurant {
                    restaurantHeader(restaurant)
                }

                // Stats row
                statsRow

                // Quick actions grid
                quickActionsGrid

                // Pending bookings preview
                if !viewModel.pendingBookings.isEmpty {
                    pendingBookingsSection
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadDashboard(
                restaurantId: restaurantId,
                storeService: services.storeService,
                bookingService: services.bookingService,
                menuService: services.menuService
            )
        }
        .refreshable {
            await viewModel.refresh()
        }
        .overlay {
            if viewModel.isLoading && viewModel.restaurant == nil {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .errorAlert(error: $viewModel.error)
        // QR code sheet — presented as a sheet (not full-screen) because it is
        // informational content, not a camera feed. Matches the Android app's
        // dialog-style QR display (full-screen card in store_page.dart).
        //
        // The sheet is intentionally NOT tied to StoreDestination push navigation:
        //   - RestaurantQRView is a modal presentation, not a push-navigation destination
        //   - Putting it in StoreDestination would incorrectly add it to the nav stack history
        .sheet(isPresented: $showingQRCode) {
            // guard: viewModel.restaurant should always be non-nil here because
            // the QR button is only visible inside dashboardContent(restaurantId:),
            // which is only rendered after loadDashboard() completes successfully.
            if let restaurant = viewModel.restaurant {
                RestaurantQRView(restaurant: restaurant)
            }
        }
    }

    // MARK: - Restaurant Header

    private func restaurantHeader(_ restaurant: Restaurant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name.localised)
                        .font(.title2)
                        .fontWeight(.bold)

                    if !restaurant.description.localised.isEmpty {
                        Text(restaurant.description.localised)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "storefront.fill")
                    .font(.title)
                    .foregroundStyle(.accent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "store_stat_today",
                value: "\(viewModel.todayBookingsCount)",
                icon: "calendar",
                colour: .blue
            )
            StatCard(
                title: "store_stat_pending",
                value: "\(viewModel.pendingCount)",
                icon: "clock",
                colour: .orange
            )
            StatCard(
                title: "store_stat_total",
                value: "\(viewModel.totalCount)",
                icon: "number",
                colour: .green
            )
        }
    }

    // MARK: - Quick Actions

    private var quickActionsGrid: some View {
        // 2-column flexible grid.
        // With 5 items, SwiftUI fills rows left-to-right: [Manage Menu | Manage Bookings]
        //                                                   [View Reviews | Edit Info   ]
        //                                                   [QR Code      |             ]
        // The lone 5th card sits left-aligned — a common iOS pattern (see App Store, Settings).
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NavigationLink(value: StoreDestination.manageMenu) {
                QuickActionCard(title: "store_manage_menu", icon: "menucard", colour: .purple)
            }

            NavigationLink(value: StoreDestination.bookings) {
                QuickActionCard(title: "store_manage_bookings", icon: "calendar.badge.clock", colour: .orange)
            }

            NavigationLink(value: StoreDestination.reviews) {
                QuickActionCard(title: "store_view_reviews", icon: "star.bubble", colour: .yellow)
            }

            NavigationLink(value: StoreDestination.editInfo) {
                QuickActionCard(title: "store_edit_info", icon: "pencil.circle", colour: .blue)
            }

            // QR Code card — opens a sheet showing the restaurant's menu QR code.
            //
            // WHY a Button instead of NavigationLink(value: StoreDestination):
            //   NavigationLink pushes onto the navigation stack (back button appears).
            //   The QR sheet is a modal — it should dismiss with a swipe or "Done" button.
            //   A Button that sets showingQRCode = true is the correct presentation trigger.
            //
            // ANDROID EQUIVALENT:
            //   MenuQRGenerator widget embedded inline in the Quick Actions section
            //   of lib/pages/store_page.dart (not a separate navigation route).
            Button {
                showingQRCode = true
            } label: {
                QuickActionCard(title: "store_qr_code", icon: "qrcode", colour: .green)
            }
            // Remove the default Button tap highlight — QuickActionCard has its own background
            .buttonStyle(.plain)
        }
    }

    // MARK: - Pending Bookings Preview

    private var pendingBookingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("store_pending_bookings")
                    .font(.headline)
                Spacer()
                NavigationLink(value: StoreDestination.bookings) {
                    Text("store_see_all")
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                }
            }

            ForEach(viewModel.pendingBookings.prefix(3)) { booking in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(booking.diner?.displayName ?? "store_unknown_diner")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(booking.formattedDate) · \(booking.numberOfGuests) \("booking_guests_label")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button {
                        Task { await viewModel.acceptBooking(id: booking.id) }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Button {
                        Task { await viewModel.declineBooking(id: booking.id, reason: nil) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Store Navigation Destinations

/// Type-safe navigation destinations for the Store tab
enum StoreDestination: Hashable {
    case manageMenu
    case bookings
    case reviews
    case editInfo
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let colour: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(colour)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Action Card

private struct QuickActionCard: View {
    let title: LocalizedStringKey
    let icon: String
    let colour: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(colour)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
