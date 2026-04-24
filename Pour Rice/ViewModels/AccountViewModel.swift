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

    // MARK: - Profile Editing State

    /// Whether the profile edit sheet is presented
    var isEditing = false

    /// Edit buffer for display name
    var editDisplayName = ""

    /// Edit buffer for phone number
    var editPhoneNumber = ""

    /// Edit buffer for bio
    var editBio = ""

    /// Edit buffer for preferred theme
    var editTheme = "system"

    /// Edit buffer for notifications enabled
    var editNotifications = true

    /// Whether a profile save operation is in progress
    var isSaving = false

    /// Whether the success/error toast is visible
    var showToast = false

    /// Toast message text
    var toastMessage = ""

    /// Toast style (success, error, info)
    var toastStyle: ToastStyle = .success

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
        case .restaurant:
            return String(localized: "account_type_owner", bundle: L10n.bundle)
        case .diner, .none:
            return String(localized: "account_type_customer", bundle: L10n.bundle)
        }
    }

    /// Preferred language display label
    var preferredLanguageDisplay: String {
        switch authService.currentUser?.preferredLanguage {
        case "zh-Hant":
            return String(localized: "language_tc", bundle: L10n.bundle)
        default:
            return String(localized: "language_en", bundle: L10n.bundle)
        }
    }

    /// Current preferred language code ("en" or "zh-Hant")
    /// Used to drive the language Picker selection in AccountView
    var preferredLanguage: String {
        authService.currentUser?.preferredLanguage ?? "en"
    }

    /// Preferred theme display label
    var themeDisplay: String {
        switch authService.currentUser?.preferredTheme {
        case "light":
            return String(localized: "theme_light", bundle: L10n.bundle)
        case "dark":
            return String(localized: "theme_dark", bundle: L10n.bundle)
        default:
            return String(localized: "theme_system", bundle: L10n.bundle)
        }
    }

    /// Notifications enabled display label
    var notificationsDisplay: String {
        if authService.currentUser?.notificationsEnabled ?? true {
            return String(localized: "notifications_enabled", bundle: L10n.bundle)
        } else {
            return String(localized: "notifications_disabled", bundle: L10n.bundle)
        }
    }

    // MARK: - Initialisation

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Profile Editing Computed

    /// Whether the edit buffers differ from the current user profile
    var hasChanges: Bool {
        guard let user = authService.currentUser else { return false }
        return editDisplayName != user.displayName
            || editPhoneNumber != (user.phoneNumber ?? "")
            || editBio != (user.bio ?? "")
            || editTheme != user.preferredTheme
            || editNotifications != user.notificationsEnabled
    }

    // MARK: - Actions

    /// Populates edit buffers from the current user profile and presents the edit sheet
    func startEditing() {
        guard let user = authService.currentUser else { return }
        editDisplayName = user.displayName
        editPhoneNumber = user.phoneNumber ?? ""
        editBio = user.bio ?? ""
        editTheme = user.preferredTheme
        editNotifications = user.notificationsEnabled
        isEditing = true
    }

    /// Saves the edited profile fields to the backend and dismisses the sheet
    func saveProfile() async {
        guard let user = authService.currentUser else { return }
        isSaving = true
        errorMessage = nil

        let request = UpdateUserRequest(
            displayName: editDisplayName != user.displayName ? editDisplayName : nil,
            phoneNumber: editPhoneNumber != (user.phoneNumber ?? "") ? editPhoneNumber : nil,
            bio: editBio != (user.bio ?? "") ? editBio : nil,
            theme: editTheme != user.preferredTheme ? editTheme : nil,
            notifications: editNotifications != user.notificationsEnabled ? editNotifications : nil
        )

        do {
            try await authService.updateUserProfile(request)
            isEditing = false
            toastMessage = String(localized: "profile_saved_success", bundle: L10n.bundle)
            toastStyle = .success
            showToast = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    /// Updates the user's preferred language in UserDefaults and persists it to the backend
    ///
    /// Writing to UserDefaults triggers the @AppStorage("preferredLanguage") watcher in
    /// Pour_RiceApp, which re-injects the new locale environment — instantly switching all
    /// String(localized:) calls. BilingualText.localised also reads UserDefaults directly.
    ///
    /// - Parameter code: Language code to switch to ("en" or "zh-Hant")
    func updateLanguage(_ code: String) async {
        // Immediately write to UserDefaults so the UI switches without waiting for the API
        UserDefaults.standard.set(code, forKey: "preferredLanguage")

        // Persist the preference to the backend
        let request = UpdateUserRequest(displayName: nil, photoURL: nil, preferredLanguage: code)
        do {
            try await authService.updateUserProfile(request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Signs the user out of the app
    func signOut() {
        isSigningOut = true
        errorMessage = nil
        Task { @MainActor in
            defer { isSigningOut = false }

            do {
                try await authService.signOut()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}