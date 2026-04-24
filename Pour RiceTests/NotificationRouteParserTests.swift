//
//  NotificationRouteParserTests.swift
//  Pour RiceTests
//
//  Covers the FCM route contract used by chat and booking push notifications.
//

import Testing
@testable import Pour_Rice

struct NotificationRouteParserTests {

    /// Parses the current booking route from the primary `route` payload key.
    @Test func parsesBookingRoute() {
        #expect(NotificationRouteParser.parse(userInfo: ["route": "/booking"]) == .bookings)
    }

    /// Parses the current chat route from the primary `route` payload key.
    @Test func parsesChatRoute() {
        #expect(NotificationRouteParser.parse(userInfo: ["route": "/chat/restaurant-123"]) == .chat(roomId: "restaurant-123"))
    }

    /// Falls back to the legacy custom URL for booking notifications during rollout.
    @Test func parsesLegacyBookingUrl() {
        #expect(NotificationRouteParser.parse(userInfo: ["url": "pourrice://bookings"]) == .bookings)
    }

    /// Falls back to the legacy custom URL for chat notifications during rollout.
    @Test func parsesLegacyChatUrl() {
        #expect(NotificationRouteParser.parse(userInfo: ["url": "pourrice://chat/restaurant-123"]) == .chat(roomId: "restaurant-123"))
    }

    /// Ignores unsupported routes so malformed payloads do not trigger navigation.
    @Test func ignoresInvalidRoutes() {
        #expect(NotificationRouteParser.parse(userInfo: ["route": "/restaurant/abc"]) == nil)
        #expect(NotificationRouteParser.parse(userInfo: ["route": "/chat/"]) == nil)
    }
}