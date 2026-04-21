//
//  SearchMapView.swift
//  Pour Rice
//
//  Map view for search results showing restaurant pins on an Apple MapKit map
//  Displays when user toggles from list to map mode in SearchView
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  - SwiftUI Map() = GoogleMap widget in Flutter / MapView in Android
//  - Marker() = google_maps_flutter Marker
//  - MapCameraPosition = CameraPosition in Google Maps
//  - UserAnnotation() = MyLocationButton enabled on GoogleMap
//  ============================================================================
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Search Map View

/// Map view displaying restaurant search results as pins
///
/// Features:
/// - Restaurant markers tinted by open/closed status
/// - User location annotation
/// - Auto-fit camera to show all results
/// - Tappable callout card for selected restaurant (navigates to detail)
struct SearchMapView: View {

    // MARK: - Properties

    let restaurants: [Restaurant]
    var userLocation: CLLocation?

    // MARK: - State

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedTag: String?

    // MARK: - Body

    var body: some View {
        let validRestaurants = restaurants.filter {
            $0.location.latitude != 0 || $0.location.longitude != 0
        }

        Map(position: $cameraPosition, selection: $selectedTag) {
            UserAnnotation()

            ForEach(validRestaurants) { restaurant in
                Marker(
                    restaurant.name.localised,
                    systemImage: "fork.knife",
                    coordinate: CLLocationCoordinate2D(
                        latitude: restaurant.location.latitude,
                        longitude: restaurant.location.longitude
                    )
                )
                .tint(restaurant.isOpenNow ? .accent : .secondary)
                .tag(restaurant.id)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            updateCamera(for: validRestaurants)
        }
        .onChange(of: restaurants.count) { _, _ in
            let valid = restaurants.filter {
                $0.location.latitude != 0 || $0.location.longitude != 0
            }
            updateCamera(for: valid)
        }
        // Selected restaurant callout card — safeAreaInset pushes it above the tab bar
        // so the card never overlaps navigation chrome
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let tag = selectedTag,
               let restaurant = validRestaurants.first(where: { $0.id == tag }) {
                NavigationLink(value: restaurant) {
                    SearchMapCalloutCard(
                        restaurant: restaurant,
                        userLocation: userLocation
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.vertical, Constants.UI.spacingSmall)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring, value: selectedTag)
            }
        }
    }

    // MARK: - Camera

    private func updateCamera(for validRestaurants: [Restaurant]) {
        guard !validRestaurants.isEmpty else {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: Constants.Map.defaultLatitude,
                    longitude: Constants.Map.defaultLongitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: Constants.Map.searchSpanDelta,
                    longitudeDelta: Constants.Map.searchSpanDelta
                )
            ))
            return
        }

        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLng = Double.greatestFiniteMagnitude
        var maxLng = -Double.greatestFiniteMagnitude

        for r in validRestaurants {
            minLat = min(minLat, r.location.latitude)
            maxLat = max(maxLat, r.location.latitude)
            minLng = min(minLng, r.location.longitude)
            maxLng = max(maxLng, r.location.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.3, 0.01)
        )

        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Callout Card

/// Compact card overlay shown when a map pin is selected
/// Layout mirrors SearchResultRow: image with open/closed pill + distance overlays,
/// followed by name, address, and rating info.
private struct SearchMapCalloutCard: View {

    let restaurant: Restaurant
    var userLocation: CLLocation?

    var body: some View {
        HStack(spacing: 12) {

            // Thumbnail with open/closed pill and distance badge overlays
            ZStack {
                AsyncImageView(
                    url: restaurant.imageURLs.first,
                    contentMode: .fill,
                    cornerRadius: Constants.UI.cornerRadiusMedium,
                    aspectRatio: 1
                )
                .frame(width: 80, height: 80)

                VStack {
                    // Distance badge — top-left
                    HStack {
                        if let distance = restaurant.distance(from: userLocation) {
                            DistanceBadge(meters: distance)
                        }
                        Spacer()
                    }
                    Spacer()
                    // Open/Closed pill — bottom-left (matches list row style)
                    HStack {
                        Text(restaurant.isOpenNow ? "open_now" : "closed")
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
                .padding(5)
            }
            .frame(width: 80, height: 80)
            .clipped()

            // Restaurant details
            VStack(alignment: .leading, spacing: 5) {

                Text(restaurant.name.localised)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(restaurant.address.localised)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Rating pill
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
                    .padding(.vertical, 3)
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

            Spacer(minLength: 0)
        }
        .padding(Constants.UI.spacingSmall)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusLarge)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
    }
}
