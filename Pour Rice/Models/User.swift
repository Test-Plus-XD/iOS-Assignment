//
//  User.swift
//  Pour Rice
//
//  User profile model representing authenticated users
//  Stores user preferences and account information
//

import Foundation

/// Represents a user account with profile information and preferences
/// Synced with Firebase Authentication and Firestore
struct User: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique user identifier matching Firebase Auth UID
    let id: String

    /// User's email address
    let email: String

    /// Display name for the user
    var displayName: String

    /// User account type (customer or restaurant owner)
    let userType: UserType

    /// Profile photo URL (optional)
    var photoURL: String?

    /// User's preferred language code (en or zh-Hant)
    var preferredLanguage: String

    /// Date when the account was created
    let createdAt: Date

    /// Date of last profile update
    var updatedAt: Date

    // MARK: - User Type

    /// Enumeration of possible user account types
    enum UserType: String, Codable {
        /// Regular customer user
        case customer

        /// Restaurant owner with management access
        case owner
    }

    // MARK: - Custom Decoding

    enum CodingKeys: String, CodingKey {
        case id = "uid"
        case email
        case displayName
        case userType
        case photoURL
        case preferredLanguage
        case createdAt
        case updatedAt
    }

    // MARK: - Initialisation

    /// Creates a new user instance
    /// - Parameters:
    ///   - id: Unique user identifier
    ///   - email: User's email address
    ///   - displayName: Display name
    ///   - userType: Account type
    ///   - photoURL: Profile photo URL (optional)
    ///   - preferredLanguage: Preferred language code
    init(
        id: String,
        email: String,
        displayName: String,
        userType: UserType = .customer,
        photoURL: String? = nil,
        preferredLanguage: String = "en"
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.userType = userType
        self.photoURL = photoURL
        self.preferredLanguage = preferredLanguage
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - User Request/Response Models

/// Request model for creating a new user profile
struct CreateUserRequest: Codable {
    let uid: String
    let email: String
    let displayName: String
    let userType: String
    let preferredLanguage: String
}

/// Request model for updating user profile
struct UpdateUserRequest: Codable {
    let displayName: String?
    let photoURL: String?
    let preferredLanguage: String?
}
