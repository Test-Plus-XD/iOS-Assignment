# iOS Development Guide for Flutter Developers

This guide explains all the code in the Sprint 1-4 completion commit with detailed inline comments designed specifically for developers coming from Flutter/Android backgrounds.

## Table of Contents
1. [App Structure & Lifecycle](#app-structure--lifecycle)
2. [Dependency Injection & Services](#dependency-injection--services)
3. [Network Layer](#network-layer)
4. [Data Models](#data-models)
5. [Authentication](#authentication)
6. [Services](#services)
7. [UI/Views](#ui-views)

---

## App Structure & Lifecycle

### AppDelegate.swift - Firebase Initialization

**Flutter Equivalent**: Similar to `main()` with `Firebase.initializeApp()`

```swift
// WHAT IS APPDELEGATE?
// In iOS, AppDelegate handles app-wide lifecycle events
// It's like MainActivity in Android, but for the entire app, not just one screen

import UIKit               // iOS UI framework
import FirebaseCore        // Firebase SDK

class AppDelegate: NSObject, UIApplicationDelegate {

    // This method is called FIRST when your app launches
    // Similar to Flutter's main() or Android's onCreate()
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Initialize Firebase (must be called before ANY Firebase usage)
        // Flutter equivalent: await Firebase.initializeApp()
        FirebaseApp.configure()

        return true  // true = successful launch
    }

    // PUSH NOTIFICATIONS
    // Called when device token is generated for this app
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert binary device token to hex string
        // In Flutter, you'd get this from firebase_messaging plugin
        let tokenParts = deviceToken.map { byte in
            String(format: "%02.2hhx", byte)
        }
        let token = tokenParts.joined()

        print("📱 Device Token: \(token)")
        // TODO: Send to your backend server
    }
}
```

**Key iOS Concepts**:
- `NSObject`: Base class for all iOS objects (like Object in Java/Dart)
- `UIApplicationDelegate`: Protocol (interface) for handling app events
- `didFinishLaunchingWithOptions`: First method called on app launch
- Device Token: Unique identifier for push notifications (per app, per device)

---

### Pour_RiceApp.swift - Main Entry Point

**Flutter Equivalent**: Your `main.dart` with `runApp()`

```swift
import SwiftUI
import FirebaseCore

@main  // This attribute marks the entry point of the app
       // Similar to void main() in Flutter
struct Pour_RiceApp: App {

    // CONNECTING APPDELEGATE TO SWIFTUI
    // SwiftUI apps don't automatically use AppDelegate
    // This line bridges them together
    // It's like saying "hey SwiftUI, also run this AppDelegate"
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // STATE MANAGEMENT
    // @State is like setState() in Flutter
    // It tells SwiftUI to rebuild the view when this changes
    @State private var services = Services()

    // SCENE CONFIGURATION
    // In SwiftUI, "Scene" is like the app window
    // Similar to MaterialApp in Flutter
    var body: some Scene {
        WindowGroup {  // Creates a window for the app
            RootView()
                // DEPENDENCY INJECTION
                // These .environment() calls inject services into the view tree
                // Similar to Provider in Flutter or Koin/Hilt in Android
                .environment(\.services, services)
                .environment(\.authService, services.authService)
        }
    }
}

// ROOT VIEW - Handles Authentication State
struct RootView: View {

    // Access injected auth service from environment
    // Like using context.read<AuthService>() in Flutter Provider
    @Environment(\.authService) private var authService

    var body: some View {
        Group {
            // Conditional rendering based on auth state
            // Similar to: authState == AuthState.authenticated ? HomePage() : LoginPage()
            if authService.isAuthenticated {
                MainTabView()  // Authenticated: show main app
                    .transition(.opacity)  // Smooth fade transition
            } else {
                LoginView()    // Not authenticated: show login
                    .transition(.opacity)
            }
        }
        // Animate when isAuthenticated changes
        // Similar to AnimatedSwitcher in Flutter
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

// MAIN TAB VIEW - Bottom Navigation
struct MainTabView: View {

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    var body: some View {
        // TabView is like BottomNavigationBar in Flutter
        TabView {
            // HOME TAB
            NavigationStack {  // Like Navigator in Flutter
                VStack(spacing: Constants.UI.spacingLarge) {
                    Image(systemName: "house.fill")  // SF Symbols icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.accent)  // Accent color from Assets

                    Text("home_title")  // Localized string
                        .font(.title)
                        .fontWeight(.bold)

                    Text("coming_soon")
                        .foregroundStyle(.secondary)

                    // Temporary sign out button for testing
                    Button {
                        try? authService.signOut()
                    } label: {
                        Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.bordered)
                }
                .navigationTitle("home_title")
            }
            .tabItem {  // Define tab bar item
                Label(String(localized: "home_title"), systemImage: "house.fill")
            }

            // SEARCH TAB (placeholder)
            NavigationStack {
                VStack(spacing: Constants.UI.spacingLarge) {
                    Image(systemName: "magnifyingglass")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.accent)

                    Text("search_title")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("coming_soon")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("search_title")
            }
            .tabItem {
                Label(String(localized: "search_title"), systemImage: "magnifyingglass")
            }

            // ACCOUNT TAB (placeholder)
            NavigationStack {
                VStack(spacing: Constants.UI.spacingLarge) {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.accent)

                    Text("account_title")
                        .font(.title)
                        .fontWeight(.bold)

                    // Show user info if logged in
                    if let user = authService.currentUser {
                        VStack(spacing: Constants.UI.spacingSmall) {
                            Text(user.displayName)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        try? authService.signOut()
                    } label: {
                        Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.bordered)
                }
                .navigationTitle("account_title")
            }
            .tabItem {
                Label(String(localized: "account_title"), systemImage: "person.fill")
            }
        }
    }
}
```

**Key Concepts**:
- `@main`: Marks the app entry point (like `void main()` in Dart)
- `App` protocol: Required for SwiftUI apps (like runApp() in Flutter)
- `WindowGroup`: Creates a window/scene (like MaterialApp)
- `@State`: Local state management (like setState() in Flutter)
- `@Environment`: Dependency injection (like Provider in Flutter)
- `TabView`: Bottom tab navigation (like BottomNavigationBar)
- `NavigationStack`: Navigation container (like Navigator in Flutter)

---

## Dependency Injection & Services

### View+Extensions.swift - Service Container & View Extensions

**Flutter Equivalent**: Provider, GetIt, or context extensions

```swift
import SwiftUI

// ENVIRONMENT KEYS - For Dependency Injection
// In iOS, we use Environment to pass data down the view tree
// Similar to Provider in Flutter or Hilt in Android

/// Custom environment key for services container
/// Think of this as defining a new Provider type
struct ServicesKey: EnvironmentKey {
    static let defaultValue = Services()  // Default value if not provided
}

/// Custom environment key for auth service
struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: AuthService? = nil
}

// EXTENDING ENVIRONMENT VALUES
// This adds new properties to the Environment
// Similar to extending BuildContext in Flutter
extension EnvironmentValues {
    /// Access services through environment
    /// Usage: @Environment(\.services) private var services
    var services: Services {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }

    /// Direct access to auth service
    /// Usage: @Environment(\.authService) private var authService
    var authService: AuthService {
        get { self[AuthServiceKey.self]! }
        set { self[AuthServiceKey.self] = newValue }
    }
}

// SERVICES CONTAINER - Dependency Injection
// This holds all app-wide services
// Similar to GetIt in Flutter or Application class in Android

@MainActor  // Ensures all access happens on the main thread (UI thread)
class Services {

    // All service instances
    // These are created once and reused throughout the app (singleton pattern)
    let authService: AuthService
    let apiClient: APIClient
    let restaurantService: RestaurantService
    let reviewService: ReviewService
    let menuService: MenuService
    let algoliaService: AlgoliaService
    let locationService: LocationService

    /// Creates all services with proper dependencies
    /// This is called once when the app launches
    init() {
        // CIRCULAR DEPENDENCY RESOLUTION
        // Problem: AuthService needs APIClient, but APIClient needs AuthService
        // Solution: Create temporary client, then create real one

        // Step 1: Create temporary API client without auth
        let tempClient = DefaultAPIClient()

        // Step 2: Create auth service with temporary client
        let auth = AuthService(apiClient: tempClient)

        // Step 3: Create real API client with auth service
        self.apiClient = DefaultAPIClient(authService: auth)
        self.authService = auth

        // Step 4: Create other services with the real API client
        self.restaurantService = RestaurantService(apiClient: apiClient)
        self.reviewService = ReviewService(apiClient: apiClient)
        self.menuService = MenuService(apiClient: apiClient)
        self.algoliaService = AlgoliaService()
        self.locationService = LocationService()

        print("✅ Services container initialized")
    }
}

// VIEW EXTENSIONS - Reusable View Modifiers
// These are like custom widgets in Flutter

extension View {
    /// Adds a loading overlay with spinner
    /// Usage: MyView().loadingOverlay(isLoading: true)
    ///
    /// Flutter equivalent:
    /// Stack(children: [
    ///   MyWidget(),
    ///   if (isLoading) LoadingOverlay(),
    /// ])
    func loadingOverlay(isLoading: Bool) -> some View {
        self.overlay {  // overlay() adds a view on top
            if isLoading {
                ZStack {  // ZStack is like Stack in Flutter
                    // Semi-transparent black background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()  // Extend under notch/home indicator

                    // Spinning loading indicator
                    ProgressView()  // Like CircularProgressIndicator in Flutter
                        .scaleEffect(1.5)  // Make it 1.5x bigger
                        .tint(.white)  // White color
                }
            }
        }
    }
}

extension View {
    /// Shows an alert for errors
    /// Usage: MyView().errorAlert(error: $errorState)
    ///
    /// Flutter equivalent: showDialog() with AlertDialog
    func errorAlert(error: Binding<Error?>, buttonTitle: String = "OK") -> some View {
        self.alert(
            String(localized: "error_title"),  // Alert title
            isPresented: .constant(error.wrappedValue != nil),  // Show if error exists
            presenting: error.wrappedValue  // Pass error to alert
        ) { _ in
            // Alert button
            Button(buttonTitle) {
                error.wrappedValue = nil  // Clear error when dismissed
            }
        } message: { error in
            // Alert message
            Text(error.localizedDescription)
        }
    }
}

extension View {
    /// Applies iOS-native card styling
    /// Usage: MyView().cardStyle()
    ///
    /// Flutter equivalent:
    /// Card(
    ///   elevation: 2,
    ///   shape: RoundedRectangleBorder(borderRadius: 12),
    ///   child: Padding(...),
    /// )
    func cardStyle(
        cornerRadius: CGFloat = Constants.UI.cornerRadiusMedium,
        padding: CGFloat = Constants.UI.spacingMedium
    ) -> some View {
        self
            .padding(padding)  // Inner padding
            .background(Color(.systemBackground))  // Adaptive background color
            .cornerRadius(cornerRadius)  // Rounded corners
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)  // Drop shadow
    }
}

extension View {
    /// Adds haptic feedback on tap
    /// Usage: Button {...}.hapticFeedback()
    ///
    /// iOS has physical haptic feedback (vibration)
    /// Android has similar with HapticFeedback
    /// Flutter uses HapticFeedback.lightImpact()
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(  // Add gesture without blocking other gestures
            TapGesture()
                .onEnded { _ in
                    // Trigger haptic vibration
                    let generator = UIImpactFeedbackGenerator(style: style)
                    generator.impactOccurred()
                }
        )
    }
}

extension View {
    /// Dismisses keyboard when tapping outside text fields
    /// Usage: MyView().dismissKeyboardOnTap()
    ///
    /// Flutter equivalent: GestureDetector with onTap: FocusScope.of(context).unfocus()
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            // Send resign first responder action to the app
            // "First responder" = the view currently handling input (keyboard)
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),  // Method to dismiss keyboard
                to: nil,   // Send to whoever is first responder
                from: nil,
                for: nil
            )
        }
    }
}

extension View {
    /// Conditionally applies a modifier
    /// Usage: MyView().if(showBorder) { view in view.border(Color.red) }
    ///
    /// Flutter doesn't need this - you can use ternary operators
    /// But in SwiftUI, this is a common pattern for conditional modifiers
    @ViewBuilder  // Allows returning different view types
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)  // Apply transform if true
        } else {
            self  // Return unchanged if false
        }
    }
}
```

**Key Concepts**:
- `EnvironmentKey`: Define custom environment values (like creating a Provider)
- `@MainActor`: Ensures code runs on main thread (UI thread)
- `extension View`: Add reusable modifiers (like creating custom widgets)
- `@ViewBuilder`: Build views conditionally (like conditional rendering)
- `Binding<T>`: Two-way binding (like `TextEditingController` in Flutter)
- `overlay()`: Add view on top (like Stack in Flutter)
- `simultaneousGesture()`: Add gesture without blocking others

---

## Network Layer

### APIClient.swift - HTTP Client

**Flutter Equivalent**: Dio, http package, or Retrofit

```swift
import Foundation

// PROTOCOL - Interface Definition
// Protocols in Swift are like abstract classes or interfaces in Dart/Java
// They define what methods a class must implement
protocol APIClient: Sendable {  // Sendable = can be used across threads safely

    /// Makes an HTTP request and decodes the JSON response
    /// - Parameters:
    ///   - endpoint: Which API endpoint to call
    ///   - responseType: What type to decode the response into
    /// - Returns: Decoded response object
    /// - Throws: APIError if request fails
    ///
    /// Flutter equivalent:
    /// Future<T> request<T>(Endpoint endpoint, T Function(Map<String, dynamic>) fromJson)
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T
}

// DEFAULT IMPLEMENTATION
// This is the actual HTTP client implementation
@MainActor  // All network calls happen on main thread (for UI updates)
final class DefaultAPIClient: APIClient {

    // URLSession is iOS's built-in HTTP client
    // Similar to http.Client in Dart or OkHttpClient in Android
    private let session: URLSession

    // Auth service to get Firebase ID tokens
    // Optional because some endpoints don't need authentication
    private let authService: AuthService?

    /// Initialize the API client
    /// - Parameters:
    ///   - session: HTTP session (default: URLSession.shared)
    ///   - authService: Auth service for getting tokens (optional)
    init(session: URLSession = .shared, authService: AuthService? = nil) {
        self.session = session
        self.authService = authService
    }

    /// Makes an HTTP request with automatic header injection
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {

        // STEP 1: BUILD THE REQUEST
        // Create URLRequest object with method, URL, headers, body
        var request = try buildRequest(for: endpoint)

        // STEP 2: INJECT HEADERS
        // Add API passcode and Firebase auth token
        try await injectHeaders(into: &request)

        // STEP 3: EXECUTE REQUEST
        // async/await makes this wait for response
        // Similar to: final response = await dio.get(url)
        let (data, response) = try await session.data(for: request)

        // STEP 4: VALIDATE RESPONSE
        // Check for HTTP errors (404, 500, etc.)
        try validateResponse(response)

        // STEP 5: DECODE JSON
        // Convert JSON data to Swift object
        return try decodeResponse(data: data, responseType: responseType)
    }

    // PRIVATE HELPER METHODS

    /// Builds a URLRequest from an endpoint
    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        // Construct full URL
        // Example: "https://api.example.com" + "/restaurants/nearby"
        guard let url = URL(string: Constants.API.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue  // GET, POST, PUT, etc.
        request.timeoutInterval = 30  // 30 second timeout

        // ADD QUERY PARAMETERS (for GET requests)
        // Example: /restaurants?lat=22.28&lng=114.15&radius=5000
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            guard let urlWithQuery = components?.url else {
                throw APIError.invalidURL
            }
            request.url = urlWithQuery
        }

        // ADD REQUEST BODY (for POST/PUT requests)
        // Encode body object to JSON and attach to request
        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: Constants.API.Headers.contentType)
        }

        return request
    }

    /// Injects required headers (API passcode + Firebase token)
    private func injectHeaders(into request: inout URLRequest) async throws {
        // ALWAYS ADD: API Passcode header
        // This is like an API key for backend authentication
        request.setValue(
            Constants.API.passcode,
            forHTTPHeaderField: Constants.API.Headers.apiPasscode
        )

        // CONDITIONALLY ADD: Firebase ID token (for authenticated endpoints)
        if let authService = authService {
            do {
                // Get current user's Firebase ID token
                // This token proves the user is authenticated
                let idToken = try await authService.getIDToken()

                // Add as Bearer token in Authorization header
                // Format: "Authorization: Bearer <token>"
                request.setValue(
                    "Bearer \(idToken)",
                    forHTTPHeaderField: Constants.API.Headers.authorization
                )
            } catch {
                // If token fails, continue without it (for public endpoints)
                print("Warning: Could not retrieve ID token: \(error.localizedDescription)")
            }
        }
    }

    /// Validates HTTP response status code
    private func validateResponse(_ response: URLResponse) throws {
        // Cast to HTTPURLResponse to access status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Check status code
        switch httpResponse.statusCode {
        case 200...299:
            // 2xx = Success
            break
        case 401:
            // 401 = Unauthorized (invalid or expired token)
            throw APIError.unauthorized
        case 400...499:
            // 4xx = Client error (bad request, not found, etc.)
            throw APIError.clientError(httpResponse.statusCode)
        case 500...599:
            // 5xx = Server error
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.invalidResponse
        }
    }

    /// Decodes JSON response to Swift object
    private func decodeResponse<T: Decodable>(data: Data, responseType: T.Type) throws -> T {
        let decoder = JSONDecoder()

        // Configure date decoding strategy
        // ISO8601 format: "2024-02-14T10:30:00Z"
        decoder.dateDecodingStrategy = .iso8601

        do {
            // Decode JSON to object
            // Similar to: fromJson(jsonDecode(response.body))
            return try decoder.decode(responseType, from: data)
        } catch {
            // If decoding fails, log the response for debugging
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
            }
            throw APIError.decodingError
        }
    }
}

// HTTP METHODS
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
```

**Key Concepts**:
- `protocol`: Interface/abstract class (like `abstract class` in Dart)
- `URLSession`: iOS HTTP client (like Dio in Flutter)
- `URLRequest`: HTTP request object (like Request in Dio)
- `async throws`: Async function that can throw errors (like `Future<T>` that throws)
- `Decodable`: Protocol for JSON decoding (like `fromJson()` in Dart)
- `JSONDecoder`: Converts JSON to Swift objects automatically
- `inout`: Pass by reference (parameter can be modified)

---

This guide continues in the next message due to length limits...
