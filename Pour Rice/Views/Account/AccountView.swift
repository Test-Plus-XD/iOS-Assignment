//
//  AccountView.swift
//  Pour Rice
//
//  Account/profile screen showing user info and app settings
//  Uses Liquid Glass for interactive controls (iOS 26+)
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  FLUTTER EQUIVALENT:
//  class AccountPage extends StatelessWidget {
//    Widget build(BuildContext context) {
//      final user = context.watch<AuthService>().currentUser;
//      return Scaffold(
//        body: Column(children: [
//          ProfileHeader(user: user),
//          ListTile(title: Text('Sign Out'), onTap: () => authService.signOut()),
//        ]),
//      );
//    }
//  }
//
//  KEY IOS DIFFERENCES:
//  - List with Section { } = grouped settings list
//  - .confirmationDialog() = ActionSheet (ConfirmDialog equivalent)
//  - GlassEffectContainer + .glassEffectIfAvailable() = iOS 26 Liquid Glass
//  ============================================================================
//

import SwiftUI

// MARK: - Account View

/// Profile and settings screen for the authenticated user.
/// When the user is browsing as a guest, shows a sign-in prompt instead of profile data.
struct AccountView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - Guest Mode

    /// Binding to guest browsing state from RootView (via MainTabView).
    /// Set to `false` when the user taps "Sign In" to navigate back to LoginView.
    @Binding var isGuest: Bool

    // MARK: - State

    @State private var viewModel: AccountViewModel?

    /// Controls the sign-out confirmation dialog
    @State private var showingSignOutConfirm = false
    /// Namespace for Liquid Glass morphing transitions
    @Namespace private var glassNamespace

    /// Persisted language preference — guests can still change language via UserDefaults
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"

    /// Persisted theme preference — guests can still change theme via UserDefaults.
    /// Pour_RiceApp's RootView reads the same key and applies `.preferredColorScheme`,
    /// so writes here switch the interface immediately.
    @AppStorage("preferredTheme") private var preferredTheme = "system"

    // MARK: - Body

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Authenticated user — show profile content
                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    LoadingView()
                }
            } else {
                // Guest user — show sign-in prompt
                guestPromptView
            }
        }
        .navigationTitle("account_title")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if authService.isAuthenticated, viewModel == nil {
                viewModel = AccountViewModel(authService: authService)
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated, viewModel == nil {
                viewModel = AccountViewModel(authService: authService)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: AccountViewModel) -> some View {
        List {

            // ─── Profile Header ──────────────────────────────────────
            profileHeaderSection(vm: vm)

            // ─── Account Details ─────────────────────────────────────
            accountDetailsSection(vm: vm)

            // ─── Preferences ─────────────────────────────────────────
            preferencesSection(vm: vm)

            // ─── Tools & Extras ───────────────────────────────────────
            toolsSection

            // ─── Sign Out ─────────────────────────────────────────────
            signOutSection(vm: vm)
        }
        .listStyle(.insetGrouped)
        .toast(message: vm.toastMessage, style: vm.toastStyle, isPresented: Binding(
            get: { vm.showToast },
            set: { vm.showToast = $0 }
        ))
        // Profile edit sheet
        .sheet(isPresented: Binding(
            get: { vm.isEditing },
            set: { vm.isEditing = $0 }
        )) {
            ProfileEditView(viewModel: vm)
        }
        // Error alert if sign-out fails
        .alert("error_title", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("ok", role: .cancel) {
                vm.errorMessage = nil
            }
        } message: {
            if let error = vm.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Profile Header Section

    /// Large avatar + name + email at the top of the screen
    @ViewBuilder
    private func profileHeaderSection(vm: AccountViewModel) -> some View {
        Section {
            HStack(spacing: Constants.UI.spacingMedium) {

                // Avatar circle with initials (no photo URL support yet)
                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Text(initials(for: vm.displayName))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }

                // Name + email
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.displayName)
                        .font(.headline)

                    Text(vm.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Account type badge
                    Text(vm.accountTypeDisplay)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tint, in: Capsule())
                }
            }
            .padding(.vertical, Constants.UI.spacingSmall)

            // Edit Profile button
            Button {
                vm.startEditing()
            } label: {
                Label("profile_edit_title", systemImage: "pencil")
            }
        }
    }

    // MARK: - Account Details Section

    @ViewBuilder
    private func accountDetailsSection(vm: AccountViewModel) -> some View {
        Section(header: Text("account_section_details")) {
            LabeledContent("account_email_label") {
                Text(vm.email)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("account_type_label") {
                Text(vm.accountTypeDisplay)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Preferences Section

    @ViewBuilder
    private func preferencesSection(vm: AccountViewModel) -> some View {
        Section(header: Text("account_section_preferences")) {
            // Language picker — tapping cycles between English and Traditional Chinese.
            // The selection binding writes to UserDefaults via vm.updateLanguage(), which
            // triggers @AppStorage in Pour_RiceApp to re-inject the new locale environment
            // and instantly switches all String(localized:) text across the app.
            Picker("account_language_label", selection: Binding(
                get: { vm.preferredLanguage },
                set: { newValue in Task { await vm.updateLanguage(newValue) } }
            )) {
                Text("language_en").tag("en")
                Text("language_tc").tag("zh-Hant")
            }

            // Theme picker — writes to UserDefaults via vm.updateTheme(), which triggers
            // @AppStorage("preferredTheme") in Pour_RiceApp to re-apply .preferredColorScheme.
            Picker("account_theme_label", selection: Binding(
                get: { vm.preferredTheme },
                set: { newValue in Task { await vm.updateTheme(newValue) } }
            )) {
                Text("theme_system").tag("system")
                Text("theme_light").tag("light")
                Text("theme_dark").tag("dark")
            }

            Toggle("account_notifications_label", isOn: Binding(
                get: { vm.notificationsEnabled },
                set: { newValue in Task { await vm.updateNotifications(newValue) } }
            ))
        }
    }

    // MARK: - Tools Section

    @ViewBuilder
    private var toolsSection: some View {
        Section(header: Text("account_section_tools")) {
            NavigationLink(value: GeminiNavigation(restaurant: nil)) {
                Label("account_ai_assistant", systemImage: "sparkles")
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Sign Out Section

    @ViewBuilder
    private func signOutSection(vm: AccountViewModel) -> some View {
        Section {
            // LIQUID GLASS IMPLEMENTATION:
            // GlassEffectContainer groups the sign-out button as a glass element.
            // .glassEffectIfAvailable() falls back to ultraThinMaterial on iOS < 26.
            // This follows Apple HIG: glass only on interactive controls, not content.
            GlassEffectContainer {
                Button(role: .destructive) {
                    showingSignOutConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        if vm.isSigningOut {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Label("sign_out",
                                  systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        Spacer()
                    }
                    .padding(.vertical, Constants.UI.spacingSmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .contentShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))
                .glassEffectID("account-sign-out-button", in: glassNamespace)
                .hapticFeedback(style: .heavy)
                .disabled(vm.isSigningOut)
                .confirmationDialog(
                    "account_sign_out_confirm_title",
                    isPresented: $showingSignOutConfirm,
                    titleVisibility: .visible
                ) {
                    Button("sign_out", role: .destructive) {
                        vm.signOut()
                    }
                    Button("cancel", role: .cancel) { }
                } message: {
                    Text("account_sign_out_confirm_message")
                }
            }
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Guest Prompt View

    /// Shown when the user is browsing as a guest (not authenticated).
    /// Provides a sign-in call-to-action and a language picker.
    @ViewBuilder
    private var guestPromptView: some View {
        List {
            // ─── Sign-In Prompt ──────────────────────────────────────
            Section {
                VStack(spacing: Constants.UI.spacingMedium) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.tint)

                    Text("account_guest_title")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("account_guest_message")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    GlassEffectContainer {
                        Button {
                            isGuest = false
                        } label: {
                            Text("sign_in")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .glassEffectIfAvailable(.regular.interactive(), in: Capsule())
                        .glassEffectID("guest-sign-in-button", in: glassNamespace)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Constants.UI.spacingLarge)
            }

            // ─── Preferences (available to guests) ────────────────────
            Section(header: Text("account_section_preferences")) {
                Picker("account_language_label", selection: $preferredLanguage) {
                    Text("language_en").tag("en")
                    Text("language_tc").tag("zh-Hant")
                }

                Picker("account_theme_label", selection: $preferredTheme) {
                    Text("theme_system").tag("system")
                    Text("theme_light").tag("light")
                    Text("theme_dark").tag("dark")
                }
            }

            // ─── Tools (available to guests) ─────────────────────────
            Section(header: Text("account_section_tools")) {
                NavigationLink(value: GeminiNavigation(restaurant: nil)) {
                    Label("account_ai_assistant", systemImage: "sparkles")
                        .foregroundStyle(.primary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    /// Returns up to 2 initials from a display name
    private func initials(for name: String) -> String {
        let words = name.split(separator: " ")
        switch words.count {
        case 0:
            return "?"
        case 1:
            return String(words[0].prefix(2)).uppercased()
        default:
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AccountView(isGuest: .constant(true))
            .environment(\.services, Services())
            .environment(\.authService, Services().authService)
    }
}

