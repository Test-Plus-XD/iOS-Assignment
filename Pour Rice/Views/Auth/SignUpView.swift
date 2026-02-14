//
//  SignUpView.swift
//  Pour Rice
//
//  Liquid Glass variant of the user registration screen
//  Demonstrates Liquid Glass material adoption for authentication UI
//  Applies frosted glass effects exclusively to interactive controls and navigation elements
//
//  LIQUID GLASS IN REGISTRATION FLOWS:
//  - Apply .regular.interactive() to buttons for physics-based touch response
//  - Use GlassEffectContainer to group related action buttons for proper blending
//  - Apply .glassEffectID() for smooth morphing during state transitions
//  - DO NOT apply to form fields, validation messages, or informational content
//  - Keep toggles and switches as standard controls for familiarity
//
//  IMPLEMENTATION STRATEGY:
//  - Glass on primary action button (Create Account)
//  - Glass on secondary navigation (Sign In link)
//  - Standard styling for form inputs and validation feedback
//  - Clear visual hierarchy through selective glass application
//

import SwiftUI

/// Sign up view with Liquid Glass effects on interactive controls only
/// Provides email/password registration with validation following iOS 26+ guidelines
/// Demonstrates proper glass effect usage patterns for form-based authentication
///
/// IMPLEMENTATION NOTES:
/// - Glass effects applied exclusively to action buttons and navigation links
/// - GlassEffectContainer groups related interactive controls for blending
/// - .interactive() enables physics-based response (scale, bounce, shimmer)
/// - .glassEffectID() provides identity for smooth morphing animations
/// - Form fields remain standard styled for content entry clarity
struct SignUpViewLiquidGlass: View {

    // MARK: - Environment

    /// Auth service for sign up operations
    /// Injected via environment for dependency injection and testability
    @Environment(\.authService) private var authService
    /// Dismisses the view
    /// Used to return to login screen after successful registration or cancellation
    @Environment(\.dismiss) private var dismiss

    // MARK: - State Properties

    /// User's display name input
    /// Bound to text field for two-way data flow
    @State private var displayName = ""
    /// User's email address input
    /// Bound to email text field for two-way data flow
    @State private var email = ""
    /// User's password input
    /// Bound to secure field for two-way data flow
    @State private var password = ""
    /// Password confirmation input
    /// Used to verify user entered password correctly
    @State private var confirmPassword = ""
    /// Controls password visibility toggle
    /// When true, displays password as plain text instead of dots
    @State private var isPasswordVisible = false
    /// Controls confirm password visibility toggle
    /// When true, displays confirm password as plain text instead of dots
    @State private var isConfirmPasswordVisible = false
    /// Terms and conditions agreement
    /// User must toggle this to true before creating account
    @State private var agreedToTerms = false
    /// Tracks if sign up is in progress
    /// Used to show loading indicator and disable form during network request
    @State private var isLoading = false
    /// Error message to display
    /// Set when registration fails (email in use, network error, etc.)
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Constants.UI.spacingLarge) {

                // MARK: - Header Section

                VStack(spacing: Constants.UI.spacingSmall) {
                    Text("create_account")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("sign_up_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Constants.UI.spacingLarge)

                // MARK: - Sign Up Form

                // Form fields - NO glass effect applied
                // Text input fields are content entry areas, not navigation or controls
                // Glass effect is reserved for buttons and interactive navigation elements
                VStack(spacing: Constants.UI.spacingMedium) {

                    // Display name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("display_name")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField(String(localized: "display_name_placeholder"), text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    // Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("email")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField(String(localized: "email_placeholder"), text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }

                    // Password field with visibility toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("password")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack {
                            if isPasswordVisible {
                                TextField(String(localized: "password_placeholder"), text: $password)
                                    .textContentType(.newPassword)
                            } else {
                                SecureField(String(localized: "password_placeholder"), text: $password)
                                    .textContentType(.newPassword)
                            }

                            // Eye icon toggle - kept as subtle control without glass
                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        // Password requirements - informational text
                        Text("password_requirements")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Confirm password field with visibility toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("confirm_password")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack {
                            if isConfirmPasswordVisible {
                                TextField(String(localized: "confirm_password_placeholder"), text: $confirmPassword)
                                    .textContentType(.newPassword)
                            } else {
                                SecureField(String(localized: "confirm_password_placeholder"), text: $confirmPassword)
                                    .textContentType(.newPassword)
                            }

                            Button {
                                isConfirmPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isConfirmPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        // Password match indicator - validation feedback
                        // NO glass effect on informational displays
                        if !confirmPassword.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(passwordsMatch ? .green : .red)
                                Text(passwordsMatch ? "passwords_match" : "passwords_dont_match")
                                    .font(.caption)
                                    .foregroundStyle(passwordsMatch ? .green : .red)
                            }
                        }
                    }

                    // Terms and conditions toggle
                    // Standard toggle control - NO glass effect
                    // Toggles work best with familiar native styling for accessibility
                    Toggle(isOn: $agreedToTerms) {
                        HStack(spacing: 4) {
                            Text("i_agree_to")
                                .font(.subheadline)
                            Button {
                                // TODO: Show terms and conditions
                            } label: {
                                Text("terms_and_conditions")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.accent)
                }
                .padding(.horizontal, Constants.UI.spacingLarge)

                // MARK: - Validation Messages

                // Error message - NO glass effect
                // Error displays are informational content, not controls
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding()
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, Constants.UI.spacingLarge)
                }

                // Validation error list - NO glass effect
                // Validation feedback is informational content
                if !validationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(validationErrors, id: \.self) { error in
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, Constants.UI.spacingLarge)
                }

                // MARK: - Action Buttons

                // GlassEffectContainer groups related interactive controls
                // Ensures proper blending when multiple glass elements are near each other
                // Required for smooth morphing animations between glass states
                GlassEffectContainer(spacing: Constants.UI.spacingMedium) {
                    
                    // Primary create account button with interactive glass
                    // .interactive() enables physics-based scale, bounce, shimmer on touch
                    Button {
                        Task {
                            await signUp()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("create_account")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!isFormValid || isLoading)
                    // Interactive glass effect with physics-based response
                    // Capsule shape is ideal for full-width prominent buttons
                    .glassEffectIfAvailable(.regular.interactive(), in: Capsule())
                    // Unique identifier enables smooth state transition animations
                    .glassEffectID("create-account-button")

                    // Secondary sign-in link with glass effect
                    // Navigation element appropriate for glass treatment
                    HStack(spacing: 4) {
                        Text("already_have_account")
                            .foregroundStyle(.secondary)

                        Button {
                            dismiss()
                        } label: {
                            Text("sign_in")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        // Subtle glass effect for secondary action
                        // .clear variant provides minimal glass treatment for hierarchy
                        .glassEffectIfAvailable(.clear, in: Capsule())
                        .glassEffectID("sign-in-link")
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, Constants.UI.spacingLarge)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Form Validation

    /// Validates if all form fields are properly filled
    /// Checks display name, email format, password requirements, and terms agreement
    /// - Returns: true if form is valid, false otherwise
    private var isFormValid: Bool {
        return !displayName.isEmpty &&
               !email.isEmpty &&
               email.contains("@") &&
               password.count >= 6 &&
               passwordsMatch &&
               agreedToTerms
    }

    /// Checks if passwords match
    /// Compares password and confirmPassword fields for equality
    /// - Returns: true if both passwords match and are non-empty, false otherwise
    private var passwordsMatch: Bool {
        return !password.isEmpty && password == confirmPassword
    }

    /// Returns array of validation error messages
    /// Provides real-time feedback on form field requirements
    /// Displayed below form when validation issues are present
    /// - Returns: Array of localised validation error strings
    private var validationErrors: [String] {
        var errors: [String] = []

        if !displayName.isEmpty && displayName.count < 2 {
            errors.append(String(localized: "error_name_too_short"))
        }

        if !email.isEmpty && !email.contains("@") {
            errors.append(String(localized: "error_invalid_email"))
        }

        if !password.isEmpty && password.count < 6 {
            errors.append(String(localized: "error_password_too_short"))
        }

        if !confirmPassword.isEmpty && !passwordsMatch {
            errors.append(String(localized: "error_passwords_dont_match"))
        }

        return errors
    }

    // MARK: - Actions

    /// Attempts to create a new user account
    /// Sends registration request to Firebase with email, password, and display name
    /// Provides haptic feedback and handles success/error states
    /// On success, AuthService updates app state to navigate to main screen
    private func signUp() async {
        errorMessage = nil
        isLoading = true

        // Provide haptic feedback when user taps create account button
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        do {
            try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )

            // Success haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

        } catch {
            // Show error message to user
            errorMessage = error.localizedDescription

            // Error haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }

        isLoading = false
    }
}

// MARK: - View Extension for Backwards Compatibility

extension View {
    /// Applies Liquid Glass effect if available on iOS 26+, otherwise falls back to ultraThinMaterial
    /// Provides graceful degradation for older iOS versions whilst maintaining modern appearance
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
            self.glassEffect(glass, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Preview

/// SwiftUI preview for design-time development
/// Shows sign-up view with Liquid Glass effects in Xcode canvas
#Preview {
    NavigationStack {
        SignUpViewLiquidGlass()
            .environment(\.authService, AuthService(apiClient: DefaultAPIClient()))
    }
}