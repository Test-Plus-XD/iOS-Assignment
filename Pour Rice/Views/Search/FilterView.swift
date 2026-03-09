//
//  FilterView.swift
//  Pour Rice
//
//  Filter sheet for narrowing restaurant search results
//  Allows filtering by Hong Kong district and cuisine/dietary keyword
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is a modal sheet (bottom sheet) for filtering search results.
//  Presented via .sheet() in SearchView when the filter button is tapped.
//
//  FLUTTER EQUIVALENT:
//  showModalBottomSheet(
//    context: context,
//    isScrollControlled: true,
//    builder: (ctx) => FilterSheet(viewModel: vm),
//  )
//  ============================================================================
//

import SwiftUI

// MARK: - Filter View

/// Modal sheet for configuring search filters
///
/// Allows users to filter restaurants by:
/// - Hong Kong district (multi-select)
/// - Cuisine/dietary keyword (multi-select)
///
/// Changes are applied when the user taps "Apply Filters".
/// "Clear All" resets all filters to their default state.
struct FilterView: View {

    // MARK: - Environment

    /// Used to dismiss this sheet programmatically
    /// Equivalent to Navigator.pop() in Flutter
    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies

    /// Shared ViewModel from SearchView
    /// Passed in directly so filter changes update the search screen instantly
    let viewModel: SearchViewModel

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {

                // ── District Filter Section ────────────────────────────────
                // Multi-select toggle list for Hong Kong districts

                Section(String(localized: "filter_district_title")) {
                    ForEach(SearchViewModel.availableDistricts, id: \.self) { district in
                        // Toggle row — checkmark appears when district is selected
                        Button {
                            toggleDistrict(district)
                        } label: {
                            HStack {
                                Text(district)
                                    .foregroundStyle(.primary)
                                Spacer()
                                // Checkmark if selected (like a checkbox in Flutter)
                                if viewModel.selectedDistricts.contains(district) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                // ── Keyword Filter Section ─────────────────────────────────
                // Multi-select toggle list for cuisine/dietary keywords

                Section(String(localized: "filter_keyword_title")) {
                    ForEach(SearchViewModel.availableKeywords, id: \.self) { keyword in
                        Button {
                            toggleKeyword(keyword)
                        } label: {
                            HStack {
                                Text(keyword)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedKeywords.contains(keyword) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "filter_title"))
            .navigationBarTitleDisplayMode(.inline)
            // Toolbar with Cancel, Clear, and Apply buttons
            .toolbar {
                // Cancel — dismiss without applying
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "filter_cancel")) {
                        dismiss()
                    }
                }

                // Apply — apply filters and trigger search
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "filter_apply")) {
                        Task { await viewModel.applyFilters() }
                    }
                    .fontWeight(.semibold)
                    .hapticFeedback(style: .medium)
                }

                // Clear — reset all filters (shown only when filters are active)
                if viewModel.hasActiveFilters {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(String(localized: "filter_clear")) {
                            Task { await viewModel.clearFilters() }
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    /// Toggles a district in/out of the selection set
    /// Set automatically handles uniqueness (no duplicate selections)
    private func toggleDistrict(_ district: String) {
        if viewModel.selectedDistricts.contains(district) {
            viewModel.selectedDistricts.remove(district)
        } else {
            viewModel.selectedDistricts.insert(district)
        }
    }

    /// Toggles a keyword in/out of the selection set
    private func toggleKeyword(_ keyword: String) {
        if viewModel.selectedKeywords.contains(keyword) {
            viewModel.selectedKeywords.remove(keyword)
        } else {
            viewModel.selectedKeywords.insert(keyword)
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = SearchViewModel(algoliaService: AlgoliaService())
    FilterView(viewModel: vm)
}
