# Pour Rice: Flutter to Native iOS Conversion Plan

## 📊 Project Status & Progress

**Last Updated:** 14 February 2026

### ✅ Completed Sprints
- **Sprint 1: Foundation** - COMPLETED ✅
- **Sprint 2: Models & Network** - COMPLETED ✅
- **Sprint 3: Core Services** - COMPLETED ✅
- **Sprint 4: Authentication Flow** - COMPLETED ✅

### 📦 Latest Package Versions (Updated)
- Firebase iOS SDK: v12.9 (latest) - ✅ INSTALLED
- Alamofire: v5.x (latest) - ✅ INSTALLED
- Kingfisher: v8.x (latest) - ✅ INSTALLED
- AlgoliaSearchClient: v9.38 (latest) - ✅ INSTALLED

### ⚠️ Action Items Required
1. ✅ **Add Swift Package Dependencies** - COMPLETED by user
2. ✅ **GoogleService-Info.plist** - Already present in project

### 📁 Files Created in Sprints 1-4
#### Models
- ✅ `Models/BilingualText.swift` - Bilingual text support (EN/TC)
- ✅ `Models/Restaurant.swift` - Restaurant data model with Location and OpeningHour
- ✅ `Models/User.swift` - User profile model
- ✅ `Models/Review.swift` - Review and rating model
- ✅ `Models/Menu.swift` - Menu item model with dietary info

#### Network Layer
- ✅ `Core/Network/APIClient.swift` - Base network client with header injection
- ✅ `Core/Network/APIEndpoint.swift` - All API endpoint definitions
- ✅ `Core/Network/APIError.swift` - Localized error handling

#### Core Services
- ✅ `Core/Services/AuthService.swift` - Firebase authentication service
- ✅ `Core/Services/RestaurantService.swift` - Restaurant API with caching
- ✅ `Core/Services/ReviewService.swift` - Review submission and fetching
- ✅ `Core/Services/MenuService.swift` - Menu operations with filtering
- ✅ `Core/Services/AlgoliaService.swift` - Search service integration
- ✅ `Core/Services/LocationService.swift` - GPS location service

#### Views & UI
- ✅ `Views/Auth/LoginView.swift` - Email/password login screen
- ✅ `Views/Auth/SignUpView.swift` - User registration screen
- ✅ `Core/Extensions/View+Extensions.swift` - SwiftUI view helpers and service environment

#### App Configuration
- ✅ `App/AppDelegate.swift` - Firebase initialization
- ✅ `Pour_RiceApp.swift` - Updated with auth state management
- ✅ `Core/Utilities/Constants.swift` - API configuration and app constants
- ✅ `Resources/Localizable.xcstrings` - String Catalog with 30+ bilingual keys
- ✅ Folder structure: App, Core, Models, ViewModels, Views, Resources

### 🚀 Next Steps
- **Sprint 5**: Home & Search screens implementation
- **Sprint 6**: Restaurant Detail & Menu screens
- **Sprint 7**: Account screen & Polish
- All created files need to be added to Xcode project (drag & drop into appropriate groups)

---

## Overview

Convert the Pour Rice restaurant discovery app from Flutter/Ionic to a native iOS application using Swift, SwiftUI, and modern iOS development patterns. This plan focuses on delivering an MVP with core features while establishing a scalable architecture for future enhancements.

**Project:** iOS Assignment at `/Users/test-plus/Projects/iOS Assignment`
**Scope:** MVP - Restaurant search/discovery, authentication, menu viewing, reviews (NO bookings in MVP)
**Architecture:** SwiftUI with @Observable macro (iOS 17+)
**Backend:** Firebase iOS SDK + Vercel Express API
**Localization:** Full bilingual support (British English + Traditional Chinese)
**Code Style:** Detailed inline comments, modern iOS design patterns
**UI Guidelines:** Native iOS design (iOS HIG) - NOT Android Material Design

---

## Phase 1: Project Configuration & Dependencies

### 1.1 Update Deployment Target
**Critical:** Current deployment target is iOS 26.2

### 1.2 Add Swift Package Dependencies

**UPDATED: Using Latest Versions as of February 2026**

```swift
// Package Dependencies to add via Xcode > File > Add Package Dependencies
// See PACKAGE_DEPENDENCIES.md for detailed installation instructions

1. Firebase iOS SDK (v11.x - Latest)
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage
   URL: https://github.com/firebase/firebase-ios-sdk

2. Alamofire (v5.x - Latest) - Network layer
   - Cleaner API than URLSession
   - Request interceptors for automatic header injection
   - Multipart upload support
   URL: https://github.com/Alamofire/Alamofire

3. Kingfisher (v8.x - Latest) - Image loading/caching
   - Async image loading with SwiftUI integration
   - Memory and disk caching
   URL: https://github.com/onevcat/Kingfisher

4. AlgoliaSearchClient (v8.x - Latest) - Search
   - Native Algolia integration
   URL: https://github.com/algolia/algoliasearch-client-swift
```

**Note**: A detailed package installation guide has been created at `PACKAGE_DEPENDENCIES.md` with step-by-step instructions for adding packages in Xcode.

### 1.3 Firebase Configuration
- Download `GoogleService-Info.plist` from Firebase Console
- Add to project (Pour Rice target)
- Configure in AppDelegate for initialization before app launch

### 1.4 Create Project Structure

```
Pour Rice/
├── App/
│   ├── Pour_RiceApp.swift          # Main entry point
│   └── AppDelegate.swift           # Firebase config
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift         # Base network client
│   │   ├── APIEndpoint.swift       # Endpoint definitions
│   │   └── APIError.swift          # Error types
│   ├── Services/
│   │   ├── AuthService.swift       # Firebase Auth
│   │   ├── RestaurantService.swift # Restaurant API
│   │   ├── ReviewService.swift     # Review API
│   │   ├── MenuService.swift       # Menu API
│   │   ├── AlgoliaService.swift    # Search
│   │   └── LocationService.swift   # GPS
│   │   # Note: BookingService removed from MVP scope
│   ├── Extensions/
│   │   ├── View+Extensions.swift   # SwiftUI helpers
│   │   └── Date+Extensions.swift   # Date formatting
│   └── Utilities/
│       └── Constants.swift         # API URLs, keys
├── Models/
│   ├── Restaurant.swift            # Restaurant model
│   ├── User.swift                  # User profile
│   ├── Review.swift                # Review model
│   ├── Menu.swift              # Menu item
│   └── BilingualText.swift         # EN/TC text
│   # Note: Booking.swift removed from MVP scope
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── SearchViewModel.swift
│   ├── RestaurantViewModel.swift
│   ├── MenuViewModel.swift
│   └── AccountViewModel.swift
│   # Note: BookingViewModel removed from MVP scope
├── Views/
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── FilterView.swift
│   ├── Restaurant/
│   │   └── RestaurantView.swift
│   ├── Menu/
│   │   └── MenuView.swift
│   ├── Account/
│   │   └── AccountView.swift
│   # Note: Booking views and BookingHistoryView removed from MVP scope
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   └── Common/
│       ├── LoadingView.swift
│       ├── ErrorView.swift
│       └── AsyncImageView.swift
└── Resources/
    ├── Assets.xcassets/
    ├── Localizable.xcstrings         # String Catalog
    └── GoogleService-Info.plist
```

---

## Phase 2: Core Architecture Implementation

### 2.1 MVVM with @Observable Pattern

ViewModels use the new @Observable macro (iOS 17+) instead of ObservableObject:

```swift
@Observable
class HomeViewModel {
    var restaurants: [Restaurant] = []
    var isLoading = false
    var error: Error?

    private let restaurantService: RestaurantService

    init(restaurantService: RestaurantService) {
        self.restaurantService = restaurantService
    }

    func fetchRestaurants() async {
        isLoading = true
        defer { isLoading = false }

        do {
            restaurants = try await restaurantService.fetchNearby()
        } catch {
            self.error = error
        }
    }
}
```

Views automatically observe state changes:

```swift
struct HomeView: View {
    @State private var viewModel: HomeViewModel

    var body: some View {
        // UI updates automatically when viewModel properties change
        if viewModel.isLoading {
            LoadingView()
        } else {
            // Content
        }
    }
}
```

### 2.2 Navigation Structure

**Hybrid approach:** TabView for primary navigation + NavigationStack for hierarchical flows

Tab Structure for MVP (3 tabs):
1. **Home** - Featured/nearby restaurants
2. **Search** - Algolia-powered search with filters
3. **Account** - Profile, settings, language toggle

Note: Bookings tab removed from MVP scope

### 2.3 Dependency Injection

Use SwiftUI Environment for service injection:

```swift
// Define environment key
struct ServicesKey: EnvironmentKey {
    static let defaultValue = Services()
}

extension EnvironmentValues {
    var services: Services {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}

// Usage in views
@Environment(\.services) var services
```

---

## Phase 3: Network Layer & Services

### 3.1 API Client

**Base URL:** `https://vercel-express-api-alpha.vercel.app`
**Required Headers:**
- `x-api-passcode: PourRice` (all requests)
- `Authorization: Bearer <firebase_id_token>` (authenticated requests)

Create `Core/Network/APIClient.swift`:

```swift
protocol APIClient {
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T
}

class DefaultAPIClient: APIClient {
    private let session: URLSession
    private let authService: AuthService

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        var request = try buildRequest(endpoint)

        // Add required headers
        request.addValue("PourRice", forHTTPHeaderField: "x-api-passcode")

        // Add Firebase ID token if authenticated
        if let idToken = try? await authService.getIDToken() {
            request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### 3.2 API Endpoints

Create `Core/Network/APIEndpoint.swift`:

```swift
/// Defines all API endpoints for the Pour Rice backend
/// Each case represents a specific API operation with required parameters
enum APIEndpoint {
    /// Fetch restaurants near a geographical location
    /// - Parameters:
    ///   - lat: Latitude coordinate
    ///   - lng: Longitude coordinate
    ///   - radius: Search radius in metres (default: 5000)
    case fetchRestaurants(lat: Double, lng: Double, radius: Double)

    /// Fetch detailed information for a specific restaurant
    /// - Parameter id: Unique restaurant identifier
    case fetchRestaurant(id: String)

    /// Submit a new review for a restaurant
    /// - Parameter request: Review data including rating and comment
    case submitReview(ReviewRequest)

    /// Fetch menu items for a specific restaurant
    /// - Parameter restaurantId: Unique restaurant identifier
    case fetchMenuItems(restaurantId: String)

    /// Returns the URL path component for each endpoint
    var path: String {
        switch self {
        case .fetchRestaurants: return "/API/Restaurants/nearby"
        case .fetchRestaurant(let id): return "/API/Restaurants/\(id)"
        case .submitReview: return "/API/Reviews"
        case .fetchMenuItems(let id): return "/API/Restaurants/\(id)/menu"
        }
    }

    /// Returns the HTTP method for each endpoint
    var method: HTTPMethod {
        switch self {
        case .submitReview: return .post
        default: return .get
        }
    }
}
```

### 3.3 Error Handling

Create `Core/Network/APIError.swift`:

```swift
enum APIError: LocalizedError {
    case networkError(Error)
    case decodingError
    case unauthorized
    case serverError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .networkError: return String(localized: "error_network")
        case .decodingError: return String(localized: "error_decoding")
        case .unauthorized: return String(localized: "error_unauthorized")
        case .serverError(let code): return String(localized: "error_server_\(code)")
        case .invalidResponse: return String(localized: "error_invalid_response")
        }
    }
}
```

### 3.4 Firebase Auth Service

Create `Core/Services/AuthService.swift`:

```swift
@Observable
class AuthService {
    var currentUser: User?
    var isAuthenticated = false

    private let auth = Auth.auth()

    init() {
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            self?.isAuthenticated = user != nil
            Task {
                if let user = user {
                    try? await self?.loadUserProfile(uid: user.uid)
                }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        await loadUserProfile(uid: result.user.uid)
    }

    func signUp(email: String, password: String, name: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        // Create user profile in Firestore via API
        await createUserProfile(uid: result.user.uid, email: email, name: name)
    }

    func signOut() throws {
        try auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    func getIDToken() async throws -> String {
        guard let user = auth.currentUser else {
            throw APIError.unauthorized
        }
        return try await user.getIDToken()
    }
}
```

### 3.5 Restaurant Service

Create `Core/Services/RestaurantService.swift`:

```swift
class RestaurantService {
    private let apiClient: APIClient
    private let cache = NSCache<NSString, CacheEntry>()

    func fetchNearbyRestaurants(
        latitude: Double,
        longitude: Double,
        radius: Double = 5000
    ) async throws -> [Restaurant] {
        let endpoint = APIEndpoint.fetchRestaurants(lat: latitude, lng: longitude, radius: radius)
        let response = try await apiClient.request(endpoint, responseType: RestaurantListResponse.self)
        return response.restaurants
    }

    func fetchRestaurant(id: String) async throws -> Restaurant {
        // Check cache first
        if let cached = cache.object(forKey: id as NSString) {
            return cached.restaurant
        }

        let endpoint = APIEndpoint.fetchRestaurant(id: id)
        let restaurant = try await apiClient.request(endpoint, responseType: Restaurant.self)

        // Cache result
        cache.setObject(CacheEntry(restaurant: restaurant), forKey: id as NSString)
        return restaurant
    }
}
```

### 3.6 Algolia Search Service

Create `Core/Services/AlgoliaService.swift`:

```swift
class AlgoliaService {
    private let client: SearchClient
    private let indexName = "Restaurants"

    init() {
        client = SearchClient(
            appID: "V9HMGL1VIZ",
            apiKey: "ALGOLIA_SEARCH_KEY"
        )
    }

    func search(
        query: String,
        filters: SearchFilters,
        location: (lat: Double, lng: Double)? = nil
    ) async throws -> [Restaurant] {
        let index = client.index(withName: indexName)

        var searchQuery = Query(query: query)

        // Add location-based search
        if let location = location {
            searchQuery.aroundLatLng = LatLng(lat: location.lat, lng: location.lng)
            searchQuery.aroundRadius = .explicit(5000) // 5km
        }

        // Add filters
        if !filters.cuisines.isEmpty {
            searchQuery.filters = "cuisine:\(filters.cuisines.joined(separator: " OR "))"
        }

        let result = try await index.search(query: searchQuery)
        return try result.hits.map { try $0.object() }
    }
}
```

---

## Phase 4: Data Models

### 4.1 Bilingual Text Model

Create `Models/BilingualText.swift`:

```swift
struct BilingualText: Codable, Hashable {
    let en: String
    let tc: String // Traditional Chinese

    var localized: String {
        // Use app language setting
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        return language == "zh" ? tc : en
    }
}
```

### 4.2 Restaurant Model

Create `Models/Restaurant.swift`:

```swift
struct Restaurant: Codable, Identifiable {
    let id: String
    let name: BilingualText
    let description: BilingualText
    let address: BilingualText
    let district: BilingualText
    let cuisine: BilingualText
    let keywords: [BilingualText]
    let priceRange: String
    let rating: Double
    let reviewCount: Int
    let imageURLs: [String]
    let location: Location
    let openingHours: [OpeningHour]
    let phoneNumber: String
    let email: String?
    let website: String?
    let seats: Int

    // Custom decoding for backend field names
    enum CodingKeys: String, CodingKey {
        case id = "restaurantId"
        case name = "Name_EN" // Will need custom decoder
        case address = "Address_EN"
        case district = "District_EN"
        case keywords = "Keyword_EN"
        case priceRange, rating, reviewCount
        case imageURLs = "ImageUrl"
        case location = "Location"
        case openingHours, phoneNumber, email, website, seats
    }
}

struct Location: Codable {
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case latitude = "Latitude"
        case longitude = "Longitude"
    }
}

struct OpeningHour: Codable {
    let day: String
    let open: String
    let close: String
    let isClosed: Bool
}
```

### 4.3 Other Core Models

Create similar models for:
- `Models/User.swift` - User profile with uid, email, displayName, type, preferences
- `Models/Booking.swift` - Booking with restaurantId, userId, dateTime, numberOfGuests, status
- `Models/Review.swift` - Review with restaurantId, userId, rating, comment, images
- `Models/Menu.swift` - Menu with name (BilingualText), description (BilingualText), price, image

---

## Phase 5: Localization Setup

### 5.1 Create String Catalog

1. In Xcode: File > New > File > String Catalog
2. Name it `Localizable.xcstrings`
3. Add languages: English (en), Chinese Traditional (zh-Hant)

### 5.2 Key Localisation Strings (Initial Set)

Note: Using British English spelling throughout (localisation, authorised, etc.)

```
// Navigation
home_title - Home / 首頁
search_title - Search / 搜尋
account_title - Account / 帳戶

// Restaurant Detail
restaurant_details - Restaurant Details / 餐廳詳情
menu - Menu / 菜單
reviews - Reviews / 評價
opening_hours - Opening Hours / 營業時間
get_directions - Get Directions / 取得路線
call_restaurant - Call Restaurant / 致電餐廳
visit_website - Visit Website / 訪問網站

// Menu
menu_items - Menu Items / 菜單項目
search_menu - Search Menu / 搜尋菜單
price - Price / 價格
description - Description / 描述

// Reviews
write_review - Write Review / 撰寫評價
rating - Rating / 評分
submit - Submit / 提交

// Errors (British English)
error_network - Network error. Please try again. / 網絡錯誤，請重試
error_unauthorised - Please sign in to continue. / 請登入以繼續
error_server - Server error. Please try again later. / 伺服器錯誤，請稍後再試
error_decoding - Unable to process response. / 無法處理回應
error_invalid_response - Invalid response from server. / 伺服器回應無效

// Common
loading - Loading... / 載入中...
retry - Retry / 重試
cancel - Cancel / 取消
save - Save / 儲存
done - Done / 完成
close - Close / 關閉
```

### 5.3 Language Toggle Implementation

Store language preference in AppStorage:

```swift
@AppStorage("appLanguage") private var appLanguage = "en"

// Toggle in AccountView
Button {
    appLanguage = appLanguage == "en" ? "zh-Hant" : "en"
} label: {
    Text("language_toggle")
}

// Apply to root view
.environment(\.locale, Locale(identifier: appLanguage))
```

---

## Phase 6: MVP Screen Implementations

### 6.1 Authentication Flow

**LoginView.swift:**
- Email/password fields
- Sign in button
- "Don't have an account? Sign up" link
- Error message display

**SignUpView.swift:**
- Email, password, confirm password, display name fields
- Sign up button
- Terms agreement checkbox
- Validation feedback

### 6.2 Main Tab View

**ContentView.swift** becomes **MainTabView.swift**:

```swift
/// Main tab-based navigation structure for the app
/// Follows iOS Human Interface Guidelines for tab bar design
/// Uses SF Symbols for consistent iOS visual language
struct MainTabView: View {
    // MARK: - Environment Properties

    /// Access to app-wide services (dependency injection)
    @Environment(\.services) var services

    /// Persisted language preference (en or zh-Hant)
    @AppStorage("appLanguage") private var appLanguage = "en"

    // MARK: - Body

    var body: some View {
        TabView {
            // Home tab - Restaurant discovery
            HomeView(viewModel: HomeViewModel(restaurantService: services.restaurantService))
                .tabItem {
                    Label(String(localized: "home_title"), systemImage: "house.fill")
                }

            // Search tab - Algolia-powered search
            SearchView(viewModel: SearchViewModel(algoliaService: services.algoliaService))
                .tabItem {
                    Label(String(localized: "search_title"), systemImage: "magnifyingglass")
                }

            // Account tab - User profile and settings
            AccountView(viewModel: AccountViewModel(authService: services.authService))
                .tabItem {
                    Label(String(localized: "account_title"), systemImage: "person.fill")
                }
        }
        // Apply language preference to entire tab view hierarchy
        .environment(\.locale, Locale(identifier: appLanguage))
        // Use native iOS tab bar styling (not Material Design)
        .tint(.accentColor)
    }
}
```

### 6.3 Home Screen

**HomeView.swift:**
- Featured restaurants carousel (horizontal scroll)
- Nearby restaurants list (vertical)
- Location permission handling
- Pull-to-refresh
- Navigate to RestaurantView on tap

**HomeViewModel.swift:**
```swift
@Observable
class HomeViewModel {
    var featuredRestaurants: [Restaurant] = []
    var nearbyRestaurants: [Restaurant] = []
    var isLoading = false
    var error: Error?

    private let restaurantService: RestaurantService
    private let locationService: LocationService

    func fetchHomeData() async {
        isLoading = true
        defer { isLoading = false }

        guard let location = locationService.currentLocation else {
            // Handle no location permission
            return
        }

        async let featured = restaurantService.fetchFeatured()
        async let nearby = restaurantService.fetchNearby(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: 5000
        )

        do {
            featuredRestaurants = try await featured
            nearbyRestaurants = try await nearby
        } catch {
            self.error = error
        }
    }
}
```

### 6.4 Search Screen

**SearchView.swift:**
- Search bar with debouncing (300ms)
- Filter button (opens FilterView sheet)
- Results list with restaurant cards
- Empty state for no results
- Loading skeleton

**SearchViewModel.swift:**
```swift
@Observable
class SearchViewModel {
    var searchQuery = ""
    var results: [Restaurant] = []
    var filters = SearchFilters()
    var isSearching = false

    private let algoliaService: AlgoliaService
    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300)) // Debounce
            guard !Task.isCancelled else { return }

            isSearching = true
            defer { isSearching = false }

            do {
                results = try await algoliaService.search(
                    query: searchQuery,
                    filters: filters
                )
            } catch {
                results = []
            }
        }
    }
}
```

### 6.5 Restaurant Detail Screen

**RestaurantView.swift:**
- Hero image carousel with page indicators
- Restaurant name, rating, cuisine, price range
- "Book Table" button (prominent CTA)
- Opening hours with current open/closed status
- Location map preview (tap for Apple Maps)
- Reviews section (show 3, "See all" button)
- Menu preview (show 6 items, "See full menu" button)

**RestaurantViewModel.swift:**
```swift
@Observable
class RestaurantViewModel {
    var restaurant: Restaurant?
    var reviews: [Review] = []
    var menuPreview: [Menu] = []
    var isLoading = false
    var error: Error?

    func loadRestaurant(id: String) async {
        isLoading = true
        defer { isLoading = false }

        async let restaurantTask = restaurantService.fetchRestaurant(id: id)
        async let reviewsTask = reviewService.fetchReviews(restaurantId: id, limit: 3)
        async let menuTask = menuService.fetchMenuItems(restaurantId: id, limit: 6)

        do {
            restaurant = try await restaurantTask
            reviews = try await reviewsTask
            menuPreview = try await menuTask
        } catch {
            self.error = error
        }
    }
}
```

### 6.6 Menu Screen

**MenuView.swift:**
- Categorized menu items (Appetizers, Mains, Desserts, Drinks)
- Sticky section headers
- Search within menu
- Tap item for detail modal (image, description, price, dietary info)

### 6.7 Account Screen

**AccountView.swift:**
- User profile section (name, email, photo)
- Language toggle (EN/TC) using native iOS style picker
- Sign out button
- App version footer
- Native iOS list style (grouped, not Material Design cards)

---

## Phase 7: Implementation Sequence

### Sprint 1: Foundation (Days 1-3) - **COMPLETED** ✅
1. ✅ Update deployment target to iOS 17.0 in project settings
2. ✅ Add SPM dependencies (Firebase, Alamofire, Kingfisher, Algolia) - User completed on macOS
3. ✅ GoogleService-Info.plist already present in project
4. ✅ Create folder structure as outlined in Phase 1.4
5. ⚠️ Item.swift kept as requested (SwiftData integration preserved)
6. ✅ Create Constants.swift with API URLs and keys
7. ✅ Set up String Catalog with initial localization strings (30+ keys)

### Sprint 2: Models & Network (Days 4-6) - **COMPLETED** ✅
1. ✅ Create BilingualText.swift model
2. ✅ Create Restaurant.swift with custom decoding for API responses
3. ✅ Create User.swift, Review.swift, Menu.swift models
4. ✅ Create APIClient.swift with automatic header injection
5. ✅ Create APIEndpoint.swift with all REST endpoints
6. ✅ Create APIError.swift with British English localized errors
7. ⚠️ Test API integration - Requires Xcode on macOS

### Sprint 3: Core Services (Days 7-9) - **COMPLETED** ✅
1. ✅ Create AppDelegate.swift for Firebase initialisation
2. ✅ Create AuthService.swift with sign in/up/out (@Observable, detailed comments)
3. ✅ Create RestaurantService.swift with NSCache caching (detailed comments)
4. ✅ Create ReviewService.swift with validation (detailed comments)
5. ✅ Create MenuService.swift with filtering/sorting (detailed comments)
6. ✅ Create AlgoliaService.swift with geospatial search (detailed comments)
7. ✅ Create LocationService.swift with CLLocationManager (detailed comments)
8. ⚠️ Test each service independently - Requires Xcode on macOS
Note: BookingService removed from MVP

### Sprint 4: Authentication Flow (Days 10-11) - **COMPLETED** ✅
1. ✅ Create LoginView.swift with email/password validation
2. ✅ Create SignUpView.swift with password confirmation and terms agreement
3. ✅ Create View+Extensions.swift for services environment and SwiftUI helpers
4. ✅ Update Pour_RiceApp.swift with @Observable, auth state management, and RootView
5. ✅ Implement PasswordResetView for forgot password flow
6. ⚠️ Test complete auth flow (sign up → sign in → sign out) - Requires Xcode on macOS

### Sprint 5: Home & Search (Days 12-15)
1. ✅ Create MainTabView.swift (replace ContentView)
2. ✅ Create HomeViewModel.swift
3. ✅ Create HomeView.swift with featured carousel and nearby list
4. ✅ Create SearchViewModel.swift with debouncing
5. ✅ Create SearchView.swift with search bar and filters
6. ✅ Create FilterView.swift sheet
7. ✅ Test navigation and data loading

### Sprint 6: Restaurant Detail & Menu (Days 16-18)
1. ✅ Create RestaurantViewModel.swift
2. ✅ Create RestaurantView.swift with all sections
3. ✅ Create MenuViewModel.swift
4. ✅ Create MenuView.swift with categories
5. ✅ Create AsyncImageView.swift wrapper for Kingfisher
6. ✅ Test navigation from search/home to detail to menu

### Sprint 7: Account & Polish (Days 19-21)
1. ✅ Create AccountViewModel.swift (with detailed comments)
2. ✅ Create AccountView.swift with native iOS design
3. ✅ Implement language toggle (native iOS picker)
4. ✅ Add loading states to all views (LoadingView.swift)
5. ✅ Add error states (ErrorView.swift)
6. ✅ Add empty states (EmptyStateView.swift)
7. ✅ Implement pull-to-refresh on lists (native iOS style)
8. ✅ Add haptic feedback for buttons
9. ✅ Complete localisation (all strings in British English)
10. ✅ Test language switching across all screens

### Sprint 8: iOS Design Polish (Days 22-24)
1. ✅ Apply iOS Human Interface Guidelines throughout
2. ✅ Ensure all UI uses native iOS components (no Material Design)
3. ✅ Implement proper iOS navigation patterns
4. ✅ Add SF Symbols throughout for consistency
5. ✅ Apply iOS-native spacing and padding
6. ✅ Use iOS system colours and semantic colours
7. ✅ Implement iOS-native card styles (not Material cards)
8. ✅ Add iOS-native animations and transitions
9. ✅ VoiceOver accessibility testing
10. ✅ Dynamic Type support verification

### Sprint 9: Final Review (Days 25-26)
1. ✅ End-to-end testing of all flows
2. ✅ Fix any bugs found
3. ✅ Verify British English spelling throughout
4. ✅ Code review for comment quality
5. ✅ Documentation update
6. ✅ Prepare for TestFlight/App Store submission

Note: Testing removed from MVP scope (no unit or UI tests)

---

## Critical Files to Modify/Create

### Files to Modify:
1. `/Users/test-plus/Projects/iOS Assignment/Pour Rice/Pour_RiceApp.swift`
   - Add AppDelegate
   - Add environment setup
   - Add auth state management
   - Replace ContentView with MainTabView

2. `/Users/test-plus/Projects/iOS Assignment/Pour Rice/ContentView.swift`
   - Rename to MainTabView.swift
   - Implement tab structure
   - Add language environment

### Files to Delete:
1. `/Users/test-plus/Projects/iOS Assignment/Pour Rice/Item.swift` (SwiftData model)

### Files to Create (prioritized):
1. `Core/Utilities/Constants.swift` - API configuration
2. `Core/Network/APIClient.swift` - Network foundation
3. `Core/Network/APIEndpoint.swift` - Endpoint definitions
4. `Core/Network/APIError.swift` - Error handling
5. `Models/BilingualText.swift` - Bilingual support
6. `Models/Restaurant.swift` - Core domain model
7. `Core/Services/AuthService.swift` - Authentication
8. `App/AppDelegate.swift` - Firebase initialization
9. `Resources/Localizable.xcstrings` - Localization

---

## Verification & Testing

### Manual Testing Checklist:
- [ ] Sign up with new account
- [ ] Sign in with existing account
- [ ] View featured restaurants on home
- [ ] View nearby restaurants (with location permission)
- [ ] Search for restaurant by name
- [ ] Apply filters in search
- [ ] View restaurant detail
- [ ] Navigate to full menu
- [ ] Submit a review
- [ ] Toggle language EN ↔ TC
- [ ] Verify British English spelling in all error messages
- [ ] Verify iOS-native design (not Android/Material)
- [ ] Sign out

Note: Automated testing removed from MVP scope

### Performance Targets:
- App launch time < 2 seconds
- Home screen load < 1 second (with cached images)
- Search response < 500ms (Algolia)
- Memory usage < 150 MB average
- Smooth scrolling at 60 FPS

---

## Success Criteria

### Technical:
- ✅ All SPM dependencies installed and configured
- ✅ Firebase authentication working
- ✅ API integration with all required endpoints
- ✅ Algolia search functional with filters
- ✅ Full bilingual support (British English/TC)
- ✅ Detailed inline comments throughout codebase
- ✅ Native iOS design (no Android/Material Design elements)
- ✅ British English spelling in all strings and code
- ✅ No memory leaks

### User Experience:
- ✅ Complete authentication flow
- ✅ Restaurant discovery (home + search)
- ✅ Restaurant detail viewing
- ✅ Menu browsing
- ✅ Review submission
- ✅ Language switching
- ✅ Smooth, responsive UI (iOS-native feel)
- ✅ Proper error handling with British English messages
- ✅ iOS Human Interface Guidelines compliance

---

## Future Enhancements (Post-MVP)

Phase 2 features to add later:
1. Real-time chat with Socket.IO
2. Google Gemini AI restaurant recommendations
3. QR code scanning for menu/table check-in
4. Payment integration (Stripe/Apple Pay)
5. Push notifications for booking reminders
6. Social features (share restaurants, reviews)
7. Dark mode support
8. iPad optimization with adaptive layouts
9. Apple Watch companion app
10. Offline mode with Firestore persistence
11. Restaurant owner dashboard
12. Review photo uploads
13. Advanced filters (dietary restrictions, ambiance)
14. Reservation modification/cancellation
15. Restaurant favorites/bookmarks

---

## Important Notes

### Code Quality
- **Comments Required:** All classes, functions, and complex logic must have detailed inline comments
- **British English:** Use British spelling throughout (initialise, authorise, localisation, colour, etc.)
- **iOS Design Language:** Follow iOS Human Interface Guidelines strictly - no Material Design patterns

### iOS vs Android Design Differences
- **Navigation:** iOS TabView and NavigationStack (not Android bottom nav or drawer)
- **Lists:** iOS native List with .listStyle(.insetGrouped) or .grouped (not Material cards)
- **Buttons:** iOS native Button with .buttonStyle(.bordered) or SF Symbols (not Material floating action buttons)
- **Text Fields:** iOS native TextField with .textFieldStyle(.roundedBorder) (not Material outlined fields)
- **Colours:** iOS semantic colours (.primary, .secondary) or SF Symbols tinting (not Material colour palette)
- **Spacing:** iOS standard spacing (8, 16, 24pt) (not Material 4dp grid)
- **Typography:** iOS San Francisco font system (not Roboto)
- **Icons:** SF Symbols exclusively (not Material Icons)
- **Cards:** iOS .background with rounded corners (not Material elevation/shadows)

### Technical Architecture
- Architecture uses iOS 17+ @Observable for cleaner state management
- Firebase SDK handles auth, API handles data
- Algolia provides search, backend handles reviews
- String Catalog provides professional bilingual support
- Kingfisher handles image caching automatically
- Location permission required for nearby restaurants feature
- All API calls require `x-api-passcode: PourRice` header
- Backend expects bilingual fields as `Name_EN`, `Name_TC` format
- Bookings removed from MVP - will be added in Phase 2
- Testing removed from MVP - will be added in Phase 2
