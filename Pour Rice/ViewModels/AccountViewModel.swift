//
//  AccountViewModel.swift
//  Pour Rice
//
//  ViewModel for the Account/Profile screen
//  Exposes user profile data and handles sign-out
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This ViewModel is intentionally thin — it mainly wraps AuthService,
//  which already owns the user state (@Observable propagates changes).
//
//  FLUTTER EQUIVALENT:
//  class AccountViewModel extends ChangeNotifier {
//    final AuthService _authService;
//    User? get currentUser => _authService.currentUser;
//    Future<void> signOut() => _authService.signOut();
//  }
//  ============================================================================
//

import Foundation
import Observation

// MARK: - Account View Model

/// ViewModel for the account/profile screen
/// Wraps AuthService to expose user data and sign-out functionality
@MainActor
@Observable
final class AccountViewModel {

    // MARK: - State

    /// Whether a sign-out operation is in progress
    var isSigningOut = false

    /// Error message if sign-out failed
    var errorMessage: String?

    // MARK: - Dependencies

    private let authService: AuthService

    // MARK: - Computed Properties

    /// The currently authenticated user, or nil if not signed in
    var currentUser: User? {
        authService.currentUser
    }

    /// Display name (falls back to email prefix if name is empty)
    var displayName: String {
        guard let user = authService.currentUser else { return "" }
        let name = user.displayName
        if name.isEmpty {
            // Use the part before @ in the email as a fallback display name
            return user.email.components(separatedBy: "@").first ?? user.email
        }
        return name
    }

    /// User email address
    var email: String {
        authService.currentUser?.email ?? ""
    }

    /// User account type display string
    var accountTypeDisplay: String {
        switch authService.currentUser?.userType {
        case .owner:
            return String(localized: "account_type_owner")
        case .customer, .none:
            return String(localized: "account_type_customer")
        }
    }

    /// Preferred language display label
    var preferredLanguageDisplay: String {
        switch authService.currentUser?.preferredLanguage {
        case "zh-Hant":
            return String(localized: "language_tc")
        default:
            return String(localized: "language_en")
        }
    }

    // MARK: - Initialisation

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Actions

    /// Signs the user out of the app
    func signOut() {
        isSigningOut = true
        errorMessage = nil
        do {
            try authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningOut = false
    }
}
