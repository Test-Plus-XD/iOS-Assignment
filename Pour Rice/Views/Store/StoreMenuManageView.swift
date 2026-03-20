//
//  StoreMenuManageView.swift
//  Pour Rice
//
//  Menu management view for restaurant owners
//  Supports creating, editing, and deleting menu items
//

import SwiftUI

/// Restaurant owner's menu management interface
struct StoreMenuManageView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel = StoreViewModel()
    @State private var showAddItem = false

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.menuItems.isEmpty && !viewModel.isLoading {
                ContentUnavailableView {
                    Label(String(localized: "store_menu_empty"), systemImage: "menucard")
                } description: {
                    Text(String(localized: "store_menu_empty_description"))
                } actions: {
                    Button(String(localized: "store_menu_add")) {
                        showAddItem = true
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                List {
                    ForEach(viewModel.menuItems) { item in
                        menuItemRow(item)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let item = viewModel.menuItems[index]
                            Task { await viewModel.deleteMenuItem(id: item.id) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "store_manage_menu"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            if let restaurantId = authService.currentUser?.restaurantId {
                await viewModel.loadDashboard(
                    restaurantId: restaurantId,
                    storeService: services.storeService,
                    bookingService: services.bookingService,
                    menuService: services.menuService
                )
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddMenuItemSheet(viewModel: viewModel, restaurantId: authService.currentUser?.restaurantId ?? "")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    // MARK: - Menu Item Row

    private func menuItemRow(_ item: Menu) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name.localised)
                .font(.headline)
            if !item.description.localised.isEmpty {
                Text(item.description.localised)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if item.price > 0 {
                Text("HK$\(String(format: "%.0f", item.price))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Menu Item Sheet

private struct AddMenuItemSheet: View {
    let viewModel: StoreViewModel
    let restaurantId: String

    @Environment(\.dismiss) private var dismiss

    @State private var nameEN = ""
    @State private var nameTC = ""
    @State private var descEN = ""
    @State private var descTC = ""
    @State private var price = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "store_menu_name")) {
                    TextField("English", text: $nameEN)
                    TextField("繁體中文", text: $nameTC)
                }

                Section(String(localized: "store_menu_description")) {
                    TextField("English", text: $descEN, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("繁體中文", text: $descTC, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(String(localized: "store_menu_price")) {
                    TextField("HK$", text: $price)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text(String(localized: "store_menu_add"))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(nameEN.isEmpty || nameTC.isEmpty || isSubmitting)
                }
            }
            .navigationTitle(String(localized: "store_menu_add_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        let request = CreateMenuItemRequest(
            restaurantId: restaurantId,
            nameEN: nameEN,
            nameTC: nameTC,
            descriptionEN: descEN.isEmpty ? nil : descEN,
            descriptionTC: descTC.isEmpty ? nil : descTC,
            price: Double(price),
            image: nil
        )
        await viewModel.createMenuItem(request)
        isSubmitting = false
        dismiss()
    }
}
