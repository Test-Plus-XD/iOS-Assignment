//
//  SignUpView.swift
//  Pour Rice
//
//  User registration screen for new account creation
//  Includes validation for email, password, and display name
//

import SwiftUI

/// Sign up view for new users to create an account
/// Provides email/password registration with validation
struct SignUpView: View {

    // MARK: - Environment

    /// Auth service for sign up operations
    @Environment(\.authService) private var authService

    /// Dismisses the view
    @Environment(\.dismiss) private var dismiss

    // MARK: - State Properties

    /// User's display name input
    @State private var displayName = ""

    /// User's email address input
    @State private var email = ""

    /// User's password input
    @State private var password = ""

    /// Password confirmation input
    @State private var confirmPassword = ""

    /// Controls password visibility toggle
    @State private var isPasswordVisible = false

    /// Controls confirm password visibility toggle
    @State private var isConfirmPasswordVisible = false

    /// Terms and conditions agreement
    @State private var agreedToTerms = false

    /// Tracks if sign up is in progress
    @State private var isLoading = false

    /// Error message to display
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Constants.UI.spacingLarge) {

                // MARK: - Header

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

                    // Password field
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

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        // Password requirements
                        Text("password_requirements")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Confirm password field
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

                        // Password match indicator
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

                    // Terms and conditions
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

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, Constants.UI.spacingLarge)
                }

                // Display validation errors
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
                    .padding(.horizontal, Constants.UI.spacingLarge)
                }

                // MARK: - Sign Up Button

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
                .padding(.horizontal, Constants.UI.spacingLarge)

                // MARK: - Sign In Link

                HStack(spacing: 4) {
                    Text("already_have_account")
                        .foregroundStyle(.secondary)

                    Button {
                        dismiss()
                    } label: {
                        Text("sign_in")
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Form Validation

    /// Validates if all form fields are properly filled
    private var isFormValid: Bool {
        return !displayName.isEmpty &&
               !email.isEmpty &&
               email.contains("@") &&
               password.count >= 6 &&
               passwordsMatch &&
               agreedToTerms
    }

    /// Checks if passwords match
    private var passwordsMatch: Bool {
        return !password.isEmpty && password == confirmPassword
    }

    /// Returns array of validation error messages
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
    private func signUp() async {
        // Clear previous errors
        errorMessage = nil
        isLoading = true

        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        do {
            try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )

            // Success - AuthService will handle navigation via state change
            // Success haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

        } catch {
            // Show error message
            errorMessage = error.localizedDescription

            // Error haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SignUpView()
            .environment(\.authService, AuthService(apiClient: DefaultAPIClient()))
    }
}
