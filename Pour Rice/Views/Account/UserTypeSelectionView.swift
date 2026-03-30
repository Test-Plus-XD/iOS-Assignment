//
//  UserTypeSelectionView.swift
//  Pour Rice
//
//  Presented as a non-dismissable sheet immediately after a new user registers.
//  The user chooses between Diner (食客) and Restaurant Owner (店主).
//  On selection the type is persisted via PUT /API/Users/:uid and the sheet
//  closes automatically once AuthService.needsTypeSelection becomes false.
//

import SwiftUI

// MARK: - User Type Selection View

/// Full-screen sheet prompting new users to pick their account type.
///
/// FLOW:
///  1. User taps a card → `isLoading` shows a spinner on the chosen card
///  2. `authService.updateUserType(_:)` → PUT /API/Users/:uid { type }
///  3. AuthService sets `needsTypeSelection = false`
///  4. The binding in `MainTabView` resolves to `false` → SwiftUI dismisses sheet
///  5. `onDismiss` fires → toast appears in `MainTabView`
///
/// DISMISSAL:
///  `.interactiveDismissDisabled(true)` prevents swipe-to-dismiss and the
///  sheet toolbar has no cancel/close button, so the only exit is choosing a type.
struct UserTypeSelectionView: View {

    // MARK: - Environment

    @Environment(\.authService) private var authService

    // MARK: - State

    /// Which card the user last tapped (drives highlight + spinner placement)
    @State private var selectedType: User.UserType?

    /// True while the API call is in flight
    @State private var isLoading = false

    /// Inline error shown beneath the cards if the API call fails
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Subtitle ──────────────────────────────────────────
                    Text("user_type_selection_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // ── Type Cards ────────────────────────────────────────
                    VStack(spacing: 16) {
                        UserTypeCard(
                            icon: "fork.knife.circle.fill",
                            titleKey: "account_type_customer",
                            descriptionKey: "user_type_diner_description",
                            accentColor: .orange,
                            isSelected: selectedType == .diner,
                            isLoading: isLoading && selectedType == .diner,
                            isDisabled: isLoading
                        ) {
                            pickType(.diner)
                        }

                        UserTypeCard(
                            icon: "storefront.fill",
                            titleKey: "account_type_owner",
                            descriptionKey: "user_type_restaurant_description",
                            accentColor: .green,
                            isSelected: selectedType == .restaurant,
                            isLoading: isLoading && selectedType == .restaurant,
                            isDisabled: isLoading
                        ) {
                            pickType(.restaurant)
                        }
                    }
                    .padding(.horizontal)

                    // ── Inline error ───────────────────────────────────────
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("user_type_selection_title")
            .navigationBarTitleDisplayMode(.large)
        }
        // The user MUST choose — no swipe-to-dismiss, no close button
        .interactiveDismissDisabled(true)
    }

    // MARK: - Actions

    private func pickType(_ type: User.UserType) {
        guard !isLoading else { return }
        selectedType = type
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.updateUserType(type)
                // Sheet dismisses automatically via MainTabView binding
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                selectedType = nil
            }
        }
    }
}

// MARK: - User Type Card

/// A tappable card representing one account type option.
private struct UserTypeCard: View {

    let icon: String
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey
    let accentColor: Color
    let isSelected: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {

                // Icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundStyle(accentColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleKey)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(descriptionKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Trailing indicator
                if isLoading {
                    ProgressView()
                        .tint(accentColor)
                        .controlSize(.regular)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.background)
                    .shadow(
                        color: isSelected ? accentColor.opacity(0.25) : .black.opacity(0.07),
                        radius: isSelected ? 10 : 5,
                        y: 3
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? accentColor : Color(.separator).opacity(0.5), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.5 : 1)
        .animation(.spring(duration: 0.3), value: isSelected)
        .animation(.spring(duration: 0.3), value: isLoading)
    }
}
