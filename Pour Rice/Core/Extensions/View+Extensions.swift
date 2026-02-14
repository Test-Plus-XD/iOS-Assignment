//
//  View+Extensions.swift
//  Pour Rice
//
//  SwiftUI View extensions for common UI patterns and helpers
//  Provides reusable modifiers following iOS design guidelines
//

import SwiftUI

// MARK: - Environment Values for Services

/// Environment key for accessing the services container
struct ServicesKey: EnvironmentKey {
    static let defaultValue = Services()
}

/// Environment key for accessing the auth service
struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: AuthService? = nil
}

extension EnvironmentValues {
    /// Access to all app services through dependency injection
    var services: Services {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }

    /// Direct access to auth service
    var authService: AuthService {
        get { self[AuthServiceKey.self]! }
        set { self[AuthServiceKey.self] = newValue }
    }
}

// MARK: - Services Container

/// Container for all app services
/// Provides centralized dependency injection
@MainActor
class Services {

    // MARK: - Service Instances

    /// Authentication service
    let authService: AuthService

    /// API client for network requests
    let apiClient: APIClient

    /// Restaurant service
    let restaurantService: RestaurantService

    /// Review service
    let reviewService: ReviewService

    /// Menu service
    let menuService: MenuService

    /// Algolia search service
    let algoliaService: AlgoliaService

    /// Location service
    let locationService: LocationService

    // MARK: - Initialisation

    /// Creates a new services container with all dependencies
    init() {
        // Initialize API client first (without auth service initially)
        let tempClient = DefaultAPIClient()

        // Initialize auth service with temporary client
        let auth = AuthService(apiClient: tempClient)

        // Now create the real API client with auth service
        self.apiClient = DefaultAPIClient(authService: auth)
        self.authService = auth

        // Initialize other services with API client
        self.restaurantService = RestaurantService(apiClient: apiClient)
        self.reviewService = ReviewService(apiClient: apiClient)
        self.menuService = MenuService(apiClient: apiClient)
        self.algoliaService = AlgoliaService()
        self.locationService = LocationService()

        print("✅ Services container initialized")
    }
}

// MARK: - Loading Overlay

extension View {
    /// Adds a loading overlay with spinner
    /// - Parameter isLoading: Binding to loading state
    /// - Returns: Modified view with loading overlay
    func loadingOverlay(isLoading: Bool) -> some View {
        self.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
    }
}

// MARK: - Error Alert

extension View {
    /// Presents an alert for error messages
    /// - Parameters:
    ///   - error: Binding to optional error
    ///   - buttonTitle: Title for dismiss button
    /// - Returns: Modified view with error alert
    func errorAlert(error: Binding<Error?>, buttonTitle: String = "OK") -> some View {
        self.alert(
            String(localized: "error_title"),
            isPresented: .constant(error.wrappedValue != nil),
            presenting: error.wrappedValue
        ) { _ in
            Button(buttonTitle) {
                error.wrappedValue = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

// MARK: - Card Style

extension View {
    /// Applies iOS-native card styling to the view
    /// - Parameters:
    ///   - cornerRadius: Corner radius value
    ///   - padding: Inner padding
    /// - Returns: Modified view with card styling
    func cardStyle(
        cornerRadius: CGFloat = Constants.UI.cornerRadiusMedium,
        padding: CGFloat = Constants.UI.spacingMedium
    ) -> some View {
        self
            .padding(padding)
            .background(Color(.systemBackground))
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Haptic Feedback

extension View {
    /// Adds haptic feedback to button taps
    /// - Parameter style: Impact feedback style
    /// - Returns: Modified view with haptic feedback
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    let generator = UIImpactFeedbackGenerator(style: style)
                    generator.impactOccurred()
                }
        )
    }
}

// MARK: - Keyboard Dismissal

extension View {
    /// Dismisses keyboard when tapping outside text fields
    /// - Returns: Modified view with tap gesture
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}

// MARK: - Conditional Modifier

extension View {
    /// Conditionally applies a modifier to the view
    /// - Parameters:
    ///   - condition: Condition to check
    ///   - transform: Modifier to apply if condition is true
    /// - Returns: Modified or unmodified view
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
