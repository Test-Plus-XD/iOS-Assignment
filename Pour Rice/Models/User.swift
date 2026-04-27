//
//  User.swift
//  Pour Rice
//
//  User profile model representing authenticated users
//  Stores user preferences and account information
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is like a data class in Kotlin or a model class in Dart.
//  In Flutter, you'd use json_serializable or freezed for JSON parsing.
//  In Swift, we use Codable protocol (similar to Gson in Android).
//  ============================================================================
//

import Foundation  // Foundation provides basic data types like Date, String, etc.

/// Represents a user account with profile information and preferences
/// Synced with Firebase Authentication and Firestore
///
/// PROTOCOL CONFORMANCE:
/// - Codable: Enables JSON encoding/decoding (like @Serializable in Kotlin)
/// - Identifiable: Required for SwiftUI lists (like having a unique 'key' in Flutter)
/// - Hashable: Allows use in Sets and as Dictionary keys
/// - Sendable: Thread-safe, can be shared across async boundaries (Swift 6 concurrency)
struct User: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties
    // (MARK creates a separator in Xcode's navigator for better organization)

    /// Unique user identifier matching Firebase Auth UID
    ///
    /// WHAT IS 'let':
    /// 'let' = immutable constant (like 'final' in Dart or 'val' in Kotlin)
    /// Once set during initialization, it can never be changed
    ///
    /// WHAT IS String:
    /// Swift's native string type (like String in Dart/Kotlin)
    let id: String

    /// User's email address
    /// Immutable because email shouldn't change after account creation
    let email: String

    /// Display name for the user
    ///
    /// WHAT IS 'var':
    /// 'var' = mutable variable (like 'var' in Dart or 'var' in Kotlin)
    /// Can be changed after initialization
    var displayName: String

    /// User account type (customer or restaurant owner)
    /// Uses the UserType enum defined below
    let userType: UserType

    /// Whether the backend profile contains an explicit account type.
    ///
    /// New accounts can briefly return an empty `type` until the user chooses
    /// Diner or Restaurant Owner in `UserTypeSelectionView`. In that pending
    /// state the app uses `.diner` as a harmless UI fallback, while
    /// `AuthService` uses this flag to keep the type-selection sheet open.
    let hasSelectedUserType: Bool

    /// Profile photo URL (optional)
    ///
    /// WHAT IS String?:
    /// The question mark means this is an Optional type
    /// It can be either a String value OR nil (null in Dart/Kotlin)
    ///
    /// FLUTTER EQUIVALENT:
    /// String? photoURL;
    var photoURL: String?

    /// Phone number (optional)
    var phoneNumber: String?

    /// User biography (optional)
    var bio: String?

    /// ID of the restaurant owned by this user (Restaurant type only)
    /// Set when the user claims a restaurant via POST /API/Restaurants/:id/claim
    var restaurantId: String?

    /// User's preferred language code (en or zh-Hant)
    /// Used to display restaurant content in the correct language
    var preferredLanguage: String

    /// User's preferred theme ("light", "dark", or "system")
    var preferredTheme: String

    /// Whether push notifications are enabled
    var notificationsEnabled: Bool

    /// Date when the account was created
    /// Automatically set to current time during initialization
    let createdAt: Date

    /// Date of last profile update
    /// Should be updated whenever user modifies their profile
    var updatedAt: Date

    // MARK: - User Type

    /// Enumeration of possible user account types
    ///
    /// WHAT IS enum:
    /// Similar to enum in Dart/Kotlin, but more powerful in Swift
    /// Each case represents a possible value
    ///
    /// PROTOCOL CONFORMANCE:
    /// - String: The raw value type (each case maps to a String)
    /// - Codable: Automatically handles JSON encoding/decoding
    ///
    /// FLUTTER EQUIVALENT:
    /// enum UserType { diner, restaurant }
    enum UserType: String, Codable {
        /// Regular diner/customer user
        /// When encoded to JSON, this becomes the string "Diner"
        case diner = "Diner"

        /// Restaurant owner with management access
        /// When encoded to JSON, this becomes the string "Restaurant"
        case restaurant = "Restaurant"
    }

    // MARK: - Custom Decoding

    /// Maps JSON field names to Swift property names
    ///
    /// WHY THIS IS NEEDED:
    /// The backend API returns "uid" but we want to use "id" in our code
    /// CodingKeys tells Codable how to map between them
    ///
    /// FLUTTER EQUIVALENT:
    /// @JsonKey(name: 'uid') String id;
    ///
    /// For properties not listed here (like email), Swift uses the property name directly
    enum CodingKeys: String, CodingKey {
        case id = "uid"              // JSON has "uid", Swift uses "id"
        case email
        case displayName
        case userType = "type"       // JSON has "type", Swift uses "userType"
        case photoURL
        case phoneNumber
        case bio
        case restaurantId
        case preferences             // Nested object: { language, theme, notifications }
        case createdAt
        case updatedAt = "modifiedAt" // JSON has "modifiedAt", Swift uses "updatedAt"
    }

    /// Keys for the nested `preferences` object in the API response
    private enum PreferencesCodingKeys: String, CodingKey {
        case language                // "EN" | "TC"
        case theme                   // "light" | "dark" | "system"
        case notifications           // Bool
    }

    // MARK: - Custom Decodable

    /// Custom decoder to handle the nested `preferences.language` field and
    /// the `modifiedAt` → `updatedAt` key rename.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id               = try c.decode(String.self,   forKey: .id)
        email            = try c.decode(String.self,   forKey: .email)
        displayName      = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        let rawUserType = try c.decodeIfPresent(String.self, forKey: .userType)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawUserType, let decodedUserType = UserType(rawValue: rawUserType) {
            userType = decodedUserType
            hasSelectedUserType = true
        } else {
            userType = .diner
            hasSelectedUserType = false
        }
        photoURL         = try c.decodeIfPresent(String.self, forKey: .photoURL)
        phoneNumber      = try c.decodeIfPresent(String.self, forKey: .phoneNumber)
        bio              = try c.decodeIfPresent(String.self, forKey: .bio)
        restaurantId     = try c.decodeIfPresent(String.self, forKey: .restaurantId)
        createdAt        = (try? c.decode(Date.self,   forKey: .createdAt)) ?? Date()
        updatedAt        = (try? c.decode(Date.self,   forKey: .updatedAt)) ?? Date()

        // Preferences live inside the nested "preferences" object. Do not read
        // the legacy top-level preferredLanguage field; that was an iOS client
        // payload bug. If an older malformed profile lacks preferences, fall
        // back locally so auth/profile decoding still succeeds.
        if let prefs = try? c.nestedContainer(keyedBy: PreferencesCodingKeys.self, forKey: .preferences) {
            let rawLanguage = try prefs.decodeIfPresent(String.self, forKey: .language) ?? "EN"
            preferredLanguage = User.appLanguageCode(fromAPIValue: rawLanguage)
            preferredTheme = try prefs.decodeIfPresent(String.self, forKey: .theme) ?? "system"
            notificationsEnabled = try prefs.decodeIfPresent(Bool.self, forKey: .notifications) ?? true
        } else {
            preferredLanguage = "en"
            preferredTheme = "system"
            notificationsEnabled = true
        }
    }

    // MARK: - Custom Encodable

    /// Custom encoder to mirror decoding behavior, handling
    /// nested `preferences.language` and key renames.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)                 // maps to "uid"
        try c.encode(email, forKey: .email)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(hasSelectedUserType ? userType.rawValue : "", forKey: .userType) // maps to "type"
        try c.encodeIfPresent(photoURL, forKey: .photoURL)
        try c.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try c.encodeIfPresent(bio, forKey: .bio)
        try c.encodeIfPresent(restaurantId, forKey: .restaurantId)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)   // maps to "modifiedAt"

        // Encode nested preferences with language mapping ("en" -> "EN", "zh-Hant" -> "TC")
        var prefs = c.nestedContainer(keyedBy: PreferencesCodingKeys.self, forKey: .preferences)
        let langCode: String
        switch preferredLanguage {
        case "zh-Hant":
            langCode = "TC"
        case "en":
            fallthrough
        default:
            langCode = "EN"
        }
        try prefs.encode(langCode, forKey: .language)
        try prefs.encode(preferredTheme, forKey: .theme)
        try prefs.encode(notificationsEnabled, forKey: .notifications)
    }

    /// Normalises backend preference language values into app locale codes.
    private static func appLanguageCode(fromAPIValue value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "tc", "zh-hant", "zh_hant":
            return "zh-Hant"
        default:
            return "en"
        }
    }

    // MARK: - Initialisation

    /// Creates a new user instance
    ///
    /// WHAT IS init:
    /// This is Swift's constructor (like a constructor in Dart/Kotlin)
    /// Called when creating a new User object
    ///
    /// FLUTTER EQUIVALENT:
    /// User({
    ///   required this.id,
    ///   required this.email,
    ///   this.userType = UserType.customer,
    /// })
    ///
    /// - Parameters:
    ///   - id: Unique user identifier (from Firebase Auth)
    ///   - email: User's email address
    ///   - displayName: Display name shown in the app
    ///   - userType: Account type (defaults to .diner)
    ///   - photoURL: Profile photo URL (defaults to nil/null)
    ///   - preferredLanguage: Language code (defaults to "en" for British English)
    init(
        id: String,
        email: String,
        displayName: String,
        userType: UserType = .diner,
        hasSelectedUserType: Bool = true,
        photoURL: String? = nil,
        phoneNumber: String? = nil,
        bio: String? = nil,
        restaurantId: String? = nil,
        preferredLanguage: String = "en",
        preferredTheme: String = "system",
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.userType = userType
        self.hasSelectedUserType = hasSelectedUserType
        self.photoURL = photoURL
        self.phoneNumber = phoneNumber
        self.bio = bio
        self.restaurantId = restaurantId
        self.preferredLanguage = preferredLanguage
        self.preferredTheme = preferredTheme
        self.notificationsEnabled = notificationsEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - User Request/Response Models

/// Request model for creating a new user profile
///
/// WHAT IS THIS FOR:
/// When we call the backend API to create a new user, we send this structure
/// It's separate from the User model because the API expects different field names
///
/// WHY SEPARATE MODELS:
/// - CreateUserRequest: What we SEND to the API
/// - User: What we RECEIVE from the API and use in the app
///
/// FLUTTER EQUIVALENT:
/// class CreateUserRequest {
///   final String uid;
///   final String email;
///   // ... etc
/// }
struct CreateUserRequest: Codable {
    let uid: String                    // Firebase Auth user ID
    let email: String                  // User's email address
    let displayName: String            // User's chosen display name
    let userType: String               // Account type as string ("Diner" or "Restaurant")
    let preferences: Preferences       // Nested preference payload expected by the backend

    struct Preferences: Codable {
        let language: String?
        let theme: String?
        let notifications: Bool?
    }

    enum CodingKeys: String, CodingKey {
        case uid
        case email
        case displayName
        case userType = "type"         // API expects "type" not "userType"
        case preferences
    }

    init(
        uid: String,
        email: String,
        displayName: String,
        userType: String,
        languageCode: String
    ) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.userType = userType
        self.preferences = Preferences(
            language: languageCode == "zh-Hant" ? "TC" : "EN",
            theme: "system",
            notifications: true
        )
    }
}

/// Request model for updating only the user type (Diner / Restaurant)
///
/// WHAT IS THIS FOR:
/// Sent by the user-type selection sheet after first sign-up.
/// Uses a minimal payload so only `type` is updated via `{ merge: true }` on the server.
struct UpdateUserTypeRequest: Codable, Sendable {
    /// Raw string value — "Diner" or "Restaurant"
    let type: String
}

/// Request model for updating user profile
///
/// WHAT IS THIS FOR:
/// When updating a user's profile (name, photo, language), we send this to the API
///
/// WHY ALL OPTIONALS:
/// All fields are optional (String?) because users can update just one field
/// If a field is nil, the API knows not to update that field
///
/// EXAMPLE:
/// To only update the display name:
/// UpdateUserRequest(displayName: "New Name", photoURL: nil, preferredLanguage: nil)
///
/// The API stores language inside `preferences.language` with values "EN" or "TC".
/// This struct mirrors that nested structure so `{ merge: true }` on the server
/// correctly updates the nested field.
struct UpdateUserRequest: Codable {
    let displayName: String?
    let photoURL: String?
    let phoneNumber: String?
    let bio: String?
    let preferences: Preferences?
    let restaurantId: String?

    struct Preferences: Codable {
        let language: String?
        let theme: String?
        let notifications: Bool?
    }

    /// Convenience initialiser that maps app language codes ("en"/"zh-Hant")
    /// to the API codes ("EN"/"TC") used inside `preferences.language`.
    init(
        displayName: String? = nil,
        photoURL: String? = nil,
        phoneNumber: String? = nil,
        bio: String? = nil,
        preferredLanguage: String? = nil,
        theme: String? = nil,
        notifications: Bool? = nil,
        restaurantId: String? = nil
    ) {
        self.displayName = displayName
        self.photoURL = photoURL
        self.phoneNumber = phoneNumber
        self.bio = bio
        self.restaurantId = restaurantId
        if preferredLanguage != nil || theme != nil || notifications != nil {
            let apiLangCode: String? = preferredLanguage.map { $0 == "zh-Hant" ? "TC" : "EN" }
            self.preferences = Preferences(language: apiLangCode, theme: theme, notifications: notifications)
        } else {
            self.preferences = nil
        }
    }
}
