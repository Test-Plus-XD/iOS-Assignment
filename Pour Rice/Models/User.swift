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

    /// Profile photo URL (optional)
    ///
    /// WHAT IS String?:
    /// The question mark means this is an Optional type
    /// It can be either a String value OR nil (null in Dart/Kotlin)
    ///
    /// FLUTTER EQUIVALENT:
    /// String? photoURL;
    var photoURL: String?

    /// User's preferred language code (en or zh-Hant)
    /// Used to display restaurant content in the correct language
    var preferredLanguage: String

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
    /// enum UserType { customer, owner }
    enum UserType: String, Codable {
        /// Regular customer user
        /// When encoded to JSON, this becomes the string "customer"
        case customer

        /// Restaurant owner with management access
        /// When encoded to JSON, this becomes the string "owner"
        case owner
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
        case email                   // No mapping needed, same name in JSON and Swift
        case displayName             // No mapping needed
        case userType                // No mapping needed
        case photoURL                // No mapping needed
        case preferredLanguage       // No mapping needed
        case createdAt               // No mapping needed
        case updatedAt               // No mapping needed
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
    ///   - userType: Account type (defaults to .customer)
    ///   - photoURL: Profile photo URL (defaults to nil/null)
    ///   - preferredLanguage: Language code (defaults to "en" for British English)
    init(
        id: String,
        email: String,
        displayName: String,
        userType: UserType = .customer,        // Default value if not provided
        photoURL: String? = nil,                // Default to nil if not provided
        preferredLanguage: String = "en"        // Default to English
    ) {
        // Assign the provided values to the instance properties
        // 'self.' refers to the instance being created (like 'this.' in Dart/Kotlin)
        self.id = id
        self.email = email
        self.displayName = displayName
        self.userType = userType
        self.photoURL = photoURL
        self.preferredLanguage = preferredLanguage

        // Automatically set timestamps to current time
        // Date() creates a new Date object with the current date/time
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
    let userType: String               // Account type as string ("customer" or "owner")
    let preferredLanguage: String      // Language preference ("en" or "zh-Hant")
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
/// FLUTTER EQUIVALENT:
/// class UpdateUserRequest {
///   String? displayName;
///   String? photoURL;
///   String? preferredLanguage;
/// }
struct UpdateUserRequest: Codable {
    let displayName: String?          // New display name (nil = don't update)
    let photoURL: String?             // New photo URL (nil = don't update)
    let preferredLanguage: String?    // New language preference (nil = don't update)
}
