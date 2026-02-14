//
//  AuthService.swift
//  Pour Rice
//
//  Firebase Authentication service for user sign in, sign up, and session management
//  Manages authentication state and provides user profile integration
//

import Foundation
import FirebaseAuth
import Observation

/// Service responsible for all authentication operations
/// Manages Firebase Auth state and user session lifecycle
/// Uses @Observable macro for automatic SwiftUI view updates
@MainActor
@Observable
final class AuthService {

    // MARK: - Published Properties

    /// Currently authenticated user profile
    var currentUser: User?

    /// Authentication state flag
    var isAuthenticated = false

    /// Loading state for async operations
    var isLoading = false

    /// Last authentication error
    var error: Error?

    // MARK: - Private Properties

    /// Firebase Auth instance
    private let auth = Auth.auth()

    /// API client for user profile operations
    private let apiClient: APIClient

    /// Authentication state listener handle
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Initialisation

    /// Creates a new authentication service instance
    /// Automatically starts listening for auth state changes
    /// - Parameter apiClient: API client for profile operations
    init(apiClient: APIClient) {
        self.apiClient = apiClient

        // Set up authentication state listener
        setupAuthStateListener()
    }

    deinit {
        // Remove auth state listener when service is deallocated
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Authentication State

    /// Sets up a listener for Firebase authentication state changes
    /// Automatically updates isAuthenticated and loads user profile
    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }

                self.isAuthenticated = user != nil

                if let user = user {
                    // User is signed in - load their profile
                    do {
                        try await self.loadUserProfile(uid: user.uid)
                    } catch {
                        print("⚠️ Failed to load user profile: \(error.localizedDescription)")
                        self.error = error
                    }
                } else {
                    // User is signed out - clear profile
                    self.currentUser = nil
                }
            }
        }
    }

    // MARK: - Sign In

    /// Signs in a user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Throws: Authentication errors from Firebase
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Authenticate with Firebase
            let result = try await auth.signIn(withEmail: email, password: password)

            // Load user profile from backend
            try await loadUserProfile(uid: result.user.uid)

            print("✅ User signed in successfully: \(result.user.uid)")

        } catch {
            self.error = error
            print("❌ Sign in failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sign Up

    /// Creates a new user account with email and password
    /// Automatically creates user profile in backend database
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password (minimum 6 characters)
    ///   - displayName: User's display name
    /// - Throws: Authentication or API errors
    func signUp(email: String, password: String, displayName: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Create Firebase Auth account
            let result = try await auth.createUser(withEmail: email, password: password)

            // Create user profile in backend
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
    /// - Throws: Sign out errors from Firebase
    func signOut() throws {
        do {
            try auth.signOut()
            currentUser = nil
            isAuthenticated = false
            error = nil

            print("✅ User signed out successfully")

        } catch {
            self.error = error
            print("❌ Sign out failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Token Management

    /// Retrieves the current user's Firebase ID token
    /// Used for authenticated API requests
    /// - Returns: Firebase ID token string
    /// - Throws: APIError.unauthorized if no user is signed in
    func getIDToken() async throws -> String {
        guard let user = auth.currentUser else {
            throw APIError.unauthorized
        }

        do {
            // Force refresh token to ensure it's valid
            let token = try await user.getIDToken(forcingRefresh: true)
            return token
        } catch {
            print("❌ Failed to get ID token: \(error.localizedDescription)")
            throw APIError.unauthorized
        }
    }

    // MARK: - User Profile Management

    /// Loads user profile from backend API
    /// - Parameter uid: Firebase user ID
    /// - Throws: API errors
    private func loadUserProfile(uid: String) async throws {
        let endpoint = APIEndpoint.fetchUserProfile(userId: uid)
        currentUser = try await apiClient.request(endpoint, responseType: User.self)
    }

    /// Creates a new user profile in the backend database
    /// - Parameters:
    ///   - uid: Firebase user ID
    ///   - email: User's email address
    ///   - displayName: User's display name
    /// - Throws: API errors
    private func createUserProfile(uid: String, email: String, displayName: String) async throws {
        let request = CreateUserRequest(
            uid: uid,
            email: email,
            displayName: displayName,
            userType: "customer",
            preferredLanguage: Locale.current.language.languageCode?.identifier ?? "en"
        )

        let endpoint = APIEndpoint.createUserProfile(request)
        currentUser = try await apiClient.request(endpoint, responseType: User.self)
    }

    /// Updates the current user's profile
    /// - Parameter request: Updated profile data
    /// - Throws: API errors or unauthorized if not signed in
    func updateUserProfile(_ request: UpdateUserRequest) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.unauthorized
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
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
    /// - Parameter email: Email address to send reset link to
    /// - Throws: Firebase auth errors
    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordResetEmail(toEmail: email)
            print("✅ Password reset email sent to: \(email)")
        } catch {
            print("❌ Failed to send password reset email: \(error.localizedDescription)")
            throw error
        }
    }
}
