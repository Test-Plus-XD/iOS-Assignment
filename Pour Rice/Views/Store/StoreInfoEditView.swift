//
//  StoreInfoEditView.swift
//  Pour Rice
//
//  Restaurant information editing form for owners
//  All bilingual fields, contact details, location, and image upload
//  Uses bundled JSON (districts, keywords, payments) for picker data
//

import SwiftUI
import PhotosUI
import MapKit

/// Form for editing restaurant information
struct StoreInfoEditView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"
    private var isTC: Bool { preferredLanguage == "zh-Hant" }

    // MARK: - Static Data (loaded once)

    private let allDistricts  = LocalDataLoader.loadDistricts()
    private let allKeywords   = LocalDataLoader.loadKeywords()
    private let allPayments   = LocalDataLoader.loadPayments()

    // MARK: - State

    @State private var viewModel = StoreViewModel()

    // Name
    @State private var nameEN = ""
    @State private var nameTC = ""

    // Description
    @State private var descEN = ""
    @State private var descTC = ""

    // Address
    @State private var addressEN = ""
    @State private var addressTC = ""

    // District (single select)
    @State private var selectedDistrict: LocalDataLoader.BilingualEntry? = nil
    @State private var showDistrictPicker = false

    // Keywords (multi-select)
    @State private var selectedKeywordIds = Set<String>()
    @State private var showKeywordPicker = false

    // Payments (multi-select)
    @State private var selectedPaymentIds = Set<String>()
    @State private var showPaymentPicker = false

    // Contact
    @State private var seats = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""

    // Location
    @State private var latitude  = ""
    @State private var longitude = ""

    // Save / upload state
    @State private var isSaving = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingImage = false

    // MARK: - Body

    var body: some View {
        Form {
            nameSection
            descriptionSection
            addressSection
            districtSection
            keywordsSection
            paymentsSection
            contactSection
            detailsSection
            locationSection
            imageSection
            saveSection
        }
        .navigationTitle("store_edit_info")
        .task { await loadExistingData() }
        .onChange(of: selectedPhoto) { _, newValue in
            if let newValue { Task { await uploadPhoto(newValue) } }
        }
        .sheet(isPresented: $showDistrictPicker) {
            DistrictPickerSheet(
                allDistricts: allDistricts,
                selected: $selectedDistrict,
                isTC: isTC
            )
        }
        .sheet(isPresented: $showKeywordPicker) {
            MultiSelectSheet(
                title: "store_edit_keywords",
                entries: allKeywords,
                selected: $selectedKeywordIds,
                isTC: isTC
            )
        }
        .sheet(isPresented: $showPaymentPicker) {
            MultiSelectSheet(
                title: "store_edit_payments",
                entries: allPayments,
                selected: $selectedPaymentIds,
                isTC: isTC
            )
        }
        .toast(message: viewModel.toastMessage, style: viewModel.toastStyle, isPresented: Binding(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        ))
    }

    // MARK: - Form Sections

    private var nameSection: some View {
        Section("store_edit_name") {
            TextField("English", text: $nameEN)
            TextField("繁體中文", text: $nameTC)
        }
    }

    private var descriptionSection: some View {
        Section("store_edit_description") {
            TextField("English", text: $descEN, axis: .vertical)
                .lineLimit(2...5)
            TextField("繁體中文", text: $descTC, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var addressSection: some View {
        Section("store_edit_address") {
            TextField("English", text: $addressEN)
            TextField("繁體中文", text: $addressTC)
        }
    }

    private var districtSection: some View {
        Section("store_edit_district") {
            Button {
                showDistrictPicker = true
            } label: {
                HStack {
                    if let d = selectedDistrict {
                        Text(isTC ? d.tc : d.en)
                            .foregroundStyle(.primary)
                    } else {
                        Text("store_edit_district_placeholder")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var keywordsSection: some View {
        Section("store_edit_keywords") {
            Button {
                showKeywordPicker = true
            } label: {
                HStack {
                    let selected = allKeywords.filter { selectedKeywordIds.contains($0.id) }
                    if selected.isEmpty {
                        Text("store_edit_keywords_placeholder")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(selected.map { isTC ? $0.tc : $0.en }.joined(separator: ", "))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var paymentsSection: some View {
        Section("store_edit_payments") {
            Button {
                showPaymentPicker = true
            } label: {
                HStack {
                    let selected = allPayments.filter { selectedPaymentIds.contains($0.id) }
                    if selected.isEmpty {
                        Text("store_edit_payments_placeholder")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(selected.map { isTC ? $0.tc : $0.en }.joined(separator: ", "))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var contactSection: some View {
        Section("store_edit_contact_info") {
            HStack {
                Label("", systemImage: "phone").labelStyle(.iconOnly).foregroundStyle(.secondary)
                TextField("store_edit_phone", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            HStack {
                Label("", systemImage: "envelope").labelStyle(.iconOnly).foregroundStyle(.secondary)
                TextField("store_edit_email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
            }
            HStack {
                Label("", systemImage: "globe").labelStyle(.iconOnly).foregroundStyle(.secondary)
                TextField("store_edit_website", text: $website)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
            }
        }
    }

    private var detailsSection: some View {
        Section("store_edit_details") {
            HStack {
                Label("", systemImage: "chair").labelStyle(.iconOnly).foregroundStyle(.secondary)
                TextField("store_edit_seats", text: $seats)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var locationSection: some View {
        Section("store_edit_location") {
            HStack {
                Text("store_edit_latitude").foregroundStyle(.secondary)
                Spacer()
                TextField("0.000000", text: $latitude)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }
            HStack {
                Text("store_edit_longitude").foregroundStyle(.secondary)
                Spacer()
                TextField("0.000000", text: $longitude)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }
            if let lat = Double(latitude), let lng = Double(longitude), lat != 0 || lng != 0 {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))) {
                    Marker("", systemImage: "fork.knife",
                           coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                    .tint(.accent)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(true)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    private var imageSection: some View {
        Section("store_edit_image") {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(
                    isUploadingImage ? "store_edit_uploading" : "store_edit_choose_image",
                    systemImage: "photo"
                )
            }
            .disabled(isUploadingImage)
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                Task { await save() }
            } label: {
                HStack {
                    Spacer()
                    if isSaving { ProgressView() }
                    else { Text("store_edit_save").fontWeight(.semibold) }
                    Spacer()
                }
            }
            .disabled(isSaving)
        }
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

        guard let r = viewModel.restaurant else { return }

        nameEN    = r.name.en
        nameTC    = r.name.tc
        descEN    = r.description.en
        descTC    = r.description.tc
        addressEN = r.address.en
        addressTC = r.address.tc
        seats     = r.seats > 0 ? "\(r.seats)" : ""
        phone     = r.phoneNumber
        email     = r.email ?? ""
        website   = r.website ?? ""

        let lat = r.location.latitude
        let lng = r.location.longitude
        if lat != 0 || lng != 0 {
            latitude  = String(format: "%.6f", lat)
            longitude = String(format: "%.6f", lng)
        }

        // Pre-select district from matching entry in allDistricts
        if !r.district.en.isEmpty {
            selectedDistrict = allDistricts.first { $0.en == r.district.en }
        }

        // Pre-select keywords
        let existingKwIds = Set(r.keywords.map { $0.en })
        selectedKeywordIds = Set(allKeywords.filter { existingKwIds.contains($0.en) }.map { $0.id })
    }

    // MARK: - Save

    private func save() async {
        isSaving = true

        let contactsUpdate: RestaurantContactsUpdate? = {
            guard !phone.isEmpty || !email.isEmpty || !website.isEmpty else { return nil }
            return RestaurantContactsUpdate(
                phone:   phone.isEmpty   ? nil : phone,
                email:   email.isEmpty   ? nil : email,
                website: website.isEmpty ? nil : website
            )
        }()

        let selectedKwEN = allKeywords.filter { selectedKeywordIds.contains($0.id) }.map { $0.en }
        let selectedKwTC = allKeywords.filter { selectedKeywordIds.contains($0.id) }.map { $0.tc }

        let request = UpdateRestaurantRequest(
            nameEN:        nameEN.isEmpty    ? nil : nameEN,
            nameTC:        nameTC.isEmpty    ? nil : nameTC,
            descriptionEN: descEN.isEmpty    ? nil : descEN,
            descriptionTC: descTC.isEmpty    ? nil : descTC,
            addressEN:     addressEN.isEmpty ? nil : addressEN,
            addressTC:     addressTC.isEmpty ? nil : addressTC,
            districtEN:    selectedDistrict?.en,
            districtTC:    selectedDistrict?.tc,
            keywordEN:     selectedKwEN.isEmpty ? nil : selectedKwEN,
            keywordTC:     selectedKwTC.isEmpty ? nil : selectedKwTC,
            seats:         Int(seats),
            contacts:      contactsUpdate,
            latitude:      Double(latitude),
            longitude:     Double(longitude)
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

// MARK: - District Picker Sheet

private struct DistrictPickerSheet: View {
    let allDistricts: [LocalDataLoader.BilingualEntry]
    @Binding var selected: LocalDataLoader.BilingualEntry?
    let isTC: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(allDistricts) { district in
                HStack {
                    Text(isTC ? district.tc : district.en)
                    Spacer()
                    if selected?.id == district.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selected = district
                    dismiss()
                }
            }
            .listStyle(.plain)
            .navigationTitle("store_edit_district")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Multi-Select Picker Sheet

private struct MultiSelectSheet: View {
    let title: LocalizedStringKey
    let entries: [LocalDataLoader.BilingualEntry]
    @Binding var selected: Set<String>
    let isTC: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                HStack {
                    Text(isTC ? entry.tc : entry.en)
                    Spacer()
                    if selected.contains(entry.id) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selected.contains(entry.id) {
                        selected.remove(entry.id)
                    } else {
                        selected.insert(entry.id)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
