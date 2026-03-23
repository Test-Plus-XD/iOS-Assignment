//
//  StoreInfoEditView.swift
//  Pour Rice
//
//  Restaurant information editing form for owners
//  Supports bilingual fields, image upload, and contact details
//

import SwiftUI
import PhotosUI

/// Form for editing restaurant information
struct StoreInfoEditView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel = StoreViewModel()
    @State private var nameEN = ""
    @State private var nameTC = ""
    @State private var addressEN = ""
    @State private var addressTC = ""
    @State private var seats = ""
    @State private var contacts = ""
    @State private var isSaving = false

    // Photo picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingImage = false

    // MARK: - Body

    var body: some View {
        Form {
            // Name
            Section("store_edit_name") {
                TextField("English", text: $nameEN)
                TextField("繁體中文", text: $nameTC)
            }

            // Address
            Section("store_edit_address") {
                TextField("English", text: $addressEN)
                TextField("繁體中文", text: $addressTC)
            }

            // Details
            Section("store_edit_details") {
                TextField("store_edit_seats", text: $seats)
                    .keyboardType(.numberPad)
                TextField("store_edit_contacts", text: $contacts)
                    .textContentType(.telephoneNumber)
            }

            // Image
            Section("store_edit_image") {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    Label(
                        isUploadingImage
                            ? "store_edit_uploading"
                            : "store_edit_choose_image",
                        systemImage: "photo"
                    )
                }
                .disabled(isUploadingImage)
            }

            // Save
            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("store_edit_save")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("store_edit_info")
        .task {
            await loadExistingData()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if let newValue {
                Task { await uploadPhoto(newValue) }
            }
        }
        .toast(message: viewModel.toastMessage, style: viewModel.toastStyle, isPresented: Binding(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        ))
    }

    // MARK: - Load Existing Data

    private func loadExistingData() async {
        guard let restaurantId = authService.currentUser?.restaurantId else { return }

        await viewModel.loadDashboard(
            restaurantId: restaurantId,
            storeService: services.storeService,
            bookingService: services.bookingService,
            menuService: services.menuService
        )

        if let restaurant = viewModel.restaurant {
            nameEN = restaurant.name.en
            nameTC = restaurant.name.tc
            addressEN = restaurant.address.en
            addressTC = restaurant.address.tc
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true

        let request = UpdateRestaurantRequest(
            nameEN: nameEN.isEmpty ? nil : nameEN,
            nameTC: nameTC.isEmpty ? nil : nameTC,
            addressEN: addressEN.isEmpty ? nil : addressEN,
            addressTC: addressTC.isEmpty ? nil : addressTC,
            seats: Int(seats),
            contacts: contacts.isEmpty ? nil : contacts.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        )

        await viewModel.updateRestaurantInfo(request: request)
        isSaving = false
    }

    // MARK: - Upload Photo

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        isUploadingImage = true
        if let data = try? await item.loadTransferable(type: Data.self) {
            _ = await viewModel.uploadImage(imageData: data)
        }
        isUploadingImage = false
    }

}
