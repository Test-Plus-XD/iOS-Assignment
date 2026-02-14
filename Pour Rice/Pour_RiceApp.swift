//
//  Pour_RiceApp.swift
//  Pour Rice
//
//  Main application entry point for Pour Rice restaurant discovery app
//  Follows iOS 17+ architecture with @Observable macro and modern Swift concurrency
//  Configures Firebase and manages authentication state
//

import SwiftUI
import FirebaseCore

/// Main application entry point for Pour Rice restaurant discovery app
/// Manages app lifecycle, Firebase configuration, and authentication state
@main
struct Pour_RiceApp: App {

    // MARK: - App Delegate

    /// App delegate for Firebase initialization
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Services

    /// Centralized services container for dependency injection
    @State private var services = Services()

    // MARK: - Scene Configuration

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.services, services)
                .environment(\.authService, services.authService)
        }
    }
}

// MARK: - Root View

/// Root view that handles authentication state
/// Shows LoginView for unauthenticated users, MainTabView for authenticated users
struct RootView: View {

    // MARK: - Environment

    /// Auth service for checking authentication state
    @Environment(\.authService) private var authService

    // MARK: - Body

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // User is authenticated - show main app
                MainTabView()
                    .transition(.opacity)
            } else {
                // User is not authenticated - show login
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

// MARK: - Main Tab View (Placeholder)

/// Main tab-based navigation structure for the app
/// This is a placeholder - will be fully implemented in Sprint 5
struct MainTabView: View {

    // MARK: - Environment

    /// Access to app-wide services
    @Environment(\.services) private var services

    /// Auth service for sign out
    @Environment(\.authService) private var authService

    // MARK: - Body

    var body: some View {
        TabView {
            // Home tab placeholder
            NavigationStack {
                VStack(spacing: Constants.UI.spacingLarge) {
                    Image(systemName: "house.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.accent)

                    Text("home_title")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("coming_soon")
                        .foregroundStyle(.secondary)

                    // Temporary sign out button for testing
                    Button {
                        try? authService.signOut()
                    } label: {
                        Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, Constants.UI.spacingLarge)
                }
                .navigationTitle("home_title")
            }
            .tabItem {
                Label(String(localized: "home_title"), systemImage: "house.fill")
            }

            // Search tab placeholder
            NavigationStack {
                VStack(spacing: Constants.UI.spacingLarge) {
                    Image(systemName: "magnifyingglass")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.accent)

                    Text("search_title")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("coming_soon")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("search_title")
            }
            .tabItem {
                Label(String(localized: "search_title"), systemImage: "magnifyingglass")
            }

            // Account tab placeholder
            NavigationStack {
                VStack(spacing: Constants.UI.spacingLarge) {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.accent)

                    Text("account_title")
                        .font(.title)
                        .fontWeight(.bold)

                    if let user = authService.currentUser {
                        VStack(spacing: Constants.UI.spacingSmall) {
                            Text(user.displayName)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        try? authService.signOut()
                    } label: {
                        Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.bordered)
                }
                .navigationTitle("account_title")
            }
            .tabItem {
                Label(String(localized: "account_title"), systemImage: "person.fill")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environment(\.services, Services())
        .environment(\.authService, Services().authService)
}
