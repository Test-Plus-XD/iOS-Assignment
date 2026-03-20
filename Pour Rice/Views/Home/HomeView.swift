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

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView(message: String(localized: "home_loading"))
            }
        }
        .navigationTitle(String(localized: "home_title"))
        .navigationBarTitleDisplayMode(.large)
        // .task runs async code when this view appears on screen
        // Equivalent to initState() + async operation in Flutter
        // Cancelled automatically when view disappears
        .task {
            // Initialise ViewModel with injected services (first appearance only)
            if viewModel == nil {
                let vm = HomeViewModel(
                    restaurantService: services.restaurantService,
                    locationService: services.locationService
                )
                viewModel = vm
                await vm.loadData()
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
        }
    }

    // MARK: - Featured Section

    /// Horizontal scrolling carousel of featured restaurants
    @ViewBuilder
    private func featuredSection(restaurants: [Restaurant]) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            // Section header
            Text(String(localized: "home_featured_title"))
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
                        .accessibilityLabel("\(restaurant.name.localised), \(restaurant.cuisine.localised), \(restaurant.ratingDisplay) stars, \(restaurant.isOpenNow ? String(localized: "open_now") : String(localized: "closed"))")
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
            Text(String(localized: "home_nearby_title"))
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
                // List of nearby restaurants
                // LazyVStack only renders visible rows (better performance)
                LazyVStack(spacing: 0) {
                    ForEach(restaurants) { restaurant in
                        NavigationLink(value: restaurant) {
                            RestaurantRowView(
                                restaurant: restaurant,
                                userLocation: services.locationService.currentLocation
                            )
                            .padding(.horizontal, Constants.UI.spacingMedium)
                            .padding(.vertical, Constants.UI.spacingSmall)
                        }
                        .buttonStyle(.plain)
                        .hapticFeedback(style: .light)
                        .accessibilityLabel("\(restaurant.name.localised), \(restaurant.cuisine.localised), \(restaurant.ratingDisplay) stars")

                        // Divider between rows (like Divider() in Flutter)
                        Divider()
                            .padding(.leading, Constants.UI.spacingMedium)
                    }
                }
            }
        }
        .padding(.bottom, Constants.UI.spacingLarge)
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
                         ? String(localized: "open_now")
                         : String(localized: "closed"))
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
/// Used in the nearby restaurants section.
private struct RestaurantRowView: View {

    let restaurant: Restaurant
    var userLocation: CLLocation?

    var body: some View {
        HStack(spacing: Constants.UI.spacingMedium) {

            // Square thumbnail image with optional distance badge
            ZStack(alignment: .topTrailing) {
                AsyncImageView(
                    url: restaurant.imageURLs.first,
                    contentMode: .fill,
                    cornerRadius: Constants.UI.cornerRadiusMedium,
                    aspectRatio: 1
                )
                .frame(width: 72, height: 72)

                if let distance = restaurant.distance(from: userLocation) {
                    DistanceBadge(meters: distance)
                        .padding(4)
                }
            }
            .frame(width: 72, height: 72)

            // Restaurant info
            VStack(alignment: .leading, spacing: 4) {

                Text(restaurant.name.localised)
                    .font(.headline)
                    .lineLimit(1)

                Text(restaurant.cuisine.localised)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack {
                    // Star + rating
                    Label(restaurant.ratingDisplay, systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(restaurant.priceRangeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Open/Closed
                    Text(restaurant.isOpenNow
                         ? String(localized: "open_now")
                         : String(localized: "closed"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(restaurant.isOpenNow ? .green : .secondary)
                }
            }

            // Disclosure chevron (standard iOS navigation indicator)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Rating Badge

/// Small yellow rating badge overlaid on restaurant images
private struct RatingBadge: View {

    let rating: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(String(format: "%.1f", rating))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        // Capsule = pill shape
        .background(.black.opacity(0.6), in: Capsule())
    }
}

// MARK: - Distance Badge

/// Small badge showing the distance from the user to a restaurant.
/// Displayed on the top-right of restaurant card images when location is available.
struct DistanceBadge: View {

    let meters: Double

    /// Human-readable distance string (e.g. "350 m" or "1.2 km")
    private var label: String {
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
                Text(String(localized: "home_featured_title"))
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
                Text(String(localized: "home_nearby_title"))
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
