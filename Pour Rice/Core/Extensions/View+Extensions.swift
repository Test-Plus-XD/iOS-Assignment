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

    /// Booking service
    let bookingService: BookingService

    /// Chat REST service
    let chatService: ChatService

    /// Socket.IO real-time service
    let socketService: SocketService

    /// Gemini AI service
    let geminiService: GeminiService

    /// Store/restaurant management service
    let storeService: StoreService

    // MARK: - Initialisation

    /// Creates a new services container with all dependencies
    init() {
        // Create a single API client, then wire up auth after AuthService exists.
        // This resolves the circular dependency: APIClient needs AuthService for
        // token injection, AuthService needs APIClient for network requests.
        let client = DefaultAPIClient()
        let auth = AuthService(apiClient: client)
        client.authService = auth

        self.apiClient = client
        self.authService = auth

        // Initialise other services with the same API client
        self.restaurantService = RestaurantService(apiClient: client)
        self.reviewService = ReviewService(apiClient: client)
        self.menuService = MenuService(apiClient: client)
        self.locationService = LocationService()
        self.bookingService = BookingService(apiClient: client)
        self.chatService = ChatService(apiClient: client)
        self.socketService = SocketService()
        self.geminiService = GeminiService(apiClient: client)
        self.storeService = StoreService(apiClient: client)

        print("✅ Services container initialised")
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
            "error_title",
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

// MARK: - Shimmer Effect

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.5), location: 0.4),
                            .init(color: .white.opacity(0.7), location: 0.5),
                            .init(color: .white.opacity(0.5), location: 0.6),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 2)
                    .offset(x: width * phase)
                    .blendMode(.plusLighter)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Applies an animated shimmer gradient overlay — use on skeleton loading placeholders.
    func shimmerEffect() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Notification Haptic

extension View {
    /// Fires a UINotificationFeedbackGenerator on the given feedback type.
    func notificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Toast / Snackbar System

/// Visual style for toast notifications
enum ToastStyle {
    case success
    case error
    case info

    var backgroundColor: Color {
        switch self {
        case .success: .green
        case .error:   .red
        case .info:    .blue
        }
    }

    var iconName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error:   "xmark.circle.fill"
        case .info:    "info.circle.fill"
        }
    }

    var hapticType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success: .success
        case .error:   .error
        case .info:    .warning
        }
    }
}

/// ViewModifier that overlays a toast banner at the top of the screen
private struct ToastModifier: ViewModifier {
    let message: String
    let style: ToastStyle
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    HStack(spacing: 10) {
                        Image(systemName: style.iconName)
                            .font(.title3)
                        Text(message)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(style.backgroundColor.gradient, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        UINotificationFeedbackGenerator().notificationOccurred(style.hapticType)
                    }
                }
            }
            .animation(.spring(duration: 0.4), value: isPresented)
            .onChange(of: isPresented) { _, shown in
                if shown {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        withAnimation { isPresented = false }
                    }
                }
            }
    }
}

extension View {
    /// Displays a temporary toast banner at the top of the view.
    /// Auto-dismisses after 2.5 seconds with haptic feedback.
    func toast(message: String, style: ToastStyle, isPresented: Binding<Bool>) -> some View {
        modifier(ToastModifier(message: message, style: style, isPresented: isPresented))
    }
}

// MARK: - Localisation Bundle Helper

/// Provides the correct language-specific Bundle for `String(localized:bundle:)`.
/// Used in Models, ViewModels, and Services where `LocalizedStringKey` (SwiftUI) is unavailable.
///
/// Views should use `Text("key")` / `.navigationTitle("key")` with `LocalizedStringKey` instead,
/// which respects `.environment(\.locale, ...)` automatically.
enum L10n {
    static var bundle: Bundle {
        let lang = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "en"
        let langCode = lang.hasPrefix("zh") ? "zh-Hant" : "en"
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}
