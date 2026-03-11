//
//  AppDelegate.swift
//  Pour Rice
//
//  Application delegate for Firebase initialization and app lifecycle management
//  Configures Firebase services before the app launches
//

import UIKit
import FirebaseCore

/// Application delegate responsible for Firebase initialization
/// Configures all Firebase services (Auth, Firestore, Storage) at app launch
class AppDelegate: NSObject, UIApplicationDelegate {

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

        return true
    }

    // MARK: - Remote Notifications (Future Enhancement)

    /// Called when the app successfully registers for remote notifications
    /// Currently unused but available for future push notification implementation
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert device token to string for logging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 Device Token: \(token)")

        // TODO: Send device token to backend for push notifications (Phase 2)
    }

    /// Called when the app fails to register for remote notifications
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
