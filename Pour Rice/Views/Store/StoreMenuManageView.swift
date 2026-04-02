//
//  StoreMenuManageView.swift
//  Pour Rice
//
//  Menu management view for restaurant owners
//  Supports creating, editing, and deleting menu items
//  Liquid Glass toolbar buttons; bulk-delete selection mode
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
    @State private var editingItem: Menu? = nil

    /// Selection mode for bulk deletion
    @State private var isSelecting = false
    @State private var selectedIds = Set<String>()
    @State private var showDeleteConfirm = false

    @Namespace private var glassNamespace

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.menuItems.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                menuList
            }
        }
        .navigationTitle("store_manage_menu")
        .toolbar { toolbarContent }
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
            AddMenuItemSheet(
                viewModel: viewModel,
                restaurantId: authService.currentUser?.restaurantId ?? ""
            )
        }
        .sheet(item: $editingItem) { item in
            EditMenuItemSheet(viewModel: viewModel, item: item)
        }
        .confirmationDialog(
            "store_menu_delete_confirm_title",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("store_menu_delete_confirm_action", role: .destructive) {
                Task { await deleteSelected() }
            }
        } message: {
            Text("store_menu_delete_confirm_message")
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .toast(message: viewModel.toastMessage, style: viewModel.toastStyle, isPresented: Binding(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        ))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            // Liquid Glass button cluster: [bin] [+]
            GlassEffectContainer(spacing: 8) {
                // Bulk delete (bin) — only shown in normal mode; tapping enters selection
                if !isSelecting {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            isSelecting = true
                            selectedIds.removeAll()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .glassEffect(.regular.interactive(), in: Circle())
                    .glassEffectID("bin", in: glassNamespace)
                }

                // Add item button
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .glassEffectID("add", in: glassNamespace)
            }
        }

        // Selection-mode action bar
        if isSelecting {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") {
                    withAnimation(.spring(duration: 0.3)) {
                        isSelecting = false
                        selectedIds.removeAll()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if !selectedIds.isEmpty { showDeleteConfirm = true }
                } label: {
                    Text("store_menu_delete_selected")
                        .foregroundStyle(selectedIds.isEmpty ? .secondary : .red)
                }
                .disabled(selectedIds.isEmpty)
            }
        }
    }

    // MARK: - Menu List

    private var menuList: some View {
        List {
            ForEach(viewModel.menuItems) { item in
                menuItemRow(item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelecting {
                            toggleSelection(item.id)
                        } else {
                            editingItem = item
                        }
                    }
            }
            .onDelete { indexSet in
                guard !isSelecting else { return }
                for index in indexSet {
                    let item = viewModel.menuItems[index]
                    Task { await viewModel.deleteMenuItem(id: item.id) }
                }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: isSelecting)
    }

    // MARK: - Menu Item Row

    private func menuItemRow(_ item: Menu) -> some View {
        HStack(spacing: 12) {
            // Selection indicator
            if isSelecting {
                Image(systemName: selectedIds.contains(item.id)
                      ? "checkmark.circle.fill"
                      : "circle")
                    .foregroundStyle(selectedIds.contains(item.id) ? .tint : .secondary)
                    .font(.title3)
                    .animation(.spring(duration: 0.2), value: selectedIds.contains(item.id))
            }

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
                    Text(item.priceDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.accent)
                }
            }

            Spacer()

            // Edit chevron (normal mode only)
            if !isSelecting {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("store_menu_empty", systemImage: "menucard")
        } description: {
            Text("store_menu_empty_description")
        } actions: {
            Button("store_menu_add") { showAddItem = true }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ id: String) {
        withAnimation(.spring(duration: 0.2)) {
            if selectedIds.contains(id) {
                selectedIds.remove(id)
            } else {
                selectedIds.insert(id)
            }
        }
    }

    private func deleteSelected() async {
        let ids = selectedIds
        withAnimation { isSelecting = false; selectedIds.removeAll() }
        for id in ids {
            await viewModel.deleteMenuItem(id: id)
        }
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
                Section("store_menu_name") {
                    TextField("English", text: $nameEN)
                    TextField("繁體中文", text: $nameTC)
                }

                Section("store_menu_description") {
                    TextField("English", text: $descEN, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("繁體中文", text: $descTC, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("store_menu_price") {
                    TextField("HK$", text: $price)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting { ProgressView() }
                            else { Text("store_menu_add").fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .disabled(nameEN.isEmpty || nameTC.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("store_menu_add_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
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

// MARK: - Edit Menu Item Sheet

private struct EditMenuItemSheet: View {
    let viewModel: StoreViewModel
    let item: Menu

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
                Section("store_menu_name") {
                    TextField("English", text: $nameEN)
                    TextField("繁體中文", text: $nameTC)
                }

                Section("store_menu_description") {
                    TextField("English", text: $descEN, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("繁體中文", text: $descTC, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("store_menu_price") {
                    TextField("HK$", text: $price)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting { ProgressView() }
                            else { Text("store_edit_save").fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .disabled(nameEN.isEmpty || nameTC.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("store_menu_edit_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
            .onAppear {
                nameEN = item.name.en
                nameTC = item.name.tc
                descEN = item.description.en
                descTC = item.description.tc
                price  = item.price > 0 ? String(format: "%.0f", item.price) : ""
            }
        }
    }

    private func save() async {
        isSubmitting = true
        let request = UpdateMenuItemRequest(
            nameEN: nameEN.isEmpty ? nil : nameEN,
            nameTC: nameTC.isEmpty ? nil : nameTC,
            descriptionEN: descEN.isEmpty ? nil : descEN,
            descriptionTC: descTC.isEmpty ? nil : descTC,
            price: Double(price),
            image: nil
        )
        await viewModel.updateMenuItem(id: item.id, request: request)
        isSubmitting = false
        dismiss()
    }
}
