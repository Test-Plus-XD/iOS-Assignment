//
//  Pour_RiceAppLiquidGlass.swift
//  Pour Rice
//
//  Liquid Glass variant of the main app structure
//  Demonstrates Liquid Glass material adoption for iOS 26+
//  Applies frosted glass effect to navigation layers and controls
//
//  LIQUID GLASS OVERVIEW:
//  Liquid Glass is a dynamic, translucent material that combines optical properties
//  of glass (reflection, refraction) with fluid behavior. It creates visual hierarchy
//  and depth while maintaining interface familiarity.
//
//  KEY PRINCIPLES:
//  - Use for navigation layer (TabView, toolbars, sheets, popovers)
//  - Do NOT use for content layer (background, scrollable areas)
//  - Automatically adapts to light/dark mode, content, and focus state
//  - Two variants: Regular (default, adaptive) and Clear (transparent, needs dimming)
//

import SwiftUI
import FirebaseCore

/// Main Tab View with Liquid Glass effect
/// Applies frosted glass material to the tab bar for enhanced visual hierarchy
/// The glass effect adapts dynamically to the content beneath it
///
/// LIQUID GLASS ADOPTION:
/// The .glassEffect() modifier applies the Regular variant (most versatile)
/// in a Capsule shape, which is ideal for navigation bars
struct MainTabViewLiquidGlass: View {

    // MARK: - Environment

    /// Access to app-wide services (injected from Pour_RiceApp)
    @Environment(\.services) private var services

    /// Auth service for sign out functionality
    @Environment(\.authService) private var authService

    // MARK: - Body

    var body: some View {
        TabView {

            // ================================================================
            // HOME TAB - First tab showing home screen
            // ================================================================

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

                    Button {
                        try? authService.signOut()
                    } label: {
                        Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, Constants.UI.spacingLarge)
                    // Apply Liquid Glass to button
                    .glassEffect(in: Capsule())
                }
                .navigationTitle("home_title")
            }
            .tabItem {
                Label(String(localized: "home_title"), systemImage: "house.fill")
            }

            // ================================================================
            // SEARCH TAB - Second tab (placeholder)
            // ================================================================

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

            // ================================================================
            // ACCOUNT TAB - Third tab showing user profile
            // ================================================================

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
                        // Apply Liquid Glass to user info container
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        try? authService.signOut()
                    } label: {
                        Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.bordered)
                    // Apply Liquid Glass to button
                    .glassEffect(in: Capsule())
                }
                .navigationTitle("account_title")
            }
            .tabItem {
                Label(String(localized: "account_title"), systemImage: "person.fill")
            }
        }
        // Apply Liquid Glass to the TabView itself
        // Regular variant adapts automatically to content beneath
        .glassEffect()
    }
}

// MARK: - Preview

#Preview {
    MainTabViewLiquidGlass()
        .environment(\.services, Services())
        .environment(\.authService, Services().authService)
}
