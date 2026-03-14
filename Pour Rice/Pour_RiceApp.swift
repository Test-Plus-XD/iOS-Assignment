//
//  Pour_RiceApp.swift (Liquid Glass Variant)
//  Pour Rice
//
//  Main application entry point for Pour Rice restaurant discovery app
//  Follows iOS 17+ architecture with @Observable macro and modern Swift concurrency
//  Configures Firebase and manages authentication state
//  Enhanced with iOS 26+ Liquid Glass material system
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is like your main.dart file in Flutter. It's the entry point where
//  your app starts. In Flutter you have main() and runApp(), in iOS/SwiftUI
//  we use the @main attribute to mark the entry point.
//  ============================================================================
//
//  ============================================================================
//  LIQUID GLASS OVERVIEW (iOS 26+):
//  Liquid Glass is a dynamic, translucent material that combines optical
//  properties of glass (reflection, refraction, blur) with fluid behaviour.
//  
//  KEY PRINCIPLES FROM APPLE HIG:
//  - Use ONLY for navigation layer (controls, navigation, transient UI)
//  - NEVER use for content layer (backgrounds, scrollable areas, media)
//  - Automatically adapts to light/dark mode, content, and focus state
//  - Group related glass elements in GlassEffectContainer for proper blending
//  - Use .interactive() for buttons, sliders, toggles, and other controls
//  - Use .glassEffectID() for smooth morphing during state transitions
//  
//  VARIANTS:
//  - .regular: Default, balanced translucency (most versatile)
//  - .clear: Very transparent, subtle (requires dimming layer beneath)
//  - .identity: Minimal effect (useful for conditional states)
//  ============================================================================
//

import SwiftUI        // SwiftUI framework for building user interfaces (like Flutter widgets)
import FirebaseCore   // Firebase SDK for authentication, database, etc.
import GoogleSignIn

/// Main application entry point for Pour Rice restaurant discovery app
/// Manages app lifecycle, Firebase configuration, and authentication state
///
/// FLUTTER EQUIVALENT:
/// void main() {
///   runApp(MyApp());
/// }
///
/// The @main attribute tells iOS "start the app here"
/// Similar to void main() in Dart or public static void main() in Java
@main
struct Pour_RiceApp: App {
    /// Firebase docs for SwiftUI recommend wiring an AppDelegate via
    /// UIApplicationDelegateAdaptor so SDK lifecycle hooks (including OAuth-related
    /// callbacks) are available to the app process.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // App is a protocol (interface) that all SwiftUI apps must conform to
    // It's like extending StatelessWidget or MaterialApp in Flutter

    // MARK: - Services

    /// Centralised services container for dependency injection
    ///
    /// Services is a reference type (class), so a simple `let` is sufficient —
    /// SwiftUI @State is only needed for value types that must trigger re-renders.
    /// The @Observable properties *inside* AuthService already drive view updates.
    ///
    /// WHY a static shared instance:
    /// SwiftUI may re-create the @main App struct multiple times during the app
    /// lifecycle. A static ensures Firebase is configured exactly once and the
    /// same Services instance is reused across recreations.
    ///
    /// See: https://github.com/firebase/firebase-ios-sdk/issues/14436
    private let services: Services

    /// Shared services instance — guarantees single Firebase configuration and
    /// single Services creation even when SwiftUI re-invokes App.init().
    private static let sharedServices: Services = {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return Services()
    }()

    /// Persisted language preference ("en" or "zh-Hant") stored in UserDefaults.
    /// @AppStorage watches UserDefaults — when AccountView's Picker changes this value,
    /// SwiftUI rebuilds body and re-injects the new locale into the entire view tree,
    /// causing all String(localized:) calls to instantly switch language without restart.
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"

    // MARK: - Initialisation

    /// Configures Firebase and creates the services container in the correct order.
    ///
    /// CRITICAL ORDER:
    /// 1. FirebaseApp.configure() — must run FIRST
    /// 2. Services() — creates AuthService which calls Auth.auth()
    ///
    /// FLUTTER EQUIVALENT:
    /// void main() async {
    ///   WidgetsFlutterBinding.ensureInitialized();
    ///   await Firebase.initializeApp();          // ← step 1
    ///   runApp(MyApp(services: Services()));     // ← step 2
    /// }
    init() {
        self.services = Self.sharedServices
    }

    // MARK: - Scene Configuration

    /// The main content of the app
    ///
    /// FLUTTER EQUIVALENT:
    /// This is like the build() method in a StatelessWidget
    /// It returns what to display on screen
    ///
    /// The return type "some Scene" means:
    /// - "some" = Swift's opaque type (don't worry about the exact type)
    /// - "Scene" = A container for your app's UI (like MaterialApp in Flutter)
    var body: some Scene {
        // WindowGroup is the container for your app's windows
        // Think of it like MaterialApp in Flutter - it sets up the root of your app
        WindowGroup {
            // RootView is our first screen (defined below)
            RootView()
                // DEPENDENCY INJECTION - Passing services down the view tree
                //
                // .environment() injects values into the view hierarchy
                // Any child view can access these via @Environment
                //
                // FLUTTER EQUIVALENT:
                // Provider(
                //   create: (_) => Services(),
                //   child: RootView(),
                // )
                //
                // Now any view can use: @Environment(\.services) to access services
                //
                // LANGUAGE TOGGLE:
                // Re-injects locale whenever @AppStorage("preferredLanguage") changes.
                // This causes all String(localized:) in the tree to pick up the new language
                // without an app restart. BilingualText.localised also reads UserDefaults
                // directly, so dynamic API data (restaurant names etc.) switches too.
                .environment(\.locale, Locale(identifier: preferredLanguage))
                .environment(\.services, services)
                .environment(\.authService, services.authService)
                .onOpenURL { url in
                    // iOS 26+ preferred URL handling path (scene-based lifecycle)
                    // for OAuth callback handoff from Google Sign-In.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

// MARK: - Root View

/// Root view that handles authentication state
/// Shows LoginView for unauthenticated users, MainTabView for authenticated users
///
/// FLUTTER EQUIVALENT:
/// class RootView extends StatelessWidget {
///   Widget build(BuildContext context) {
///     final auth = context.watch<AuthService>();
///     return auth.isAuthenticated ? MainTabView() : LoginView();
///   }
/// }
struct RootView: View {
    // View is the protocol (interface) that all SwiftUI views must conform to
    // It's like extending Widget in Flutter

    // MARK: - Environment

    /// Auth service for checking authentication state
    ///
    /// WHAT IS @Environment:
    /// Reads a value from the environment that was injected with .environment()
    ///
    /// FLUTTER EQUIVALENT:
    /// final authService = context.watch<AuthService>();
    /// or
    /// final authService = Provider.of<AuthService>(context);
    ///
    /// The syntax \.authService uses KeyPath - it's Swift's way of accessing properties
    @Environment(\.authService) private var authService

    // MARK: - State

    /// Guest browsing mode — allows unauthenticated users to browse Home, Search,
    /// and Restaurant pages. The Account tab prompts them to sign in.
    @State private var isGuest = false

    // MARK: - Body

    /// The UI content of this view
    ///
    /// Every SwiftUI view must have a "body" property that returns the UI
    /// Similar to the build() method in Flutter widgets
    var body: some View {
        // "some View" means the return type is some kind of View, but Swift figures out which one

        // Group is a container that doesn't add any visual elements
        // It just groups views together without affecting layout
        // Similar to an empty Container() or SizedBox() in Flutter
        Group {
            // Conditional rendering based on authentication or guest state
            //
            // FLUTTER EQUIVALENT:
            // (isAuthenticated || isGuest) ? MainTabView() : LoginView()
            if authService.isAuthenticated || isGuest {
                // User is signed in or browsing as guest - show the main app interface
                MainTabView(isGuest: $isGuest)
                    // .transition() defines the animation when this view appears/disappears
                    // .opacity makes it fade in/out
                    // Like FadeTransition in Flutter
                    .transition(.opacity)
            } else {
                // User is not signed in - show the login screen
                LoginView(isGuest: $isGuest)
                    .transition(.opacity)
            }
        }
        // .animation() tells SwiftUI to animate changes to the specified value
        // Whenever authService.isAuthenticated changes, SwiftUI will animate the transition
        //
        // FLUTTER EQUIVALENT:
        // AnimatedSwitcher(
        //   duration: Duration(milliseconds: 300),
        //   child: isAuthenticated ? MainTabView() : LoginView(),
        // )
        .animation(.easeInOut, value: authService.isAuthenticated)
        .animation(.easeInOut, value: isGuest)
    }
}

// MARK: - Main Tab View

/// Main tab-based navigation structure for the app with Liquid Glass effects (iOS 26+)
/// Wires up all real feature screens: Home, Search, and Account.
///
/// FLUTTER EQUIVALENT:
/// Scaffold(
///   bottomNavigationBar: BottomNavigationBar(...),
///   body: [HomeScreen(), SearchScreen(), AccountScreen()][currentIndex],
/// )
///
/// LIQUID GLASS IMPLEMENTATION NOTES:
/// - TabView automatically receives glass treatment in iOS 26
/// - NavigationDestination registers type-safe push routes for each stack
/// - Restaurant taps push RestaurantView; "See Full Menu" pushes MenuView
struct MainTabView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - Guest Mode

    /// Binding to guest browsing state from RootView.
    /// Passed to AccountView so it can exit guest mode when the user taps "Sign In".
    @Binding var isGuest: Bool

    // MARK: - Body

    var body: some View {
        // TabView creates a bottom tab bar navigation
        //
        // FLUTTER EQUIVALENT: Scaffold with BottomNavigationBar
        //
        // LIQUID GLASS NOTE:
        // In iOS 26, TabView automatically receives glass treatment without explicit modifier
        TabView {

            // ================================================================
            // HOME TAB — restaurant discovery + featured carousel
            // ================================================================

            Tab(String(localized: "home_title"), systemImage: "house.fill") {
                NavigationStack {
                    HomeView()
                        // Type-safe push navigation: Restaurant → RestaurantView
                        //
                        // FLUTTER EQUIVALENT:
                        // MaterialPageRoute(builder: (_) => RestaurantScreen(restaurant))
                        //
                        // NavigationLink(value: restaurant) in HomeView triggers this destination
                        .navigationDestination(for: Restaurant.self) { restaurant in
                            RestaurantView(restaurant: restaurant)
                        }
                        // String destinations — used by RestaurantView to push MenuView
                        // The value is "restaurantId::restaurantName" encoded as a string
                        .navigationDestination(for: MenuNavigation.self) { nav in
                            MenuView(restaurantId: nav.restaurantId, restaurantName: nav.restaurantName)
                        }
                }
            }

            // ================================================================
            // SEARCH TAB — Algolia-powered restaurant search
            // ================================================================

            Tab(String(localized: "search_title"), systemImage: "magnifyingglass") {
                NavigationStack {
                    SearchView()
                        .navigationDestination(for: Restaurant.self) { restaurant in
                            RestaurantView(restaurant: restaurant)
                        }
                        .navigationDestination(for: MenuNavigation.self) { nav in
                            MenuView(restaurantId: nav.restaurantId, restaurantName: nav.restaurantName)
                        }
                }
            }

            // ================================================================
            // ACCOUNT TAB — user profile and sign-out
            // ================================================================

            Tab(String(localized: "account_title"), systemImage: "person.fill") {
                NavigationStack {
                    AccountView(isGuest: $isGuest)
                }
            }
        }
        // TabView itself receives glass treatment automatically in iOS 26
        // No need to explicitly apply .glassEffect() - system handles it
    }
}

// MARK: - Menu Navigation Value

/// Hashable navigation value for pushing MenuView from RestaurantView
/// Bundles restaurantId + restaurantName so NavigationLink(value:) can carry both
///
/// WHY A SEPARATE TYPE:
/// NavigationLink(value:) requires a Hashable value. We need to pass two strings
/// (id + name) together. A struct is cleaner than encoding/decoding a single string.
struct MenuNavigation: Hashable {
    let restaurantId: String
    let restaurantName: String
}

// MARK: - View Extension for Backwards Compatibility

extension View {
    /// Applies Liquid Glass effect if available on iOS 26+, otherwise falls back to ultraThinMaterial
    /// Provides graceful degradation for older iOS versions whilst maintaining modern appearance
    ///
    /// WHAT THIS DOES:
    /// Checks if iOS 26+ is available, applies glass effect if yes, uses material if no
    /// This ensures your app works on older iOS versions without crashing
    ///
    /// FLUTTER EQUIVALENT:
    /// Similar to checking Platform.version before using new features
    /// if (Platform.version >= '26') {
    ///   return GlassEffect();
    /// } else {
    ///   return Material();
    /// }
    ///
    /// - Parameters:
    ///   - glass: Glass configuration (regular, clear, or identity variant)
    ///   - shape: Shape to apply glass effect to (Capsule, RoundedRectangle, Circle, etc.)
    /// - Returns: View with glass effect on iOS 26+ or material background on earlier versions
    @ViewBuilder
    @available(*, introduced: 1.0)
    func glassEffectCompat(
        _ glass: Glass = .regular,
        in shape: some Shape = Capsule()
    ) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ - use native Liquid Glass material
            self.glassEffect(glass, in: shape)
        } else {
            // iOS 25 and earlier - fall back to ultraThinMaterial
            // Provides similar translucent effect without Liquid Glass's dynamic behaviour
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Preview

/// SwiftUI Preview - Shows this view in Xcode's canvas for design-time preview
///
/// WHAT IS #Preview:
/// A macro that creates a preview in Xcode's canvas (the preview pane)
/// You can see your UI without running the app on a simulator
///
/// FLUTTER EQUIVALENT:
/// There's no exact equivalent - similar to Hot Reload but for static preview
/// Like Android Studio's Layout Preview
#Preview {
    // Preview also needs Firebase configured before creating Services.
    // Guard against double-configure if preview is refreshed.
    let _ = {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }()
    let previewServices = Services()
    RootView()
        .environment(\.services, previewServices)
        .environment(\.authService, previewServices.authService)
}
