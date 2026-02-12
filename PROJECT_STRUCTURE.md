# Pour Rice - Project Structure

**Created:** Sprint 1 - Foundation
**Last Updated:** 11 February 2026

---

## 📁 Current Project Structure

```
Pour Rice/
│
├── 📱 App/                              [Empty - Ready for AppDelegate]
│   └── (AppDelegate.swift - to be created in Sprint 3)
│
├── ⚙️ Core/
│   ├── Network/                         [Empty - Ready for API layer]
│   │   ├── (APIClient.swift - Sprint 2)
│   │   ├── (APIEndpoint.swift - Sprint 2)
│   │   └── (APIError.swift - Sprint 2)
│   │
│   ├── Services/                        [Empty - Ready for business logic]
│   │   ├── (AuthService.swift - Sprint 3)
│   │   ├── (RestaurantService.swift - Sprint 3)
│   │   ├── (ReviewService.swift - Sprint 3)
│   │   ├── (MenuService.swift - Sprint 3)
│   │   ├── (AlgoliaService.swift - Sprint 3)
│   │   └── (LocationService.swift - Sprint 3)
│   │
│   ├── Extensions/                      [Empty - Ready for Swift extensions]
│   │   ├── (View+Extensions.swift - Sprint 5+)
│   │   └── (Date+Extensions.swift - Sprint 5+)
│   │
│   └── Utilities/
│       └── ✅ Constants.swift           [CREATED] - API config, app settings
│
├── 📦 Models/                           [Empty - Ready for data models]
│   ├── (BilingualText.swift - Sprint 2)
│   ├── (Restaurant.swift - Sprint 2)
│   ├── (User.swift - Sprint 2)
│   ├── (Review.swift - Sprint 2)
│   └── (MenuItem.swift - Sprint 2)
│
├── 🧠 ViewModels/                       [Empty - Ready for MVVM logic]
│   ├── (HomeViewModel.swift - Sprint 5)
│   ├── (SearchViewModel.swift - Sprint 5)
│   ├── (RestaurantDetailViewModel.swift - Sprint 6)
│   ├── (MenuViewModel.swift - Sprint 6)
│   └── (AccountViewModel.swift - Sprint 7)
│
├── 🎨 Views/
│   ├── Home/                            [Empty - Sprint 5]
│   │   └── (HomeView.swift)
│   │
│   ├── Search/                          [Empty - Sprint 5]
│   │   ├── (SearchView.swift)
│   │   └── (FilterView.swift)
│   │
│   ├── RestaurantDetail/                [Empty - Sprint 6]
│   │   └── (RestaurantDetailView.swift)
│   │
│   ├── Menu/                            [Empty - Sprint 6]
│   │   └── (MenuView.swift)
│   │
│   ├── Account/                         [Empty - Sprint 7]
│   │   └── (AccountView.swift)
│   │
│   ├── Auth/                            [Empty - Sprint 4]
│   │   ├── (LoginView.swift)
│   │   └── (SignUpView.swift)
│   │
│   └── Common/                          [Empty - Sprint 7]
│       ├── (LoadingView.swift)
│       ├── (ErrorView.swift)
│       └── (AsyncImageView.swift)
│
├── 🎭 Resources/
│   └── ✅ Localizable.xcstrings         [CREATED] - 30+ bilingual strings
│
├── 🖼️ Assets.xcassets/
│   ├── AccentColor.colorset
│   └── AppIcon.appiconset
│
├── ✅ Pour_RiceApp.swift                [UPDATED] - SwiftData removed
├── ✅ ContentView.swift                 [EXISTS] - To be renamed to MainTabView.swift in Sprint 5
│
└── 📄 Root Directory Files:
    ├── ✅ PACKAGE_DEPENDENCIES.md       [CREATED] - Package installation guide
    ├── ✅ SPRINT_1_SUMMARY.md           [CREATED] - Sprint 1 completion summary
    ├── ✅ PROJECT_STRUCTURE.md          [THIS FILE]
    └── ✅ Plan.md                       [UPDATED] - Progress tracking

```

---

## 📊 Status Legend

- ✅ **Created/Updated** - File exists and is ready
- [Empty] - Directory created, awaiting files
- (filename) - Planned file, not yet created
- Sprint X - Indicates when file will be created

---

## 🎯 Sprint 1 Deliverables

### Created Files
1. **Core/Utilities/Constants.swift**
   - API configuration (base URL, passcode, endpoints)
   - Algolia settings
   - Firebase collections
   - App settings and UI constants
   - Cache and search configuration

2. **Resources/Localizable.xcstrings**
   - 30+ bilingual string keys
   - British English + Traditional Chinese
   - Navigation, UI, errors, actions

3. **Documentation Files**
   - PACKAGE_DEPENDENCIES.md
   - SPRINT_1_SUMMARY.md
   - PROJECT_STRUCTURE.md (this file)

### Updated Files
1. **Pour_RiceApp.swift**
   - Removed SwiftData dependencies
   - Cleaned up ModelContainer code
   - Added detailed comments

2. **Plan.md**
   - Updated package versions to latest
   - Added progress tracking section
   - Marked Sprint 1 as completed

### Deleted Files
1. **Item.swift** - SwiftData model (no longer needed)

---

## 🏗️ Architecture Overview

### MVVM Pattern
- **Models/**: Data structures and domain models
- **ViewModels/**: Business logic and state management (@Observable)
- **Views/**: SwiftUI views and UI components

### Core Layer
- **Network/**: API client, endpoints, error handling
- **Services/**: Reusable business logic services
- **Extensions/**: Swift language extensions
- **Utilities/**: App-wide constants and helpers

### Resource Management
- **Resources/**: Localization, assets, configuration files
- **Assets.xcassets/**: Images, colors, app icons

---

## 📦 Swift Package Dependencies (To Be Added)

See `PACKAGE_DEPENDENCIES.md` for installation instructions.

1. **Firebase iOS SDK v11.x**
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage

2. **Alamofire v5.x**
   - Network layer

3. **Kingfisher v8.x**
   - Image caching

4. **AlgoliaSearchClient v8.x**
   - Search functionality

---

## 🚀 Next Sprint: Sprint 2 - Models & Network

**Files to Create:**
1. Models/BilingualText.swift
2. Models/Restaurant.swift
3. Models/User.swift
4. Models/Review.swift
5. Models/MenuItem.swift
6. Core/Network/APIClient.swift
7. Core/Network/APIEndpoint.swift
8. Core/Network/APIError.swift

**Objectives:**
- Define all core data models
- Implement network layer with header injection
- Create API endpoint definitions
- Implement error handling
- Test basic API integration

---

## 💡 Development Guidelines

### Code Style
- **British English spelling** (localisation, authorisation, colour)
- **Detailed inline comments** on all classes and functions
- **iOS Human Interface Guidelines** compliance
- **No Material Design** patterns or Android styling

### State Management
- Use **@Observable macro** (iOS 17+)
- SwiftUI native state management
- No ObservableObject (legacy pattern)

### Localization
- All user-facing strings in Localizable.xcstrings
- BilingualText model for API responses
- Support British English (en) and Traditional Chinese (zh-Hant)

---

## ✅ Verification Checklist

Before proceeding to Sprint 2:

- [ ] Swift packages added in Xcode (see PACKAGE_DEPENDENCIES.md)
- [ ] GoogleService-Info.plist downloaded and added to project
- [ ] Algolia search key updated in Constants.swift
- [ ] Project builds successfully in Xcode
- [ ] All Sprint 1 files present and correct
- [ ] Deployment target set to iOS 17.0

---

**Status:** Sprint 1 Foundation Complete ✅
**Next:** Sprint 2 - Models & Network Layer
