//
//  LoginView.swift
//  Pour Rice
//
//  Liquid Glass variant of the login screen
//  Demonstrates Liquid Glass material adoption for authentication UI
//  Applies frosted glass effects exclusively to interactive controls and navigation elements
//
//  LIQUID GLASS IN AUTH FLOWS:
//  - Apply .regular.interactive() to buttons for touch response (scale, bounce, shimmer)
//  - Use GlassEffectContainer to group related interactive controls for proper blending
//  - Apply .glassEffectID() for smooth morphing during state transitions
//  - DO NOT apply to logos, form containers, or content displays
//  - Modals and sheets receive glass treatment automatically in navigation layer
//
//  PRINCIPLE VIOLATION TO AVOID:
//  - Never apply glass to text input fields (they're content, not navigation)
//  - Never apply glass to logos or branding elements
//  - Never apply glass to information displays (error messages, user data)
//  - Only apply to buttons, toggles, and other interactive controls
//

import SwiftUI

/// Login view with Liquid Glass effects on interactive controls only
/// Enhances authentication form with frosted glass material following Apple HIG
/// Demonstrates proper glass effect usage patterns for iOS 26+
///
/// IMPLEMENTATION NOTES:
/// - Glass effects applied exclusively to interactive controls (buttons)
/// - GlassEffectContainer groups related glass elements for proper blending
/// - .interactive() enables physics-based response to touch/hover
/// - .glassEffectID() provides identity for smooth morphing animations
/// - Backwards compatibility ensures graceful fallback for iOS 25 and earlier
struct LoginViewLiquidGlass: View {

    // MARK: - Environment

    /// Auth service for sign-in operations
    /// Injected via environment for dependency injection and testability
    @Environment(\.authService) private var authService

    // MARK: - State Properties

    /// User's email address input
    /// Bound to email text field for two-way data flow
    @State private var email = ""
    /// User's password input
    /// Bound to secure field for two-way data flow
    @State private var password = ""
    /// Controls password visibility toggle
    /// When true, displays password as plain text instead of dots
    @State private var isPasswordVisible = false
    /// Tracks if sign-in is in progress
    /// Used to show loading indicator and disable form during network request
    @State private var isLoading = false
    /// Error message to display
    /// Set when authentication fails (invalid credentials, network error, etc.)
    @State private var errorMessage: String?
    /// Controls navigation to sign-up screen
    /// Triggers when user taps "Sign Up" link
    @State private var showingSignUp = false
    /// Controls password reset sheet presentation
    /// Shows modal sheet for password reset flow
    @State private var showingPasswordReset = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.UI.spacingLarge) {

                    // MARK: - Logo & Title Section

                    VStack(spacing: Constants.UI.spacingMedium) {
                        // App logo - NO glass effect applied
                        // Logos are branding/content, not interactive controls
                        // Glass should only be applied to navigation and control layer
                        Image(systemName: "fork.knife.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(.accent)

                        Text("app_name")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("login_subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Constants.UI.spacingExtraLarge)

                    // MARK: - Login Form

                    // Form fields - NO glass effect applied
                    // Text input fields are content entry areas, not navigation/controls
                    // Glass effect is reserved for buttons and interactive navigation elements
                    VStack(spacing: Constants.UI.spacingMedium) {

                        // Email field with label
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
                                        .textContentType(.password)
                                } else {
                                    SecureField(String(localized: "password_placeholder"), text: $password)
                                        .textContentType(.password)
                                }

                                // Eye icon toggle button - could have glass, but better as subtle control
                                // Kept without glass to maintain focus on primary actions
                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                        }

                        // Forgot password button with glass effect
                        // This is a navigational control, appropriate for glass treatment
                        HStack {
                            Spacer()
                            Button {
                                showingPasswordReset = true
                            } label: {
                                Text("forgot_password")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                            // Interactive glass effect for touch response
                            // Capsule shape suits pill-style text buttons
                            .glassEffectIfAvailable(.regular.interactive(), in: Capsule())
                            // Unique ID for smooth morphing if button changes state
                            .glassEffectID("forgot-password-button")
                        }
                    }
                    .padding(.horizontal, Constants.UI.spacingLarge)

                    // MARK: - Error Message

                    // Error message - NO glass effect
                    // Error text is informational content, not a control
                    // Display errors with standard styling for clarity
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding()
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, Constants.UI.spacingLarge)
                    }

                    // MARK: - Primary Action Buttons

                    // GlassEffectContainer groups related interactive controls
                    // Ensures proper blending when multiple glass elements are near each other
                    // Required for smooth morphing animations between glass states
                    GlassEffectContainer(spacing: Constants.UI.spacingMedium) {
                        
                        // Primary sign-in button with interactive glass
                        // .interactive() enables physics-based scale, bounce, shimmer on touch
                        Button {
                            Task {
                                await signIn()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("sign_in")
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
                        .glassEffectID("sign-in-button")

                        // Secondary sign-up link with glass effect
                        HStack(spacing: 4) {
                            Text("no_account")
                                .foregroundStyle(.secondary)

                            Button {
                                showingSignUp = true
                            } label: {
                                Text("sign_up")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                            // Subtle glass effect for secondary action
                            // .clear variant provides minimal glass treatment for hierarchy
                            .glassEffectIfAvailable(.clear, in: Capsule())
                            .glassEffectID("sign-up-link")
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal, Constants.UI.spacingLarge)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpViewLiquidGlass()
            }
            // Password reset sheet automatically receives glass treatment in iOS 26
            // Sheets and modals are part of navigation layer and get glass by default
            .sheet(isPresented: $showingPasswordReset) {
                PasswordResetViewLiquidGlass(email: email)
            }
        }
    }

    // MARK: - Form Validation

    /// Validates if the form fields are properly filled
    /// Checks for non-empty email with @ symbol and minimum password length
    /// - Returns: true if form is valid, false otherwise
    private var isFormValid: Bool {
        return !email.isEmpty &&
               email.contains("@") &&
               password.count >= 6
    }

    // MARK: - Actions

    /// Attempts to sign in with email and password
    /// Shows loading state, provides haptic feedback, and handles errors
    /// On success, AuthService updates app state to navigate to main screen
    private func signIn() async {
        errorMessage = nil
        isLoading = true

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        do {
            try await authService.signIn(email: email, password: password)

        } catch {
            errorMessage = error.localizedDescription

            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }

        isLoading = false
    }
}

// MARK: - Password Reset View with Liquid Glass

/// Sheet view for password reset with Liquid Glass effects on interactive controls
/// Demonstrates glass material in modal sheets following iOS 26+ guidelines
/// Glass effects applied exclusively to buttons and navigation elements
///
/// SHEET BEHAVIOUR IN iOS 26:
/// - Sheets automatically receive glass treatment in their presentation layer
/// - No need to apply .glassEffect() to the sheet itself
/// - Apply glass only to interactive controls within the sheet content
struct PasswordResetViewLiquidGlass: View {

    /// Pre-filled email from login screen
    /// Used to populate the email field for convenience
    let email: String
    /// Dismisses the sheet
    /// Used to close the modal after successful reset or cancellation
    @Environment(\.dismiss) private var dismiss
    /// Auth service for password reset
    /// Injected via environment for Firebase integration
    @Environment(\.authService) private var authService
    /// Email input for password reset
    /// Initialised with pre-filled email from login screen
    @State private var resetEmail: String
    /// Loading state
    /// True whilst sending reset email request to Firebase
    @State private var isLoading = false
    /// Success state
    /// True after reset email successfully sent
    @State private var resetSent = false
    /// Error message
    /// Displayed if reset request fails (invalid email, network error, etc.)
    @State private var errorMessage: String?

    /// Initialiser that pre-fills email field
    /// - Parameter email: Email address from login screen (may be empty)
    init(email: String) {
        self.email = email
        _resetEmail = State(initialValue: email)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.UI.spacingLarge) {

                if resetSent {
                    // Success state - informational content
                    // NO glass effect applied to content displays
                    VStack(spacing: Constants.UI.spacingMedium) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.green)

                        Text("password_reset_sent")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("password_reset_check_email")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    // Done button with glass effect
                    // Interactive control appropriate for glass treatment
                    Button {
                        dismiss()
                    } label: {
                        Text("done")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    // Interactive glass for touch response
                    .glassEffectIfAvailable(.regular.interactive(), in: Capsule())
                    .glassEffectID("done-button")
                    .padding(.horizontal)

                } else {
                    // Input state - form fields
                    // NO glass effect on text fields (they're content, not controls)
                    VStack(alignment: .leading, spacing: Constants.UI.spacingMedium) {
                        Text("password_reset_instructions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField(String(localized: "email_placeholder"), text: $resetEmail)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()

                    // Error message - NO glass effect (informational content)
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding()
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

                    // Send button with glass effect
                    // Interactive control appropriate for glass treatment
                    Button {
                        Task {
                            await sendPasswordReset()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("send_reset_link")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(resetEmail.isEmpty || isLoading)
                    // Interactive glass effect for touch response
                    .glassEffectIfAvailable(.regular.interactive(), in: Capsule())
                    .glassEffectID("send-reset-button")
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("reset_password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Cancel button with subtle glass effect
                    Button {
                        dismiss()
                    } label: {
                        Text("cancel")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    // Subtle glass for toolbar button (navigation element)
                    .glassEffectIfAvailable(.clear, in: Capsule())
                    .glassEffectID("cancel-button")
                }
            }
        }
    }

    /// Sends password reset email via Firebase
    /// Updates UI state to show success message or error
    private func sendPasswordReset() async {
        errorMessage = nil
        isLoading = true

        do {
            try await authService.sendPasswordReset(email: resetEmail)
            resetSent = true

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Placeholder for SignUpViewLiquidGlass

/// Placeholder for sign-up view with Liquid Glass effects
/// Full implementation provided in separate file
struct SignUpViewLiquidGlass: View {
    var body: some View {
        Text("Sign Up coming soon...")
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
/// Shows login view with Liquid Glass effects in Xcode canvas
#Preview {
    LoginViewLiquidGlass()
        .environment(\.authService, AuthService(apiClient: DefaultAPIClient()))
}