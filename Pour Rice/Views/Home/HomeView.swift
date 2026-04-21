//
//  HomeView.swift
//  Pour Rice
//
//  Home screen showing featured restaurant carousel and nearby restaurant list
//  Entry point for restaurant discovery with location-aware results
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is equivalent to a Flutter StatefulWidget with a ChangeNotifier.
//  Key iOS/SwiftUI differences:
//
//  @State → local state owned by this view
//  @Environment → dependency injection (like Provider/context.read())
//  NavigationLink → like Navigator.push() but declarative
//  .task { } → runs async code when view appears (like initState() + async)
//  .refreshable { } → pull-to-refresh (like RefreshIndicator in Flutter)
//  ScrollView + LazyVStack → like SingleChildScrollView + Column (lazy)
//  ============================================================================
//

import SwiftUI
import CoreLocation

// MARK: - Home View

/// Main home screen with featured restaurant carousel and nearby restaurant list
///
/// ARCHITECTURE:
/// HomeView reads from HomeViewModel (created via @State)
/// and delegates business logic to the ViewModel.
/// The view only handles presentation — no business logic lives here.
///
/// NAVIGATION:
/// Uses NavigationLink(value:) + .navigationDestination(for:) for type-safe navigation.
/// Tapping a restaurant pushes RestaurantView onto the NavigationStack.
struct HomeView: View {

    // MARK: - Environment

    /// App-wide services (auth, API, location, etc.)
    /// Injected by Pour_RiceApp.swift and passed through the view hierarchy
    @Environment(\.services) private var services

    // MARK: - State

    /// Tracks language changes to force BilingualText re-evaluation
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"

    /// ViewModel managing data and business logic for this screen
    ///
    /// WHAT IS @State:
    /// Declares local state owned by this view.
    /// When the value changes, SwiftUI rebuilds the view.
    ///
    /// WHY WE INITIALISE HERE:
    /// The ViewModel is created fresh when this view first appears.
    /// Services are injected via Environment, so we create the VM in .task{}
    @State private var viewModel: HomeViewModel?
    @State private var selectedAdRoute: HomeRoute?

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView(message: "home_loading")
            }
        }
        .navigationTitle("home_title")
        .navigationBarTitleDisplayMode(.large)
        // .task runs async code when this view appears on screen
        // Equivalent to initState() + async operation in Flutter
        // Cancelled automatically when view disappears
        .task {
            // Initialise ViewModel with injected services (first appearance only)
            if viewModel == nil {
                let vm = HomeViewModel(
                    restaurantService: services.restaurantService,
                    locationService: services.locationService,
                    advertisementService: services.advertisementService
                )
                viewModel = vm
                await vm.loadData()
            }
        }
        .toast(message: viewModel?.toastMessage ?? "", style: viewModel?.toastStyle ?? .success, isPresented: Binding(
            get: { viewModel?.showToast ?? false },
            set: { viewModel?.showToast = $0 }
        ))
        .navigationDestination(item: $selectedAdRoute) { route in
            switch route {
            case .restaurant(let restaurantId):
                RestaurantLoadView(restaurantId: restaurantId)
            }
        }
    }

    // MARK: - Content

    /// Main content view once the ViewModel is ready
    @ViewBuilder
    private func content(vm: HomeViewModel) -> some View {
        if vm.isLoading && !vm.hasLoadedOnce {
            // Initial load — show shimmer skeleton instead of spinner
            HomeSkeletonView()

        } else if let error = vm.errorMessage, vm.featuredRestaurants.isEmpty, vm.nearbyRestaurants.isEmpty {
            // Error state with retry button
            ErrorView(message: error) {
                Task { await vm.loadData() }
            }

        } else {
            // Main content — scrollable list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {

                    // ─── Featured Restaurants Carousel ───────────────────
                    if !vm.featuredRestaurants.isEmpty {
                        featuredSection(restaurants: vm.featuredRestaurants)
                    }

                    // ─── Featured Offers (Advertisements) ────────────────
                    // Only shown when there are active advertisements to display
                    if !vm.advertisements.isEmpty {
                        featuredOffersSection(ads: vm.advertisements)
                    }

                    // ─── Nearby Restaurants List ──────────────────────────
                    nearbySection(restaurants: vm.nearbyRestaurants, isLoading: vm.isLoading)

                }
            }
            // Pull-to-refresh support
            // User pulls down → calls vm.refresh() asynchronously
            //
            // FLUTTER EQUIVALENT:
            // RefreshIndicator(onRefresh: () => vm.refresh(), child: ...)
            .refreshable {
                await vm.refresh()
            }
            .id(preferredLanguage)
        }
    }

    // MARK: - Featured Section

    /// Horizontal scrolling carousel of featured restaurants
    @ViewBuilder
    private func featuredSection(restaurants: [Restaurant]) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            // Section header
            Text("home_featured_title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.top, Constants.UI.spacingMedium)

            // Horizontal scroll of featured restaurant cards
            // ScrollView(.horizontal) = horizontal scrolling (like PageView/ListView in Flutter)
            ScrollView(.horizontal, showsIndicators: false) {
                // HStack arranges cards horizontally (like Row in Flutter)
                HStack(spacing: Constants.UI.spacingMedium) {
                    ForEach(restaurants) { restaurant in
                        // NavigationLink(value:) declares a navigation destination
                        // When tapped, pushes RestaurantView onto the NavigationStack
                        //
                        // FLUTTER EQUIVALENT:
                        // GestureDetector(
                        //   onTap: () => Navigator.push(context, MaterialPageRoute(
                        //     builder: (ctx) => RestaurantView(restaurant: restaurant)
                        //   )),
                        //   child: FeaturedRestaurantCard(restaurant: restaurant),
                        // )
                        NavigationLink(value: restaurant) {
                            FeaturedRestaurantCard(
                                restaurant: restaurant,
                                userLocation: services.locationService.currentLocation
                            )
                        }
                        .buttonStyle(.plain)  // Removes default button styling
                        .hapticFeedback(style: .light)
                        .accessibilityLabel("\(restaurant.name.localised), \(restaurant.cuisine.localised), \(restaurant.ratingDisplay) stars, \(restaurant.isOpenNow ? "open_now" : "closed")")
                    }
                }
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.bottom, Constants.UI.spacingMedium)
            }
        }
    }

    // MARK: - Featured Offers Section

    /// Horizontal scrolling carousel of active restaurant advertisements.
    /// Each card shows the bilingual ad image + title and navigates to the
    /// associated restaurant page when tapped.
    @ViewBuilder
    private func featuredOffersSection(ads: [Advertisement]) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            // Section header — "Featured Offers" / "甄選優惠"
            Text("home_offers_title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.top, Constants.UI.spacingMedium)

            // Horizontal scroll of ad cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.UI.spacingMedium) {
                    ForEach(ads) { ad in
                        AdOfferCard(ad: ad)
                            .frame(width: 260, height: 160)
                            .onTapGesture {
                                guard !ad.restaurantId.isEmpty else { return }
                                selectedAdRoute = .restaurant(id: ad.restaurantId)
                            }
                    }
                }
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.bottom, Constants.UI.spacingMedium)
            }
        }
    }

    // MARK: - Nearby Section

    /// Vertical list of nearby restaurants
    @ViewBuilder
    private func nearbySection(restaurants: [Restaurant], isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            // Section header
            Text("home_nearby_title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.top, Constants.UI.spacingMedium)

            if isLoading {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonRestaurantRow()
                            .padding(.horizontal, Constants.UI.spacingMedium)
                            .padding(.vertical, Constants.UI.spacingSmall)
                        Divider().padding(.leading, Constants.UI.spacingMedium)
                    }
                }
            } else if restaurants.isEmpty {
                EmptyStateView.noNearbyRestaurants()
                    .frame(height: 200)
            } else {
                // List of nearby restaurants — card-style with accent tint
                LazyVStack(spacing: 10) {
                    ForEach(restaurants) { restaurant in
                        NavigationLink(value: restaurant) {
                            RestaurantRowView(
                                restaurant: restaurant,
                                userLocation: services.locationService.currentLocation
                            )
                        }
                        .buttonStyle(.plain)
                        .hapticFeedback(style: .light)
                        .accessibilityLabel("\(restaurant.name.localised), \(restaurant.cuisine.localised), \(restaurant.ratingDisplay) stars")
                    }
                }
                .padding(.horizontal, Constants.UI.spacingMedium)
            }
        }
        .padding(.bottom, Constants.UI.spacingLarge)
    }
}

// MARK: - Ad Offer Card

/// A card displaying a single active advertisement in the Featured Offers carousel.
/// Shows the bilingual hero image with a gradient overlay and the ad title.
private struct AdOfferCard: View {

    let ad: Advertisement

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background hero image (language-appropriate)
            if let url = ad.localizedImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        // Placeholder colour when image is unavailable
                        Color(.systemGray5)
                    @unknown default:
                        Color(.systemGray5)
                    }
                }
                .clipped()
            } else {
                Color(.systemGray5)
            }

            // Gradient overlay so title text is readable over any image
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )

            if !ad.localizedTitle.isEmpty || !ad.localizedContent.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !ad.localizedTitle.isEmpty {
                        Text(ad.localizedTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                    }
                    if !ad.localizedContent.isEmpty {
                        Text(ad.localizedContent)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .cornerRadius(Constants.UI.cornerRadiusMedium)
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Featured Restaurant Card

/// Large horizontal card for the featured restaurants carousel
///
/// Shows the restaurant image, name, cuisine type, and rating.
/// Tappable to navigate to the restaurant detail screen.
private struct FeaturedRestaurantCard: View {

    let restaurant: Restaurant
    var userLocation: CLLocation?

    var body: some View {
        // Full-bleed image card with text overlaid at the bottom
        ZStack(alignment: .bottom) {
            RestaurantCardImage(urlString: restaurant.imageURLs.first)
                .frame(width: 280, height: 200)

            // Bottom gradient for text readability
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.75), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Text info overlaid at the bottom
            VStack(alignment: .leading, spacing: 3) {
                Text(restaurant.name.localised)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack {
                    Text(restaurant.cuisine.localised)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))

                    Text("·")
                        .foregroundStyle(.white.opacity(0.6))

                    Text(restaurant.priceRangeDisplay)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    Text(restaurant.isOpenNow
                         ? "open_now"
                         : "closed")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(restaurant.isOpenNow ? .green : .white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.15), in: Capsule())
                }
            }
            .padding(.horizontal, Constants.UI.spacingSmall)
            .padding(.bottom, Constants.UI.spacingSmall)

            // Badges pinned to top corners
            VStack {
                HStack {
                    RatingBadge(rating: restaurant.rating)
                    Spacer()
                    if let distance = restaurant.distance(from: userLocation) {
                        DistanceBadge(meters: distance)
                    }
                }
                .padding(Constants.UI.spacingSmall)
                Spacer()
            }
        }
        .frame(width: 280, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusLarge))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Restaurant Row View

/// Compact horizontal row view for restaurant lists
///
/// Shows thumbnail image, name, cuisine, rating, and distance.
/// Styled with organic accent-coloured card with soft shadow.
/// Used in the nearby restaurants section.
private struct RestaurantRowView: View {

    let restaurant: Restaurant
    var userLocation: CLLocation?

    var body: some View {
        HStack(spacing: 14) {

            // Rounded thumbnail with overlay badges
            ZStack {
                AsyncImageView(
                    url: restaurant.imageURLs.first,
                    contentMode: .fill,
                    cornerRadius: Constants.UI.cornerRadiusLarge,
                    aspectRatio: 1
                )
                .frame(width: 88, height: 88)

                VStack {
                    // Distance badge — top-left
                    HStack {
                        if let distance = restaurant.distance(from: userLocation) {
                            DistanceBadge(meters: distance)
                        }
                        Spacer()
                    }
                    Spacer()
                    // Open/Closed pill — bottom-left
                    HStack {
                        Text(restaurant.isOpenNow
                             ? "open_now"
                             : "closed")
                            .font(.system(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                restaurant.isOpenNow
                                    ? Color.accentColor.opacity(0.9)
                                    : Color.secondary.opacity(0.7),
                                in: Capsule()
                            )
                        Spacer()
                    }
                }
                .padding(6)
            }
            .frame(width: 88, height: 88)
            .clipped()

            // Restaurant info
            VStack(alignment: .leading, spacing: 6) {

                Text(restaurant.name.localised)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !restaurant.keywords.isEmpty {
                    Text(restaurant.keywords.map { $0.localised }.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(restaurant.district.localised)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    // Star + rating with accent background
                    if restaurant.rating <= 0 {
                        Text("New")
                            .font(.caption)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text(restaurant.ratingDisplay)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        restaurant.rating <= 0
                            ? Color(red: 0.94, green: 0.63, blue: 0.13)
                            : Color.accentColor.opacity(0.85),
                        in: Capsule()
                    )

                    Text(restaurant.priceRangeDisplay)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            // Disclosure chevron
            Image(systemName: "chevron.right")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor.opacity(0.5))
        }
        .padding(Constants.UI.spacingSmall)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusLarge)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.accentColor.opacity(0.08), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusLarge)
                .strokeBorder(Color.accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Rating Badge

/// Small yellow rating badge overlaid on restaurant images
private struct RatingBadge: View {

    let rating: Double

    var body: some View {
        Group {
            if rating <= 0 {
                Text("New")
                    .font(.caption)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text(String(format: "%.1f", rating))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            rating <= 0
                ? Color(red: 0.94, green: 0.63, blue: 0.13)
                : .black.opacity(0.6),
            in: Capsule()
        )
    }
}

private enum HomeRoute: Hashable, Identifiable {
    case restaurant(id: String)

    var id: String {
        switch self {
        case .restaurant(let id):
            return "restaurant-\(id)"
        }
    }
}

private struct RestaurantLoadView: View {
    @Environment(\.services) private var services

    let restaurantId: String
    @State private var restaurant: Restaurant?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let restaurant {
                RestaurantView(restaurant: restaurant)
            } else if let errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await loadRestaurant() }
                }
            } else {
                LoadingView(message: "restaurant_loading")
            }
        }
        .task(id: restaurantId) {
            if restaurant == nil { await loadRestaurant() }
        }
    }

    private func loadRestaurant() async {
        do {
            errorMessage = nil
            restaurant = try await services.restaurantService.fetchRestaurant(id: restaurantId)
        } catch {
            errorMessage = String(localized: "error_unknown", bundle: L10n.bundle)
        }
    }
}

// MARK: - Distance Badge

/// Small badge showing the distance from the user to a restaurant.
/// Displayed on the top-right of restaurant card images when location is available.
struct DistanceBadge: View {

    let meters: Double

    /// Human-readable distance string (e.g. "350 m" or "1.2 km")
    private var label: String {
        Self.formattedDistance(meters: meters)
    }

    /// Returns a formatted distance Text view for use outside the badge
    static func label(meters: Double) -> Text {
        Text(formattedDistance(meters: meters))
    }

    /// Shared formatting logic
    static func formattedDistance(meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "location.fill")
                .font(.system(size: 8))
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.black.opacity(0.6), in: Capsule())
    }
}

// MARK: - Skeleton Loading Views

/// Full-page shimmer skeleton shown during the initial data load.
private struct HomeSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {

                // Featured skeleton header
                Text("home_featured_title")
                    .font(.title2).fontWeight(.bold)
                    .padding(.horizontal, Constants.UI.spacingMedium)
                    .padding(.top, Constants.UI.spacingMedium)
                    .redacted(reason: .placeholder)

                // Featured skeleton cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.UI.spacingMedium) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonFeaturedCard()
                        }
                    }
                    .padding(.horizontal, Constants.UI.spacingMedium)
                    .padding(.bottom, Constants.UI.spacingMedium)
                }

                // Nearby skeleton header
                Text("home_nearby_title")
                    .font(.title2).fontWeight(.bold)
                    .padding(.horizontal, Constants.UI.spacingMedium)
                    .padding(.top, Constants.UI.spacingMedium)
                    .redacted(reason: .placeholder)

                // Nearby skeleton rows
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonRestaurantRow()
                            .padding(.horizontal, Constants.UI.spacingMedium)
                            .padding(.vertical, Constants.UI.spacingSmall)
                        Divider().padding(.leading, Constants.UI.spacingMedium)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Shimmer placeholder for a featured restaurant card
private struct SkeletonFeaturedCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusLarge)
            .fill(Color(.systemFill))
            .frame(width: 280, height: 200)
            .shimmerEffect()
    }
}

/// Shimmer placeholder for a nearby restaurant row
struct SkeletonRestaurantRow: View {
    var body: some View {
        HStack(spacing: Constants.UI.spacingMedium) {
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium)
                .fill(Color(.systemFill))
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(width: 100, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(width: 80, height: 10)
            }

            Spacer()
        }
        .shimmerEffect()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
            .environment(\.services, Services())
            .environment(\.authService, Services().authService)
    }
}
