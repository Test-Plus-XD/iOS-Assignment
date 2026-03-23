//
//  EmptyStateView.swift
//  Pour Rice
//
//  Reusable empty state view following iOS design guidelines
//  Displayed when a list or data set has no content to show
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is equivalent to an empty state widget shown instead of a list.
//
//  FLUTTER EQUIVALENT:
//  Center(
//    child: Column(
//      children: [
//        Icon(icon, size: 60, color: Colors.grey),
//        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
//        Text(message),
//        if (actionTitle != null && onAction != null)
//          ElevatedButton(onPressed: onAction, child: Text(actionTitle!)),
//      ],
//    ),
//  )
//  ============================================================================
//

import SwiftUI

// MARK: - Empty State View

/// Reusable empty state view with icon, title, message, and optional action
///
/// Displayed when a data set is empty — e.g., no search results,
/// no reviews yet, or no restaurants nearby.
///
/// USAGE:
/// ```swift
/// if restaurants.isEmpty {
///     EmptyStateView(
///         icon: "magnifyingglass",
///         title: "No Restaurants Found",
///         message: "Try searching in a different area",
///         actionTitle: "Clear Filters",
///         onAction: { viewModel.clearFilters() }
///     )
/// }
/// ```
struct EmptyStateView: View {

    // MARK: - Properties

    /// SF Symbols icon name to display (ignored when assetImage is set)
    /// Browse available icons at https://developer.apple.com/sf-symbols/
    ///
    /// FLUTTER EQUIVALENT:
    /// final IconData icon;
    let icon: String

    /// Asset catalogue image name — when set, renders Image(assetImage) instead of Image(systemName: icon)
    /// Use this for branding images (e.g., "AppIcon") instead of SF Symbols
    let assetImage: String?

    /// Primary heading text
    let title: String

    /// Secondary descriptive text explaining the empty state
    let message: String

    /// Optional button title — set to nil to hide the action button
    let actionTitle: String?

    /// Optional action closure — called when the action button is tapped
    let onAction: (() -> Void)?

    // MARK: - Initialisation

    /// Creates an empty state view with customisable content
    /// - Parameters:
    ///   - icon: SF Symbols icon name (e.g., "magnifyingglass"); ignored when assetImage is provided
    ///   - assetImage: Asset catalogue image name (e.g., "AppIcon"); takes precedence over icon
    ///   - title: Primary heading text
    ///   - message: Descriptive message explaining the empty state
    ///   - actionTitle: Optional button label (nil hides the button)
    ///   - onAction: Optional action when button is tapped
    init(
        icon: String = "",
        assetImage: String? = nil,
        title: String,
        message: String,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.assetImage = assetImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: Constants.UI.spacingMedium) {

            // Icon — asset image takes precedence over SF Symbol
            if let assetImage {
                Image(assetImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.bottom, Constants.UI.spacingSmall)
            } else {
                // Large icon from SF Symbols
                // .secondary colour adapts to light/dark mode automatically
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Constants.UI.spacingSmall)
            }

            // Title in larger, bold text
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Descriptive message in secondary colour
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)  // Constrain width for better readability

            // Optional action button
            // Only rendered when both actionTitle and onAction are provided
            if let actionTitle = actionTitle, let onAction = onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .padding(.horizontal, Constants.UI.spacingLarge)
                        .padding(.vertical, Constants.UI.spacingSmall)
                }
                // .bordered = outlined button (less prominent than .borderedProminent)
                .buttonStyle(.bordered)
                .padding(.top, Constants.UI.spacingSmall)
            }
        }
        .padding(Constants.UI.spacingLarge)
        // Fill all available space to centre the empty state on screen
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preset Empty States

extension EmptyStateView {

    // MARK: - Preset Factory Methods
    //
    // These static methods create pre-configured empty state views
    // for common scenarios throughout the app.
    //
    // WHY STATIC METHODS:
    // Avoids duplicating strings and icon names across the codebase.
    // Makes it easy to use the right empty state for the right situation.
    //
    // FLUTTER EQUIVALENT:
    // static Widget noSearchResults(VoidCallback? onClear) => EmptyStateView(...)

    /// Empty state for search with no results
    /// - Parameter onClear: Action to clear search query and filters
    static func noSearchResults(onClear: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "empty_search_title",
            message: "empty_search_message",
            actionTitle: onClear != nil ? "empty_search_action" : nil,
            onAction: onClear
        )
    }

    /// Empty state for restaurant list with no results nearby
    static func noNearbyRestaurants() -> EmptyStateView {
        EmptyStateView(
            assetImage: "AppLogo",
            title: "empty_restaurants_title",
            message: "empty_restaurants_message"
        )
    }

    /// Empty state for reviews section (no reviews yet)
    static func noReviews() -> EmptyStateView {
        EmptyStateView(
            icon: "star",
            title: "empty_reviews_title",
            message: "empty_reviews_message"
        )
    }

    /// Empty state for menu with no items available
    static func noMenuItems() -> EmptyStateView {
        EmptyStateView(
            icon: "list.bullet.rectangle",
            title: "empty_menu_title",
            message: "empty_menu_message"
        )
    }
}

// MARK: - Preview

#Preview("No Search Results") {
    EmptyStateView.noSearchResults(onClear: { print("Clear tapped") })
}

#Preview("No Nearby Restaurants") {
    EmptyStateView.noNearbyRestaurants()
}

#Preview("No Reviews") {
    EmptyStateView.noReviews()
}

#Preview("Custom Empty State") {
    EmptyStateView(
        icon: "heart",
        title: "No Favourites Yet",
        message: "Restaurants you save will appear here",
        actionTitle: "Explore Restaurants",
        onAction: { print("Explore tapped") }
    )
}
