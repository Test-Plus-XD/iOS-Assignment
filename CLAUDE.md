# Pour Rice - iOS Assignment

## Overview
A SwiftUI-based iOS application for basic item tracking with timestamps. Uses SwiftData for persistent storage.

## Technology Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Architecture**: MVVM with reactive data binding
- **Testing**: XCTest (UI), Swift Testing (Unit)
- **Minimum iOS**: 17+

## Project Structure
```
Pour Rice/
  ├── Pour_RiceApp.swift        # App entry point with SwiftData setup
  ├── ContentView.swift          # Main UI: list view with add/delete
  ├── Item.swift                 # Data model: timestamp-based items
  └── Assets.xcassets/           # App resources
```

## Current Implementation

### ✅ Completed
- SwiftUI setup with NavigationSplitView (master-detail layout)
- SwiftData integration with persistent ModelContainer
- Item CRUD operations (Add, Read, Delete)
- Timestamp tracking for each item
- Edit mode and toolbar actions
- Swipe-to-delete gesture support

### ❌ Not Implemented
- Detail view content (placeholder only)
- Item properties beyond timestamp (name, description, etc.)
- Search/filter functionality
- Sorting and grouping
- Unit and UI tests (boilerplate only)
- Production-ready documentation

## Key Files
- `Pour_RiceApp.swift:9-27` - App initialization and SwiftData configuration
- `ContentView.swift:10-60` - Main UI with @Query and CRUD operations
- `Item.swift:5-10` - Data model definition

## How to Extend
1. **Add item properties**: Modify `Item` model to include name, description, category, etc.
2. **Enhance detail view**: Replace placeholder text in `ContentView` with functional item editing
3. **Add features**: Implement search, filtering, or sorting using SwiftData queries
4. **Write tests**: Complete unit and UI test files for coverage

## Notes
- The app uses modern SwiftUI patterns with automatic @Query updates
- Data persists automatically through SwiftData's ModelContainer
- All UI state management is reactive and view-driven
