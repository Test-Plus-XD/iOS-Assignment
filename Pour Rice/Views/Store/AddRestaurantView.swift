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

private struct RestaurantKeywordOption: Identifiable {
    let id = UUID()
    let en: String
    let tc: String
}

private struct RestaurantPaymentOption: Identifiable {
    let id = UUID()
    let en: String
    let tc: String
}

private struct HKDistrictOption: Identifiable {
    let id = UUID()
    let en: String
    let tc: String
}

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

// MARK: - Static Data (matching Flutter/Ionic constants exactly)

private let orderedDays: [(en: String, tc: String)] = [
    ("Monday", "星期一"), ("Tuesday", "星期二"), ("Wednesday", "星期三"),
    ("Thursday", "星期四"), ("Friday", "星期五"), ("Saturday", "星期六"), ("Sunday", "星期日")
]

private let hkDistricts: [HKDistrictOption] = [
    HKDistrictOption(en: "Islands", tc: "離島"),
    HKDistrictOption(en: "Kwai Tsing", tc: "葵青"),
    HKDistrictOption(en: "North", tc: "北區"),
    HKDistrictOption(en: "Sai Kung", tc: "西貢"),
    HKDistrictOption(en: "Sha Tin", tc: "沙田"),
    HKDistrictOption(en: "Tai Po", tc: "大埔"),
    HKDistrictOption(en: "Tsuen Wan", tc: "荃灣"),
    HKDistrictOption(en: "Tuen Mun", tc: "屯門"),
    HKDistrictOption(en: "Yuen Long", tc: "元朗"),
    HKDistrictOption(en: "Kowloon City", tc: "九龍城"),
    HKDistrictOption(en: "Kwun Tong", tc: "觀塘"),
    HKDistrictOption(en: "Sham Shui Po", tc: "深水埗"),
    HKDistrictOption(en: "Wong Tai Sin", tc: "黃大仙"),
    HKDistrictOption(en: "Yau Tsim Mong", tc: "油尖旺區"),
    HKDistrictOption(en: "Central/Western", tc: "中西區"),
    HKDistrictOption(en: "Eastern", tc: "東區"),
    HKDistrictOption(en: "Southern", tc: "南區"),
    HKDistrictOption(en: "Wan Chai", tc: "灣仔"),
]

private let restaurantKeywords: [RestaurantKeywordOption] = [
    // Core vegan/plant-based
    RestaurantKeywordOption(en: "Vegan", tc: "純素"),
    RestaurantKeywordOption(en: "Vegetarian", tc: "素食"),
    RestaurantKeywordOption(en: "Plant-Based", tc: "植物性"),
    RestaurantKeywordOption(en: "Organic", tc: "有機"),
    RestaurantKeywordOption(en: "Farm-to-Table", tc: "農場直送"),
    RestaurantKeywordOption(en: "Sustainable", tc: "可持續"),
    RestaurantKeywordOption(en: "Eco-Friendly", tc: "環保"),
    RestaurantKeywordOption(en: "Whole Foods", tc: "全食物"),
    RestaurantKeywordOption(en: "Raw Vegan", tc: "生機素食"),
    RestaurantKeywordOption(en: "Macrobiotic", tc: "長壽飲食"),
    // Religious
    RestaurantKeywordOption(en: "Buddhism", tc: "佛教"),
    RestaurantKeywordOption(en: "Buddhist Vegetarian", tc: "齋"),
    RestaurantKeywordOption(en: "Muslim", tc: "穆斯林"),
    RestaurantKeywordOption(en: "Halal", tc: "清真"),
    RestaurantKeywordOption(en: "Kosher", tc: "猶太潔食"),
    RestaurantKeywordOption(en: "Jain", tc: "耆那教"),
    RestaurantKeywordOption(en: "Hindu", tc: "印度教"),
    RestaurantKeywordOption(en: "Taoist", tc: "道教"),
    // Cuisine
    RestaurantKeywordOption(en: "Asian", tc: "亞洲菜"),
    RestaurantKeywordOption(en: "Chinese", tc: "中菜"),
    RestaurantKeywordOption(en: "Japanese", tc: "日本菜"),
    RestaurantKeywordOption(en: "Korean", tc: "韓國菜"),
    RestaurantKeywordOption(en: "Thai", tc: "泰國菜"),
    RestaurantKeywordOption(en: "Vietnamese", tc: "越南菜"),
    RestaurantKeywordOption(en: "Indian", tc: "印度菜"),
    RestaurantKeywordOption(en: "Italian", tc: "意大利菜"),
    RestaurantKeywordOption(en: "Mediterranean", tc: "地中海菜"),
    RestaurantKeywordOption(en: "Mexican", tc: "墨西哥菜"),
    RestaurantKeywordOption(en: "Middle Eastern", tc: "中東菜"),
    RestaurantKeywordOption(en: "Western", tc: "西式"),
    RestaurantKeywordOption(en: "Fusion", tc: "融合菜"),
    RestaurantKeywordOption(en: "International", tc: "國際菜"),
    // Restaurant types
    RestaurantKeywordOption(en: "Fine Dining", tc: "高級餐廳"),
    RestaurantKeywordOption(en: "Casual Dining", tc: "休閒餐廳"),
    RestaurantKeywordOption(en: "Fast Casual", tc: "快餐店"),
    RestaurantKeywordOption(en: "Cafe", tc: "咖啡廳"),
    RestaurantKeywordOption(en: "Bistro", tc: "小酒館"),
    RestaurantKeywordOption(en: "Buffet", tc: "自助餐"),
    RestaurantKeywordOption(en: "Food Court", tc: "美食廣場"),
    RestaurantKeywordOption(en: "Takeaway", tc: "外賣"),
    RestaurantKeywordOption(en: "Delivery", tc: "送餐"),
    // Meal types
    RestaurantKeywordOption(en: "Breakfast", tc: "早餐"),
    RestaurantKeywordOption(en: "Brunch", tc: "早午餐"),
    RestaurantKeywordOption(en: "Lunch", tc: "午餐"),
    RestaurantKeywordOption(en: "Dinner", tc: "晚餐"),
    RestaurantKeywordOption(en: "All-Day Dining", tc: "全日餐飲"),
    // Dietary
    RestaurantKeywordOption(en: "Gluten-Free", tc: "無麩質"),
    RestaurantKeywordOption(en: "Soy-Free", tc: "無大豆"),
    RestaurantKeywordOption(en: "Nut-Free", tc: "無堅果"),
    RestaurantKeywordOption(en: "Sugar-Free", tc: "無糖"),
    RestaurantKeywordOption(en: "Oil-Free", tc: "無油"),
    RestaurantKeywordOption(en: "Low-Carb", tc: "低碳水"),
    RestaurantKeywordOption(en: "High-Protein", tc: "高蛋白"),
    RestaurantKeywordOption(en: "Keto-Friendly", tc: "生酮友善"),
    // Specialty
    RestaurantKeywordOption(en: "Smoothie Bowls", tc: "冰沙碗"),
    RestaurantKeywordOption(en: "Juices", tc: "果汁"),
    RestaurantKeywordOption(en: "Coffee", tc: "咖啡"),
    RestaurantKeywordOption(en: "Tea", tc: "茶"),
    RestaurantKeywordOption(en: "Desserts", tc: "甜品"),
    RestaurantKeywordOption(en: "Bakery", tc: "麵包店"),
    RestaurantKeywordOption(en: "Noodles", tc: "麵食"),
    RestaurantKeywordOption(en: "Rice Bowls", tc: "飯類"),
    RestaurantKeywordOption(en: "Salads", tc: "沙律"),
    RestaurantKeywordOption(en: "Soups", tc: "湯類"),
    RestaurantKeywordOption(en: "Burgers", tc: "漢堡"),
    RestaurantKeywordOption(en: "Pizza", tc: "披薩"),
    RestaurantKeywordOption(en: "Pasta", tc: "意粉"),
    RestaurantKeywordOption(en: "Tacos", tc: "墨西哥捲餅"),
    RestaurantKeywordOption(en: "Sushi", tc: "壽司"),
    RestaurantKeywordOption(en: "Ramen", tc: "拉麵"),
    RestaurantKeywordOption(en: "Dumplings", tc: "餃子"),
    RestaurantKeywordOption(en: "Dim Sum", tc: "點心"),
    RestaurantKeywordOption(en: "Hot Pot", tc: "火鍋"),
    // Ambiance
    RestaurantKeywordOption(en: "Pet-Friendly", tc: "寵物友善"),
    RestaurantKeywordOption(en: "Kid-Friendly", tc: "兒童友善"),
    RestaurantKeywordOption(en: "Romantic", tc: "浪漫"),
    RestaurantKeywordOption(en: "Business", tc: "商務"),
    RestaurantKeywordOption(en: "Casual", tc: "休閒"),
    RestaurantKeywordOption(en: "Cozy", tc: "舒適"),
    RestaurantKeywordOption(en: "Modern", tc: "現代"),
    RestaurantKeywordOption(en: "Traditional", tc: "傳統"),
    RestaurantKeywordOption(en: "Rooftop", tc: "天台"),
    RestaurantKeywordOption(en: "Waterfront", tc: "海濱"),
    RestaurantKeywordOption(en: "Garden", tc: "花園"),
    RestaurantKeywordOption(en: "Outdoor Seating", tc: "戶外座位"),
    RestaurantKeywordOption(en: "Private Room", tc: "私人房間"),
    RestaurantKeywordOption(en: "Bar", tc: "酒吧"),
    RestaurantKeywordOption(en: "Live Music", tc: "現場音樂"),
    RestaurantKeywordOption(en: "Wi-Fi", tc: "Wi-Fi"),
    RestaurantKeywordOption(en: "Air-Conditioned", tc: "室內冷氣"),
]

private let restaurantPayments: [RestaurantPaymentOption] = [
    RestaurantPaymentOption(en: "Cash", tc: "現金"),
    RestaurantPaymentOption(en: "Credit Card", tc: "信用卡"),
    RestaurantPaymentOption(en: "Debit Card", tc: "扣賬卡"),
    RestaurantPaymentOption(en: "Octopus", tc: "八達通"),
    RestaurantPaymentOption(en: "AliPay HK", tc: "支付寶香港"),
    RestaurantPaymentOption(en: "WeChat Pay HK", tc: "微信支付香港"),
    RestaurantPaymentOption(en: "PayMe", tc: "PayMe"),
    RestaurantPaymentOption(en: "FPS", tc: "轉數快"),
    RestaurantPaymentOption(en: "Apple Pay", tc: "Apple Pay"),
    RestaurantPaymentOption(en: "Google Pay", tc: "Google Pay"),
]
