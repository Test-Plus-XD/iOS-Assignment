//
//  Pour_RiceTests.swift
//  Pour RiceTests
//
//  Created by Test-Plus on 10/2/2026.
//

import Foundation
import Testing
@testable import Pour_Rice

struct Pour_RiceTests {

    @Test func decodesPendingUserTypeFromEmptyBackendValue() throws {
        let user = try decodeUser(type: "")

        #expect(user.userType == .diner)
        #expect(user.hasSelectedUserType == false)
    }

    @Test func decodesPendingUserTypeWhenBackendValueIsMissing() throws {
        let user = try decodeUser(type: nil)

        #expect(user.userType == .diner)
        #expect(user.hasSelectedUserType == false)
    }

    @Test func decodesSelectedUserType() throws {
        let user = try decodeUser(type: "Restaurant")

        #expect(user.userType == .restaurant)
        #expect(user.hasSelectedUserType)
    }

    @Test func decodesProfileWithMissingPreferencesUsingLocalDefaults() throws {
        let user = try decodeUser(type: "Diner", includePreferences: false)

        #expect(user.preferredLanguage == "en")
        #expect(user.preferredTheme == "system")
        #expect(user.notificationsEnabled)
    }

    @Test func createUserRequestUsesNestedPreferencesPayload() throws {
        let request = CreateUserRequest(
            uid: "user-123",
            email: "owner@example.com",
            displayName: "Test User",
            userType: "Diner",
            languageCode: "zh-Hant"
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let preferences = try #require(object["preferences"] as? [String: Any])

        #expect(object["preferredLanguage"] == nil)
        #expect(preferences["language"] as? String == "TC")
        #expect(preferences["theme"] as? String == "system")
        #expect(preferences["notifications"] as? Bool == true)
    }

    private func decodeUser(type: String?, includePreferences: Bool = true) throws -> User {
        var fields = [
            #""uid": "user-123""#,
            #""email": "owner@example.com""#,
            #""displayName": "Test User""#
        ]

        if includePreferences {
            fields.append(#""preferences": {"language": "EN", "theme": "system", "notifications": true}"#)
        }

        if let type {
            fields.append(#""type": "\#(type)""#)
        }

        let json = "{\(fields.joined(separator: ","))}"
        return try JSONDecoder().decode(User.self, from: Data(json.utf8))
    }
}
