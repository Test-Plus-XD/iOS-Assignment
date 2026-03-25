//
//  DirectionsView.swift
//  Pour Rice
//
//  Modal sheet showing route directions from user's location to a restaurant
//  Uses MKDirections for in-app route calculation with Apple Maps handoff
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  - MKDirections = Google Directions API in the cross-platform app
//  - MapPolyline = google_maps_flutter Polyline
//  - MKMapItem.openInMaps() = url_launcher with Google Maps URL
//  - Picker(.segmented) = SegmentedButton in Material 3
//  ============================================================================
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Transport Mode

/// Hashable transport mode enum wrapping MKDirectionsTransportType
/// MKDirectionsTransportType does not conform to Hashable, so SwiftUI Picker
/// cannot use it as a tag directly. This enum bridges the gap.
enum TransportMode: String, CaseIterable, Hashable {
    case transit
    case walking
    case driving

    var transportType: MKDirectionsTransportType {
        switch self {
        case .transit:  .transit
        case .walking:  .walking
        case .driving:  .automobile
        }
    }

    var icon: String {
        switch self {
        case .transit:  "bus"
        case .walking:  "figure.walk"
        case .driving:  "car"
        }
    }

    var labelKey: LocalizedStringKey {
        switch self {
        case .transit:  "directions_transit"
        case .walking:  "directions_walking"
        case .driving:  "directions_driving"
        }
    }

    var launchDirectionsMode: String {
        switch self {
        case .transit:  MKLaunchOptionsDirectionsModeTransit
        case .walking:  MKLaunchOptionsDirectionsModeWalking
        case .driving:  MKLaunchOptionsDirectionsModeDriving
        }
    }
}

// MARK: - Directions View Model

/// Manages route calculation state for the directions sheet
@MainActor
@Observable
final class DirectionsViewModel {

    // MARK: - State

    var selectedMode: TransportMode = .transit
    var route: MKRoute?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Input

    let restaurant: Restaurant
    let userLocation: CLLocation?

    // MARK: - Init

    init(restaurant: Restaurant, userLocation: CLLocation?) {
        self.restaurant = restaurant
        self.userLocation = userLocation
    }

    // MARK: - Computed

    var restaurantCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: restaurant.location.latitude,
            longitude: restaurant.location.longitude
        )
    }

    // MARK: - Directions

    /// Calculates a route from the user's current location to the restaurant
    func fetchDirections() async {
        guard let userLocation else {
            errorMessage = String(localized: "directions_no_location", bundle: L10n.bundle)
            return
        }

        isLoading = true
        errorMessage = nil
        route = nil

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(
            coordinate: userLocation.coordinate
        ))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: restaurantCoordinate
        ))
        request.transportType = selectedMode.transportType

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            route = response.routes.first
        } catch {
            errorMessage = String(localized: "directions_error", bundle: L10n.bundle)
        }

        isLoading = false
    }

    /// Opens Apple Maps with turn-by-turn navigation to the restaurant
    func openInAppleMaps() {
        let destination = MKMapItem(placemark: MKPlacemark(
            coordinate: restaurantCoordinate
        ))
        destination.name = restaurant.name.localised
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: selectedMode.launchDirectionsMode
        ])
    }

    // MARK: - Formatted Output

    /// Formatted travel time string (e.g. "25 min")
    var formattedTravelTime: String? {
        guard let route else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: route.expectedTravelTime)
    }

    /// Formatted distance string (e.g. "3.2 km")
    var formattedDistance: String? {
        guard let route else { return nil }
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        let measurement = Measurement(value: route.distance, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
}

// MARK: - Directions View

/// Modal sheet displaying route from user's location to a restaurant
///
/// Features:
/// - Map with route polyline overlay
/// - Transport mode picker (Transit / Walking / Driving)
/// - Travel time and distance summary
/// - "Open in Apple Maps" button for full turn-by-turn navigation
struct DirectionsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: DirectionsViewModel

    // MARK: - Init

    init(restaurant: Restaurant, userLocation: CLLocation?) {
        _viewModel = State(initialValue: DirectionsViewModel(
            restaurant: restaurant,
            userLocation: userLocation
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map with route
                mapSection
                    .frame(height: Constants.Map.directionsMapHeight)

                // Transport mode picker
                transportPicker
                    .padding(Constants.UI.spacingMedium)

                // Route summary
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if viewModel.route != nil {
                    routeSummary
                        .padding(.horizontal, Constants.UI.spacingMedium)
                }

                Spacer()

                // Open in Apple Maps
                Button {
                    viewModel.openInAppleMaps()
                } label: {
                    Label("directions_open_apple_maps", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(Constants.UI.spacingMedium)
            }
            .navigationTitle("directions_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.fetchDirections()
            }
            .onChange(of: viewModel.selectedMode) { _, _ in
                Task { await viewModel.fetchDirections() }
            }
        }
    }

    // MARK: - Map Section

    private var mapSection: some View {
        Map {
            UserAnnotation()

            Marker(
                viewModel.restaurant.name.localised,
                systemImage: "fork.knife",
                coordinate: viewModel.restaurantCoordinate
            )
            .tint(.accent)

            if let route = viewModel.route {
                MapPolyline(route.polyline)
                    .stroke(.tint, lineWidth: 5)
            }
        }
        .mapControls {
            MapCompass()
        }
    }

    // MARK: - Transport Picker

    private var transportPicker: some View {
        Picker("directions_transport_mode", selection: $viewModel.selectedMode) {
            ForEach(TransportMode.allCases, id: \.self) { mode in
                Label(mode.labelKey, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Route Summary

    private var routeSummary: some View {
        HStack(spacing: Constants.UI.spacingLarge) {
            // Travel time
            VStack(spacing: 4) {
                Text("directions_estimated_time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.formattedTravelTime ?? "—")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            // Distance
            VStack(spacing: 4) {
                Text("directions_distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.formattedDistance ?? "—")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Constants.UI.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
