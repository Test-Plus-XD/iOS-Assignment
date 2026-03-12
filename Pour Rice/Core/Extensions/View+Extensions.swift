//
//  View+Extensions.swift
//  Pour Rice
//
//  SwiftUI View extensions for common UI patterns and helpers
//  Provides reusable modifiers following iOS design guidelines
//

import SwiftUI
import FirebaseCore

// MARK: - Environment Values for Services

/// Environment key for accessing the services container
struct ServicesKey: EnvironmentKey {
    // Default is nil; the real Services instance is injected in Pour_RiceApp.body.
    // A non-nil eager default would call Auth.auth() at static-init time,
    // before Firebase is configured.
    static let defaultValue: Services? = nil

    /// Lazily created fallback used only during SwiftUI's initial
    /// body evaluation before the real service is injected.
    @MainActor static let fallback: Services = {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return Services()
    }()
}

/// Environment key for accessing the auth service
struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: AuthService? = nil

    /// Lazily created fallback used only during SwiftUI's initial
    /// body evaluation before the real service is injected.
    @MainActor static let fallback: AuthService = {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return AuthService(apiClient: DefaultAPIClient())
    }()
}

extension EnvironmentValues {
    /// Access to all app services through dependency injection
    /// Force-unwrap is safe here because Services is always injected in Pour_RiceApp.body
    var services: Services {
        get {
            if let s = self[ServicesKey.self] { return s }
            return ServicesKey.fallback
        }
        set { self[ServicesKey.self] = newValue }
    }

    /// Direct access to auth service
    var authService: AuthService {
        get {
            // Prefer explicit auth service injection when present.
            if let authService = self[AuthServiceKey.self] {
                return authService
            }

            // Fallback: derive auth service from the services container.
            // This prevents runtime crashes in view trees that inject only
            // `\.services` but still read `\.authService`.
            if let services = self[ServicesKey.self] {
                return services.authService
            }

            // Final fallback: return a lazily created AuthService.
            // This only runs during SwiftUI's initial body evaluation
            // before the real service is injected from Pour_RiceApp.
            return AuthServiceKey.fallback
        }
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
