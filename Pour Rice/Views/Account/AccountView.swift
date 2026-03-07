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

/// Profile and settings screen for the authenticated user
struct AccountView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel: AccountViewModel?

    /// Controls the sign-out confirmation dialog
    @State private var showingSignOutConfirm = false

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView()
            }
        }
        .navigationTitle(String(localized: "account_title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
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

            // ─── Sign Out ─────────────────────────────────────────────
            signOutSection(vm: vm)
        }
        .listStyle(.insetGrouped)
        // Error alert if sign-out fails
        .alert(String(localized: "error_title"), isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button(String(localized: "ok"), role: .cancel) {
                vm.errorMessage = nil
            }
        } message: {
            if let error = vm.errorMessage {
                Text(error)
            }
        }
        // Confirmation dialog before signing out
        .confirmationDialog(
            String(localized: "account_sign_out_confirm_title"),
            isPresented: $showingSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "sign_out"), role: .destructive) {
                vm.signOut()
            }
            Button(String(localized: "cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "account_sign_out_confirm_message"))
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
                        .fill(.accent.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Text(initials(for: vm.displayName))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)
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
                        .background(.accent, in: Capsule())
                }
            }
            .padding(.vertical, Constants.UI.spacingSmall)
        }
    }

    // MARK: - Account Details Section

    @ViewBuilder
    private func accountDetailsSection(vm: AccountViewModel) -> some View {
        Section(header: Text(String(localized: "account_section_details"))) {
            LabeledContent(String(localized: "account_email_label")) {
                Text(vm.email)
                    .foregroundStyle(.secondary)
            }

            LabeledContent(String(localized: "account_type_label")) {
                Text(vm.accountTypeDisplay)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Preferences Section

    @ViewBuilder
    private func preferencesSection(vm: AccountViewModel) -> some View {
        Section(header: Text(String(localized: "account_section_preferences"))) {
            LabeledContent(String(localized: "account_language_label")) {
                Text(vm.preferredLanguageDisplay)
                    .foregroundStyle(.secondary)
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
                            Label(String(localized: "sign_out"),
                                  systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        Spacer()
                    }
                    .padding(.vertical, Constants.UI.spacingSmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .glassEffectIfAvailable(.regular.interactive(), in: RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))
                .glassEffectID("account-sign-out-button")
                .disabled(vm.isSigningOut)
            }
        }
        .listRowBackground(Color.clear)
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
        AccountView()
            .environment(\.services, Services())
            .environment(\.authService, Services().authService)
    }
}
