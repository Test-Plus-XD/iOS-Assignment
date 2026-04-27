//
//  ProfileEditView.swift
//  Pour Rice
//
//  Profile editing sheet for updating display name, phone number, and bio
//  Presented as a sheet from AccountView
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  FLUTTER EQUIVALENT:
//  showModalBottomSheet(
//    context: context,
//    builder: (_) => ProfileEditForm(user: user, onSave: (updates) => ...),
//  );
//
//  KEY IOS DIFFERENCES:
//  - .sheet() = showModalBottomSheet()
//  - @Bindable = two-way binding to @Observable ViewModel
//  - .toolbar { ToolbarItem } = AppBar actions
//  ============================================================================
//

import SwiftUI

// MARK: - Profile Edit View

/// Sheet view for editing user profile fields (display name, phone, bio)
struct ProfileEditView: View {

    // MARK: - Dependencies

    @Bindable var viewModel: AccountViewModel

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                // ─── Display Name ─────────────────────────────────────
                Section(header: Text("profile_display_name")) {
                    TextField("profile_display_name", text: $viewModel.editDisplayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                // ─── Phone Number ─────────────────────────────────────
                Section(header: Text("profile_phone_number")) {
                    TextField("profile_phone_number", text: $viewModel.editPhoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                // ─── Bio ──────────────────────────────────────────────
                Section(header: Text("profile_bio")) {
                    TextField("profile_bio_placeholder", text: $viewModel.editBio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("profile_edit_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("profile_save") {
                        Task { await viewModel.saveProfile() }
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isSaving)
                }
            }
            .loadingOverlay(isLoading: viewModel.isSaving)
            .alert("error_title", isPresented: Binding(
                get: { viewModel.errorMessage != nil && viewModel.isEditing },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("ok", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}
