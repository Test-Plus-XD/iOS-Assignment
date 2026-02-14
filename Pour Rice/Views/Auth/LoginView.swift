//
//  LoginView.swift
//  Pour Rice
//
//  User login screen with email/password authentication
//  Follows iOS Human Interface Guidelines for form design
//

import SwiftUI

/// Login view for existing users to sign in
/// Provides email/password authentication with validation and error handling
struct LoginView: View {

    // MARK: - Environment

    /// Auth service for sign in operations
    @Environment(\.authService) private var authService

    // MARK: - State Properties

    /// User's email address input
    @State private var email = ""

    /// User's password input
    @State private var password = ""

    /// Controls password visibility toggle
    @State private var isPasswordVisible = false

    /// Tracks if sign in is in progress
    @State private var isLoading = false

    /// Error message to display
    @State private var errorMessage: String?

    /// Controls navigation to sign up screen
    @State private var showingSignUp = false

    /// Controls password reset sheet
    @State private var showingPasswordReset = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.UI.spacingLarge) {

                    // MARK: - Logo & Title

                    VStack(spacing: Constants.UI.spacingMedium) {
                        // App logo or icon
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

                    VStack(spacing: Constants.UI.spacingMedium) {

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
                                        .textContentType(.password)
                                } else {
                                    SecureField(String(localized: "password_placeholder"), text: $password)
                                        .textContentType(.password)
                                }

                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                        }

                        // Forgot password button
                        HStack {
                            Spacer()
                            Button {
                                showingPasswordReset = true
                            } label: {
                                Text("forgot_password")
                                    .font(.subheadline)
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                    .padding(.horizontal, Constants.UI.spacingLarge)

                    // MARK: - Error Message

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, Constants.UI.spacingLarge)
                    }

                    // MARK: - Sign In Button

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
                    .padding(.horizontal, Constants.UI.spacingLarge)

                    // MARK: - Sign Up Link

                    HStack(spacing: 4) {
                        Text("no_account")
                            .foregroundStyle(.secondary)

                        Button {
                            showingSignUp = true
                        } label: {
                            Text("sign_up")
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.subheadline)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showingPasswordReset) {
                PasswordResetView(email: email)
            }
        }
    }

    // MARK: - Form Validation

    /// Validates if the form fields are properly filled
    private var isFormValid: Bool {
        return !email.isEmpty &&
               email.contains("@") &&
               password.count >= 6
    }

    // MARK: - Actions

    /// Attempts to sign in with email and password
    private func signIn() async {
        // Clear previous errors
        errorMessage = nil
        isLoading = true

        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        do {
            try await authService.signIn(email: email, password: password)

            // Success - AuthService will handle navigation via state change

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

// MARK: - Password Reset View

/// Sheet view for password reset functionality
struct PasswordResetView: View {

    /// Pre-filled email from login screen
    let email: String

    /// Dismisses the sheet
    @Environment(\.dismiss) private var dismiss

    /// Auth service for password reset
    @Environment(\.authService) private var authService

    /// Email input for password reset
    @State private var resetEmail: String

    /// Loading state
    @State private var isLoading = false

    /// Success state
    @State private var resetSent = false

    /// Error message
    @State private var errorMessage: String?

    init(email: String) {
        self.email = email
        _resetEmail = State(initialValue: email)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.UI.spacingLarge) {

                if resetSent {
                    // Success state
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

                    Button {
                        dismiss()
                    } label: {
                        Text("done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                } else {
                    // Input state
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

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

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
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(resetEmail.isEmpty || isLoading)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("reset_password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("cancel")
                    }
                }
            }
        }
    }

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

// MARK: - Preview

#Preview {
    LoginView()
        .environment(\.authService, AuthService(apiClient: DefaultAPIClient()))
}
