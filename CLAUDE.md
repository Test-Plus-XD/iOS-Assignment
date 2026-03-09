# Pour Rice - iOS Assignment

## Overview
A SwiftUI-based iOS application for vegetarian restaurant discovery in Hong Kong.
Fetches restaurant data from a Vercel Express backend (with Algolia search proxy) and uses Firebase for authentication.

## Technology Stack
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with `@Observable` and `@Environment`
- **Authentication**: Firebase Auth (email/password + Google Sign-In)
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
  │   └── AppDelegate.swift              # Firebase initialisation
  ├── Pour_RiceApp.swift                 # App entry point, tab navigation, service injection
  ├── ContentView.swift                  # Placeholder / legacy entry
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
- `Pour_RiceApp.swift` - Tab bar setup, `NavigationDestination` registration, `Services` injection
- `Core/Services/RestaurantService.swift` - Restaurant API calls, caching, and Vercel proxy search; private `AlgoliaHit` → `Restaurant` mapping
- `Core/Utilities/Constants.swift` - All API base URLs, endpoint paths, header names, and UI constants
- `Models/Restaurant.swift` - `Decodable` restaurant model; memberwise `init` added via extension
- `Models/BilingualText.swift` - `BilingualText(en:tc:)` and `BilingualText(uniform:)` constructors
- `ViewModels/SearchViewModel.swift` - Debounced search (300ms `Task.sleep`), filter state
- `Views/Search/FilterView.swift` - District and keyword filter sheet

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
| `ContentView.swift` | 61 |
| `Item.swift` | 18 |
| `Pour RiceTests/Pour_RiceTests.swift` | 17 |
| `Pour RiceUITests/Pour_RiceUITests.swift` | 41 |
| `Pour RiceUITests/Pour_RiceUITestsLaunchTests.swift` | 33 |
| **Total** | **9,299** |
