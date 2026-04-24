//
//  NotificationCoordinatorService.swift
//  Pour Rice
//
//  Coordinates FCM token registration, foreground in-app banners, and push-driven navigation.
//  Socket.IO remains scoped to active chat rooms; this service owns app-wide notification behaviour.
//

import Foundation
import Observation
import UIKit
import UserNotifications
import FirebaseMessaging

// MARK: - In-App Notification Banner

/// Foreground notification banner shown by SwiftUI when the app receives a supported FCM payload.
struct InAppNotificationBanner: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let body: String
    let route: NotificationRoute?
    let notificationKey: String?
}

// MARK: - Notification Route Request

/// One-shot navigation request emitted when a user taps either an OS notification or an in-app banner.
struct NotificationRouteRequest: Identifiable, Equatable, Sendable {
    let id = UUID()
    let route: NotificationRoute
}

// MARK: - Notification Coordinator Service

/// Service responsible for the native iOS notification lifecycle.
///
/// Responsibilities:
/// - requests user notification permission after authentication
/// - registers and unregisters the current FCM token with the Vercel API
/// - displays foreground in-app banners for chat and booking notifications
/// - suppresses active-chat foreground banners to avoid duplicate chat UI
/// - emits typed navigation requests for notification taps
@MainActor
@Observable
final class NotificationCoordinatorService {

    // MARK: - Published State

    /// Banner currently shown at the top of the app while it is in the foreground.
    var banner: InAppNotificationBanner?

    /// Pending route request consumed by MainTabView.
    var routeRequest: NotificationRouteRequest?

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let authService: AuthService

    // MARK: - Token State

    private var currentFcmToken: String?
    private var registeredFcmToken: String?
    private var isRegisteringToken = false

    // MARK: - Foreground State

    private var activeChatRoomId: String?
    private var handledNotificationKeys: [String: Date] = [:]
    private let duplicateWindow: TimeInterval = 10 * 60

    // MARK: - Initialisation

    /// Creates a notification coordinator with the shared API and auth services.
    init(apiClient: APIClient, authService: AuthService) {
        self.apiClient = apiClient
        self.authService = authService
    }

    // MARK: - Auth-Driven Registration

    /// Synchronises notification permission and backend token registration for the current auth state.
    func synchroniseForCurrentUser(reason: String) async {
        guard authService.isAuthenticated,
              authService.currentUser != nil else { return }

        guard authService.currentUser?.notificationsEnabled ?? true else {
            await unregisterCurrentToken(reason: "\(reason)-notifications-disabled")
            return
        }

        let didReceivePermission = await requestNotificationPermission()
        guard didReceivePermission else {
            print("🔕 NotificationCoordinator: Notification permission not granted")
            return
        }

        UIApplication.shared.registerForRemoteNotifications()
        await refreshAndRegisterFcmToken(reason: reason)
    }

    /// Stores a token from Firebase Messaging and registers it when an authenticated user is available.
    func handleFcmTokenRefresh(_ token: String?, reason: String) async {
        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        currentFcmToken = token
        await registerCurrentTokenIfPossible(reason: reason)
    }

    /// Removes the current FCM token from the backend before Firebase Auth signs out.
    func unregisterCurrentToken(reason: String) async {
        guard let token = currentFcmToken ?? registeredFcmToken else { return }

        do {
            try await apiClient.requestVoid(
                .unregisterFcmToken(token: token),
                callerService: "NotificationCoordinator"
            )
            if registeredFcmToken == token {
                registeredFcmToken = nil
            }
            print("✅ NotificationCoordinator: Unregistered FCM token during \(reason)")
        } catch {
            print("⚠️ NotificationCoordinator: Failed to unregister FCM token during \(reason): \(error.localizedDescription)")
        }
    }

    // MARK: - Foreground Notifications

    /// Handles a foreground remote notification and returns the iOS presentation options.
    func handleForegroundNotification(userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        guard let route = NotificationRouteParser.parse(userInfo: userInfo) else {
            return [.banner, .list, .sound]
        }

        if shouldSuppressForegroundNotification(route: route) {
            return []
        }

        let notificationKey = notificationKey(from: userInfo)
        if let notificationKey, !markNotificationKeyAsHandled(notificationKey) {
            return []
        }

        showBanner(
            title: title(from: userInfo),
            body: body(from: userInfo),
            route: route,
            notificationKey: notificationKey
        )

        // The app renders its own foreground banner so iOS should not show a second visual banner.
        return [.sound]
    }

    /// Handles a user tap on an OS notification or a cold-start launch payload.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let route = NotificationRouteParser.parse(userInfo: userInfo) else { return }
        routeRequest = NotificationRouteRequest(route: route)
    }

    /// Opens the route associated with the currently visible in-app banner.
    func openBanner(_ banner: InAppNotificationBanner) {
        guard self.banner?.id == banner.id else { return }
        self.banner = nil
        if let route = banner.route {
            routeRequest = NotificationRouteRequest(route: route)
        }
    }

    /// Clears a route request once MainTabView has applied it.
    func clearRouteRequest(_ request: NotificationRouteRequest) {
        if routeRequest?.id == request.id {
            routeRequest = nil
        }
    }

    // MARK: - Active Chat Tracking

    /// Records the currently visible chat room so duplicate foreground banners can be suppressed.
    func setActiveChatRoom(_ roomId: String) {
        activeChatRoomId = roomId
    }

    /// Clears the active chat room when the chat view disappears.
    func clearActiveChatRoom(_ roomId: String) {
        if activeChatRoomId == roomId {
            activeChatRoomId = nil
        }
    }

    // MARK: - Private Token Helpers

    /// Requests notification permission with alert, badge, and sound options.
    private func requestNotificationPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()

        do {
            let settings = await centre.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true
            case .denied:
                return false
            case .notDetermined:
                return try await centre.requestAuthorization(options: [.alert, .badge, .sound])
            @unknown default:
                return false
            }
        } catch {
            print("⚠️ NotificationCoordinator: Permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Fetches the current Firebase Messaging token and forwards it to backend registration.
    private func refreshAndRegisterFcmToken(reason: String) async {
        do {
            let token = try await fetchFcmToken()
            currentFcmToken = token
            await registerCurrentTokenIfPossible(reason: reason)
        } catch {
            print("⚠️ NotificationCoordinator: Failed to fetch FCM token during \(reason): \(error.localizedDescription)")
        }
    }

    /// Wraps Firebase Messaging's callback-based token API in async/await.
    private func fetchFcmToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.resume(throwing: APIError.invalidResponse)
                    return
                }

                continuation.resume(returning: token)
            }
        }
    }

    /// Registers the current FCM token with the Vercel API when auth and preferences allow it.
    private func registerCurrentTokenIfPossible(reason: String) async {
        guard !isRegisteringToken,
              let token = currentFcmToken,
              authService.isAuthenticated,
              authService.currentUser != nil,
              authService.currentUser?.notificationsEnabled ?? true else { return }

        if registeredFcmToken == token {
            return
        }

        isRegisteringToken = true
        defer { isRegisteringToken = false }

        let request = RegisterFcmTokenRequest(
            token: token,
            platform: "ios-native",
            appId: Bundle.main.bundleIdentifier ?? Constants.App.bundleIdentifier
        )

        do {
            try await apiClient.requestVoid(
                .registerFcmToken(request),
                callerService: "NotificationCoordinator"
            )
            registeredFcmToken = token
            print("✅ NotificationCoordinator: Registered FCM token during \(reason)")
        } catch {
            print("⚠️ NotificationCoordinator: Failed to register FCM token during \(reason): \(error.localizedDescription)")
        }
    }

    // MARK: - Private Notification Helpers

    /// Suppresses chat banners when the matching chat room is already visible.
    private func shouldSuppressForegroundNotification(route: NotificationRoute) -> Bool {
        if case .chat(let roomId) = route {
            return activeChatRoomId == roomId
        }

        return false
    }

    /// Shows the app-rendered in-app notification banner and schedules auto-dismissal.
    private func showBanner(title: String, body: String, route: NotificationRoute?, notificationKey: String?) {
        let nextBanner = InAppNotificationBanner(
            title: title,
            body: body,
            route: route,
            notificationKey: notificationKey
        )
        banner = nextBanner

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if self.banner?.id == nextBanner.id {
                self.banner = nil
            }
        }
    }

    /// Returns false when a notification key has already been handled recently.
    private func markNotificationKeyAsHandled(_ key: String) -> Bool {
        pruneHandledNotificationKeys()

        if handledNotificationKeys[key] != nil {
            return false
        }

        handledNotificationKeys[key] = Date()
        return true
    }

    /// Removes old de-duplication keys so memory stays bounded.
    private func pruneHandledNotificationKeys() {
        let cutoff = Date().addingTimeInterval(-duplicateWindow)
        handledNotificationKeys = handledNotificationKeys.filter { $0.value >= cutoff }
    }

    /// Builds the most stable de-duplication key available in the payload.
    private func notificationKey(from userInfo: [AnyHashable: Any]) -> String? {
        if let notificationTag = NotificationRouteParser.stringValue(for: "notificationTag", in: userInfo) {
            return notificationTag
        }

        if let messageId = NotificationRouteParser.stringValue(for: "messageId", in: userInfo) {
            return "message:\(messageId)"
        }

        if let fcmMessageId = NotificationRouteParser.stringValue(for: "gcm.message_id", in: userInfo) {
            return "fcm:\(fcmMessageId)"
        }

        return nil
    }

    /// Reads a title from data payload first, then APNs alert fallback.
    private func title(from userInfo: [AnyHashable: Any]) -> String {
        if let title = NotificationRouteParser.stringValue(for: "title", in: userInfo) {
            return title
        }

        return apsAlertValue("title", from: userInfo) ?? "Pour Rice"
    }

    /// Reads a body from data payload first, then APNs alert fallback.
    private func body(from userInfo: [AnyHashable: Any]) -> String {
        if let body = NotificationRouteParser.stringValue(for: "body", in: userInfo) {
            return body
        }

        return apsAlertValue("body", from: userInfo) ?? ""
    }

    /// Extracts nested APNs alert values from `aps.alert`.
    private func apsAlertValue(_ key: String, from userInfo: [AnyHashable: Any]) -> String? {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let value = alert[key] as? String else { return nil }
        return value
    }
}