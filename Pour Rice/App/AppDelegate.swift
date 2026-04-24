//
//  AppDelegate.swift
//  Pour Rice
//
//  Application delegate for Firebase initialization and app lifecycle management
//  Configures Firebase services before the app launches
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseInAppMessaging
import GoogleSignIn
import UserNotifications

/// Application delegate responsible for Firebase initialization
/// Configures all Firebase services (Auth, Firestore, Storage) at app launch
final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Notification Coordinator

    /// Notification coordinator is injected from Pour_RiceApp after Services is created.
    private weak var notificationCoordinator: NotificationCoordinatorService?

    /// Remote notification payload captured during cold start before Services is injected.
    private var pendingLaunchUserInfo: [AnyHashable: Any]?

    /// Connects UIKit/Firebase delegate callbacks to the SwiftUI notification coordinator.
    func configure(notificationCoordinator: NotificationCoordinatorService) {
        self.notificationCoordinator = notificationCoordinator

        if let pendingLaunchUserInfo {
            self.pendingLaunchUserInfo = nil
            Task { @MainActor in
                notificationCoordinator.handleNotificationTap(userInfo: pendingLaunchUserInfo)
            }
        }
    }

    // MARK: - Application Lifecycle

    /// Called when the application finishes launching
    /// Initialises Firebase with configuration from GoogleService-Info.plist
    /// - Parameters:
    ///   - application: The singleton app object
    ///   - launchOptions: Launch options dictionary
    /// - Returns: true if initialisation succeeds
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Guard: Firebase is already configured in Pour_RiceApp.init().
        // This delegate may still be registered for push-notification callbacks,
        // so we skip double-configure to avoid a runtime exception.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("✅ Firebase configured in AppDelegate")
        } else {
            print("ℹ️ Firebase was already configured")
        }

        // Firebase swizzling is disabled in Info.plist, so delegates are set explicitly here.
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Touch Firebase In-App Messaging so campaign delivery is initialised with Firebase Analytics.
        _ = InAppMessaging.inAppMessaging()

        if let launchUserInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            if let notificationCoordinator {
                Task { @MainActor in
                    notificationCoordinator.handleNotificationTap(userInfo: launchUserInfo)
                }
            } else {
                pendingLaunchUserInfo = launchUserInfo
            }
        }

        return true
    }


    // MARK: - URL Handling

    /// Handles URL callbacks for OAuth flows (Google Sign-In).
    /// Called when the app receives a URL that matches a registered URL scheme.
    /// The SwiftUI scene-level `.onOpenURL` in Pour_RiceApp also handles this;
    /// GIDSignIn safely ignores duplicate calls for the same URL.
    ///
    /// NOTE: Deprecated in iOS 26 in favour of scene-based URL handling.
    /// Kept as a fallback for the Google Sign-In SDK's UIKit callback path.
    @available(iOS, deprecated: 26.0, message: "Scene-based .onOpenURL in Pour_RiceApp is the primary handler")
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Remote Notifications

    /// Called when APNs issues a device token after remote notification registration.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Firebase swizzling is disabled, so APNs token forwarding must be manual.
        Messaging.messaging().apnsToken = deviceToken

        // Convert APNs token to a readable suffix for diagnostics without logging the full token in production.
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 Device Token: \(token)")
    }

    /// Called when the app fails to register for remote notifications
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    /// Receives silent/background notification payloads when APNs wakes the app.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Firebase swizzling is disabled, so notification receipt is forwarded manually for Analytics.
        Messaging.messaging().appDidReceiveMessage(userInfo)

        // Chat and booking visual routing is handled from notification taps, not background fetch callbacks.
        completionHandler(.noData)
    }
}

// MARK: - Firebase Messaging Delegate

extension AppDelegate: MessagingDelegate {
    /// Called when Firebase creates or refreshes the FCM registration token.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            await self.notificationCoordinator?.handleFcmTokenRefresh(fcmToken, reason: "messaging-delegate")
        }
    }
}

// MARK: - User Notification Centre Delegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Handles remote notifications delivered while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Firebase swizzling is disabled, so notification receipt is forwarded manually for Analytics.
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)

        Task { @MainActor in
            let options = self.notificationCoordinator?.handleForegroundNotification(
                userInfo: notification.request.content.userInfo
            ) ?? [.banner, .list, .sound]
            completionHandler(options)
        }
    }

    /// Handles user taps on APNs notifications from background or terminated app states.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Firebase swizzling is disabled, so notification opens are forwarded manually for Analytics.
        Messaging.messaging().appDidReceiveMessage(response.notification.request.content.userInfo)

        Task { @MainActor in
            self.notificationCoordinator?.handleNotificationTap(
                userInfo: response.notification.request.content.userInfo
            )
            completionHandler()
        }
    }
}