//
//  Pour_RiceApp.swift
//  Pour Rice
//
//  Main application entry point for Pour Rice restaurant discovery app
//  Follows iOS 17+ architecture with @Observable macro and modern Swift concurrency
//  Configures Firebase and manages authentication state
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is like your main.dart file in Flutter. It's the entry point where
//  your app starts. In Flutter you have main() and runApp(), in iOS/SwiftUI
//  we use the @main attribute to mark the entry point.
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
    // (MARK creates a separator in Xcode's code navigator for organization)

    /// App delegate for Firebase initialization
    ///
    /// WHAT THIS DOES:
    /// Connects our AppDelegate class (which initializes Firebase) to this SwiftUI app
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

    /// Centralized services container for dependency injection
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

// MARK: - Main Tab View (Placeholder)

/// Main tab-based navigation structure for the app
/// This is a placeholder - will be fully implemented in Sprint 5
///
/// FLUTTER EQUIVALENT:
/// Scaffold(
///   bottomNavigationBar: BottomNavigationBar(...),
///   body: pages[currentIndex],
/// )
struct MainTabView: View {

    // MARK: - Environment

    /// Access to app-wide services (injected from Pour_RiceApp)
    @Environment(\.services) private var services

    /// Auth service for sign out functionality
    @Environment(\.authService) private var authService

    // MARK: - Body

    var body: some View {
        // TabView creates a bottom tab bar navigation
        //
        // FLUTTER EQUIVALENT:
        // Scaffold with BottomNavigationBar
        //
        // Each section in {} becomes a tab
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
                    Image(systemName: "house.fill")
                        .resizable()          // Makes image resizable (like fit: BoxFit.contain)
                        .scaledToFit()        // Maintains aspect ratio
                        .frame(width: 60, height: 60)  // Sets size (like SizedBox)
                        .foregroundStyle(.accent)       // Color from Assets.xcassets accent color

                    // Text widget for displaying text (same as Flutter's Text)
                    // "home_title" is a localized string key
                    // iOS will automatically show English or Chinese based on device language
                    Text("home_title")
                        .font(.title)          // Predefined font size (like Theme.of(context).textTheme.title)
                        .fontWeight(.bold)     // Bold text

                    Text("coming_soon")
                        .foregroundStyle(.secondary)  // Secondary color (grayed out)

                    // SIGN OUT BUTTON (temporary for testing)
                    //
                    // Button has two parts: action {} and label {}
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
                    }
                    .buttonStyle(.bordered)  // Apply bordered button style (outline)
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
                    }

                    // Sign out button
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
