# Swift Package Dependencies Setup

**IMPORTANT**: Most packages are already present in `Pour Rice.xcodeproj`. Use Xcode > File > Add Package Dependencies only if package resolution removes or fails to attach one of these products.

## Packages to Add (Using Latest Versions)

### 1. Firebase iOS SDK
- **URL**: https://github.com/firebase/firebase-ios-sdk
- **Version**: Existing project pin (`12.11.0`) or newer
- **Products to add to "Pour Rice" target**:
  - FirebaseCore
  - FirebaseAnalytics
  - FirebaseAuth
  - FirebaseInstallations
  - FirebaseMessaging
  - FirebaseInAppMessaging

### 2. Kingfisher
- **URL**: https://github.com/onevcat/Kingfisher
- **Version**: Latest (8.x or higher)
- **Products to add**: Kingfisher

### 3. GoogleSignIn-iOS
- **URL**: https://github.com/google/GoogleSignIn-iOS
- **Version**: Latest (8.x or higher)
- **Products to add**: GoogleSignIn

### 4. Socket.IO Client Swift
- **URL**: https://github.com/socketio/socket.io-client-swift
- **Version**: Existing project pin/branch
- **Products to add**: SocketIO

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
- `import FirebaseCore`
- `import FirebaseAuth`
- `import FirebaseMessaging`
- `import FirebaseInAppMessaging`
- `import Kingfisher`
- `import GoogleSignIn`
- `import SocketIO`