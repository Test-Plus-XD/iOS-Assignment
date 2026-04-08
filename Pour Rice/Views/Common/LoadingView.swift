//
//  LoadingView.swift
//  Pour Rice
//
//  Reusable full-screen loading indicator following iOS design guidelines
//  Displays a spinner with optional descriptive message
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is equivalent to a CircularProgressIndicator wrapped in a Center widget.
//
//  FLUTTER EQUIVALENT:
//  Center(
//    child: Column(
//      mainAxisAlignment: MainAxisAlignment.center,
//      children: [
//        CircularProgressIndicator(),
//        if (message != null) Text(message!),
//      ],
//    ),
//  )
//  ============================================================================
//

import SwiftUI

// MARK: - Loading View

/// Full-screen loading indicator with optional message
///
/// Used across the app wherever data is being fetched.
/// Follows iOS native styling with ProgressView (spinner).
///
/// USAGE:
/// ```swift
/// if viewModel.isLoading {
///     LoadingView()
/// }
/// ```
///
/// Or with a message:
/// ```swift
/// LoadingView(message: "Finding nearby restaurants…")
/// ```
struct LoadingView: View {

    // MARK: - Properties

    /// Optional descriptive message shown below the spinner
    /// Helps users understand what is being loaded
    let message: String?

    // MARK: - Initialisation

    /// Creates a loading view with optional message
    /// - Parameter message: Text to display below the spinner (nil shows spinner only)
    init(message: String? = nil) {
        self.message = message
    }

    // MARK: - Body

    var body: some View {
        // VStack arranges spinner and text vertically with spacing
        // Like Column in Flutter or LinearLayout with VERTICAL orientation
        VStack(spacing: Constants.UI.spacingMedium) {

            // ProgressView() = native iOS spinner
            // Like CircularProgressIndicator in Flutter
            // No need to configure colour — automatically adapts to light/dark mode
            ProgressView()
                .scaleEffect(1.5)   // Scale up the spinner for better visibility

            // Only show message if one was provided
            // .map { } transforms optional into view if non-nil
            if let message = message {
                Text(LocalizedStringKey(message))
                    .font(.subheadline)         // Smaller than body text, suitable for status
                    .foregroundStyle(.secondary) // Secondary colour (grey)
                    .multilineTextAlignment(.center) // Centre multi-line text
            }
        }
        // Make the loading view fill the available space
        // Equivalent to Expanded() in Flutter
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Inline Loading View

/// Compact horizontal loading indicator for inline use
///
/// Used when loading data within a list row or compact area.
/// Shows a small spinner with a label beside it.
///
/// USAGE:
/// ```swift
/// InlineLoadingView(label: "Loading reviews…")
/// ```
struct InlineLoadingView: View {

    // MARK: - Properties

    /// Label to display beside the spinner
    let label: LocalizedStringKey

    // MARK: - Body

    var body: some View {
        // HStack arranges elements horizontally (like Row in Flutter)
        HStack(spacing: Constants.UI.spacingSmall) {
            ProgressView()
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        // Centre the inline loading indicator
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.UI.spacingSmall)
    }
}

// MARK: - Preview

#Preview("Default") {
    LoadingView()
}

#Preview("With Message") {
    LoadingView(message: "Finding restaurants near you…")
}

#Preview("Inline") {
    InlineLoadingView(label: "Loading reviews…")
}
