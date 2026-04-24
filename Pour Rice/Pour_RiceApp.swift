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
        self.appDelegate.configure(notificationCoordinator: services.notificationCoordinatorService)
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
                .environment(\.services, services)
                .environment(\.authService, services.authService)
                // NOTE: onOpenURL is intentionally placed on RootView (below), not here.
                // RootView needs @Environment(\.services) to fetch restaurants for deep links,
                // and environment values are not available on the WindowGroup content before
                // the view is inserted into the hierarchy. The .environment() injections above
                // are visible to RootView's body, but a modifier on WindowGroup itself runs
                // before those injections propagate — so the handler is on RootView instead.
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

    /// Services container used to fetch a restaurant when a pourrice:// deep link is received.
    /// Must live here (not in Pour_RiceApp.body) because @Environment is only available
    /// inside View conformers, not inside Scene.body modifiers.
    @Environment(\.services) private var services

    // MARK: - State

    /// Guest browsing mode — allows unauthenticated users to browse Home, Search,
    /// and Restaurant pages. The Account tab prompts them to sign in.
    @State private var isGuest = false

    /// Persisted language preference ("en" or "zh-Hant") stored in UserDefaults.
    /// @AppStorage watches UserDefaults — when AccountView's Picker changes this value,
    /// SwiftUI rebuilds body and re-injects the new locale into the entire view tree,
    /// causing all String(localized:) calls to instantly switch language without restart.
    ///
    /// Placed here in RootView (a View) rather than Pour_RiceApp (an App) because
    /// @AppStorage reliably triggers body re-evaluation on View conformers, whereas
    /// Scene body re-evaluation from App-level @AppStorage is unreliable.
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"

    /// Persisted theme preference ("light", "dark", or "system").
    /// Applied globally so the interface switches immediately after login/profile sync.
    @AppStorage("preferredTheme") private var preferredTheme = "system"

    // MARK: - Deep Link State

    /// Holds the restaurantId extracted from an incoming pourrice://menu/{id} URL.
    ///
    /// Flow:
    ///  onOpenURL (synchronous) → set pendingDeepLinkId
    ///  .onChange(of: pendingDeepLinkId) → async fetch → set deepLinkRestaurant → show sheet
    ///
    /// Using a String? here rather than MenuNavigation? because onOpenURL is synchronous —
    /// we cannot await the restaurant name fetch inside the handler.
    /// The async fetch and sheet presentation are handled in .onChange below.
    @State private var pendingDeepLinkId: String?

    /// The fully-fetched Restaurant object for the pending deep link.
    /// Set by the .onChange task after a successful API call.
    /// Cleared in the sheet's onDismiss callback.
    @State private var deepLinkRestaurant: Restaurant?

    /// Drives the deep link MenuView sheet presentation.
    @State private var showingDeepLinkMenu = false

    /// Maps the saved theme preference to SwiftUI's optional ColorScheme override.
    private var appColorScheme: ColorScheme? {
        switch preferredTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

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
        // LANGUAGE TOGGLE:
        // Re-injects locale whenever @AppStorage("preferredLanguage") changes.
        // This causes all String(localized:) in the tree to pick up the new language
        // without an app restart. BilingualText.localised also reads UserDefaults
        // directly, so dynamic API data (restaurant names etc.) switches too.
        .environment(\.locale, Locale(identifier: preferredLanguage))
        .preferredColorScheme(appColorScheme)
        // ── URL / Deep Link Handling ──────────────────────────────────────
        // Handles both Google Sign-In OAuth callbacks AND Pour Rice QR deep links.
        //
        // Placed here on RootView.body (not on WindowGroup in Pour_RiceApp.body)
        // so that @Environment(\.services) is accessible for the async restaurant fetch.
        //
        // FLUTTER EQUIVALENT:
        // In Flutter you'd listen to a Stream from the uni_links package.
        // In iOS, the OS delivers URLs directly to this modifier on scene resume.
        //
        // ANDROID EQUIVALENT:
        // The Android app has NO OS-level deep link handling (no intent-filter in
        // AndroidManifest.xml). iOS requires the Info.plist scheme registration
        // and this handler for the OS to route pourrice:// URLs to the app.
        .onOpenURL { url in
            // ── Google Sign-In OAuth ──────────────────────────────────────
            // Passes the URL to Google's SDK first — it returns true if it handled it.
            // Must remain as the first call so OAuth token exchanges are never lost.
            _ = GIDSignIn.sharedInstance.handle(url)

            // ── Pour Rice QR Deep Link ────────────────────────────────────
            // Stripe Checkout returns through pourrice://store?... while the ad sheet is active.
            if url.scheme == Constants.DeepLink.scheme,
               url.host == Constants.DeepLink.storeHost {
                NotificationCenter.default.post(name: .storeStripeReturnURL, object: url)
                return
            }

            // Only handle URLs matching pourrice://menu/{restaurantId}.
            // All other schemes (including Google's reverse client ID) fall through
            // to GIDSignIn.handle above and are ignored here.
            guard url.scheme == Constants.DeepLink.scheme,          // "pourrice"
                  url.host == Constants.DeepLink.menuHost,           // "menu"
                  let restaurantId = url.pathComponents               // ["/" , "abc123"]
                      .dropFirst()                                     // ["abc123"]
                      .first,                                          // "abc123"
                  !restaurantId.isEmpty
            else { return }

            // Store the ID; the async fetch happens in .onChange below.
            // onOpenURL is a synchronous callback — we cannot await here.
            pendingDeepLinkId = restaurantId
        }
        // ── Async restaurant fetch triggered by deep link ─────────────────
        // .onChange fires on the main actor whenever pendingDeepLinkId changes.
        // It launches a Task to fetch the restaurant, then presents the menu sheet.
        //
        // WHY .onChange instead of fetching inside onOpenURL:
        //   onOpenURL is a synchronous closure. Swift async/await requires an async
        //   context. .onChange provides one via Task { } on the main actor.
        .onChange(of: pendingDeepLinkId) { _, newId in
            guard let restaurantId = newId else { return }

            Task {
                do {
                    // Fetch restaurant details from GET /API/Restaurants/{id}
                    // RestaurantService caches results — repeat opens of the same QR are free
                    let restaurant = try await services.restaurantService.fetchRestaurant(id: restaurantId)
                    deepLinkRestaurant = restaurant
                    showingDeepLinkMenu = true
                } catch {
                    // Silently discard — a broken deep link should not crash or confuse the user.
                    // The app simply stays on the current screen (same as Android behaviour).
                    print("❌ Deep link restaurant fetch failed for id '\(restaurantId)': \(error)")
                }
                // Clear the pending ID regardless of success/failure so repeated
                // taps on the same QR code fire a fresh .onChange next time
                pendingDeepLinkId = nil
            }
        }
        // ── Deep link sheet ───────────────────────────────────────────────
        // Presents MenuView modally when a valid pourrice:// deep link is opened.
        // Modal presentation (not push navigation) is used because:
        //   1. We don't know which tab is active when the URL arrives
        //   2. Modal sheets layer on top of the current UI without disrupting tab state
        //   3. The user can dismiss with a swipe to return exactly where they were
        //
        // NavigationStack wrapper gives MenuView its own navigation bar with a
        // back/done button. Without it, MenuView renders without any chrome.
        .sheet(isPresented: $showingDeepLinkMenu, onDismiss: {
            // Release the restaurant object when dismissed to free memory
            deepLinkRestaurant = nil
        }) {
            if let restaurant = deepLinkRestaurant {
                NavigationStack {
                    MenuView(
                        restaurantId: restaurant.id,
                        restaurantName: restaurant.name.localised
                    )
                }
            }
        }
        // ── Foreground FCM banner ─────────────────────────────────────────
        // App-rendered foreground notification banner for chat and booking pushes.
        // iOS background notifications are still shown by APNs; this overlay is only
        // for the active foreground app where we suppress the system visual banner.
        .overlay(alignment: .top) {
            notificationBannerOverlay
        }
        // ── Auth-driven FCM token sync ─────────────────────────────────────
        // Permission and backend token registration are attempted only after
        // the profile has loaded, because notification preferences live there.
        .task {
            await services.notificationCoordinatorService.synchroniseForCurrentUser(reason: "root-task")
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            Task {
                await services.notificationCoordinatorService.synchroniseForCurrentUser(reason: "auth-user-change")
            }
        }
        .onChange(of: authService.currentUser?.notificationsEnabled) { _, _ in
            Task {
                await services.notificationCoordinatorService.synchroniseForCurrentUser(reason: "notification-preference-change")
            }
        }
    }

    // MARK: - Foreground Notification Banner

    /// App-level banner shown for foreground FCM notifications that are not suppressed.
    private var notificationBannerOverlay: some View {
        Group {
            if let banner = services.notificationCoordinatorService.banner {
                Button {
                    services.notificationCoordinatorService.openBanner(banner)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.title3)
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(banner.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            if !banner.body.isEmpty {
                                Text(banner.body)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: services.notificationCoordinatorService.banner?.id)
    }
}

// MARK: - Main Tab View

/// Stable tab identifiers used for programmatic notification routing.
private enum AppTab: Hashable {
    case home
    case search
    case bookings
    case store
    case chat
    case account
}

/// Main tab-based navigation structure for the app with Liquid Glass effects (iOS 26+)
/// Adapts tabs based on the user's account type:
///   - Guest:            Home | Search | Account
///   - Diner:            Home | Search | Bookings | Chat | Account
///   - Restaurant Owner: Home | Search | Store    | Chat | Account
///
/// Gemini AI is accessible from RestaurantView and AccountView (no dedicated tab).
///
/// LIQUID GLASS IMPLEMENTATION NOTES:
/// - TabView automatically receives glass treatment in iOS 26
/// - NavigationDestination registers type-safe push routes for each stack
struct MainTabView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - Guest Mode

    /// Binding to guest browsing state from RootView.
    /// Passed to AccountView so it can exit guest mode when the user taps "Sign In".
    @Binding var isGuest: Bool

    // MARK: - Type Selection Toast

    /// Set to `true` by the sheet's `onDismiss` after the user picks their account type.
    @State private var showTypeSelectionToast = false

    /// Currently selected tab, allowing notification taps to route into Chat, Bookings, or Store.
    @State private var selectedTab: AppTab = .home

    /// Store navigation path used to push restaurant-owner booking management from notifications.
    @State private var storeNavigationPath = NavigationPath()

    /// Chat navigation path used to push a specific room from notifications.
    @State private var chatNavigationPath = NavigationPath()

    // MARK: - Computed

    /// Convenience: true when the signed-in user is a restaurant owner
    private var isRestaurantOwner: Bool {
        authService.currentUser?.userType == .restaurant
    }

    /// Convenience: true when the signed-in user is a diner
    private var isDiner: Bool {
        !isGuest && authService.isAuthenticated && !isRestaurantOwner
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {

            // ================================================================
            // HOME TAB — restaurant discovery + featured carousel
            // ================================================================

            Tab("home_title", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack {
                    HomeView()
                        .navigationDestination(for: Restaurant.self) { restaurant in
                            RestaurantView(restaurant: restaurant)
                        }
                        .navigationDestination(for: MenuNavigation.self) { nav in
                            MenuView(restaurantId: nav.restaurantId, restaurantName: nav.restaurantName)
                        }
                        .navigationDestination(for: GeminiNavigation.self) { nav in
                            GeminiChatView(restaurant: nav.restaurant)
                        }
                        .navigationDestination(for: ChatRoom.self) { room in
                            ChatRoomView(room: room)
                        }
                }
            }

            // ================================================================
            // SEARCH TAB — Algolia-powered restaurant search
            // ================================================================

            Tab("search_title", systemImage: "magnifyingglass", value: AppTab.search) {
                NavigationStack {
                    SearchView()
                        .navigationDestination(for: Restaurant.self) { restaurant in
                            RestaurantView(restaurant: restaurant)
                        }
                        .navigationDestination(for: MenuNavigation.self) { nav in
                            MenuView(restaurantId: nav.restaurantId, restaurantName: nav.restaurantName)
                        }
                        .navigationDestination(for: GeminiNavigation.self) { nav in
                            GeminiChatView(restaurant: nav.restaurant)
                        }
                        .navigationDestination(for: ChatRoom.self) { room in
                            ChatRoomView(room: room)
                        }
                }
            }

            // ================================================================
            // BOOKINGS TAB — diner reservations (authenticated diners only)
            // ================================================================

            if isDiner {
                Tab("bookings_title", systemImage: "calendar", value: AppTab.bookings) {
                    NavigationStack {
                        BookingsView()
                    }
                }
            }

            // ================================================================
            // STORE TAB — restaurant owner dashboard (restaurant owners only)
            // ================================================================

            if !isGuest && isRestaurantOwner {
                Tab("store_title", systemImage: "storefront.fill", value: AppTab.store) {
                    NavigationStack(path: $storeNavigationPath) {
                        StoreView()
                            .navigationDestination(for: StoreDestination.self) { destination in
                                switch destination {
                                case .manageMenu:
                                    StoreMenuManageView()
                                case .bookings:
                                    StoreBookingsView()
                                case .reviews:
                                    Text("store_reviews_placeholder")
                                        .navigationTitle("store_view_reviews")
                                case .editInfo:
                                    StoreInfoEditView()
                                case .advertisements:
                                    if let restaurantId = authService.currentUser?.restaurantId {
                                        StoreAdsView(restaurantId: restaurantId)
                                    }
                                }
                            }
                            // Restaurant detail navigation from storefront icon
                            .navigationDestination(for: Restaurant.self) { restaurant in
                                RestaurantView(restaurant: restaurant)
                            }
                            .navigationDestination(for: GeminiNavigation.self) { nav in
                                GeminiChatView(restaurant: nav.restaurant)
                            }
                            .navigationDestination(for: ChatRoom.self) { room in
                                ChatRoomView(room: room)
                            }
                    }
                }
            }

            // ================================================================
            // CHAT TAB — real-time messaging (authenticated users only)
            // ================================================================

            if !isGuest && authService.isAuthenticated {
                Tab("chat_title", systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.chat) {
                    NavigationStack(path: $chatNavigationPath) {
                        ChatListView()
                            .navigationDestination(for: ChatRoom.self) { room in
                                ChatRoomView(room: room)
                            }
                    }
                }
            }

            // ================================================================
            // ACCOUNT TAB — user profile, preferences, and sign-out
            // ================================================================

            Tab("account_title", systemImage: "person.fill", value: AppTab.account) {
                NavigationStack {
                    AccountView(isGuest: $isGuest)
                        .navigationDestination(for: GeminiNavigation.self) { nav in
                            GeminiChatView(restaurant: nav.restaurant)
                        }
                }
            }
        }
        // ── User Type Selection Sheet ─────────────────────────────────────────
        // Shown automatically for brand-new accounts until the user picks a type.
        // The binding is read-only (set: { _ in }) because dismissal is controlled
        // entirely by `authService.needsTypeSelection` becoming false after the
        // API call in UserTypeSelectionView.
        // `.interactiveDismissDisabled(true)` inside the sheet prevents swipe-dismiss.
        .sheet(
            isPresented: Binding(
                get: { authService.needsTypeSelection },
                set: { _ in }
            ),
            onDismiss: {
                showTypeSelectionToast = true
            }
        ) {
            UserTypeSelectionView()
        }
        .toast(
            message: String(localized: "toast_user_type_saved", bundle: L10n.bundle),
            style: .success,
            isPresented: $showTypeSelectionToast
        )
        .task {
            handlePendingNotificationRouteIfAvailable()
        }
        .onChange(of: services.notificationCoordinatorService.routeRequest) { _, _ in
            handlePendingNotificationRouteIfAvailable()
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            handlePendingNotificationRouteIfAvailable()
        }
        .onChange(of: authService.currentUser?.userType.rawValue) { _, _ in
            handlePendingNotificationRouteIfAvailable()
        }
    }

    // MARK: - Notification Routing

    /// Applies one-shot route requests emitted by NotificationCoordinatorService.
    private func handlePendingNotificationRouteIfAvailable() {
        guard let request = services.notificationCoordinatorService.routeRequest,
              !isGuest,
              authService.currentUser != nil else { return }

        switch request.route {
        case .bookings:
            if isRestaurantOwner {
                selectedTab = .store
                storeNavigationPath = NavigationPath()
                storeNavigationPath.append(StoreDestination.bookings)
            } else if isDiner {
                selectedTab = .bookings
            } else {
                return
            }

        case .chat(let roomId):
            selectedTab = .chat
            chatNavigationPath = NavigationPath()
            chatNavigationPath.append(ChatRoom.placeholder(roomId: roomId, name: String(localized: "chat_conversation", bundle: L10n.bundle)))
        }

        services.notificationCoordinatorService.clearRouteRequest(request)
    }
}

// MARK: - Gemini Navigation Value

/// Hashable navigation value for pushing GeminiChatView with optional restaurant context
struct GeminiNavigation: Hashable {
    /// Optional restaurant to provide context to the AI assistant
    let restaurant: Restaurant?

    func hash(into hasher: inout Hasher) {
        hasher.combine(restaurant?.id)
    }

    static func == (lhs: GeminiNavigation, rhs: GeminiNavigation) -> Bool {
        lhs.restaurant?.id == rhs.restaurant?.id
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
