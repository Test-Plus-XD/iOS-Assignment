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
    // App is a protocol (interface) that all SwiftUI apps must conform to
    // It's like extending StatelessWidget or MaterialApp in Flutter

    // MARK: - App Delegate
    // (MARK creates a separator in Xcode's code navigator for organisation)

    /// App delegate for Firebase initialisation
    ///
    /// WHAT THIS DOES:
    /// Connects our AppDelegate class (which initialises Firebase) to this SwiftUI app
    ///
    /// WHY IT'S NEEDED:
    /// SwiftUI apps don't automatically use AppDelegate. This line bridges them.
    /// AppDelegate.swift runs Firebase.configure() before anything else starts.
    ///
    /// FLUTTER EQUIVALENT:
    /// In Flutter, you call Firebase.initializeApp() directly in main()
    /// Here we delegate that to AppDelegate using @UIApplicationDelegateAdaptor
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Services

    /// Centralised services container for dependency injection
    ///
    /// WHAT IS @State:
    /// @State tells SwiftUI this value can change and to rebuild the UI when it does
    /// Similar to setState() in Flutter or observable in MobX
    ///
    /// WHAT IS Services():
    /// A container holding all our app services (auth, API, location, etc.)
    /// Similar to Provider setup in Flutter or Koin/Hilt in Android
    ///
    /// WHY private:
    /// Only this file needs direct access. Other views get it via .environment()
    @State private var services = Services()

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
                .environment(\.services, services)
                .environment(\.authService, services.authService)
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
            // Conditional rendering based on authentication state
            //
            // FLUTTER EQUIVALENT:
            // isAuthenticated ? MainTabView() : LoginView()
            if authService.isAuthenticated {
                // User is signed in - show the main app interface
                MainTabView()
                    // .transition() defines the animation when this view appears/disappears
                    // .opacity makes it fade in/out
                    // Like FadeTransition in Flutter
                    .transition(.opacity)
            } else {
                // User is not signed in - show the login screen
                LoginView()
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
    }
}

// MARK: - Main Tab View

/// Main tab-based navigation structure for the app with Liquid Glass effects (iOS 26+)
/// Demonstrates proper Liquid Glass adoption following Apple's official guidelines
/// Glass effects are applied exclusively to navigation and control elements
///
/// FLUTTER EQUIVALENT:
/// Scaffold(
///   bottomNavigationBar: BottomNavigationBar(...),
///   body: pages[currentIndex],
/// )
///
/// LIQUID GLASS IMPLEMENTATION NOTES:
/// - GlassEffectContainer wraps groups of related glass elements
/// - .interactive() enables physics-based touch/hover response
/// - .glassEffectID() provides smooth morphing during state transitions
/// - Availability checks ensure graceful fallback for iOS 25 and earlier
struct MainTabView: View {

    // MARK: - Environment

    /// Access to app-wide services (injected from Pour_RiceApp)
    /// Provides centralised dependency injection for authentication, API, and other services
    @Environment(\.services) private var services
    /// Auth service for sign out functionality
    /// Used to handle user authentication state and sign-out operations
    @Environment(\.authService) private var authService

    // MARK: - Body

    var body: some View {
        // TabView creates a bottom tab bar navigation
        //
        // FLUTTER EQUIVALENT:
        // Scaffold with BottomNavigationBar
        //
        // Each section in {} becomes a tab
        //
        // LIQUID GLASS NOTE:
        // In iOS 26, TabView automatically receives glass treatment without explicit modifier
        TabView {

            // ================================================================
            // HOME TAB - First tab showing home screen
            // ================================================================

            // NavigationStack provides push/pop navigation capability
            // Similar to Navigator in Flutter
            NavigationStack {
                // VStack arranges children vertically (like Column in Flutter)
                // spacing parameter adds space between children
                VStack(spacing: Constants.UI.spacingLarge) {

                    // Image from SF Symbols (iOS's built-in icon set)
                    // "house.fill" is the icon name
                    //
                    // FLUTTER EQUIVALENT:
                    // Icon(Icons.home)
                    //
                    // LIQUID GLASS NOTE:
                    // NO glass effect applied - logos and branding are content, not controls
                    // Glass should only be applied to navigation/control layer
                    Image(systemName: "house.fill")
                        .resizable()          // Makes image resizable (like fit: BoxFit.contain)
                        .scaledToFit()        // Maintains aspect ratio
                        .frame(width: 60, height: 60)  // Sets size (like SizedBox)
                        .foregroundStyle(.accent)       // Colour from Assets.xcassets accent colour

                    // Text widget for displaying text (same as Flutter's Text)
                    // "home_title" is a localised string key
                    // iOS will automatically show English or Chinese based on device language
                    Text("home_title")
                        .font(.title)          // Predefined font size (like Theme.of(context).textTheme.title)
                        .fontWeight(.bold)     // Bold text

                    Text("coming_soon")
                        .foregroundStyle(.secondary)  // Secondary colour (greyed out)

                    // SIGN OUT BUTTON (temporary for testing)
                    //
                    // Button has two parts: action {} and label {}
                    //
                    // LIQUID GLASS IMPLEMENTATION:
                    // - GlassEffectContainer groups related glass elements
                    // - Required when multiple glass effects are near each other for proper blending
                    // - Enables smooth morphing animations between glass states
                    GlassEffectContainer {
                        Button {
                            // This closure runs when button is tapped
                            //
                            // try? means:
                            // - try to run signOut()
                            // - if it throws an error, ignore it
                            // - similar to try-catch without the catch
                            //
                            // FLUTTER EQUIVALENT:
                            // try {
                            //   authService.signOut();
                            // } catch (e) {
                            //   // ignore
                            // }
                            try? authService.signOut()
                        } label: {
                            // Label combines text and icon
                            // Similar to ListTile with leading icon in Flutter
                            Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        // Apply glass effect with interactive mode enabled
                        // .interactive() provides physics-based scale, bounce, and shimmer on touch
                        // Capsule shape is ideal for pill-shaped buttons
                        // Falls back to .ultraThinMaterial on iOS 25 and earlier
                        .glassEffectIfAvailable(.regular.interactive(), in: Capsule())
                        // Unique identifier enables smooth morphing during state transitions
                        // System can animate glass shape fluidly when button state changes
                        .glassEffectID("home-sign-out-button")
                    }
                    .padding(.top, Constants.UI.spacingLarge)  // Add space on top
                }
                // Navigation title shown at the top of the screen
                // Like AppBar's title in Flutter
                .navigationTitle("home_title")
            }
            // Define what this tab looks like in the tab bar
            .tabItem {
                Label(String(localized: "home_title"), systemImage: "house.fill")
            }

            // ================================================================
            // SEARCH TAB - Second tab (placeholder)
            // ================================================================

            NavigationStack {
                VStack(spacing: Constants.UI.spacingLarge) {
                    // Magnifying glass icon for search
                    // NO glass effect - it's content/branding, not a control
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

            // ================================================================
            // ACCOUNT TAB - Third tab showing user profile
            // ================================================================

            NavigationStack {
                VStack(spacing: Constants.UI.spacingLarge) {
                    // Person icon for account/profile
                    // NO glass effect - it's content/branding, not a control
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.accent)

                    Text("account_title")
                        .font(.title)
                        .fontWeight(.bold)

                    // CONDITIONAL RENDERING - Show user info if logged in
                    //
                    // if let unwraps the optional
                    // If authService.currentUser is not nil, unwrap it into 'user'
                    //
                    // FLUTTER EQUIVALENT:
                    // if (authService.currentUser != null) {
                    //   final user = authService.currentUser!;
                    //   // use user
                    // }
                    //
                    // LIQUID GLASS NOTE:
                    // User information display - NO glass effect
                    // This is content (user data), not a control or navigation element
                    // Glass should only be on interactive elements, not information displays
                    if let user = authService.currentUser {
                        VStack(spacing: Constants.UI.spacingSmall) {
                            // Display user's name
                            Text(user.displayName)
                                .font(.headline)
                            // Display user's email
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        // Standard material background for content (not Liquid Glass)
                        // Content should use traditional materials, not glass effects
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Sign out button with proper glass effect implementation
                    // Wrapped in container for proper blending if other glass elements are added later
                    GlassEffectContainer {
                        Button {
                            try? authService.signOut()
                        } label: {
                            Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        // Interactive glass effect for touch response (scale, bounce, shimmer)
                        .glassEffectIfAvailable(.regular.interactive(), in: Capsule())
                        // Unique ID for smooth morphing if button transitions to different states
                        .glassEffectID("account-sign-out-button")
                    }
                }
                .navigationTitle("account_title")
            }
            .tabItem {
                Label(String(localized: "account_title"), systemImage: "person.fill")
            }
        }
        // TabView itself receives glass treatment automatically in iOS 26
        // No need to explicitly apply .glassEffect() - system handles it
    }
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
    func glassEffectIfAvailable(
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
    RootView()
        // Provide mock services for the preview
        .environment(\.services, Services())
        .environment(\.authService, Services().authService)
}