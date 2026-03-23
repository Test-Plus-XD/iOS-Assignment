//
//  MenuView.swift
//  Pour Rice
//
//  Full menu screen for a restaurant, grouped by category
//  Supports client-side search and dietary filtering
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  FLUTTER EQUIVALENT of this screen:
//
//  class MenuPage extends StatefulWidget { ... }
//  // Sectioned list with ListHeader + ListTile rows
//  // searchDelegate for in-page search
//  // BottomSheet or Dialog for dietary filters
//
//  KEY IOS DIFFERENCES:
//  - .searchable() = built-in iOS search bar in NavigationStack
//  - List with Section { } = grouped/sectioned list (ListView.builder equivalent)
//  - .sheet() = modal bottom sheet (showModalBottomSheet equivalent)
//  - @State private var viewModel = … triggers rebuild when Observable changes
//  ============================================================================
//

import SwiftUI

// MARK: - Menu View

/// Full-menu screen showing all items for a specific restaurant
/// Sectioned by category with search and dietary filter support
struct MenuView: View {

    // MARK: - Environment

    @Environment(\.services) private var services

    // MARK: - Properties

    /// ID of the restaurant whose menu we're showing
    let restaurantId: String

    /// Restaurant name for the navigation title
    let restaurantName: String

    // MARK: - State

    /// ViewModel managing all menu state and filtering logic
    @State private var viewModel: MenuViewModel?

    /// Whether the dietary filter sheet is presented
    @State private var showingFilters = false

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView(message: "menu_loading")
            }
        }
        .navigationTitle(restaurantName)
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
                let vm = MenuViewModel(menuService: services.menuService)
                viewModel = vm
                await vm.loadMenu(restaurantId: restaurantId)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: MenuViewModel) -> some View {
        if vm.isLoading && vm.allItems.isEmpty {
            LoadingView(message: "menu_loading")

        } else if let error = vm.errorMessage, vm.allItems.isEmpty {
            ErrorView(message: error) {
                Task { await vm.loadMenu(restaurantId: restaurantId) }
            }

        } else if vm.allItems.isEmpty {
            EmptyStateView.noMenuItems()

        } else {
            menuList(vm: vm)
                .searchable(
                    text: Binding(get: { vm.searchQuery }, set: { vm.searchQuery = $0 }),
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "menu_search_placeholder"
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        filterButton(vm: vm)
                    }
                }
                .sheet(isPresented: $showingFilters) {
                    MenuFilterView(viewModel: vm)
                }
                .refreshable {
                    await vm.refresh(restaurantId: restaurantId)
                }
        }
    }

    // MARK: - Menu List

    /// Sectioned list grouped by MenuCategory
    @ViewBuilder
    private func menuList(vm: MenuViewModel) -> some View {
        if vm.groupedMenu.isEmpty {
            // Empty state when filters return no results
            EmptyStateView(
                icon: "line.3.horizontal.decrease.circle",
                title: "menu_no_results_title",
                message: "menu_no_results_message",
                actionTitle: "clear_filters"
            ) {
                vm.clearFilters()
            }
        } else {
            List {
                ForEach(vm.groupedMenu, id: \.category) { section in
                    Section(header: Text(section.category.localised)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    ) {
                        ForEach(section.items) { item in
                            MenuItemRow(item: item)
                                .listRowInsets(EdgeInsets(
                                    top: Constants.UI.spacingSmall,
                                    leading: Constants.UI.spacingMedium,
                                    bottom: Constants.UI.spacingSmall,
                                    trailing: Constants.UI.spacingMedium
                                ))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: vm.filteredItems.map { $0.id })
        }
    }

    // MARK: - Filter Button

    @ViewBuilder
    private func filterButton(vm: MenuViewModel) -> some View {
        Button {
            showingFilters = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                // Show filled variant when filters are active (visual indicator)
                .symbolVariant(vm.hasActiveFilters ? .fill : .none)
                .foregroundStyle(vm.hasActiveFilters ? Color.accentColor : .primary)
        }
        .accessibilityLabel("accessibility_filter_menu")
    }
}

// MARK: - Menu Item Row

/// A single row representing a menu item
/// Shows image, name, description, price, dietary info, and availability
private struct MenuItemRow: View {

    let item: Menu

    var body: some View {
        HStack(spacing: Constants.UI.spacingMedium) {

            // ─── Thumbnail ─────────────────────────────────────────────
            if item.imageURL != nil {
                MenuItemImage(urlString: item.imageURL)
            }

            // ─── Info ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {

                // Name + availability
                HStack {
                    Text(item.name.localised)
                        .font(.headline)
                        .foregroundStyle(item.isAvailable ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()

                    if !item.isAvailable {
                        Text("unavailable")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary, in: Capsule())
                    }
                }

                // Description
                Text(item.description.localised)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Price + dietary tags + spice level
                HStack(spacing: Constants.UI.spacingSmall) {
                    Text(item.priceDisplay)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)

                    Spacer()

                    // Spice level (🌶️ icons)
                    if let spice = item.spiceLevelDisplay {
                        Text(spice)
                            .font(.caption2)
                    }

                    // Dietary tags as small chips
                    if !item.dietaryInfo.isEmpty {
                        dietaryChips(tags: item.dietaryInfo)
                    }
                }
            }
        }
        // Gray out unavailable items
        .opacity(item.isAvailable ? 1 : 0.6)
    }

    /// Renders up to 3 dietary tag chips (truncates with "+" if more)
    @ViewBuilder
    private func dietaryChips(tags: [DietaryTag]) -> some View {
        HStack(spacing: 4) {
            // Show first 2 tags as inline chips
            ForEach(tags.prefix(2), id: \.self) { tag in
                Text(tag.localised)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
            }
            // If more than 2 tags, show a count badge
            if tags.count > 2 {
                Text("+\(tags.count - 2)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Menu Filter View (sheet)

/// Bottom-sheet for selecting dietary filters and availability toggle
private struct MenuFilterView: View {

    /// ViewModel — passed as binding so changes reflect immediately in MenuView
    var viewModel: MenuViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {

                // ─── Availability ─────────────────────────────────────
                Section(header: Text("menu_filter_availability")) {
                    Toggle("menu_filter_available_only", isOn: Binding(
                        get: { viewModel.showAvailableOnly },
                        set: { viewModel.showAvailableOnly = $0 }
                    ))
                }

                // ─── Dietary Requirements ─────────────────────────────
                Section(header: Text("menu_filter_dietary")) {
                    ForEach(DietaryTag.allCases, id: \.self) { tag in
                        HStack {
                            Text(tag.localised)
                            Spacer()
                            // Checkmark when tag is selected
                            if viewModel.selectedDietaryFilters.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())  // Makes entire row tappable
                        .onTapGesture {
                            viewModel.toggleDietaryFilter(tag)
                        }
                    }
                }
            }
            .navigationTitle("menu_filter_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Done button
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        dismiss()
                    }
                }

                // Clear All (only when something is active)
                if viewModel.hasActiveFilters {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("clear_all", role: .destructive) {
                            viewModel.clearFilters()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MenuView(restaurantId: "preview-restaurant-id", restaurantName: "Preview Restaurant")
            .environment(\.services, Services())
    }
}
