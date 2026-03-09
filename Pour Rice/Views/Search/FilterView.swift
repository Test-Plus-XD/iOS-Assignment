//
//  FilterView.swift
//  Pour Rice
//
//  Filter sheet for narrowing restaurant search results
//  Allows filtering by cuisine type, price range, and minimum rating
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
/// - Cuisine type (multi-select)
/// - Price range (multi-select)
/// - Minimum star rating (single slider)
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

                // ── Cuisine Filter Section ─────────────────────────────────
                // Multi-select toggle list for cuisine types

                Section(String(localized: "filter_cuisine_title")) {
                    ForEach(SearchViewModel.availableCuisines, id: \.self) { cuisine in
                        // Toggle row — checkmark appears when cuisine is selected
                        Button {
                            toggleCuisine(cuisine)
                        } label: {
                            HStack {
                                Text(cuisine)
                                    .foregroundStyle(.primary)
                                Spacer()
                                // Checkmark if selected (like a checkbox in Flutter)
                                if viewModel.selectedCuisines.contains(cuisine) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                // ── Price Range Filter Section ─────────────────────────────
                // Multi-select toggle list for price ranges ($, $$, $$$, $$$$)

                Section(String(localized: "filter_price_title")) {
                    ForEach(SearchViewModel.availablePriceRanges, id: \.self) { price in
                        Button {
                            togglePriceRange(price)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(price)
                                        .foregroundStyle(.primary)
                                    Text(priceRangeLabel(price))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if viewModel.selectedPriceRanges.contains(price) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                // ── Minimum Rating Filter Section ─────────────────────────
                // Slider to set minimum star rating

                Section(String(localized: "filter_rating_title")) {
                    VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

                        // Display current minimum rating value
                        HStack {
                            Text(String(localized: "filter_rating_minimum"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if viewModel.minimumRating > 0 {
                                // Show selected minimum rating with stars
                                Label(
                                    String(format: "%.1f+", viewModel.minimumRating),
                                    systemImage: "star.fill"
                                )
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            } else {
                                Text(String(localized: "filter_rating_any"))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Slider from 0 to 4.5 stars in 0.5 increments
                        // Equivalent to Slider in Flutter
                        Slider(
                            value: Binding(
                                get: { viewModel.minimumRating },
                                set: { viewModel.minimumRating = $0 }
                            ),
                            in: 0...4.5,
                            step: 0.5
                        )
                        .tint(.orange)  // Orange to match star colour

                        // Min/max labels
                        HStack {
                            Text(String(localized: "filter_rating_any"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("4.5 ★")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
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

    /// Toggles a cuisine type in/out of the selection set
    /// Set automatically handles uniqueness (no duplicate selections)
    private func toggleCuisine(_ cuisine: String) {
        if viewModel.selectedCuisines.contains(cuisine) {
            viewModel.selectedCuisines.remove(cuisine)
        } else {
            viewModel.selectedCuisines.insert(cuisine)
        }
    }

    /// Toggles a price range in/out of the selection set
    private func togglePriceRange(_ price: String) {
        if viewModel.selectedPriceRanges.contains(price) {
            viewModel.selectedPriceRanges.remove(price)
        } else {
            viewModel.selectedPriceRanges.insert(price)
        }
    }

    // MARK: - Helpers

    /// Returns a human-readable label for a price range symbol
    private func priceRangeLabel(_ price: String) -> String {
        switch price {
        case "$":    return String(localized: "price_budget")
        case "$$":   return String(localized: "price_moderate")
        case "$$$":  return String(localized: "price_upscale")
        case "$$$$": return String(localized: "price_fine_dining")
        default:     return price
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = SearchViewModel(algoliaService: AlgoliaService())
    FilterView(viewModel: vm)
}
