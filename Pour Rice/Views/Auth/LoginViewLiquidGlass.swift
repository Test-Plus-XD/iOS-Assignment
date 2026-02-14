//
//  LoginViewLiquidGlass.swift
//  Pour Rice
//
//  Liquid Glass variant of the login screen
//  Demonstrates Liquid Glass material adoption for authentication UI
//  Applies frosted glass effects to form elements and modal sheets
//
//  LIQUID GLASS IN AUTH FLOWS:
//  - Regular variant on interactive controls (buttons, input containers)
//  - Controls highlight with glass effect when activated
//  - Modals use glass material for sheets and popovers
//  - Maintains legibility while creating depth and visual hierarchy
//

import SwiftUI

/// Login view with Liquid Glass effects on interactive elements
/// Enhances the authentication form with frosted glass material
/// Demonstrates glass effect variants and usage patterns
struct LoginViewLiquidGlass: View {

    // MARK: - Environment

    @Environment(\.authService) private var authService

    // MARK: - State Properties

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSignUp = false
    @State private var showingPasswordReset = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.UI.spacingLarge) {

                    // MARK: - Logo & Title

                    VStack(spacing: Constants.UI.spacingMedium) {
                        Image(systemName: "fork.knife.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(.accent)
                            // Apply Liquid Glass to logo container
                            .padding()
                            .glassEffect(in: Circle())

                        Text("app_name")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("login_subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Constants.UI.spacingExtraLarge)

                    // MARK: - Login Form Container with Glass Effect

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
                        HStack {
                            Spacer()
                            Button {
                                showingPasswordReset = true
                            } label: {
                                Text("forgot_password")
                                    .font(.subheadline)
                                    .foregroundStyle(.accent)
                            }
                            // Apply interactive glass effect to button
                            .glassEffect(in: Capsule())
                        }
                    }
                    .padding()
                    // Apply glass effect to entire form container
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, Constants.UI.spacingLarge)

                    // MARK: - Error Message with Glass Background

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding()
                            // Glass effect with Clear variant for error visibility
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, Constants.UI.spacingLarge)
                    }

                    // MARK: - Sign In Button with Glass Effect

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
                    // Apply interactive glass effect with interactive mode enabled
                    .glassEffect(.regular.interactive(true), in: Capsule())
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
                        // Apply glass effect to sign-up button
                        .glassEffect(in: Capsule())
                    }
                    .font(.subheadline)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpViewLiquidGlass()
            }
            // Password reset sheet with glass effects
            .sheet(isPresented: $showingPasswordReset) {
                PasswordResetViewLiquidGlass(email: email)
            }
        }
    }

    // MARK: - Form Validation

    private var isFormValid: Bool {
        return !email.isEmpty &&
               email.contains("@") &&
               password.count >= 6
    }

    // MARK: - Actions

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

/// Sheet view for password reset with Liquid Glass effects
/// Demonstrates glass material in modal sheets and form elements
struct PasswordResetViewLiquidGlass: View {

    let email: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.authService) private var authService

    @State private var resetEmail: String
    @State private var isLoading = false
    @State private var resetSent = false
    @State private var errorMessage: String?

    init(email: String) {
        self.email = email
        _resetEmail = State(initialValue: email)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.UI.spacingLarge) {

                if resetSent {
                    // Success state with glass effect
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
                    // Apply glass effect to success message
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .padding()

                    Button {
                        dismiss()
                    } label: {
                        Text("done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    // Apply interactive glass effect
                    .glassEffect(.regular.interactive(true), in: Capsule())
                    .padding(.horizontal)

                } else {
                    // Input state with glass effects
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
                    // Apply glass effect to input container
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .padding()

                    // Error message with glass effect
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding()
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
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
                    // Apply interactive glass effect
                    .glassEffect(.regular.interactive(true), in: Capsule())
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
                    // Apply glass effect to toolbar button
                    .glassEffect(in: Capsule())
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

// MARK: - Placeholder for SignUpViewLiquidGlass

/// Placeholder for sign-up view with Liquid Glass effects
/// To be implemented in next phase
struct SignUpViewLiquidGlass: View {
    var body: some View {
        Text("Sign Up coming soon...")
    }
}

// MARK: - Preview

#Preview {
    LoginViewLiquidGlass()
        .environment(\.authService, AuthService(apiClient: DefaultAPIClient()))
}
