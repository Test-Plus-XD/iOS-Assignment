# Pour Rice - iOS Assignment

## Overview
A SwiftUI-based iOS application for vegetarian restaurant discovery in Hong Kong.
Fetches restaurant data from a Vercel Express backend (with Algolia search proxy) and uses Firebase for authentication.

## Technology Stack
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with `@Observable` and `@Environment`
- **Authentication**: Firebase Auth (email/password + Google Sign-In) with guest browsing mode
- **Backend**: Vercel Express API (`https://vercel-express-api-alpha.vercel.app`)
- **Search**: Algolia via Vercel proxy (`GET /API/Algolia/Restaurants`) — no client-side Algolia SDK
- **Networking**: `URLSession` with a shared `APIClient`
- **Localisation**: English and Traditional Chinese (`Localizable.xcstrings`)
- **Testing**: XCTest (UI), Swift Testing (Unit)
- **Minimum iOS**: 26+

## Project Structure
```
Pour Rice/
  ├── App/
  │   └── AppDelegate.swift              # Firebase initialisation + Google Sign-In URL callback
  ├── Pour_RiceApp.swift                 # App entry point, tab navigation, service injection
  ├── Models/
  │   ├── Restaurant.swift               # Core restaurant model (Decodable + memberwise init)
  │   ├── Menu.swift                     # Menu item and category models
  │   ├── Review.swift                   # User review model
  │   ├── User.swift                     # User profile model
  │   └── BilingualText.swift            # EN/TC bilingual text wrapper
  ├── ViewModels/
  │   ├── HomeViewModel.swift            # Nearby restaurants, location-based fetching
  │   ├── SearchViewModel.swift          # Debounced search, district/keyword filter state
  │   ├── RestaurantViewModel.swift      # Restaurant detail + reviews
  │   ├── MenuViewModel.swift            # Restaurant menu fetching
  │   └── AccountViewModel.swift        # Auth state, profile editing
  ├── Views/
  │   ├── Auth/
  │   │   ├── LoginView.swift            # Email/Google sign-in
  │   │   └── SignUpView.swift           # Account registration
  │   ├── Home/
  │   │   └── HomeView.swift             # Nearby restaurant cards
  │   ├── Restaurant/
  │   │   └── RestaurantView.swift       # Detail page with tabs
  │   ├── Menu/
  │   │   └── MenuView.swift             # Menu item list
  │   ├── Search/
  │   │   ├── SearchView.swift           # Search bar + results list
  │   │   └── FilterView.swift          # District + keyword filter sheet
  │   ├── Account/
  │   │   └── AccountView.swift          # Profile, settings, sign-out
  │   └── Common/
  │       ├── AsyncImageView.swift       # Cached async image loader
  │       ├── EmptyStateView.swift       # Empty/no-results states
  │       ├── ErrorView.swift            # Retry error state
  │       └── LoadingView.swift          # Spinner and skeleton views
  └── Core/
      ├── Services/
      │   ├── AuthService.swift          # Firebase Auth wrapper
      │   ├── LocationService.swift      # CoreLocation wrapper
      │   ├── MenuService.swift          # Menu API calls
      │   ├── RestaurantService.swift    # Restaurant API calls + Vercel Algolia search
      │   └── ReviewService.swift       # Review API calls
      ├── Network/
      │   ├── APIClient.swift            # Shared URLSession request executor
      │   ├── APIEndpoint.swift          # Typed endpoint enum
      │   └── APIError.swift             # Network error types
      ├── Utilities/
      │   └── Constants.swift            # API URLs, headers, UI values
      └── Extensions/
          ├── View+Extensions.swift      # Services environment key + haptics
          └── Date+Extensions.swift      # Formatting helpers
```

## Key Files
- `Pour_RiceApp.swift` - Tab bar setup using iOS 26 `Tab` API, `NavigationDestination` registration, `Services` injection; uses `private static let sharedServices` to guarantee single Firebase initialization
- `App/Info.plist` - URL types for Google Sign-In OAuth callbacks; `CFBundleURLTypes` must be array of dictionaries (not single dict)
- `App/AppDelegate.swift` - Firebase initialization + Google Sign-In URL callback handler
- `Core/Services/RestaurantService.swift` - Restaurant API calls, caching, and Vercel proxy search; private `AlgoliaHit` → `Restaurant` mapping
- `Core/Utilities/Constants.swift` - All API base URLs, endpoint paths, header names, and UI constants
- `Models/Restaurant.swift` - `Decodable` restaurant model; memberwise `init` added via extension
- `Models/BilingualText.swift` - `BilingualText(en:tc:)` and `BilingualText(uniform:)` constructors; `.localized` (American) and `.localised` (British alias) both available
- `ViewModels/SearchViewModel.swift` - Debounced search (300ms `Task.sleep`), filter state
- `Views/Search/FilterView.swift` - District and keyword filter sheet

## Assets.xcassets

### Accent Colour
- **`AccentColor`** — jade/sage green (Display P3: R=0.25, G=0.75, B=0.50, α=0.75). Used app-wide via `.tint` or `Color.accentColor`.

### Image Assets (usable via `Image("name")` in SwiftUI)
| Asset | Type | Used in |
|-------|------|---------|
| `AppLogo` | `.imageset` (light + dark variants) | `LoginView`, `SignUpView`, `EmptyStateView.noNearbyRestaurants()` |
| `Google` | `.imageset` | `LoginView` Google sign-in button icon |
| `Placeholder` | `.imageset` | `AsyncImageView` — shown when restaurant image URL is nil or fails to load |
| `sample_1`, `sample_2`, `sample_3` | `.imageset` | Available sample restaurant photos (not yet wired to any view) |
| `Eclipse` | `.dataset` (animated GIF) | Not yet wired to any view |

### Do NOT use `Image("AppIcon")`
`AppIcon.appiconset` cannot be loaded via SwiftUI's `Image()`. Use `Image("AppLogo")` instead — it is a regular `.imageset` with the same light/dark artwork.

## API Integration
- **Base URL**: `https://vercel-express-api-alpha.vercel.app`
- **Required header**: `x-api-passcode: PourRice` on all requests
- **Authenticated routes**: also require `Authorization: Bearer {firebase_id_token}`
- **Search endpoint**: `GET /API/Algolia/Restaurants?query=&districts=&keywords=&page=0&hitsPerPage=50`
  - Response: `{ hits: [{objectID, Name_EN, Name_TC, District_EN, District_TC, Keyword_EN[], Keyword_TC[], ImageUrl, Seats, Latitude, Longitude}], nbHits, page, nbPages }`
  - Search results have no `openingHours`, `rating`, or `cuisine` — only shown when populated via the detail endpoint

## Search Architecture
`SearchViewModel` → `RestaurantService.search(query:filters:)` → Vercel proxy → Algolia index

- `SearchFilters` has two fields: `districts: [String]` and `keywords: [String]`
- Algolia SDK was removed; all search traffic uses `URLSession` through the backend proxy
- `AlgoliaHit` is a private struct inside `RestaurantService` — maps `objectID` → `Restaurant.id`

## Code & Comments Structure

### Naming Conventions
- **Variables / properties**: `camelCase` (e.g., `searchQuery`, `isLoading`)
- **Types / structs / classes**: `PascalCase` (e.g., `SearchViewModel`, `BilingualText`)
- **Language-specific data fields** (from API / Firestore): `Snake_CASE` with language suffix (e.g., `Name_EN`, `District_TC`, `Keyword_EN`)
- **Constants**: grouped in nested `enum` types inside `Constants` (e.g., `Constants.API.baseURL`)

### Comment Style
- **File headers**: `//  FileName.swift` block at the top of every file with purpose description
- **Cross-platform notes**: `// ============= FOR FLUTTER/ANDROID DEVELOPERS: =============` blocks explain iOS-specific patterns and their Flutter/Kotlin equivalents — helps team members from other platforms read the code
- **MARK sections**: `// MARK: - Section Name` dividers separate logical sections within a file (Dependencies, Body, Actions, Helpers, etc.)
- **Inline comments**: Used sparingly on non-obvious logic; aligned with the line they describe
- **Doc comments**: `///` triple-slash for public/internal types and methods (describes purpose, parameters, and return values)
- **TODO / FIXME**: Not used; all code is production-ready

### Architecture Pattern
- `@Observable` + `@MainActor` on all ViewModels (Swift 6 concurrency)
- Services injected via `@Environment(\.services)` using a custom `EnvironmentKey`
- Views are passive — no business logic; all state lives in the ViewModel
- Async operations use `async/await` with structured concurrency (`Task {}`)

### iOS 26 / Liquid Glass Patterns
- **Tab navigation**: Uses `Tab("title", systemImage:) { content }` API (not legacy `.tabItem {}`)
- **Liquid Glass**: `.glassEffect(_:in:)` for glass styling; `.glassEffectID(_:in:)` for morphing transitions (requires `@Namespace`)
- **ShapeStyle**: Use `.tint` for standalone accent-coloured styles; use `Color.accentColor` in ternaries with `.primary` (different `ShapeStyle` types cannot mix in ternary expressions)
- **AsyncImageView**: `ContentMode` is qualified as `SwiftUI.ContentMode` to avoid ambiguity with UIKit (imported transitively by Kingfisher)

### Guest Mode
- Users can browse without signing in by tapping "Continue as Guest" on `LoginView`
- `RootView` uses `@State isGuest` — when `true`, shows `MainTabView` without authentication
- **Accessible pages**: Home, Search, Restaurant detail, Menu (all public endpoints)
- **Account tab**: Shows a sign-in prompt with a "Sign In" button that sets `isGuest = false`, returning the user to `LoginView`
- **Language picker**: Available to guests via `@AppStorage` (no backend sync until signed in)
- `APIClient.injectHeaders` gracefully handles missing auth tokens — catches the error and continues with only the `x-api-passcode` header

### Firebase / Google Sign-In Setup
- **Initialisation order**: `FirebaseApp.configure()` in `Pour_RiceApp.init()` via static shared Services instance → then `Services()` → `AuthService` calls `Auth.auth()`
  - Uses `private static let sharedServices: Services` to ensure Firebase is configured **exactly once** even when SwiftUI re-creates the `@main` App struct
  - `init()` simply assigns `self.services = Self.sharedServices` (no double initialization)
- **AppDelegate**: Must implement `application(_:open:options:)` for Google Sign-In OAuth URL callback (UIKit-level handler). The SwiftUI `.onOpenURL` in `Pour_RiceApp` also handles this; both are safe to coexist.
- **URL scheme (`CFBundleURLTypes`)**:
  - `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` registered as a URL scheme via physical `Info.plist` file
  - **Critical**: `CFBundleURLTypes` must be an **array of dictionaries** in Info.plist (not a single dictionary). Xcode's `INFOPLIST_KEY_CFBundleURLTypes` build setting cannot properly express this structure; use a physical `Info.plist` with proper array syntax
  - Physical `Info.plist` is in the project root; `INFOPLIST_FILE = "Pour Rice/Info.plist"` in build settings tells Xcode to use it
  - With `PBXFileSystemSynchronizedRootGroup`, `Info.plist` is excluded from Copy Bundle Resources via `PBXFileSystemSynchronizedBuildFileExceptionSet` — the build system still reads it via `INFOPLIST_FILE`
- **Firebase Installations API**: Must be enabled in Google Cloud Console for the project. Without it, device registration fails with 403, causing Google Sign-In to return "An internal error has occurred."
  - If 403 `API_KEY_SERVICE_BLOCKED` persists despite API enablement, check:
    - API key has no restrictive API restrictions (set to "Don't restrict key")
    - API key has no restrictive application restrictions (set to "None")
    - Firebase Installations API is explicitly enabled (not just other APIs)
    - If issues persist, try deleting and recreating the API key and re-downloading `GoogleService-Info.plist` from Firebase Console
- **Swizzler warning** (`[GoogleUtilities/AppDelegateSwizzler]`): Cosmetic — does not cause functional failure. Silenced by setting `FirebaseAppDelegateProxyEnabled = NO` in `Info.plist`.

### SPM Dependencies
- **Kingfisher** — image loading and caching (`AsyncImageView`)
- **Firebase iOS SDK** — FirebaseCore, FirebaseAuth, FirebaseAnalytics, FirebaseAnalyticsCore, FirebaseInstallations
- **GoogleSignIn-iOS** — Google OAuth sign-in (v8.0.0)
- Removed (unused): Alamofire, algoliasearch-client-swift, swift-async-algorithms, FirebaseFirestore, FirebaseInAppMessaging-Beta, FirebaseMessaging, FirebaseStorage

## Swift File Line Counts

| File | Lines |
|------|-------|
| `Core/Services/AuthService.swift` | 553 |
| `Views/Restaurant/RestaurantView.swift` | 533 |
| `Models/Restaurant.swift` | 524 |
| `Views/Auth/LoginView.swift` | 472 |
| `Views/Auth/SignUpView.swift` | 427 |
| `Models/Menu.swift` | 383 |
| `Views/Home/HomeView.swift` | 376 |
| `Core/Services/RestaurantService.swift` | 370 |
| `Pour_RiceApp.swift` | 366 |
| `Views/Menu/MenuView.swift` | 330 |
| `Core/Services/LocationService.swift` | 315 |
| `Views/Search/SearchView.swift` | 266 |
| `Views/Common/AsyncImageView.swift` | 259 |
| `Views/Account/AccountView.swift` | 255 |
| `Models/BilingualText.swift` | 251 |
| `Core/Network/APIClient.swift` | 222 |
| `Models/User.swift` | 220 |
| `Views/Common/EmptyStateView.swift` | 216 |
| `Core/Extensions/View+Extensions.swift` | 206 |
| `ViewModels/SearchViewModel.swift` | 206 |
| `ViewModels/RestaurantViewModel.swift` | 202 |
| `Core/Network/APIEndpoint.swift` | 193 |
| `Core/Services/MenuService.swift` | 185 |
| `Core/Network/APIError.swift` | 179 |
| `Views/Common/ErrorView.swift` | 177 |
| `Core/Extensions/Date+Extensions.swift` | 177 |
| `ViewModels/HomeViewModel.swift` | 176 |
| `Core/Utilities/Constants.swift` | 174 |
| `ViewModels/MenuViewModel.swift` | 169 |
| `Views/Search/FilterView.swift` | 161 |
| `Views/Common/LoadingView.swift` | 135 |
| `ViewModels/AccountViewModel.swift` | 133 |
| `Models/Review.swift` | 130 |
| `Core/Services/ReviewService.swift` | 126 |
| `App/AppDelegate.swift` | 62 |
| `Pour RiceTests/Pour_RiceTests.swift` | 17 |
| `Pour RiceUITests/Pour_RiceUITests.swift` | 41 |
| `Pour RiceUITests/Pour_RiceUITestsLaunchTests.swift` | 33 |
| **Total** | **~9,220** |
