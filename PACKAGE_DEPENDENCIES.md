# Swift Package Dependencies Setup

**IMPORTANT**: Please add these dependencies in Xcode using: File > Add Package Dependencies

## Packages to Add (Using Latest Versions)

### 1. Firebase iOS SDK
- **URL**: https://github.com/firebase/firebase-ios-sdk
- **Version**: Latest (11.x or higher)
- **Products to add to "Pour Rice" target**:
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseStorage

### 2. Alamofire
- **URL**: https://github.com/Alamofire/Alamofire
- **Version**: Latest (5.x or higher)
- **Products to add**: Alamofire

### 3. Kingfisher
- **URL**: https://github.com/onevcat/Kingfisher
- **Version**: Latest (8.x or higher)
- **Products to add**: Kingfisher

### 4. AlgoliaSearchClient
- **URL**: https://github.com/algolia/algoliasearch-client-swift
- **Version**: Latest (8.x or higher)
- **Products to add**: AlgoliaSearchClient

## How to Add in Xcode

1. Open **Pour Rice.xcodeproj** in Xcode
2. Select the project in the navigator
3. Select the "Pour Rice" target
4. Go to the "General" tab
5. Scroll to "Frameworks, Libraries, and Embedded Content"
6. Click the "+" button and select "Add Package Dependency"
7. Paste each URL above and click "Add Package"
8. Select the products listed for each package
9. Ensure they're added to the "Pour Rice" target

## Verification

After adding all packages, the project should build successfully with `import` statements for:
- `import FirebaseAuth`
- `import FirebaseFirestore`
- `import FirebaseStorage`
- `import Alamofire`
- `import Kingfisher`
- `import AlgoliaSearchClient`
