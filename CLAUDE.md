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
- **Maps**: Apple MapKit (SwiftUI `Map`, `Marker`, `MapPolyline`, `MKDirections`) — no Google Maps SDK
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
  │   ├── Advertisement.swift            # Advertisement model + UpdateAdvertisementRequest (all-nil defaults) + CreateAdvertisementRequest
  │   ├── Review.swift                   # User review model; ReviewRequest has custom encode(to:) mapping photoURLs.first → "imageUrl"
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
  │   │   ├── RestaurantView.swift       # Detail page: carousel, info, hours, location map, menu, reviews, actions
  │   │   └── DirectionsView.swift       # Directions sheet: MKDirections route, transport picker, Apple Maps handoff
  │   ├── Menu/
  │   │   └── MenuView.swift             # Menu item list with dietary filters
  │   ├── Search/
  │   │   ├── SearchView.swift           # Search bar + results list/map toggle
  │   │   ├── SearchMapView.swift        # MapKit map for search results (pins, callout card)
  │   │   └── FilterView.swift           # District + keyword filter sheet
  │   ├── Bookings/
  │   │   ├── BookingsView.swift         # Diner bookings list (all/upcoming/past segmented)
  │   │   ├── BookingCardView.swift      # Individual booking card with status badge
  │   │   └── CreateBookingView.swift    # Booking creation sheet (date, guests, requests)
  │   ├── Store/
  │   │   ├── StoreView.swift            # Restaurant owner dashboard (stats + 6 quick actions grid)
  │   │   ├── StoreBookingsView.swift    # Restaurant booking management (accept/decline/complete)
  │   │   ├── StoreMenuManageView.swift  # Menu CRUD + Liquid Glass toolbar with bulk-import button
  │   │   ├── StoreInfoEditView.swift    # Restaurant info editor + image upload
  │   │   ├── StoreAdsView.swift         # Advertisement list/create/toggle/delete + Stripe checkout via SafariView
  │   │   ├── BulkMenuImportView.swift   # DocuPipe bulk import: file picker → review extracted items → import
  │   │   ├── ClaimRestaurantView.swift  # Restaurant ownership claim flow (search + "Add New Restaurant" trigger)
  │   │   └── AddRestaurantView.swift    # Full form sheet for creating a new restaurant listing
  │   ├── Chat/
  │   │   ├── ChatListView.swift         # Chat room list with last message preview
  │   │   ├── ChatRoomView.swift         # Real-time chat with Socket.IO + REST fallback
  │   │   └── MessageBubbleView.swift    # Individual message bubble (edit/delete context menu)
  │   ├── Gemini/
  │   │   └── GeminiChatView.swift       # Gemini AI chat with markdown rendering + suggestion chips
  │   ├── QR/
  │   │   ├── QRScannerView.swift        # Cross-platform scanner: iOS live camera (VisionKit) + macOS/simulator fallback (PhotosPicker + manual payload)
  │   │   └── RestaurantQRView.swift     # QR code generation + sharing (CoreImage, for restaurant owners)
  │   ├── Account/
  │   │   ├── AccountView.swift          # Profile, preferences, AI assistant link, sign-out, toast
  │   │   ├── ProfileEditView.swift      # Profile edit sheet (name, phone, bio, theme, notifications)
  │   │   └── UserTypeSelectionView.swift # Non-dismissable sheet for new users to choose Diner / Restaurant Owner
  │   └── Common/
  │       ├── AsyncImageView.swift       # Cached async image loader (Kingfisher)
  │       ├── SafariView.swift           # UIViewControllerRepresentable wrapping SFSafariViewController (Stripe checkout)
  │       ├── StatusBadgeView.swift      # Reusable status badge (booking statuses)
  │       ├── EmptyStateView.swift       # Empty/no-results states
  │       ├── ErrorView.swift            # Retry error state
  │       └── LoadingView.swift          # Spinner and skeleton views
  ├── Resources/
  │   ├── Localizable.xcstrings          # String catalog for UI localisation (EN + TC)
  │   ├── weekdays.json                  # 7 weekdays, Monday-first order (en/tc)
  │   ├── districts.json                 # 18 HK administrative districts (en/tc)
  │   ├── keywords.json                  # 90 restaurant keywords by category (en/tc)
  │   └── payments.json                  # 10 payment methods (en/tc)
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
      │   ├── GeminiService.swift        # Gemini AI chat + description generation + generateAdvertisement()
      │   ├── AdvertisementService.swift # Advertisement CRUD + createStripeCheckoutSession()
      │   ├── ImageUploadService.swift   # Chat image upload (progress KVO) + generic uploadImage(folder:authToken:)
      │   ├── DocuPipeService.swift      # DocuPipe menu extraction — multipart POST, returns [ExtractedMenuItem]
      │   └── StoreService.swift         # Restaurant management (claim, update, image, menu CRUD, createRestaurant)
      ├── QR/
      │   ├── QRPayloadDetector.swift    # Platform-agnostic deep-link validator → QRDetection / QRDetectionError
      │   ├── QRFrameProcessor.swift     # Core Image QR extraction from image bytes (iOS + macOS); QRFrameProcessing protocol + CoreImageQRFrameProcessor
      │   └── QRDataHandler.swift        # Shared coordinator: detector + fetch closure injection → handlePayload(_:)
      ├── Network/
      │   ├── APIClient.swift            # URLSession executor (request + requestVoid)
      │   ├── APIEndpoint.swift          # Typed endpoint enum (all routes)
      │   └── APIError.swift             # Network error types
      ├── Utilities/
      │   ├── Constants.swift            # API URLs, Socket.IO URL, endpoint paths, UI values, Map config
      │   └── LocalDataLoader.swift      # Synchronous JSON loader for bundled bilingual data; BilingualEntry model
      └── Extensions/
          ├── View+Extensions.swift      # Services env key + shimmerEffect + haptics + cardStyle
          └── Date+Extensions.swift      # Formatting helpers
```

## Key Files
- `Pour_RiceApp.swift` — Adaptive tab bar (`if isDiner`/`if isRestaurantOwner` conditions); registers `NavigationDestination` for `Restaurant`, `MenuNavigation`, `GeminiNavigation`, `ChatRoom`, `StoreDestination`; `private static let sharedServices` guarantees single Firebase init
- `Core/Extensions/View+Extensions.swift` — `Services` container (13 services: adds `advertisementService: AdvertisementService`, `docuPipeService: DocuPipeService`); `shimmerEffect()` modifier; `hapticFeedback()`, `cardStyle()`, `errorAlert()`, `loadingOverlay()`, `toast(message:style:isPresented:)` modifier; `L10n.bundle` helper for locale-aware strings in non-view contexts
- `Models/Booking.swift` — `BookingStatus` enum with `.colour` and `.label`; `BookingDiner` for restaurant-side enrichment; `canCancel`, `isUpcoming`, `isPast` computed properties
- `Models/ChatRoom.swift` — `ChatRoom.placeholder(roomId:name:)` factory for navigation values; `ChatMessage.displayText` renders "[Message deleted]" for soft-deletes
- `Core/Services/SocketService.swift` — Socket.IO v4 via `socket.io-client-swift` (`SocketManager` + `SocketIOClient`); `isConnected` and `isRegistered` state gates; `incomingMessages`, `typingIndicators`, and `connectionStateChanges` as `AsyncStream`; `reconnect()` with stored credentials
- `ViewModels/ChatRoomViewModel.swift` — Starts/stops socket stream listeners; falls back to REST if socket unavailable; typing debounce with auto-stop; automatic reconnection with connection state monitoring; `isUsingSocket` observable for UI feedback
- `ViewModels/AccountViewModel.swift` — Profile editing with edit buffers (name, phone, bio, theme, notifications); toast feedback on save; language preference management
- `Views/Restaurant/RestaurantView.swift` — Location section (embedded `Map`, address, "Get Directions" button) inserted between Contact and Menu Preview; action buttons at bottom: "Book a Table" (diner, `.sheet`), "Chat" (authenticated, `NavigationLink(value: ChatRoom.placeholder(...))`), "Ask AI" (everyone, `NavigationLink(value: GeminiNavigation(...))`)
- `Views/Restaurant/DirectionsView.swift` — `DirectionsViewModel` (`@Observable`, `@MainActor`) with `TransportMode` enum (transit/walking/driving); `fetchDirections()` builds `MKDirections.Request` + `calculate()`; `openInAppleMaps()` uses `MKMapItem.openInMaps(launchOptions:)` with `MKLaunchOptionsDirectionsModeKey`; `DirectionsView` renders map + `MapPolyline(route.polyline)` + segmented picker + route summary card
- `Views/Search/SearchMapView.swift` — `Map(position:selection:)` with `Marker` per restaurant (tinted by `isOpenNow`); `UserAnnotation()`; auto-fit camera via `MKCoordinateRegion` bounding box over all results; `SearchMapCalloutCard` bottom overlay (`.regularMaterial` card) shown on pin tap; navigates to `RestaurantView` via `NavigationLink(value: restaurant)`
- `Pour_RiceApp.swift` — `GeminiNavigation` struct (Hashable, wraps `Restaurant?`) for type-safe Gemini navigation
- `Core/Utilities/Constants.swift` — `Constants.Chat.socketURL` + `messagePageSize` + `typingDebounceNs`; `Constants.Map.defaultLatitude/Longitude` (Hong Kong: 22.3193, 114.1694) + `detailSpanDelta` + `searchSpanDelta` + `detailMapHeight` + `directionsMapHeight`
- `Core/Utilities/LocalDataLoader.swift` — `enum LocalDataLoader` (not instantiable); `BilingualEntry: Codable, Identifiable` with `id: String { en }`; private generic `load<T: Decodable>(_ filename:)` reads `Bundle.main` synchronously; public loaders: `loadWeekdays()`, `loadDistricts()`, `loadKeywords()`, `loadPayments()` — all return `[BilingualEntry]`; `#if DEBUG` prints on success (filename + count) and failure

## API Integration
- **Base URL**: `https://vercel-express-api-alpha.vercel.app`
- **Required header**: `x-api-passcode: PourRice` on all requests
- **Authenticated routes**: also require `Authorization: Bearer {firebase_id_token}`
- **Search**: `GET /API/Algolia/Restaurants?query=&districts=&keywords=&page=0&hitsPerPage=50`
- **Bookings**: `GET/POST /API/Bookings`, `PUT/DELETE /API/Bookings/:id`, `GET /API/Bookings/restaurant/:id`
- **Chat REST**: `GET /API/Chat/Records/:uid`, `GET/POST /API/Chat/Rooms`, `GET/POST/PUT/DELETE /API/Chat/Rooms/:roomId/Messages/:messageId`
- **Gemini**: `POST /API/Gemini/chat` (no auth), `POST /API/Gemini/generate` (auth), `POST /API/Gemini/restaurant-description` (no auth)
- **Restaurant**: `POST /API/Restaurants` (create, no auth, `ownerId` in body), `POST /API/Restaurants/:id/claim`, `PUT /API/Restaurants/:id`, `POST /API/Restaurants/:id/image`
- **Add Restaurant flow**: `POST /API/Restaurants` → get `{ id }` → `PUT /API/Users/:uid { restaurantId }` (auth). `StoreService.createRestaurant(request:)` handles both steps. `AddRestaurantView` — SwiftUI Form sheet triggered from `ClaimRestaurantView` ("Can't find your restaurant? Add a new one" button). Bundled JSON data loaded via `LocalDataLoader`: `districts.json` (18 HK districts), `keywords.json` (90 keywords), `payments.json` (10 methods), `weekdays.json` (7 days). Keywords/Payments shown only in active locale. Opening hours: `Toggle` per day + `DatePicker(.hourAndMinute)`. Location: `MapReader` + `.onTapGesture` → `proxy.convert(_:from:)` → `CLLocationCoordinate2D`. New `APIEndpoint.createRestaurant(CreateRestaurantRequest)` + `CreateRestaurantResponse`. `UpdateUserRequest` gained `restaurantId: String?` field.
- **Menu CRUD**: `POST/PUT/DELETE /API/Menu/Items/:id`
- **Advertisements**: `GET /API/Advertisements?restaurantId=X`, `POST/PUT/DELETE /API/Advertisements/:id` (auth required for CUD)
- **Stripe**: `POST /API/Stripe/create-ad-checkout-session` (auth required) → `{ sessionId, url }` — open `url` in `SafariView`; on `SafariView.onDismiss` advance to ad creation form
- **DocuPipe**: `POST /API/DocuPipe/extract-menu` (multipart, no auth) → `{ menu_items: [{ Name_EN, Name_TC, Description_EN, Description_TC, price }] }`
- **Gemini ad copy**: `POST /API/Gemini/restaurant-advertisement` (auth required) → `AdvertisementGenerationResponse` with `Title_EN/TC`, `Content_EN/TC`

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
  ├── chat(message:restaurantId:)                 # routes by restaurantId presence:
  │     ├── restaurantId != nil → POST /API/Gemini/restaurant-description (chat mode)
  │     │     Server fetches restaurant info + menu from Firestore, injects as [CONTEXT: ... END OF CONTEXT]
  │     └── restaurantId == nil → POST /API/Gemini/chat (general chat)
  └── generateRestaurantDescription(...)           # POST /API/Gemini/restaurant-description (description mode)

GeminiViewModel.sendMessage()
  └── service.chat(message: text, restaurantId: restaurantContext?.id)
        # No manual context building — server handles Firestore lookup automatically

POST /API/Gemini/restaurant-description supports two modes (2026-04-04):
  - Description mode: { restaurantId, name, district, keywords, language } → { description, restaurant, menu }
  - Chat mode: { restaurantId, message, history?, model? } → { result, model, history, ... }
    Chat mode is detected server-side by the presence of the `message` field.

AI responses rendered with AttributedString(markdown:) for basic markdown support.
```

## Search Architecture
`SearchViewModel` → `RestaurantService.search(query:filters:)` → Vercel proxy → Algolia index

- `SearchFilters` has two fields: `districts: [String]` and `keywords: [String]`
- Algolia SDK was removed; all search traffic uses `URLSession` through the backend proxy
- `AlgoliaHit` is a private struct inside `RestaurantService` — maps `objectID` → `Restaurant.id`
- `SearchView` has a `showingMap: Bool` state that switches between `List` (default) and `SearchMapView`; the toggle toolbar button is disabled when results are empty
- `SearchViewModel.availableDistricts` and `availableKeywords` are `[LocalDataLoader.BilingualEntry]` loaded from `districts.json` (18) / `keywords.json` (90); the `.en` field is passed to Algolia as the filter parameter value
- `FilterView` displays `district.tc` / `keyword.tc` directly from JSON when TC is active — no xcstrings lookups for individual filter values (saves ~340 lines from `Localizable.xcstrings`)

## MapKit Architecture

### Search Map (list/map toggle)
```
SearchView toolbar
  └── map/list toggle button (@State showingMap: Bool)
        ├── list mode (default): existing List { SearchResultRow } unchanged
        └── map mode: SearchMapView(restaurants: vm.searchResults, userLocation:)
              Map(position: $cameraPosition, selection: $selectedTag)
                ├── UserAnnotation()                    # user GPS dot
                └── ForEach(validRestaurants) {
                      Marker(name, systemImage: "fork.knife", coordinate:)
                        .tint(isOpenNow ? .accent : .secondary)  # green/grey
                        .tag(restaurant.id)
                    }
              .mapControls { MapUserLocationButton; MapCompass; MapScaleView }
              .overlay(alignment: .bottom) {
                if selectedTag != nil → SearchMapCalloutCard(restaurant:)
                  NavigationLink(value: restaurant) → RestaurantView
              }
              updateCamera(for:) → MKCoordinateRegion bounding all pins (×1.3 padding)
                                 → falls back to HK default if no valid coords
```

Key behaviours:
- Pins filtered: restaurants where `latitude == 0 && longitude == 0` are excluded
- Toggle button disabled when `searchResults.isEmpty` (no results to show)
- Camera auto-updates on `.onAppear` and when `restaurants.count` changes
- `.id(preferredLanguage)` on `Group` keeps BilingualText callout card in sync with language

### Restaurant Detail Directions
```
RestaurantView
  └── locationSection(restaurant:)
        ├── Map(initialPosition: .region(MKCoordinateRegion(detailSpanDelta)))
        │     └── Marker(name, systemImage: "fork.knife").tint(.accent)
        │   .frame(height: Constants.Map.detailMapHeight)      # 200pt
        │   .clipShape(RoundedRectangle)
        ├── Text(restaurant.address.localised)
        └── Button "Get Directions" → showingDirections = true
              .sheet → DirectionsView(restaurant:, userLocation:)

DirectionsView (NavigationStack modal)
  ├── mapSection
  │     Map { UserAnnotation; Marker; MapPolyline(route.polyline).stroke(.tint, 5) }
  │     .frame(height: Constants.Map.directionsMapHeight)       # 300pt
  ├── transportPicker (Picker .segmented)
  │     TransportMode: .transit | .walking | .driving           # Hashable enum
  │       → maps to MKDirectionsTransportType (.transit / .walking / .automobile)
  │       → maps to MKLaunchOptionsDirectionsMode* for Apple Maps handoff
  ├── routeSummary card
  │     formattedTravelTime  ← DateComponentsFormatter (hour, minute, .abbreviated)
  │     formattedDistance    ← MeasurementFormatter (.naturalScale, 1 decimal)
  └── "Open in Apple Maps" → MKMapItem.openInMaps(launchOptions: [DirectionsModeKey:])

DirectionsViewModel.fetchDirections()
  guard userLocation else → errorMessage ("directions_no_location")
  MKDirections.Request { source: userCoord, destination: restaurantCoord, transportType }
  MKDirections.calculate() async → route = response.routes.first
  catch → errorMessage ("directions_error")
```

Key behaviours:
- `TransportMode` is a local `Hashable` enum bridging `MKDirectionsTransportType` (which is not `Hashable`)
- Re-fetches on `.onChange(of: viewModel.selectedMode)`
- Transit routing may be unavailable for some HK locations — error shows inline, not a crash
- `MKMapItem(location:address:)` used for route source/destination; requires `import Contacts` for `CNPostalAddress` (passed as `nil`)

Key files:
- `Views/Search/SearchMapView.swift` — `SearchMapView` + private `SearchMapCalloutCard`
- `Views/Restaurant/DirectionsView.swift` — `TransportMode` enum + `DirectionsViewModel` + `DirectionsView`
- `Views/Restaurant/RestaurantView.swift` — `locationSection(restaurant:)` + `showingDirections` state
- `Views/Search/SearchView.swift` — `showingMap` state + map toggle toolbar button
- `Core/Utilities/Constants.swift` — `Constants.Map` enum

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

  Shared logic layers (platform-neutral, all in Core/QR/):
    QRPayloadDetector.detect(from:)        # validates scheme/host/path → QRDetection
    QRFrameProcessor.extractPayloads(:)    # Core Image CIDetector → [String] payloads from image data
    QRDataHandler.handlePayload(_:)        # composes detector + injected fetch closure

  iOS path (physical device with camera):
    DataScannerRepresentable (UIViewControllerRepresentable)
      DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])])
      Coordinator.dataScanner(_:didAdd:allItems:)
        → Task { @MainActor in vm.handleScannedString(payload) }
          → QRDataHandler.handlePayload(_:) → scannerState = .success(restaurant)
    Torch toggle: vm.isTorchOn synced via AVCaptureDevice in updateUIViewController

  macOS / simulator fallback path (QRScannerView.fallbackScannerView):
    Option A – PhotosPicker: loadTransferable(Data) → vm.handleScannedImageData(_:)
      → Task.detached { CoreImageQRFrameProcessor.extractPayloads } (off main actor)
      → first valid payload → QRDataHandler.handlePayload(_:)
    Option B – Manual text field: vm.handleScannedString(trimmedPayload)
      → QRDataHandler.handlePayload(_:)

  Both paths converge on QRScannerViewModel.processPayload(_:) then:
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
- `Core/QR/QRPayloadDetector.swift` — `QRDetection` result type + `QRDetectionError` + `QRPayloadDetector.detect(from:)`
- `Core/QR/QRFrameProcessor.swift` — `QRFrameProcessing` protocol + `CoreImageQRFrameProcessor` (CIDetector, iOS + macOS) + `QRFrameProcessingError`
- `Core/QR/QRDataHandler.swift` — composes detector + injected `fetchRestaurant` closure; UI-independent
- `Views/QR/QRScannerView.swift` — `FallbackReason` enum; iOS camera path (`#if canImport(VisionKit)`); macOS/simulator fallback (PhotosPicker + manual payload field); `DataScannerRepresentable` + `Coordinator`
- `Views/QR/RestaurantQRView.swift` — CoreImage QR generation + ShareLink + `UIImage: @retroactive Transferable`
- `ViewModels/QRScannerViewModel.swift` — `ScannerState` enum; `init(services:)`; `handleScannedString(_:)`, `handleScannedImageData(_:)`, `processPayload(_:)`; `isPaused` re-entrancy guard; `isTorchOn`
- `Core/Utilities/Constants.swift` — `Constants.DeepLink.scheme` + `.menuHost`
- `Pour Rice/Info.plist` — `pourrice` URL scheme + `NSCameraUsageDescription`
- `Pour_RiceApp.swift` `RootView` — `onOpenURL` + `.onChange` + deep link sheet

Simulator testing: `xcrun simctl openurl booted "pourrice://menu/{validRestaurantId}"`

## User Type Selection Architecture

New users are prompted to choose between **Diner (食客)** and **Restaurant Owner (店主)** immediately after registering. The selection is non-dismissable and persists via `PUT /API/Users/:uid { type }`.

```
Registration / Google sign-up
  └── AuthService.createUserProfile()
        ├── POST /API/Users → User (type: "Diner" default)
        ├── UserDefaults["userTypeChosen_{uid}"] = false   ← gate key
        └── needsTypeSelection = true

Auth state listener fires → AuthService.loadUserProfile()
  └── Key exists (false) → needsTypeSelection stays true
      Key missing (existing user on new device) → set true → needsTypeSelection = false

MainTabView
  └── .sheet(isPresented: Binding { authService.needsTypeSelection })
        UserTypeSelectionView
          ├── .interactiveDismissDisabled(true)   ← cannot swipe away
          ├── UserTypeCard("Diner")    → pickType(.diner)
          └── UserTypeCard("Restaurant Owner") → pickType(.restaurant)
                AuthService.updateUserType(_:)
                  ├── PUT /API/Users/:uid { type: "Diner" | "Restaurant" }
                  ├── loadUserProfile(uid:)           ← refresh currentUser
                  ├── UserDefaults["userTypeChosen_{uid}"] = true
                  └── needsTypeSelection = false      ← sheet auto-dismisses
        onDismiss → showTypeSelectionToast = true
  └── .toast("Account type saved") shown in MainTabView
```

Key behaviours:
- **New users**: `createUserProfile` sets `UserDefaults["userTypeChosen_{uid}"] = false` → sheet shown
- **Existing users / new device**: `loadUserProfile` finds no key → sets it to `true` → sheet not shown
- **On error**: card resets (no selected state, no spinner), inline error message shown; user can retry
- **Sign-out**: `needsTypeSelection` reset to `false` in `signOut()`
- `UpdateUserTypeRequest` — minimal `{ type: String }` Codable struct; avoids touching other profile fields
- `APIEndpoint.updateUserType(userId:, UpdateUserTypeRequest)` — PUT, auth-required, same path as `updateUserProfile`

Key files:
- `Views/Account/UserTypeSelectionView.swift` — sheet UI + `UserTypeCard` private component
- `Core/Services/AuthService.swift` — `needsTypeSelection` var + `updateUserType()` + gate logic in `loadUserProfile`/`createUserProfile`/`signOut`
- `Models/User.swift` — `UpdateUserTypeRequest` struct
- `Core/Network/APIEndpoint.swift` — `.updateUserType` case
- `Pour_RiceApp.swift` `MainTabView` — sheet binding + `onDismiss` toast

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
- **MapKit**: `Map(initialPosition:)` used for static embedded maps; `Map(position:selection:)` for interactive maps with pin selection; `MKMapItem` uses `init(location:address:)` (iOS 26 — replaces deprecated `init(placemark:)`)

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
| `Core/Services/AuthService.swift` | ~600 |
| `Views/Restaurant/RestaurantView.swift` | ~640 |
| `Views/Restaurant/DirectionsView.swift` | ~230 |
| `Models/Restaurant.swift` | 524 |
| `Views/Auth/LoginView.swift` | 472 |
| `Views/Auth/SignUpView.swift` | 427 |
| `Views/Gemini/GeminiChatView.swift` | ~210 |
| `Models/Menu.swift` | 383 |
| `Views/Home/HomeView.swift` | 376 |
| `Pour_RiceApp.swift` | ~420 |
| `Core/Services/RestaurantService.swift` | 370 |
| `Core/Utilities/LocalDataLoader.swift` | ~90 |
| `Views/Store/StoreView.swift` | ~260 |
| `Views/Menu/MenuView.swift` | 330 |
| `Core/Services/LocationService.swift` | 315 |
| `Models/ChatRoom.swift` | ~330 |
| `Core/Services/SocketService.swift` | ~280 |
| `ViewModels/ChatRoomViewModel.swift` | ~440 |
| `Views/Search/SearchView.swift` | ~290 |
| `Views/Search/SearchMapView.swift` | ~175 |
| `Views/Common/AsyncImageView.swift` | 259 |
| `Views/Account/AccountView.swift` | ~390 |
| `Views/Account/UserTypeSelectionView.swift` | ~165 |
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
| `Core/Utilities/Constants.swift` | ~285 |
| `ViewModels/MenuViewModel.swift` | 169 |
| `Views/Store/AddRestaurantView.swift` | ~375 |
| `Views/Search/FilterView.swift` | ~150 |
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
| `Models/Review.swift` | ~260 |
| `Core/Services/ReviewService.swift` | 126 |
| `App/AppDelegate.swift` | 62 |
| `Core/QR/QRPayloadDetector.swift` | ~100 |
| `Core/QR/QRFrameProcessor.swift` | ~85 |
| `Core/QR/QRDataHandler.swift` | ~55 |
| `Views/QR/QRScannerView.swift` | ~395 |
| `Views/QR/RestaurantQRView.swift` | 237 |
| `ViewModels/QRScannerViewModel.swift` | ~205 |
| `Pour RiceTests/Pour_RiceTests.swift` | 17 |
| `Pour RiceUITests/Pour_RiceUITests.swift` | 41 |
| `Pour RiceUITests/Pour_RiceUITestsLaunchTests.swift` | 33 |
| **Total (estimated)** | **~14,820** |

---

## Change Log

### 2026-04-08 — Cross-Platform QR Scanning + macOS Fallback (PR #5)

**New `Core/QR/` layer** — platform-neutral QR logic extracted from the ViewModel into three reusable types:
- `QRPayloadDetector` — validates `pourrice://menu/{restaurantId}` deep-link format; produces `QRDetection` (restaurantId + canonicalURL) or throws `QRDetectionError` (.invalidURL / .invalidFormat); requires path to have exactly one non-empty segment
- `QRFrameProcessor` (`QRFrameProcessing` protocol + `CoreImageQRFrameProcessor`) — uses `CIDetector(ofType: CIDetectorTypeQRCode)` to extract QR payload strings from raw image `Data`; throws `QRFrameProcessingError` (.invalidImageData / .detectorInitializationFailed / .noQRCodeDetected); available on iOS and macOS via `CoreImage`
- `QRDataHandler` — thin coordinator struct; takes an injected `fetchRestaurant` closure (decouples from `Services`); `handlePayload(_:)` runs detector then fetch in sequence

**`Views/QR/QRScannerView.swift`** — rewritten as a cross-platform scanner:
- `FallbackReason` enum (`.unsupportedPlatform` / `.cameraUnavailable`) drives reason-specific heading and message
- iOS camera path guarded by `#if canImport(VisionKit) && canImport(UIKit) && !os(macOS)` + `DataScannerViewController.isSupported/isAvailable` checks
- Torch toggle button (`vm.isTorchOn`) in iOS camera overlay; synced to `AVCaptureDevice` in `updateUIViewController`
- macOS/simulator `fallbackScannerView`: `PhotosPicker` (image import) + manual payload `TextField`; separate `isProcessingImage` / `isFetchingRestaurant` progress indicators
- ViewModel created lazily inside `.task {}` so `@Environment` values are guaranteed before injection
- `backgroundColour` helper returns `Color(nsColor: .windowBackgroundColor)` on macOS, `.systemBackground` on iOS

**`ViewModels/QRScannerViewModel.swift`** — refactored:
- `init(services: Services)` — instantiates `CoreImageQRFrameProcessor` and `QRDataHandler` with a `RestaurantService` fetch closure
- `handleScannedImageData(_:)` — new method for macOS/simulator image path; decodes payloads via `Task.detached` (off main actor to avoid UI stalls), picks first valid Pour Rice payload, then calls `processPayload(_:)`
- `processPayload(_:)` — shared re-entrancy-guarded flow (`isPaused` gate) used by both camera and fallback paths; differentiates `QRDetectionError` (format toast) from fetch errors (404 → not-found toast, other → service-unavailable toast)
- `presentImageLoadError()` — new public method called by view when `PhotosPickerItem` data load fails
- `isTorchOn: Bool` — observable property synced to device torch by `DataScannerRepresentable.updateUIViewController`

**Last Updated**: 2026-04-08

### 2026-04-06 — Rating Field & Half-Star Detail Display

**`Models/Restaurant.swift`**:
- `rating: Double` — decodes from lowercase `"rating"` JSON key (CodingKey was previously `"Rating"` — now fixed to `"rating"`)
- `reviewCount: Int` — decodes from `"ReviewCount"`; defaults to `0` since the API does not return this field directly (stats come from the review stats endpoint)
- `ratingDisplay` computed property: returns `"New"` when `rating == 0`, otherwise `String(format: "%.1f", rating)`

**`Views/Restaurant/RestaurantView.swift`**:
- Added `starSymbol(for:rating:)` private helper method — rounds to nearest 0.5 via `(rating * 2).rounded() / 2`, then maps each of 5 star indices to `"star.fill"`, `"star.leadinghalf.filled"`, or `"star"` SF Symbol names
- Replaced `Label(restaurant.ratingDisplay, systemImage: "star.fill")` + `Text("(\(restaurant.reviewCount))")` in `infoSection` with:
  - `HStack` containing a 5-star icon row (`ForEach(0..<5)` using `starSymbol`) + `Text(restaurant.ratingDisplay)` (orange, medium weight) + `Text("(\(restaurant.reviewCount))")` (secondary colour)
  - `.accessibilityLabel` set to `"\(ratingDisplay) out of 5 stars, \(reviewCount) reviews"`

**Last Updated**: 2026-04-06

### 2026-04-06 — Cross-Platform Feature Parity (Ads, DocuPipe, Review Images)

**Advertisement Management:**
- Added `Models/Advertisement.swift` — `Advertisement`, `CreateAdvertisementRequest`, `UpdateAdvertisementRequest` (all properties default to `nil` for convenience inits like `UpdateAdvertisementRequest(status: "active")`)
- Added `Core/Services/AdvertisementService.swift` — CRUD methods + `createStripeCheckoutSession(restaurantId:successURL:cancelURL:) async throws -> (sessionId: String, url: URL)`
- Added `Views/Common/SafariView.swift` — `UIViewControllerRepresentable` wrapping `SFSafariViewController` for in-app Stripe checkout flow
- Added `Views/Store/StoreAdsView.swift`:
  - `StoreAdsViewModel` (`@MainActor @Observable`) — `load/refresh/toggleStatus/delete`
  - `AdRowView` — thumbnail, bilingual title, Active/Inactive status pill, play/pause toggle button
  - `StoreAdCreationSheet` (private two-step): `.payment` step shows HK$10 pricing + "Pay with Stripe" (calls `AdvertisementService.createStripeCheckoutSession` → presents `SafariView`; `onDismiss` → `.form` step); `.form` step presents `StoreAdFormView`
  - `StoreAdFormView` (public) — EN/TC title + content fields, "Generate with AI" calls `services.geminiService.generateAdvertisement()`, Save calls `services.advertisementService.createAdvertisement()`
- `Views/Store/StoreView.swift` — added 6th quick action card (megaphone icon, pink, `StoreDestination.advertisements`); `StoreDestination` enum gains `.advertisements` case
- `Pour_RiceApp.swift` `navigationDestination` — added `.advertisements` case routing to `StoreAdsView(restaurantId:)`

**Bulk Menu Import:**
- Added `Core/Services/DocuPipeService.swift` — manual multipart `URLRequest` (boundary `PourRiceBoundary-{UUID}`), `x-api-passcode` injected, 120s timeout; `ExtractedMenuItem` struct (`id: UUID`, `nameEN`, `nameTC?`, `descriptionEN?`, `descriptionTC?`, `price?`, `isSelected: Bool = true`); `extractMenu(fileData:mimeType:fileName:) async throws -> [ExtractedMenuItem]`
- Added `Views/Store/BulkMenuImportView.swift` — three-step enum (`.pick / .review / .done`); `.pick`: `fileImporter` for `.pdf/.jpeg/.png/public.webp`; `.review`: `List` of `ExtractedItemRow` with `isSelected` toggle + "Import X Items" toolbar button calling `services.storeService.createMenuItem`; `.done`: success screen
- `Views/Store/StoreMenuManageView.swift` — bulk import button (`doc.badge.arrow.up`, purple) added to Liquid Glass toolbar cluster; presents `BulkMenuImportView` via `.sheet`
- `Core/Extensions/View+Extensions.swift` — `Services` container gains `docuPipeService: DocuPipeService` (now 13 services total)

**Review Image Upload:**
- `Core/Services/ImageUploadService.swift` — added `uploadImage(_:mimeType:filename:folder:authToken:) async throws -> String` (no progress callback; used for `Reviews` folder uploads)
- `Models/Review.swift` — `ReviewRequest` gained custom `encode(to:)` with explicit `CodingKeys` (`case imageUrl`) mapping `photoURLs.first → "imageUrl"` API key; previously Swift's synthesised encoder wrote the backend-unrecognised `"photoURLs"` array key
- `ViewModels/RestaurantViewModel.swift` — `submitReview` extended with `imageURL: String? = nil`; builds `ReviewRequest(photoURLs: imageURL.map { [$0] })`
- `Views/Restaurant/RestaurantView.swift` (`ReviewSubmissionView`) — `PhotosPicker` section (`import PhotosUI`) with image preview + remove button; `loadSelectedPhoto(_:)` decodes JPEG `Data`; `submit()` uploads to `Reviews` folder via `ImageUploadService.uploadImage` then passes URL to `viewModel.submitReview`

### 2026-04-07 — Bug Fixes (APIEndpoint Exhaustiveness, MKMapItem Deprecations)

**`Core/Network/APIEndpoint.swift`**:
- Added `.fetchAdvertisements` to the `method` switch's GET case — was missing, causing a "switch must be exhaustive" compile error

**`Views/Restaurant/DirectionsView.swift`**:
- Replaced all `MKMapItem(placemark: MKPlacemark(coordinate:))` calls with `MKMapItem(location:address:)` (iOS 26 API) — removes 6 deprecation warnings
- Added `import Contacts` required for `CNPostalAddress` parameter type (passed as `nil`)
