//
//  RestaurantView.swift
//  Pour Rice
//
//  Full restaurant detail screen showing image carousel, info, reviews, and menu preview
//  Provides navigation to full menu and review submission
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is equivalent to a Flutter StatefulWidget detail screen.
//  Key concepts:
//
//  ScrollView { LazyVStack } → SingleChildScrollView + Column (lazy)
//  .navigationDestination(for:) → type-safe route registration
//  .sheet(isPresented:) → showModalBottomSheet()
//  TabView with .page style → PageView in Flutter
//  ============================================================================
//

import SwiftUI
import MapKit
import PhotosUI

// MARK: - Restaurant View

/// Full detail screen for a single restaurant
///
/// Shows:
/// - Image carousel (swipeable)
/// - Name, cuisine, rating, price range, open status
/// - Opening hours
/// - Contact information (phone, website)
/// - Menu preview (first 6 items)
/// - Customer reviews
/// - Review submission button (for logged-in users)
struct RestaurantView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - Input

    /// Restaurant passed from navigation (avoids extra API call for basic data)
    let restaurant: Restaurant

    /// When true, the restaurant page pushes its full menu after appearing.
    /// Used by QR/deep-link routes so Back from Menu lands on this restaurant.
    private let opensMenuOnAppear: Bool

    // MARK: - State

    @State private var viewModel: RestaurantViewModel?
    @State private var showingCreateBooking = false
    @State private var showingDirections = false
    @State private var showingAllMenu = false
    @State private var didOpenInitialMenu = false

    @AppStorage("preferredLanguage") private var preferredLanguage: String = "en"
    private var isTC: Bool { preferredLanguage == "zh-Hant" }

    // MARK: - Init

    init(restaurant: Restaurant, opensMenuOnAppear: Bool = false) {
        self.restaurant = restaurant
        self.opensMenuOnAppear = opensMenuOnAppear
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView(message: "restaurant_loading")
            }
        }
        // Hide default navigation title — we use the large hero image instead
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = RestaurantViewModel(
                    restaurant: restaurant,
                    restaurantService: services.restaurantService,
                    reviewService: services.reviewService,
                    menuService: services.menuService,
                    authService: services.authService
                )
                viewModel = vm
                await vm.loadData(restaurantId: restaurant.id)
            }
        }
        .onAppear(perform: openInitialMenuIfNeeded)
        .navigationDestination(isPresented: $showingAllMenu) {
            let current = viewModel?.restaurant ?? restaurant
            MenuView(restaurantId: current.id, restaurantName: current.name.localised)
        }
        .toast(message: viewModel?.toastMessage ?? "", style: viewModel?.toastStyle ?? .success, isPresented: Binding(
            get: { viewModel?.showToast ?? false },
            set: { viewModel?.showToast = $0 }
        ))
    }

    // MARK: - Main Content

    @ViewBuilder
    private func content(vm: RestaurantViewModel) -> some View {
        let current = vm.restaurant ?? restaurant

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {

                // ─── Hero Image ──────────────────────────────────────────────
                heroSection(restaurant: current)

                // ─── Core Info (name, rating, price, open status) ──────────
                infoSection(restaurant: current)
                    .padding(.horizontal, Constants.UI.spacingMedium)
                    .padding(.top, Constants.UI.spacingMedium)

                Divider().padding(.vertical, Constants.UI.spacingMedium)

                // ─── Opening Hours ──────────────────────────────────────────
                openingHoursSection(restaurant: current)
                    .padding(.horizontal, Constants.UI.spacingMedium)

                Divider().padding(.vertical, Constants.UI.spacingMedium)

                // ─── Contact Info ───────────────────────────────────────────
                contactSection(restaurant: current)
                    .padding(.horizontal, Constants.UI.spacingMedium)

                Divider().padding(.vertical, Constants.UI.spacingMedium)

                // ─── Location Map ──────────────────────────────────────────
                locationSection(restaurant: current)
                    .padding(.horizontal, Constants.UI.spacingMedium)

                Divider().padding(.vertical, Constants.UI.spacingMedium)

                // ─── Menu Section ──────────────────────────────────────────
                if !vm.menuPreview.isEmpty {
                    menuSection(items: vm.menuPreview, restaurantId: current.id, restaurantName: current.name.localised)
                        .padding(.horizontal, Constants.UI.spacingMedium)

                    Divider().padding(.vertical, Constants.UI.spacingMedium)
                }

                // ─── Reviews Section ────────────────────────────────────────
                reviewsSection(vm: vm, restaurantId: current.id)
                    .padding(.horizontal, Constants.UI.spacingMedium)

                Divider().padding(.vertical, Constants.UI.spacingMedium)

                // ─── Action Buttons (Book / Chat / AI) ──────────────────────
                actionsSection(restaurant: current)
                    .padding(.horizontal, Constants.UI.spacingMedium)

                // Bottom padding
                Color.clear.frame(height: Constants.UI.spacingExtraLarge)
            }
        }
        .refreshable {
            await vm.refresh(restaurantId: restaurant.id)
        }
        // Review submission sheet
        .sheet(isPresented: Binding(
            get: { vm.showingReviewSheet },
            set: { vm.showingReviewSheet = $0 }
        )) {
            ReviewSubmissionView(restaurantId: restaurant.id, viewModel: vm)
        }
        // Create booking sheet
        .sheet(isPresented: $showingCreateBooking) {
            CreateBookingView(
                restaurantId: restaurant.id,
                restaurantName: restaurant.name.localised
            )
        }
        // Directions sheet
        .sheet(isPresented: $showingDirections) {
            DirectionsView(
                restaurant: restaurant,
                userLocation: services.locationService.currentLocation
            )
        }
    }

    /// Opens the menu once after this restaurant page becomes active.
    private func openInitialMenuIfNeeded() {
        guard opensMenuOnAppear, !didOpenInitialMenu else { return }
        didOpenInitialMenu = true

        Task { @MainActor in
            await Task.yield()
            showingAllMenu = true
        }
    }

    // MARK: - Action Buttons

    /// "Book a Table", "Chat with Restaurant", "Ask AI" action row
    @ViewBuilder
    private func actionsSection(restaurant: Restaurant) -> some View {
        let isAuthenticated = authService.isAuthenticated
        let isDiner = isAuthenticated && authService.currentUser?.userType != .restaurant

        VStack(spacing: 10) {
            // Book a Table — diner only
            if isDiner {
                Button {
                    showingCreateBooking = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("restaurant_action_book", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            HStack(spacing: 10) {
                // Chat with Restaurant — authenticated only
                if isAuthenticated {
                    // Creates/opens room with pattern: restaurant-{id}
                    let chatRoom = ChatRoom.placeholder(
                        roomId: "restaurant-\(restaurant.id)",
                        name: restaurant.name.localised
                    )
                    NavigationLink(value: chatRoom) {
                        Label("restaurant_action_chat", systemImage: "bubble.left.and.text.bubble.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                // Ask AI — always accessible (including guests)
                NavigationLink(value: GeminiNavigation(restaurant: restaurant)) {
                    Label("restaurant_action_ai", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Hero Section

    /// Swipeable image carousel at the top of the screen
    @ViewBuilder
    private func heroSection(restaurant: Restaurant) -> some View {
        // TabView with .page style = swipeable carousel (like PageView in Flutter)
        TabView {
            if restaurant.imageURLs.isEmpty {
                // Placeholder if no images
                RestaurantCardImage(urlString: nil)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
            } else {
                ForEach(restaurant.imageURLs, id: \.self) { urlString in
                    AsyncImageView(
                        url: urlString,
                        contentMode: .fill,
                        aspectRatio: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: 260)
                    .clipped()
                }
            }
        }
        .frame(height: 260)
        // .page style gives horizontal swipe between images with dot indicators
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: - Star Rating Helper

    /// Returns the SF Symbol name for a star position given a rating.
    /// Rounds the rating to the nearest 0.5 before determining full/half/empty.
    /// e.g. rating=3.7 → rounded=3.5 → positions 0,1,2 are "star.fill", position 3 is "star.leadinghalf.filled", position 4 is "star"
    private func starSymbol(for index: Int, rating: Double) -> String {
        let rounded = (rating * 2).rounded() / 2
        let full = Int(rounded)
        let hasHalf = rounded - Double(full) > 0
        if index < full { return "star.fill" }
        if index == full && hasHalf { return "star.leadinghalf.filled" }
        return "star"
    }

    // MARK: - Info Section

    /// Restaurant name, cuisine, rating, price, and open status
    @ViewBuilder
    private func infoSection(restaurant: Restaurant) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            // Restaurant name (bilingual)
            Text(restaurant.name.localised)
                .font(.title2)
                .fontWeight(.bold)

            // Cuisine + District
            Text("\(restaurant.cuisine.localised) · \(restaurant.district.localised)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Rating, price range, open status row
            HStack(spacing: Constants.UI.spacingMedium) {

                // Half-star row + numeric rating + review count
                HStack(spacing: 6) {
                    if restaurant.rating <= 0 {
                        Text("New")
                            .font(.caption)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color.newBadge,
                                in: Capsule()
                            )
                    } else {
                        HStack(spacing: 4) {
                            HStack(spacing: 1) {
                                ForEach(0..<5, id: \.self) { i in
                                    Image(systemName: starSymbol(for: i, rating: restaurant.rating))
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }
                            Text(restaurant.ratingDisplay)
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                        }
                    }
                    Text("(\(restaurant.reviewCount))")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(
                    restaurant.rating <= 0
                        ? "New restaurant, \(restaurant.reviewCount) reviews"
                        : "\(restaurant.ratingDisplay) out of 5 stars, \(restaurant.reviewCount) reviews"
                )

                Spacer()

                // Price range (only if set)
                if !restaurant.priceRangeDisplay.isEmpty {
                    Text(restaurant.priceRangeDisplay)
                        .fontWeight(.medium)
                }

                // Open/Closed badge
                Text(restaurant.isOpenNow ? "open_now" : "closed")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        restaurant.isOpenNow ? Color.green.opacity(0.15) : Color.red.opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(restaurant.isOpenNow ? .green : .red)
            }
        }
    }

    // MARK: - Opening Hours Section

    @ViewBuilder
    private func openingHoursSection(restaurant: Restaurant) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            Text("restaurant_hours_title")
                .font(.headline)

            // Show each day's hours
            ForEach(restaurant.openingHours, id: \.day) { hours in
                HStack {
                    Text(isTC
                         ? (LocalDataLoader.loadWeekdays().first { $0.en == hours.day }?.tc ?? hours.day)
                         : hours.day)
                        .frame(width: 100, alignment: .leading)
                        .foregroundStyle(hours.day == currentDayName ? .primary : .secondary)
                        .fontWeight(hours.day == currentDayName ? .semibold : .regular)

                    Spacer()

                    Text(hours.displayText)
                        .foregroundStyle(hours.isClosed ? .secondary : .primary)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Contact Section

    @ViewBuilder
    private func contactSection(restaurant: Restaurant) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            Text("restaurant_contact_title")
                .font(.headline)

            // Phone — tappable to open dialler
            if !restaurant.phoneNumber.isEmpty {
                Link(destination: URL(string: "tel:\(restaurant.phoneNumber.filter { !$0.isWhitespace })")!) {
                    Label(restaurant.phoneNumber, systemImage: "phone")
                        .font(.subheadline)
                }
            }

            // Email — tappable to open mail app
            if let email = restaurant.email {
                Link(destination: URL(string: "mailto:\(email)")!) {
                    Label(email, systemImage: "envelope")
                        .font(.subheadline)
                }
            }

            // Website — tappable to open Safari
            if let website = restaurant.website,
               let url = URL(string: website) {
                Link(destination: url) {
                    Label(website, systemImage: "globe")
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }

            // Seats
            if restaurant.seats > 0 {
                Label {
                    Text("\(restaurant.seats) \(Text("restaurant_seats"))")
                } icon: {
                    Image(systemName: "chair")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Location Section

    /// Embedded map showing the restaurant's location with a "Get Directions" button
    @ViewBuilder
    private func locationSection(restaurant: Restaurant) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            Text("restaurant_location_title")
                .font(.headline)

            // Embedded map with restaurant pin
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: restaurant.location.latitude,
                    longitude: restaurant.location.longitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: Constants.Map.detailSpanDelta,
                    longitudeDelta: Constants.Map.detailSpanDelta
                )
            ))) {
                Marker(
                    restaurant.name.localised,
                    systemImage: "fork.knife",
                    coordinate: CLLocationCoordinate2D(
                        latitude: restaurant.location.latitude,
                        longitude: restaurant.location.longitude
                    )
                )
                .tint(.accent)
            }
            .frame(height: Constants.Map.detailMapHeight)
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))

            // Address
            Text(restaurant.address.localised)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Get Directions button
            Button {
                showingDirections = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("restaurant_get_directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Menu Section

    /// Vertical menu section showing up to 10 items (~3 visible at a time) + full menu push
    @ViewBuilder
    private func menuSection(items: [Menu], restaurantId: String, restaurantName: String) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            HStack {
                Text("restaurant_menu_preview_title")
                    .font(.headline)
                Spacer()
                Button {
                    showingAllMenu = true
                } label: {
                    Text("restaurant_see_full_menu")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }

            // Vertical scroll showing ~3 items at a time; up to 10 items displayed
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(items.prefix(10)) { item in
                        MenuItemListRow(item: item)
                    }
                }
            }
            // Height sized for ~3 rows (~88pt each)
            .frame(height: 276)
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))
        }
    }

    // MARK: - Reviews Section

    @ViewBuilder
    private func reviewsSection(vm: RestaurantViewModel, restaurantId: String) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            HStack {
                Text("restaurant_reviews_title")
                    .font(.headline)

                Spacer()

                Text("\(vm.reviews.count) \(Text("restaurant_reviews_count"))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Write-a-review button (authenticated users who haven't reviewed)
            if !vm.userHasReviewed && authService.isAuthenticated {
                Button {
                    vm.showingReviewSheet = true
                } label: {
                    Label("review_write_button", systemImage: "star.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .hapticFeedback(style: .medium)
            }

            if vm.isLoading {
                InlineLoadingView(label: "restaurant_loading_reviews")
            } else if vm.reviews.isEmpty {
                EmptyStateView.noReviews()
                    .frame(height: 150)
            } else {
                ForEach(vm.reviews.prefix(5)) { review in
                    ReviewRowView(review: review)
                    if review.id != vm.reviews.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Returns the current day name in English (e.g. "Monday"), used to highlight
    /// today's row in the opening hours section.
    ///
    /// Calendar weekday: 1=Sun, 2=Mon, …, 7=Sat (Sunday-first).
    /// weekdays.json order: 0=Mon, 1=Tue, …, 6=Sun (Monday-first).
    /// Index formula: (weekday + 5) % 7 — maps 1→6, 2→0, 3→1, …, 7→5.
    private var currentDayName: String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let index = (weekday + 5) % 7
        let days = LocalDataLoader.loadWeekdays()
        return days.isEmpty ? "" : days[index].en
    }
}

// MARK: - Menu Item List Row

/// Horizontal card row for a single menu item in the vertical scroll preview
private struct MenuItemListRow: View {

    let item: Menu

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            MenuItemImage(urlString: item.imageURL)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name.localised)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if !item.description.localised.isEmpty {
                    Text(item.description.localised)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            Text(item.priceDisplay)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Review Row View

/// Single review row showing reviewer, rating, date, and comment
struct ReviewRowView: View {

    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            HStack {
                // Reviewer name and avatar placeholder
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Relative date (from Date+Extensions)
                    Text(review.createdAt.timeAgoDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(star <= review.rating ? .orange : .secondary)
                    }
                }
            }

            // Review comment
            Text(review.comment)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(4)
        }
        .padding(.vertical, Constants.UI.spacingSmall)
    }
}

// MARK: - Review Submission View

/// Modal sheet for submitting a new review
struct ReviewSubmissionView: View {

    // MARK: - Properties

    let restaurantId: String
    let viewModel: RestaurantViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    @State private var rating = 3
    @State private var comment = ""
    @State private var isSubmitting = false

    /// Selected photo from the Photos library
    @State private var selectedPhotoItem: PhotosPickerItem?
    /// Local preview of the selected photo
    @State private var selectedPhotoImage: Image?
    /// Raw data of the selected photo (used for upload)
    @State private var selectedPhotoData: Data?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Star rating picker
                Section("review_rating_label") {
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(star <= rating ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text("\(rating)/5")
                            .foregroundStyle(.secondary)
                    }
                }

                // Written comment
                Section("review_comment_label") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 100)
                }

                // Optional photo attachment
                Section("review_photo_label") {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if let image = selectedPhotoImage {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Label("review_photo_add", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task { await loadSelectedPhoto(newItem) }
                    }

                    if selectedPhotoImage != nil {
                        Button(role: .destructive) {
                            selectedPhotoItem = nil
                            selectedPhotoImage = nil
                            selectedPhotoData = nil
                        } label: {
                            Label("review_photo_remove", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("review_sheet_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("review_submit_button") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || comment.count < 10)
                }
            }
            .overlay {
                if isSubmitting { LoadingView() }
            }
        }
    }

    // MARK: - Photo Loading

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                selectedPhotoData = data
                if let uiImage = UIImage(data: data) {
                    selectedPhotoImage = Image(uiImage: uiImage)
                }
            }
        } catch {
            print("⚠️ ReviewSubmissionView: Failed to load photo: \(error)")
        }
    }

    // MARK: - Submit

    private func submit() async {
        isSubmitting = true

        // Upload photo first if one was selected, then submit the review.
        var uploadedImageURL: String?
        if let photoData = selectedPhotoData {
            do {
                let token = try await authService.getIDToken()
                uploadedImageURL = try await services.imageUploadService.uploadImage(
                    photoData,
                    mimeType: "image/jpeg",
                    filename: "review_\(UUID().uuidString).jpg",
                    folder: "Reviews",
                    authToken: token
                )
            } catch {
                // Non-fatal: submit review without image if upload fails
                print("⚠️ ReviewSubmissionView: Image upload failed: \(error)")
            }
        }

        _ = await viewModel.submitReview(
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            imageURL: uploadedImageURL
        )

        isSubmitting = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        // Preview with a mock restaurant — in real app, passed via NavigationLink
        Text("Restaurant View Preview")
            .navigationTitle("Restaurant")
    }
    .environment(\.services, Services())
}
