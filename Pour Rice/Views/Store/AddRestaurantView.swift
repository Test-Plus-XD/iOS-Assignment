//
//  AddRestaurantView.swift
//  Pour Rice
//
//  Form sheet for restaurant owners to create a new restaurant listing.
//  Submits POST /API/Restaurants (ownerId in body, no auth required),
//  then links the restaurant to the user via PUT /API/Users/:uid.
//

import SwiftUI
import MapKit

// MARK: - Data Models

private typealias RestaurantKeywordOption = LocalDataLoader.BilingualEntry
private typealias RestaurantPaymentOption = LocalDataLoader.BilingualEntry
private typealias HKDistrictOption        = LocalDataLoader.BilingualEntry

// MARK: - AddRestaurantView

/// Sheet for creating a new restaurant listing.
/// Shown from ClaimRestaurantView when the owner cannot find their restaurant via search.
@MainActor
struct AddRestaurantView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.authService) private var authService
    @AppStorage("preferredLanguage") private var preferredLanguage: String = "en"

    // MARK: - Form State — Names
    @State private var nameEN = ""
    @State private var nameTC = ""

    // MARK: - Form State — Address
    @State private var addressEN = ""
    @State private var addressTC = ""
    @State private var selectedDistrictEN = ""
    @State private var selectedDistrictTC = ""

    // MARK: - Form State — Details
    @State private var seatsText = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""

    // MARK: - Form State — Location
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    // MARK: - Form State — Opening Hours
    // dayEnabled: true = open; dayFrom/dayTo = time-of-day (stored as Date)
    @State private var dayEnabled: [String: Bool] = [:]
    @State private var dayFrom: [String: Date] = [:]
    @State private var dayTo: [String: Date] = [:]

    // MARK: - Form State — Keywords & Payments
    @State private var selectedKeywordsEN: Set<String> = []
    @State private var selectedKeywordsTC: Set<String> = []
    @State private var selectedPayments: Set<String> = []

    // MARK: - UI State
    @State private var isSubmitting = false
    @State private var toastMessage = ""
    @State private var toastStyle: ToastStyle = .success
    @State private var showToast = false

    // MARK: - Computed
    private var isTC: Bool { preferredLanguage == "zh-Hant" }
    private var canSubmit: Bool { !nameEN.isEmpty || !nameTC.isEmpty }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Required
                Section(isTC ? "餐廳名稱 *" : "Restaurant Name *") {
                    TextField(isTC ? "英文名稱" : "Name (English)", text: $nameEN)
                        .autocorrectionDisabled()
                    TextField(isTC ? "中文名稱" : "Name (Chinese)", text: $nameTC)
                        .autocorrectionDisabled()
                    if nameEN.isEmpty && nameTC.isEmpty {
                        Text(isTC ? "請至少填寫一個名稱" : "At least one name is required")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Address
                Section(isTC ? "地址" : "Address") {
                    TextField(isTC ? "英文地址" : "Address (English)", text: $addressEN)
                        .autocorrectionDisabled()
                    TextField(isTC ? "中文地址" : "Address (Chinese)", text: $addressTC)
                        .autocorrectionDisabled()
                    Picker(isTC ? "地區" : "District", selection: $selectedDistrictEN) {
                        Text(isTC ? "選擇地區" : "Select District").tag("")
                        ForEach(hkDistricts) { district in
                            Text(isTC ? district.tc : district.en).tag(district.en)
                        }
                    }
                    .onChange(of: selectedDistrictEN) { _, newEN in
                        selectedDistrictTC = hkDistricts.first { $0.en == newEN }?.tc ?? ""
                    }
                }

                // Details
                Section(isTC ? "詳情" : "Details") {
                    TextField(isTC ? "座位數量" : "Seats", text: $seatsText)
                        .keyboardType(.numberPad)
                    TextField(isTC ? "電話" : "Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField(isTC ? "電郵" : "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                    TextField(isTC ? "網站" : "Website", text: $website)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                }

                // Location
                Section(isTC ? "位置" : "Location") {
                    MapReader { proxy in
                        Map(position: $mapCameraPosition) {
                            if let coord = selectedCoordinate {
                                Marker(isTC ? "餐廳位置" : "Restaurant Location", coordinate: coord)
                                    .tint(.accent)
                            }
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture { location in
                            if let coord = proxy.convert(location, from: .local) {
                                selectedCoordinate = coord
                            }
                        }
                    }

                    if let coord = selectedCoordinate {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.accent)
                                .font(.caption)
                            Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(isTC ? "清除" : "Clear") {
                                selectedCoordinate = nil
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    } else {
                        Label(
                            isTC ? "點擊地圖設定位置" : "Tap the map to set location",
                            systemImage: "hand.tap"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // Opening Hours
                Section(isTC ? "營業時間" : "Opening Hours") {
                    ForEach(orderedDays, id: \.en) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isTC ? day.tc : day.en, isOn: Binding(
                                get: { dayEnabled[day.en] ?? false },
                                set: { dayEnabled[day.en] = $0 }
                            ))

                            if dayEnabled[day.en] == true {
                                HStack {
                                    DatePicker(
                                        isTC ? "開始" : "From",
                                        selection: Binding(
                                            get: { dayFrom[day.en] ?? defaultOpenTime() },
                                            set: { dayFrom[day.en] = $0 }
                                        ),
                                        displayedComponents: .hourAndMinute
                                    )
                                    DatePicker(
                                        isTC ? "結束" : "To",
                                        selection: Binding(
                                            get: { dayTo[day.en] ?? defaultCloseTime() },
                                            set: { dayTo[day.en] = $0 }
                                        ),
                                        displayedComponents: .hourAndMinute
                                    )
                                }
                                .labelsHidden()
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Keywords — display in preferred language only
                Section(isTC ? "類別" : "Keywords") {
                    ForEach(restaurantKeywords) { keyword in
                        Toggle(
                            isTC ? keyword.tc : keyword.en,
                            isOn: Binding(
                                get: { selectedKeywordsEN.contains(keyword.en) },
                                set: { checked in
                                    if checked {
                                        selectedKeywordsEN.insert(keyword.en)
                                        selectedKeywordsTC.insert(keyword.tc)
                                    } else {
                                        selectedKeywordsEN.remove(keyword.en)
                                        selectedKeywordsTC.remove(keyword.tc)
                                    }
                                }
                            )
                        )
                    }
                }

                // Payments — display in preferred language only
                Section(isTC ? "付款方式" : "Payment Methods") {
                    ForEach(restaurantPayments) { payment in
                        Toggle(
                            isTC ? payment.tc : payment.en,
                            isOn: Binding(
                                get: { selectedPayments.contains(payment.en) },
                                set: { checked in
                                    if checked { selectedPayments.insert(payment.en) }
                                    else { selectedPayments.remove(payment.en) }
                                }
                            )
                        )
                    }
                }
            }
            .navigationTitle(isTC ? "新增餐廳" : "Add Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isTC ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button(isTC ? "新增" : "Add") {
                            Task { await submit() }
                        }
                        .disabled(!canSubmit)
                    }
                }
            }
            .toast(message: toastMessage, style: toastStyle, isPresented: $showToast)
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard canSubmit else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            guard let userId = authService.currentUser?.id else {
                throw APIError.unauthorized
            }

            // Build opening hours map
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            var openingHours: [String: String] = [:]
            for day in orderedDays {
                if dayEnabled[day.en] == true {
                    let from = formatter.string(from: dayFrom[day.en] ?? defaultOpenTime())
                    let to = formatter.string(from: dayTo[day.en] ?? defaultCloseTime())
                    openingHours[day.en] = "\(from)-\(to)"
                }
            }

            // Build contacts (only include non-empty fields)
            let contacts: NewRestaurantContacts? = (!phone.isEmpty || !email.isEmpty || !website.isEmpty)
                ? NewRestaurantContacts(
                    Phone: phone.isEmpty ? nil : phone,
                    Email: email.isEmpty ? nil : email,
                    Website: website.isEmpty ? nil : website
                )
                : nil

            let request = CreateRestaurantRequest(
                Name_EN: nameEN.isEmpty ? nil : nameEN,
                Name_TC: nameTC.isEmpty ? nil : nameTC,
                Address_EN: addressEN.isEmpty ? nil : addressEN,
                Address_TC: addressTC.isEmpty ? nil : addressTC,
                District_EN: selectedDistrictEN.isEmpty ? nil : selectedDistrictEN,
                District_TC: selectedDistrictTC.isEmpty ? nil : selectedDistrictTC,
                Latitude: selectedCoordinate?.latitude,
                Longitude: selectedCoordinate?.longitude,
                Keyword_EN: selectedKeywordsEN.isEmpty ? nil : Array(selectedKeywordsEN),
                Keyword_TC: selectedKeywordsTC.isEmpty ? nil : Array(selectedKeywordsTC),
                Seats: Int(seatsText),
                Contacts: contacts,
                Payments: selectedPayments.isEmpty ? nil : Array(selectedPayments),
                Opening_Hours: openingHours.isEmpty ? nil : openingHours,
                ownerId: userId
            )

            // 1. Create restaurant (no auth required)
            let newId = try await services.storeService.createRestaurant(request: request)

            // 2. Link restaurant to user profile (auth required)
            try await authService.updateUserProfile(
                UpdateUserRequest(restaurantId: newId)
            )

            toastMessage = isTC ? "餐廳已成功新增！" : "Restaurant added successfully!"
            toastStyle = .success
            showToast = true

            try await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            toastMessage = isTC ? "新增失敗，請重試" : "Failed to add restaurant. Please try again."
            toastStyle = .error
            showToast = true
        }
    }

    // MARK: - Helpers

    private func defaultOpenTime() -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private func defaultCloseTime() -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 22; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }
}

// MARK: - Static Data (loaded from bundled JSON)

private let orderedDays:        [LocalDataLoader.BilingualEntry] = LocalDataLoader.loadWeekdays()
private let hkDistricts:        [LocalDataLoader.BilingualEntry] = LocalDataLoader.loadDistricts()
private let restaurantKeywords: [LocalDataLoader.BilingualEntry] = LocalDataLoader.loadKeywords()
private let restaurantPayments: [LocalDataLoader.BilingualEntry] = LocalDataLoader.loadPayments()
