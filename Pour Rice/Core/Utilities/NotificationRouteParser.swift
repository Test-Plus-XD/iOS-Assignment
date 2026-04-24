//
//  NotificationRouteParser.swift
//  Pour Rice
//
//  Converts FCM notification payload routes into app navigation targets.
//  Supports the current route contract and legacy pourrice:// fallback URLs.
//

import Foundation

// MARK: - Notification Route

/// Navigation targets that can be opened from FCM/APNs notification payloads.
enum NotificationRoute: Equatable, Sendable {
    case bookings
    case chat(roomId: String)
}

// MARK: - Notification Route Parser

/// Parses route data from push payloads so notification handling stays independent from SwiftUI navigation.
enum NotificationRouteParser {

    /// Parses the backend's preferred `route` field first, then falls back to the legacy `url` field.
    /// - Parameter userInfo: Raw APNs/FCM payload dictionary delivered by iOS.
    /// - Returns: A strongly typed route when the payload contains a supported destination.
    static func parse(userInfo: [AnyHashable: Any]) -> NotificationRoute? {
        if let routeText = stringValue(for: "route", in: userInfo),
           let route = parseRoute(routeText) {
            return route
        }

        if let urlText = stringValue(for: "url", in: userInfo),
           let route = parseRoute(urlText) {
            return route
        }

        return nil
    }

    /// Parses a route string from either the modern path form or the legacy custom URL form.
    /// Supported examples: `/booking`, `/chat/room123`, `pourrice://bookings`, `pourrice://chat/room123`.
    static func parseRoute(_ value: String) -> NotificationRoute? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if text == "/booking" || text == "/bookings" {
            return .bookings
        }

        if text.hasPrefix("/chat/") {
            let roomId = String(text.dropFirst("/chat/".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return roomId.isEmpty ? nil : .chat(roomId: roomId)
        }

        guard let url = URL(string: text),
              url.scheme == Constants.DeepLink.scheme else { return nil }

        if url.host == "bookings" || url.host == "booking" {
            return .bookings
        }

        if url.host == "chat" {
            let roomId = url.pathComponents.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return roomId.isEmpty ? nil : .chat(roomId: roomId)
        }

        return nil
    }

    /// Extracts a string payload value while tolerating non-string FCM values passed through APNs.
    static func stringValue(for key: String, in userInfo: [AnyHashable: Any]) -> String? {
        if let value = userInfo[key] as? String {
            return value
        }

        if let value = userInfo[key] {
            return String(describing: value)
        }

        return nil
    }
}