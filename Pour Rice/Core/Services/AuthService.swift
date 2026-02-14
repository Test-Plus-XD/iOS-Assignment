//
//  AuthService.swift
//  Pour Rice
//
//  Firebase Authentication service for user sign in, sign up, and session management
//  Manages authentication state and provides user profile integration
//
//  ============================================================================
//  FOR FLUTTER DEVELOPERS:
//  This is like FirebaseAuth.instance in Flutter, but wrapped in a service class
//  to manage state and integrate with your backend API for user profiles.
//  ============================================================================
//

import Foundation     // Swift's core framework
import FirebaseAuth   // Firebase Authentication SDK
import Observation    // New iOS 17+ framework for reactive state (replaces ObservableObject)

/// Service responsible for all authentication operations
/// Manages Firebase Auth state and user session lifecycle
/// Uses @Observable macro for automatic SwiftUI view updates
///
/// WHAT IS @MainActor:
/// Ensures all code in this class runs on the main thread (UI thread)
/// Like runOnUiThread() in Android or WidgetsBinding.instance.addPostFrameCallback in Flutter
///
/// WHAT IS @Observable:
/// New iOS 17+ macro that makes properties automatically observable
/// When properties change, SwiftUI views automatically rebuild
///
/// FLUTTER EQUIVALENT:
/// class AuthService extends ChangeNotifier {
///   // Your state here
///   void updateState() {
///     notifyListeners(); // @Observable does this automatically!
///   }
/// }
///
/// WHAT IS final:
/// Means this class cannot be subclassed (like final class in Dart/Java)
@MainActor
@Observable
final class AuthService {

    // MARK: - Published Properties
    //
    // These properties are automatically "published" by @Observable
    // Any SwiftUI view watching this service will rebuild when these change
    //
    // FLUTTER EQUIVALENT:
    // These are like properties in a ChangeNotifier
    // But you don't need to call notifyListeners() - @Observable does it!

    /// Currently authenticated user profile from your backend
    /// nil means no user is signed in
    ///
    /// FLUTTER EQUIVALENT:
    /// User? currentUser; (nullable)
    var currentUser: User?

    /// Authentication state flag - true if user is signed in
    ///
    /// WHY WE NEED THIS:
    /// Firebase gives us a user object, but we also need to know if they're authenticated
    /// This is used by RootView to decide whether to show LoginView or MainTabView
    var isAuthenticated = false

    /// Loading state for async operations (sign in, sign up, etc.)
    /// Shows/hides loading spinner in the UI
    ///
    /// FLUTTER EQUIVALENT:
    /// bool isLoading = false;
    var isLoading = false

    /// Last authentication error that occurred
    /// Used to display error messages to the user
    ///
    /// FLUTTER EQUIVALENT:
    /// Exception? error;
    var error: Error?

    // MARK: - Private Properties
    //
    // These are internal to the service and not exposed to views

    /// Firebase Auth instance - the core Firebase authentication object
    ///
    /// FLUTTER EQUIVALENT:
    /// final auth = FirebaseAuth.instance;
    private let auth = Auth.auth()

    /// API client for making HTTP requests to your backend
    /// Used to create/fetch user profiles after Firebase authentication
    private let apiClient: APIClient

    /// Handle for the authentication state listener
    /// We need to keep this to remove the listener when the service is destroyed
    ///
    /// WHAT IS THIS:
    /// Firebase lets us listen to auth state changes (sign in, sign out)
    /// This handle lets us remove the listener later to prevent memory leaks
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Initialisation

    /// Creates a new authentication service instance
    /// Automatically starts listening for auth state changes
    ///
    /// PARAMETERS:
    /// - apiClient: The HTTP client for backend API calls
    ///
    /// WHAT HAPPENS WHEN THIS RUNS:
    /// 1. Stores the API client
    /// 2. Sets up a listener for Firebase auth state changes
    /// 3. That listener will fire immediately if there's already a signed-in user
    init(apiClient: APIClient) {
        self.apiClient = apiClient

        // Start listening for auth state changes (sign in, sign out)
        setupAuthStateListener()
    }

    /// Destructor - called when this service is destroyed
    ///
    /// WHAT IS deinit:
    /// Swift's destructor (like dispose() in Flutter or finalize() in Java)
    /// Called when the object is about to be deallocated from memory
    ///
    /// WHY WE NEED THIS:
    /// We must remove the Firebase listener to prevent memory leaks
    /// If we don't, Firebase will keep calling our listener even after this object is gone
    deinit {
        // Remove the auth state listener if it exists
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Authentication State

    /// Sets up a listener for Firebase authentication state changes
    /// Automatically updates isAuthenticated and loads user profile
    ///
    /// WHEN THIS FIRES:
    /// - Immediately when first set up (if user is already signed in)
    /// - Whenever user signs in
    /// - Whenever user signs out
    /// - When Firebase token is refreshed
    ///
    /// FLUTTER EQUIVALENT:
    /// FirebaseAuth.instance.authStateChanges().listen((User? user) {
    ///   if (user != null) {
    ///     // Load profile
    ///   }
    /// });
    private func setupAuthStateListener() {
        // Add a listener to Firebase Auth state changes
        //
        // PARAMETERS EXPLAINED:
        // - [weak self]: Prevents memory leak by not creating a strong reference cycle
        // - auth: The Firebase Auth instance (always the same as self.auth)
        // - user: The current Firebase user (nil if signed out)
        //
        // WHAT IS [weak self]:
        // Creates a weak reference to avoid retain cycles (memory leaks)
        // Similar to using WeakReference in Java or weak pointers in C++
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            // Task {} creates an async task
            // @MainActor ensures this runs on the UI thread
            //
            // FLUTTER EQUIVALENT:
            // WidgetsBinding.instance.addPostFrameCallback((_) async {
            //   // Your code
            // });
            Task { @MainActor in
                // guard let self = self else { return }
                // This unwraps the weak self reference
                // If self is nil (service was destroyed), return early
                //
                // FLUTTER EQUIVALENT:
                // if (this == null) return;
                guard let self = self else { return }

                // Update authentication state
                // If user exists, we're authenticated
                self.isAuthenticated = user != nil

                if let user = user {
                    // USER IS SIGNED IN
                    // Load their profile from the backend API
                    do {
                        try await self.loadUserProfile(uid: user.uid)
                    } catch {
                        // If loading profile fails, log error but don't sign out
                        print("⚠️ Failed to load user profile: \(error.localizedDescription)")
                        self.error = error
                    }
                } else {
                    // USER IS SIGNED OUT
                    // Clear the current user
                    self.currentUser = nil
                }
            }
        }
    }

    // MARK: - Sign In

    /// Signs in a user with email and password using Firebase
    ///
    /// WHAT THIS DOES:
    /// 1. Authenticates with Firebase
    /// 2. Loads user profile from your backend
    /// 3. Updates UI state (loading, error, authenticated)
    ///
    /// PARAMETERS:
    /// - email: User's email address
    /// - password: User's password (minimum 6 characters for Firebase)
    ///
    /// THROWS:
    /// Authentication errors from Firebase (wrong password, user not found, etc.)
    ///
    /// FLUTTER EQUIVALENT:
    /// Future<void> signIn(String email, String password) async {
    ///   try {
    ///     await FirebaseAuth.instance.signInWithEmailAndPassword(
    ///       email: email,
    ///       password: password,
    ///     );
    ///   } catch (e) {
    ///     throw e;
    ///   }
    /// }
    func signIn(email: String, password: String) async throws {
        // Start loading state (shows loading spinner in UI)
        isLoading = true

        // Clear any previous errors
        error = nil

        // defer ensures this runs when the function exits (success or error)
        // Similar to try-finally in Java/Dart
        // This guarantees isLoading is set to false no matter what happens
        defer { isLoading = false }

        do {
            // STEP 1: Authenticate with Firebase
            // This returns a UserCredential containing the Firebase user
            //
            // FLUTTER EQUIVALENT:
            // final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
            //   email: email,
            //   password: password,
            // );
            let result = try await auth.signIn(withEmail: email, password: password)

            // STEP 2: Load user profile from your backend API
            // Firebase only handles authentication, not user data
            // Your backend stores additional info (display name, photo, etc.)
            try await loadUserProfile(uid: result.user.uid)

            // Log success
            print("✅ User signed in successfully: \(result.user.uid)")

        } catch {
            // If any error occurs, store it and re-throw
            // The UI will display this error to the user
            self.error = error
            print("❌ Sign in failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sign Up

    /// Creates a new user account with email and password
    /// Automatically creates user profile in backend database
    ///
    /// WHAT THIS DOES:
    /// 1. Creates Firebase Auth account
    /// 2. Creates user profile in your backend database
    /// 3. Auto-signs in the user
    ///
    /// PARAMETERS:
    /// - email: User's email address (must be valid email format)
    /// - password: User's password (minimum 6 characters required by Firebase)
    /// - displayName: User's display name (shown in the UI)
    ///
    /// THROWS:
    /// - Firebase errors (email already in use, weak password, etc.)
    /// - API errors (backend database issues)
    ///
    /// FLUTTER EQUIVALENT:
    /// Future<void> signUp(String email, String password, String name) async {
    ///   final userCredential = await FirebaseAuth.instance
    ///       .createUserWithEmailAndPassword(email: email, password: password);
    ///   await createUserProfile(userCredential.user!.uid, email, name);
    /// }
    func signUp(email: String, password: String, displayName: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // STEP 1: Create Firebase Auth account
            // This creates the authentication credentials
            //
            // FLUTTER EQUIVALENT:
            // final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            //   email: email,
            //   password: password,
            // );
            let result = try await auth.createUser(withEmail: email, password: password)

            // STEP 2: Create user profile in your backend
            // Firebase Auth only stores email/password, not user details
            // We store name, preferences, etc. in our own database
            try await createUserProfile(
                uid: result.user.uid,
                email: email,
                displayName: displayName
            )

            print("✅ User account created successfully: \(result.user.uid)")

        } catch {
            self.error = error
            print("❌ Sign up failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sign Out

    /// Signs out the current user
    /// Clears authentication state and user profile
    ///
    /// WHAT THIS DOES:
    /// 1. Signs out from Firebase
    /// 2. Clears currentUser
    /// 3. Sets isAuthenticated to false
    /// 4. RootView will then show LoginView
    ///
    /// THROWS:
    /// Sign out errors (very rare, usually succeeds)
    ///
    /// FLUTTER EQUIVALENT:
    /// Future<void> signOut() async {
    ///   await FirebaseAuth.instance.signOut();
    /// }
    func signOut() throws {
        do {
            // Sign out from Firebase
            try auth.signOut()

            // Clear local state
            currentUser = nil
            isAuthenticated = false
            error = nil

            print("✅ User signed out successfully")

        } catch {
            // If sign out fails (rare), store the error
            self.error = error
            print("❌ Sign out failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Token Management

    /// Retrieves the current user's Firebase ID token
    /// Used for authenticated API requests to your backend
    ///
    /// WHAT IS AN ID TOKEN:
    /// A JWT (JSON Web Token) that proves the user is authenticated
    /// Your backend can verify this token with Firebase to trust the request
    ///
    /// WHY WE NEED THIS:
    /// When making API calls that require authentication, we send this token
    /// in the Authorization header: "Bearer <token>"
    ///
    /// RETURNS:
    /// Firebase ID token string (valid for 1 hour, auto-refreshed)
    ///
    /// THROWS:
    /// APIError.unauthorized if no user is signed in
    ///
    /// FLUTTER EQUIVALENT:
    /// Future<String> getIdToken() async {
    ///   final user = FirebaseAuth.instance.currentUser;
    ///   if (user == null) throw Exception('Not authenticated');
    ///   return await user.getIdToken();
    /// }
    func getIDToken() async throws -> String {
        // Check if user is signed in
        // guard is like an early return if condition fails
        guard let user = auth.currentUser else {
            // No user signed in - throw unauthorized error
            throw APIError.unauthorized
        }

        do {
            // Get ID token from Firebase
            // forcingRefresh: true ensures we get a fresh token
            //
            // WHY FORCE REFRESH:
            // Tokens expire after 1 hour. Force refresh ensures we always have a valid token.
            // Firebase caches tokens, so this is fast if the token is still valid.
            let token = try await user.getIDToken(forcingRefresh: true)
            return token
        } catch {
            print("❌ Failed to get ID token: \(error.localizedDescription)")
            throw APIError.unauthorized
        }
    }

    // MARK: - User Profile Management

    /// Loads user profile from backend API
    ///
    /// WHAT THIS DOES:
    /// Fetches user data (name, email, preferences) from your backend
    /// and stores it in currentUser
    ///
    /// PARAMETERS:
    /// - uid: Firebase user ID (unique identifier)
    ///
    /// THROWS:
    /// API errors if the request fails
    ///
    /// WHY THIS IS PRIVATE:
    /// Only called internally after sign in/sign up
    /// External code shouldn't manually trigger profile loading
    private func loadUserProfile(uid: String) async throws {
        // Build API endpoint for fetching user profile
        let endpoint = APIEndpoint.fetchUserProfile(userId: uid)

        // Make API request and decode response to User object
        // This is type-safe - Swift knows the response is a User
        //
        // FLUTTER EQUIVALENT:
        // final response = await http.get('/users/$uid');
        // final user = User.fromJson(jsonDecode(response.body));
        currentUser = try await apiClient.request(endpoint, responseType: User.self)
    }

    /// Creates a new user profile in the backend database
    ///
    /// WHAT THIS DOES:
    /// After Firebase creates an auth account, we create the user's profile
    /// in our backend with additional information
    ///
    /// PARAMETERS:
    /// - uid: Firebase user ID
    /// - email: User's email
    /// - displayName: User's display name
    ///
    /// THROWS:
    /// API errors if the backend request fails
    private func createUserProfile(uid: String, email: String, displayName: String) async throws {
        // Build the request payload
        // Locale.current gets the user's device language setting
        //
        // WHAT IS Locale:
        // Contains the user's language, region, and formatting preferences
        // Similar to Platform.localeName in Flutter
        let request = CreateUserRequest(
            uid: uid,
            email: email,
            displayName: displayName,
            userType: "customer",  // All new users are customers (not restaurant owners)
            preferredLanguage: Locale.current.language.languageCode?.identifier ?? "en"
        )

        // Send POST request to create user profile
        let endpoint = APIEndpoint.createUserProfile(request)

        // Store the created user profile
        currentUser = try await apiClient.request(endpoint, responseType: User.self)
    }

    /// Updates the current user's profile
    ///
    /// WHAT THIS DOES:
    /// Allows users to update their name, photo, language preference, etc.
    ///
    /// PARAMETERS:
    /// - request: Updated profile data
    ///
    /// THROWS:
    /// - APIError.unauthorized if not signed in
    /// - API errors if update fails
    func updateUserProfile(_ request: UpdateUserRequest) async throws {
        // Ensure user is signed in
        guard let userId = currentUser?.id else {
            throw APIError.unauthorized
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Send PUT request to update profile
            let endpoint = APIEndpoint.updateUserProfile(userId: userId, request)
            currentUser = try await apiClient.request(endpoint, responseType: User.self)

            print("✅ User profile updated successfully")

        } catch {
            self.error = error
            print("❌ Profile update failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Password Management

    /// Sends a password reset email to the specified address
    ///
    /// WHAT THIS DOES:
    /// Firebase sends an email with a link to reset password
    /// User clicks the link, enters new password, done!
    ///
    /// PARAMETERS:
    /// - email: Email address to send reset link to
    ///
    /// THROWS:
    /// Firebase auth errors (invalid email, user not found, etc.)
    ///
    /// FLUTTER EQUIVALENT:
    /// Future<void> sendPasswordReset(String email) async {
    ///   await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    /// }
    func sendPasswordReset(email: String) async throws {
        do {
            // Send password reset email via Firebase
            try await auth.sendPasswordResetEmail(toEmail: email)
            print("✅ Password reset email sent to: \(email)")
        } catch {
            print("❌ Failed to send password reset email: \(error.localizedDescription)")
            throw error
        }
    }
}
