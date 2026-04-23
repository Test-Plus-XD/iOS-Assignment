//
//  ErrorView.swift
//  Pour Rice
//
//  Reusable error state view following iOS design guidelines
//  Displays an error icon, message, and optional retry action
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is equivalent to an error state widget with a retry button.
//
//  FLUTTER EQUIVALENT:
//  Center(
//    child: Column(
//      children: [
//        Icon(Icons.error_outline, size: 60, color: Colors.red),
//        Text(title),
//        Text(message),
//        if (onRetry != null)
//          ElevatedButton(onPressed: onRetry, child: Text('Try Again')),
//      ],
//    ),
//  )
//  ============================================================================
//

import SwiftUI

// MARK: - Error View

/// Full-screen error state view with optional retry action
///
/// Displayed when an API request fails or an error occurs.
/// Provides clear user feedback and a retry mechanism.
///
/// USAGE:
/// ```swift
/// if let errorMessage = viewModel.errorMessage {
///     ErrorView(
///         message: errorMessage,
///         onRetry: { await viewModel.loadData() }
///     )
/// }
/// ```
struct ErrorView: View {

    // MARK: - Properties

    /// Title for the error state (defaults to "Something Went Wrong")
    let title: LocalizedStringKey

    /// Descriptive error message shown below the title
    let message: LocalizedStringKey

    /// Optional closure called when the user taps "Try Again"
    /// Set to nil to hide the retry button (for non-recoverable errors)
    ///
    /// WHAT IS (() -> Void)?:
    /// An optional closure (function) with no parameters and no return value
    /// If non-nil, the "Try Again" button appears
    ///
    /// FLUTTER EQUIVALENT:
    /// final VoidCallback? onRetry;
    let onRetry: (() -> Void)?

    // MARK: - Initialisation

    /// Creates an error view with customisable content
    /// - Parameters:
    ///   - title: Error title (defaults to generic error message)
    ///   - message: Detailed error description
    ///   - onRetry: Optional retry action (nil hides the retry button)
    init(
        title: String = "error_title",
        message: String,
        onRetry: (() -> Void)? = nil
    ) {
        // Wrap incoming `String` values in `LocalizedStringKey` so the stored
        // properties retain their type. Call sites pass two kinds of strings:
        //   1) localisation keys like "error_title" / "network_error_message"
        //      — these are looked up in Localizable.xcstrings at render time.
        //   2) pre-resolved runtime messages like `vm.errorMessage`
        //      — these will fail the lookup and render verbatim, which is the
        //      desired behaviour since they've already been localised upstream.
        self.title = LocalizedStringKey(title)
        self.message = LocalizedStringKey(message)
        self.onRetry = onRetry
    }

    // MARK: - Body

    var body: some View {
        // VStack arranges content vertically with consistent spacing
        VStack(spacing: Constants.UI.spacingMedium) {

            // Error icon using SF Symbols
            // "exclamationmark.triangle.fill" = triangle with exclamation mark
            // This is the standard iOS error/warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))    // Large icon for visual impact
                .foregroundStyle(.orange)   // Orange = warning (red = danger)
                .padding(.bottom, Constants.UI.spacingSmall)

            // Error title
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Detailed error message
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                // Limit width for better readability on wider screens
                .frame(maxWidth: 300)

            // Retry button — only shown if onRetry closure is provided
            // This is conditional rendering (like if/else in Flutter)
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Label(
                        "error_retry",
                        systemImage: "arrow.clockwise"
                    )
                    .padding(.horizontal, Constants.UI.spacingLarge)
                    .padding(.vertical, Constants.UI.spacingSmall)
                }
                // .borderedProminent = filled background button (iOS native style)
                // Equivalent to ElevatedButton in Flutter
                .buttonStyle(.borderedProminent)
                .padding(.top, Constants.UI.spacingSmall)
            }
        }
        .padding(Constants.UI.spacingLarge)
        // Fill available space to centre content on screen
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Network Error View

/// Specialised error view for network connectivity problems
///
/// Shows a specific message when there is no internet connection.
/// Used when API requests fail due to network issues.
struct NetworkErrorView: View {

    // MARK: - Properties

    /// Closure called when the user taps "Try Again"
    let onRetry: (() -> Void)?

    // MARK: - Body

    var body: some View {
        ErrorView(
            title: "network_error_title",
            message: "network_error_message",
            onRetry: onRetry
        )
    }
}

// MARK: - Preview

#Preview("Generic Error") {
    ErrorView(
        message: "Unable to load restaurants. Please check your connection.",
        onRetry: { print("Retry tapped") }
    )
}

#Preview("No Retry") {
    ErrorView(
        title: "Permission Required",
        message: "Please enable location access to find nearby restaurants.",
        onRetry: nil
    )
}

#Preview("Network Error") {
    NetworkErrorView(onRetry: { print("Retry tapped") })
}
