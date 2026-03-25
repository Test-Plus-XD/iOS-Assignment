# Pour Rice - iOS Assignment

## Overview
A SwiftUI-based iOS application for vegetarian restaurant discovery in Hong Kong.
Supports multiple user types (diners and restaurant owners) with real-time chat, AI-powered assistance, booking management, and restaurant administration. Fetches restaurant data from a Vercel Express backend (with Algolia search proxy) and uses Firebase for authentication.

## Technology Stack
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI (Liquid Glass, iOS 26+)
- **Architecture**: MVVM with `@Observable` and `@Environment`
- **Authentication**: Firebase Auth (email/password + Google Sign-In) with guest browsing mode
- **Backend**: Vercel Express API (`https://vercel-express-api-alpha.vercel.app`)
- **Real-time**: Socket.IO v4 via Railway (`https://railway-socket-production.up.railway.app`)
- **AI**: Google Gemini via Vercel proxy (`POST /API/Gemini/chat`)
- **Search**: Algolia via Vercel proxy (`GET /API/Algolia/Restaurants`) — no client-side Algolia SDK
- **Networking**: `URLSession` with a shared `APIClient`
- **Localisation**: English and Traditional Chinese (`Localizable.xcstrings`)
- **Testing**: XCTest (UI), Swift Testing (Unit)
- **Minimum iOS**: 26+

## Tab Structure (Adaptive by User Type)

| User Type | Tabs |
|-----------|------|
| **Guest** | Home · Search · Account |
| **Diner** | Home · Search · Bookings · Chat · Account |
| **Restaurant Owner** | Home · Search · Store · Chat · Account |

Gemini AI is accessible from RestaurantView ("Ask AI" button) and AccountView ("AI Assistant" row) — no dedicated tab.

## Project Structure
```
Pour Rice/
  ├── App/
  │   └── AppDelegate.swift              # Firebase initialisation + Google Sign-In URL callback
  ├── Pour_RiceApp.swift                 # App entry, adaptive tabs, NavigationDestination, Services injection
  ├── Models/
  │   ├── Restaurant.swift               # Core restaurant model (Decodable + memberwise init)
  │   ├── Menu.swift                     # Menu item and category models
  │   ├── Review.swift                   # User review model
  │   ├── User.swift                     # User profile model (restaurantId, phoneNumber, bio, theme, notifications)
  │   ├── Booking.swift                  # Booking + BookingStatus + BookingDiner + request models
  │   ├── ChatRoom.swift                 # ChatRoom + ChatMessage + request/response models
  │   ├── GeminiMessage.swift            # GeminiMessage + history + request/response models
  │   └── BilingualText.swift            # EN/TC bilingual text wrapper
  ├── ViewModels/
  │   ├── HomeViewModel.swift            # Nearby restaurants, location-based fetching
  │   ├── SearchViewModel.swift          # Debounced search, district/keyword filter state
  │   ├── RestaurantViewModel.swift      # Restaurant detail + reviews
  │   ├── MenuViewModel.swift            # Restaurant menu fetching
  │   ├── AccountViewModel.swift         # Auth state, profile editing (theme, notifications, toast)
  │   ├── BookingsViewModel.swift        # Diner booking list (all/upcoming/past tabs)
  │   ├── CreateBookingViewModel.swift   # Booking creation form state + validation
  │   ├── StoreViewModel.swift           # Restaurant owner dashboard stats + actions
  │   ├── ChatListViewModel.swift        # Chat room list sorted by recency
  │   ├── ChatRoomViewModel.swift        # Message history + Socket.IO stream + typing + reconnection
  │   ├── GeminiViewModel.swift         # AI conversation state + context-aware suggestion chips
  │   └── QRScannerViewModel.swift      # QR scan state: URL validation, restaurant fetch, toast
  ├── Views/
  │   ├── Auth/
  │   │   ├── LoginView.swift            # Email/Google sign-in + guest mode
  │   │   └── SignUpView.swift           # Account registration
  │   ├── Home/
  │   │   └── HomeView.swift             # Nearby restaurant cards + featured carousel
  │   ├── Restaurant/
  │   │   └── RestaurantView.swift       # Detail page: carousel, info, hours, menu, reviews, actions
  │   ├── Menu/
  │   │   └── MenuView.swift             # Menu item list with dietary filters
  │   ├── Search/
  │   │   ├── SearchView.swift           # Search bar + results list
  │   │   └── FilterView.swift           # District + keyword filter sheet
  │   ├── Bookings/
  │   │   ├── BookingsView.swift         # Diner bookings list (all/upcoming/past segmented)
  │   │   ├── BookingCardView.swift      # Individual booking card with status badge
  │   │   └── CreateBookingView.swift    # Booking creation sheet (date, guests, requests)
  │   ├── Store/
  │   │   ├── StoreView.swift            # Restaurant owner dashboard (stats + quick actions)
  │   │   ├── StoreBookingsView.swift    # Restaurant booking management (accept/decline/complete)
  │   │   ├── StoreMenuManageView.swift  # Menu CRUD (add/edit/delete items)
  │   │   ├── StoreInfoEditView.swift    # Restaurant info editor + image upload
  │   │   └── ClaimRestaurantView.swift  # Restaurant ownership claim flow
  │   ├── Chat/
  │   │   ├── ChatListView.swift         # Chat room list with last message preview
  │   │   ├── ChatRoomView.swift         # Real-time chat with Socket.IO + REST fallback
  │   │   └── MessageBubbleView.swift    # Individual message bubble (edit/delete context menu)
  │   ├── Gemini/
  │   │   └── GeminiChatView.swift       # Gemini AI chat with markdown rendering + suggestion chips
  │   ├── QR/
  │   │   ├── QRScannerView.swift        # Full-screen camera scanner (VisionKit DataScannerViewController)
  │   │   └── RestaurantQRView.swift     # QR code generation + sharing (CoreImage, for restaurant owners)
  │   ├── Account/
  │   │   ├── AccountView.swift          # Profile, preferences, AI assistant link, sign-out, toast
  │   │   └── ProfileEditView.swift      # Profile edit sheet (name, phone, bio, theme, notifications)
  │   └── Common/
  │       ├── AsyncImageView.swift       # Cached async image loader (Kingfisher)
  │       ├── StatusBadgeView.swift      # Reusable status badge (booking statuses)
  │       ├── EmptyStateView.swift       # Empty/no-results states
  │       ├── ErrorView.swift            # Retry error state
  │       └── LoadingView.swift          # Spinner and skeleton views
  └── Core/
      ├── Services/
      │   ├── AuthService.swift          # Firebase Auth wrapper
      │   ├── LocationService.swift      # CoreLocation wrapper
      │   ├── RestaurantService.swift    # Restaurant API calls + Vercel Algolia search
      │   ├── MenuService.swift          # Menu API calls + client-side filtering
      │   ├── ReviewService.swift        # Review API calls
      │   ├── BookingService.swift       # Booking CRUD (diner + restaurant owner perspectives)
      │   ├── ChatService.swift          # Chat REST API (rooms, messages, edit/delete)
      │   ├── SocketService.swift        # Socket.IO v4 real-time (socket.io-client-swift library)
      │   ├── GeminiService.swift        # Gemini AI chat + description generation
      │   └── StoreService.swift         # Restaurant management (claim, update, image, menu CRUD)
      ├── Network/
      │   ├── APIClient.swift            # URLSession executor (request + requestVoid)
      │   ├── APIEndpoint.swift          # Typed endpoint enum (all routes)
      │   └── APIError.swift             # Network error types
      ├── Utilities/
      │   └── Constants.swift            # API URLs, Socket.IO URL, endpoint paths, UI values
      └── Extensions/
          ├── View+Extensions.swift      # Services env key + shimmerEffect + haptics + cardStyle
          └── Date+Extensions.swift      # Formatting helpers
```

## Key Files
- `Pour_RiceApp.swift` — Adaptive tab bar (`if isDiner`/`if isRestaurantOwner` conditions); registers `NavigationDestination` for `Restaurant`, `MenuNavigation`, `GeminiNavigation`, `ChatRoom`, `StoreDestination`; `private static let sharedServices` guarantees single Firebase init
- `Core/Extensions/View+Extensions.swift` — `Services` container (all 11 services); `shimmerEffect()` modifier; `hapticFeedback()`, `cardStyle()`, `errorAlert()`, `loadingOverlay()`, `toast(message:style:isPresented:)` modifier; `L10n.bundle` helper for locale-aware strings in non-view contexts
- `Models/Booking.swift` — `BookingStatus` enum with `.colour` and `.label`; `BookingDiner` for restaurant-side enrichment; `canCancel`, `isUpcoming`, `isPast` computed properties
- `Models/ChatRoom.swift` — `ChatRoom.placeholder(roomId:name:)` factory for navigation values; `ChatMessage.displayText` renders "[Message deleted]" for soft-deletes
- `Core/Services/SocketService.swift` — Socket.IO v4 via `socket.io-client-swift` (`SocketManager` + `SocketIOClient`); `isConnected` and `isRegistered` state gates; `incomingMessages`, `typingIndicators`, and `connectionStateChanges` as `AsyncStream`; `reconnect()` with stored credentials
- `ViewModels/ChatRoomViewModel.swift` — Starts/stops socket stream listeners; falls back to REST if socket unavailable; typing debounce with auto-stop; automatic reconnection with connection state monitoring; `isUsingSocket` observable for UI feedback
- `ViewModels/AccountViewModel.swift` — Profile editing with edit buffers (name, phone, bio, theme, notifications); toast feedback on save; language preference management
- `Views/Restaurant/RestaurantView.swift` — Action buttons at bottom: "Book a Table" (diner, `.sheet`), "Chat" (authenticated, `NavigationLink(value: ChatRoom.placeholder(...))`), "Ask AI" (everyone, `NavigationLink(value: GeminiNavigation(...))`)
- `Pour_RiceApp.swift` — `GeminiNavigation` struct (Hashable, wraps `Restaurant?`) for type-safe Gemini navigation
- `Core/Utilities/Constants.swift` — `Constants.Chat.socketURL` + `messagePageSize` + `typingDebounceNs`

## API Integration
- **Base URL**: `https://vercel-express-api-alpha.vercel.app`
- **Required header**: `x-api-passcode: PourRice` on all requests
- **Authenticated routes**: also require `Authorization: Bearer {firebase_id_token}`
- **Search**: `GET /API/Algolia/Restaurants?query=&districts=&keywords=&page=0&hitsPerPage=50`
- **Bookings**: `GET/POST /API/Bookings`, `PUT/DELETE /API/Bookings/:id`, `GET /API/Bookings/restaurant/:id`
- **Chat REST**: `GET /API/Chat/Records/:uid`, `GET/POST /API/Chat/Rooms`, `GET/POST/PUT/DELETE /API/Chat/Rooms/:roomId/Messages/:messageId`
- **Gemini**: `POST /API/Gemini/chat` (no auth), `POST /API/Gemini/generate` (auth), `POST /API/Gemini/restaurant-description` (no auth)
- **Restaurant**: `POST /API/Restaurants/:id/claim`, `PUT /API/Restaurants/:id`, `POST /API/Restaurants/:id/image`
- **Menu CRUD**: `POST/PUT/DELETE /API/Menu/Items/:id`

## Chat Architecture (REST + Socket.IO)
```
ChatRoomView.task
  ├── ChatService.fetchMessages(roomId:)        # Load history via REST
  ├── SocketService.connect(userId:token:)      # Connect via socket.io-client-swift
  │     ├── "connect" event → set isConnected=true, emit "register"
  │     └── "registered" event → set isRegistered=true (server confirms token valid)
  ├── SocketService.joinRoom(roomId:userId:)    # Waits for isRegistered before joining
  └── for await message in socketService.incomingMessages   # Real-time stream

On send:
  SocketService.sendMessage(...)    # Real-time path (preferred)
  ChatService.sendMessage(...)      # REST fallback if socket unavailable

Reconnection:
  SocketService.connectionStateChanges  # AsyncStream<Bool> monitors connect/disconnect
  ChatRoomViewModel.connectionListenerTask  # Switches between socket ↔ polling
  SocketService.reconnect()             # Re-connects with stored credentials
  ChatRoomView toolbar                  # Shows "Reconnecting…" when !isUsingSocket

isRegistered gate (critical — prevents "Not registered" server error):
  connect() emits "register" on "connect" event
  joinRoom() polls isRegistered (up to 3s) before emitting "join-room"
  startConnectionListener() waits for isRegistered after reconnect before re-joining
```

## Bookings Architecture
```
Diner flow:
  RestaurantView → "Book a Table" → CreateBookingView.sheet
    → CreateBookingViewModel.createBooking() → POST /API/Bookings
  BookingsView (tabs: All / Upcoming / Past)
    → BookingCardView with swipe-to-cancel (pending only)

Restaurant owner flow:
  StoreView dashboard → pending bookings preview
  → StoreBookingsView → accept / decline (with reason) / complete
    → BookingService.acceptBooking / declineBooking / completeBooking
    → PUT /API/Bookings/:id { status, declineMessage? }
```

## Gemini AI Integration
```
GeminiChatView(restaurant: Restaurant?)
  └── GeminiViewModel
        ├── restaurantContext: Restaurant?   # nil = general, non-nil = restaurant-specific
        ├── suggestionChips: [String]        # context-aware quick prompts
        └── messages: [GeminiMessage]        # local display (user/model)

GeminiService
  ├── conversationHistory: [GeminiHistoryEntry]   # maintained across turns
  ├── chat(message:) → POST /API/Gemini/chat       # no auth required
  └── generateRestaurantDescription(...)           # POST /API/Gemini/restaurant-description

AI responses rendered with AttributedString(markdown:) for basic markdown support.
```

## Search Architecture
`SearchViewModel` → `RestaurantService.search(query:filters:)` → Vercel proxy → Algolia index

- `SearchFilters` has two fields: `districts: [String]` and `keywords: [String]`
- Algolia SDK was removed; all search traffic uses `URLSession` through the backend proxy
- `AlgoliaHit` is a private struct inside `RestaurantService` — maps `objectID` → `Restaurant.id`

## QR Code & Deep Link Architecture

Deep link format: `pourrice://menu/{restaurantId}` — **identical on iOS and Android** for cross-platform QR compatibility.

```
QR Generation (restaurant owners):
  StoreView → "QR Code" button → .sheet → RestaurantQRView
    CoreImage.CIFilter.qrCodeGenerator()
      message = Data("pourrice://menu/{id}".utf8)
      correctionLevel = "H"          ← matches Android QrErrorCorrectLevel.H (~30% tolerance)
    CGAffineTransform(scaleX: 3, y: 3)  ← 3× scale, matches Android pixelRatio: 3.0
    Image(uiImage:).interpolation(.none) ← nearest-neighbour prevents blur on scale-up
    ShareLink(item: UIImage, ...)        ← UIImage+Transferable extension (see RestaurantQRView.swift)

QR Scanning (all users — guests, diners, owners):
  SearchView toolbar → camera.viewfinder button
    → .fullScreenCover { NavigationStack { QRScannerView() } }
        DataScannerRepresentable (UIViewControllerRepresentable)
          DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])])
          Coordinator.dataScanner(_:didAdd:allItems:)
            → Task { @MainActor in vm.handleScannedString(payload) }
        QRScannerViewModel.handleScannedString(_:)
          1. Validate scheme == "pourrice", host == "menu"
          2. Extract restaurantId from pathComponents.dropFirst().first
          3. RestaurantService.fetchRestaurant(id:)  ← GET /API/Restaurants/{id}, no auth
          4. scannerState = .success(restaurant)
        .navigationDestination(isPresented:) → MenuView(restaurantId:restaurantName:)

OS-level deep link (app opened from pourrice:// URL):
  Info.plist CFBundleURLTypes → scheme "pourrice" registered
  RootView.onOpenURL { url in
    GIDSignIn.sharedInstance.handle(url)         ← existing Google OAuth (unchanged)
    pendingDeepLinkId = url.pathComponents[1]    ← pourrice://menu/{id}
  }
  .onChange(of: pendingDeepLinkId) → Task {
    services.restaurantService.fetchRestaurant(id:)
    deepLinkRestaurant = restaurant
    showingDeepLinkMenu = true
  }
  .sheet → NavigationStack { MenuView(...) }     ← modal, works regardless of active tab
```

Key files:
- `Views/QR/QRScannerView.swift` — VisionKit scanner + DataScannerRepresentable + Coordinator
- `Views/QR/RestaurantQRView.swift` — CoreImage QR generation + ShareLink
- `ViewModels/QRScannerViewModel.swift` — ScannerState enum + URL validation + fetch
- `Core/Utilities/Constants.swift` — `Constants.DeepLink.scheme` + `.menuHost`
- `Pour Rice/Info.plist` — `pourrice` URL scheme + `NSCameraUsageDescription`
- `Pour_RiceApp.swift` `RootView` — `onOpenURL` + `.onChange` + deep link sheet

Simulator testing: `xcrun simctl openurl booted "pourrice://menu/{validRestaurantId}"`

## Code & Comments Structure

### Naming Conventions
- **Variables / properties**: `camelCase` (e.g., `searchQuery`, `isLoading`)
- **Types / structs / classes**: `PascalCase` (e.g., `SearchViewModel`, `BilingualText`)
- **Language-specific data fields** (from API / Firestore): `Snake_CASE` with language suffix (e.g., `Name_EN`, `District_TC`, `Keyword_EN`)
- **Constants**: grouped in nested `enum` types inside `Constants` (e.g., `Constants.API.baseURL`, `Constants.Chat.socketURL`)

### Comment Style
- **File headers**: `//  FileName.swift` block at the top of every file with purpose description
- **Cross-platform notes**: `// ============= FOR FLUTTER/ANDROID DEVELOPERS: =============` blocks explain iOS-specific patterns and their Flutter/Kotlin equivalents
- **MARK sections**: `// MARK: - Section Name` dividers separate logical sections
- **Doc comments**: `///` triple-slash for public/internal types and methods
- **TODO / FIXME**: Not used; all code is production-ready

### Architecture Pattern
- `@Observable` + `@MainActor` on all ViewModels (Swift 6 concurrency)
- Services injected via `@Environment(\.services)` using a custom `EnvironmentKey`
- Views are passive — no business logic; all state lives in the ViewModel
- Async operations use `async/await` with structured concurrency (`Task {}`)
- Real-time streams use `AsyncStream` iterated via `for await` inside `Task`

### Localisation Pattern
- **Views**: Use raw string keys as `LocalizedStringKey` — e.g., `Text("search_title")`, `.navigationTitle("home_title")` — which respects SwiftUI's `.environment(\.locale, ...)` injected by `RootView`
- **Subview components**: Declare title/label parameters as `LocalizedStringKey` (not `String`) so `Text(title)` performs localisation lookup — using `String` renders keys verbatim (e.g., `StatCard`, `QuickActionCard`). Same applies to computed properties passed directly to `Text()`.
- **Models/ViewModels/Services**: Use `String(localized: "key", bundle: L10n.bundle)` — `L10n.bundle` reads `UserDefaults("preferredLanguage")` and returns the matching `.lproj` bundle
- **BilingualText re-rendering**: Views displaying `BilingualText.localised` (e.g., `SearchView`, `HomeView`) use `@AppStorage("preferredLanguage")` + `.id(preferredLanguage)` to force re-evaluation when the language changes
- **Language switch flow**: `AccountViewModel.updateLanguage()` writes to `UserDefaults` immediately (instant UI switch) then persists to backend API asynchronously

### Toast/Snackbar System
- `ToastStyle` enum: `.success` (green), `.error` (red), `.info` (blue) — each with icon and haptic type
- `.toast(message:style:isPresented:)` view modifier — overlays banner at top, auto-dismisses after 2.5s, spring animation, haptic feedback
- All ViewModels expose `toastMessage: String`, `toastStyle: ToastStyle`, `showToast: Bool` + private `showToast(_:_:)` helper
- Coverage: all major user actions across Home, Search, Bookings, Store, Chat, Gemini, Restaurant, and Account pages
- Toast keys follow `toast_<context>_<action>` naming (e.g., `toast_booking_cancelled`, `toast_store_info_updated`)

### iOS 26 / Liquid Glass Patterns
- **Tab navigation**: Uses `Tab("title", systemImage:) { content }` API (not legacy `.tabItem {}`)
- **Conditional tabs**: `if isDiner { Tab(...) }` — SwiftUI handles dynamic tab counts natively in iOS 26
- **Liquid Glass**: `.glassEffect(_:in:)` for glass styling; `.glassEffectID(_:in:)` for morphing transitions (requires `@Namespace`)
- **ShapeStyle**: Use `.tint` for standalone accent-coloured styles; use `Color.accentColor` in ternaries with `.primary`
- **AsyncImageView**: `ContentMode` is qualified as `SwiftUI.ContentMode` to avoid ambiguity with UIKit

### Guest Mode
- Users can browse without signing in by tapping "Continue as Guest" on `LoginView`
- `RootView` uses `@State isGuest` — when `true`, shows `MainTabView` without authentication
- **Accessible pages**: Home, Search, Restaurant detail, Menu, Gemini AI (no auth required)
- **Account tab**: Shows sign-in prompt + language picker + AI Assistant link (guests can use Gemini)
- **Restricted**: Bookings, Chat, Store tabs are not shown to guests
- `APIClient.injectHeaders` gracefully handles missing auth tokens — only injects passcode header for public endpoints

### Firebase / Google Sign-In Setup
- **Initialisation order**: `FirebaseApp.configure()` in `Pour_RiceApp.init()` via static shared Services instance → then `Services()` → `AuthService` calls `Auth.auth()`
  - Uses `private static let sharedServices: Services` to ensure Firebase is configured **exactly once**
- **AppDelegate**: Must implement `application(_:open:options:)` for Google Sign-In OAuth URL callback
- **URL scheme (`CFBundleURLTypes`)**:
  - `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` registered as a URL scheme via physical `Info.plist`
  - **Critical**: `CFBundleURLTypes` must be an **array of dictionaries** in Info.plist
  - Physical `Info.plist` at project root; `INFOPLIST_FILE = "Pour Rice/Info.plist"` in build settings
- **Firebase Installations API**: Must be enabled in Google Cloud Console
  - If 403 `API_KEY_SERVICE_BLOCKED` persists: set API key to "Don't restrict key" + "None" application restrictions
- **Swizzler warning** (`[GoogleUtilities/AppDelegateSwizzler]`): Silenced by `FirebaseAppDelegateProxyEnabled = NO` in `Info.plist`

### SPM Dependencies
- **Kingfisher** — image loading and caching (`AsyncImageView`)
- **Firebase iOS SDK** — FirebaseCore, FirebaseAuth, FirebaseAnalytics, FirebaseAnalyticsCore, FirebaseInstallations
- **GoogleSignIn-iOS** — Google OAuth sign-in (v8.0.0)
- **socket.io-client-swift** — Socket.IO v4 client (`SocketManager` + `SocketIOClient`); branch `master`; used in `SocketService.swift`
- Removed (unused): Alamofire, algoliasearch-client-swift, swift-async-algorithms, FirebaseFirestore, FirebaseInAppMessaging-Beta, FirebaseMessaging, FirebaseStorage

## Swift File Line Counts

| File | Lines |
|------|-------|
| `Core/Services/AuthService.swift` | 553 |
| `Views/Restaurant/RestaurantView.swift` | ~580 |
| `Models/Restaurant.swift` | 524 |
| `Views/Auth/LoginView.swift` | 472 |
| `Views/Auth/SignUpView.swift` | 427 |
| `Views/Gemini/GeminiChatView.swift` | ~210 |
| `Models/Menu.swift` | 383 |
| `Views/Home/HomeView.swift` | 376 |
| `Pour_RiceApp.swift` | ~420 |
| `Core/Services/RestaurantService.swift` | 370 |
| `Views/Store/StoreView.swift` | ~260 |
| `Views/Menu/MenuView.swift` | 330 |
| `Core/Services/LocationService.swift` | 315 |
| `Models/ChatRoom.swift` | ~330 |
| `Core/Services/SocketService.swift` | ~280 |
| `ViewModels/ChatRoomViewModel.swift` | ~440 |
| `Views/Search/SearchView.swift` | 266 |
| `Views/Common/AsyncImageView.swift` | 259 |
| `Views/Account/AccountView.swift` | ~390 |
| `Models/BilingualText.swift` | 251 |
| `Core/Network/APIEndpoint.swift` | ~440 |
| `Core/Network/APIClient.swift` | ~280 |
| `Models/User.swift` | ~350 |
| `Views/Common/EmptyStateView.swift` | 216 |
| `Core/Extensions/View+Extensions.swift` | ~425 |
| `ViewModels/SearchViewModel.swift` | ~225 |
| `ViewModels/RestaurantViewModel.swift` | ~220 |
| `Core/Services/MenuService.swift` | 185 |
| `Core/Services/StoreService.swift` | ~180 |
| `Core/Network/APIError.swift` | 179 |
| `Core/Extensions/Date+Extensions.swift` | 177 |
| `ViewModels/HomeViewModel.swift` | ~195 |
| `Core/Utilities/Constants.swift` | ~240 |
| `ViewModels/MenuViewModel.swift` | 169 |
| `Views/Search/FilterView.swift` | 161 |
| `Core/Services/BookingService.swift` | ~155 |
| `Core/Services/GeminiService.swift` | ~120 |
| `Core/Services/ChatService.swift` | ~130 |
| `ViewModels/StoreViewModel.swift` | ~250 |
| `ViewModels/BookingsViewModel.swift` | ~140 |
| `ViewModels/GeminiViewModel.swift` | ~160 |
| `ViewModels/ChatListViewModel.swift` | ~110 |
| `ViewModels/CreateBookingViewModel.swift` | ~100 |
| `Views/Bookings/BookingsView.swift` | ~115 |
| `Views/Bookings/BookingCardView.swift` | ~100 |
| `Views/Bookings/CreateBookingView.swift` | ~130 |
| `Views/Chat/ChatListView.swift` | ~145 |
| `Views/Chat/ChatRoomView.swift` | ~170 |
| `Views/Account/ProfileEditView.swift` | ~110 |
| `Views/Chat/MessageBubbleView.swift` | ~80 |
| `Views/Common/LoadingView.swift` | 135 |
| `Views/Common/StatusBadgeView.swift` | ~50 |
| `Models/Booking.swift` | ~300 |
| `Models/GeminiMessage.swift` | ~200 |
| `ViewModels/AccountViewModel.swift` | ~235 |
| `Models/Review.swift` | 130 |
| `Core/Services/ReviewService.swift` | 126 |
| `App/AppDelegate.swift` | 62 |
| `Views/QR/QRScannerView.swift` | ~185 |
| `Views/QR/RestaurantQRView.swift` | 237 |
| `ViewModels/QRScannerViewModel.swift` | ~85 |
| `Pour RiceTests/Pour_RiceTests.swift` | 17 |
| `Pour RiceUITests/Pour_RiceUITests.swift` | 41 |
| `Pour RiceUITests/Pour_RiceUITestsLaunchTests.swift` | 33 |
| **Total (estimated)** | **~13,500** |
