//
//  AsyncImageView.swift
//  Pour Rice
//
//  Kingfisher-based image loading view with placeholder, error states, and caching
//  Provides consistent image loading behaviour across the app
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is equivalent to CachedNetworkImage in Flutter, or Coil/Glide in Android.
//  Kingfisher handles downloading, caching, and displaying remote images.
//
//  FLUTTER EQUIVALENT:
//  CachedNetworkImage(
//    imageUrl: url,
//    placeholder: (ctx, url) => CircularProgressIndicator(),
//    errorWidget: (ctx, url, err) => Icon(Icons.broken_image),
//    fit: BoxFit.cover,
//  )
//
//  ANDROID EQUIVALENT (Coil):
//  AsyncImage(
//    model = url,
//    contentDescription = null,
//    contentScale = ContentScale.Crop,
//    placeholder = painterResource(R.drawable.placeholder),
//  )
//  ============================================================================
//

import SwiftUI
import Kingfisher  // Third-party library for image loading and caching

// MARK: - Async Image View

/// Asynchronous image view with placeholder, loading, and error states
///
/// Uses Kingfisher for efficient image downloading and caching.
/// Provides consistent styling and error handling across the app.
///
/// KINGFISHER BENEFITS:
/// - Automatic disk and memory caching (images saved to avoid re-downloading)
/// - Progressive loading (shows placeholder while loading)
/// - Smooth fade-in transitions when image loads
/// - Automatic retry on failure
/// - Memory-efficient downsampling for large images
///
/// USAGE:
/// ```swift
/// // Basic usage
/// AsyncImageView(url: restaurant.imageURLs.first)
///
/// // With specific size and content mode
/// AsyncImageView(
///     url: restaurant.imageURLs.first,
///     contentMode: .fill,
///     cornerRadius: 12,
///     aspectRatio: 16/9
/// )
/// ```
struct AsyncImageView: View {

    // MARK: - Properties

    /// URL string for the remote image
    /// Optional — nil triggers the placeholder state immediately
    let urlString: String?

    /// How the image should be fitted within its frame
    /// .fill = image fills the entire frame (may be cropped)
    /// .fit = entire image visible (may have empty space)
    ///
    /// FLUTTER EQUIVALENT:
    /// BoxFit.cover → .fill
    /// BoxFit.contain → .fit
    let contentMode: SwiftUI.ContentMode

    /// Corner radius for rounded corners (0 = square corners)
    let cornerRadius: CGFloat

    /// Optional fixed aspect ratio (nil = no aspect ratio constraint)
    /// e.g. 16/9 for landscape images, 1/1 for square thumbnails
    let aspectRatio: CGFloat?

    // MARK: - Initialisation

    /// Creates an async image view with customisable layout
    /// - Parameters:
    ///   - urlString: Remote image URL string
    ///   - contentMode: Image content mode (.fill or .fit)
    ///   - cornerRadius: Corner radius in points (0 = no rounding)
    ///   - aspectRatio: Fixed aspect ratio (nil = determined by parent frame)
    init(
        url urlString: String?,
        contentMode: SwiftUI.ContentMode = .fill,
        cornerRadius: CGFloat = 0,
        aspectRatio: CGFloat? = nil
    ) {
        self.urlString = urlString
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.aspectRatio = aspectRatio
    }

    // MARK: - Body

    var body: some View {
        // Determine if we have a valid URL to load
        // URL(string:) returns nil if the string is not a valid URL
        let url: URL? = urlString.flatMap { URL(string: $0) }

        // KFImage is Kingfisher's SwiftUI image view
        // Equivalent to CachedNetworkImage in Flutter
        KFImage(url)
            // Configures how the image is processed before display
            .resizable()  // Allows the image to be resized to fit its frame
            // Transition animation when the image finishes loading
            // .fade creates a smooth fade-in effect (0.3 seconds)
            .fade(duration: Constants.UI.animationDurationMedium)
            // SwiftUI failure placeholder shown when image loading fails
            .onFailureView {
                Image("Placeholder")
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            // Content mode determines how the image fills its frame
            // Like BoxFit in Flutter
            .aspectRatio(contentMode: contentMode)
            // Apply fixed aspect ratio if specified
            .if(aspectRatio != nil) { view in
                view.aspectRatio(aspectRatio!, contentMode: contentMode)
            }
            // Clip to rounded rectangle shape
            // cornerRadius = 0 means no rounding (square corners)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            // Overlay a placeholder while loading
            // This is shown before the image downloads
            .overlay {
                if url == nil {
                    // No URL provided — show photo placeholder immediately
                    placeholderView
                }
            }
    }

    // MARK: - Placeholder View

    /// Placeholder shown when no URL is provided for a restaurant image
    private var placeholderView: some View {
        Image("Placeholder")
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Restaurant Hero Image

/// Large hero image for restaurant detail screens
///
/// Pre-configured for the restaurant header with correct aspect ratio and styling.
/// Includes a gradient overlay for text readability.
struct RestaurantHeroImage: View {

    // MARK: - Properties

    /// URL string for the hero image
    let urlString: String?

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Restaurant image
            AsyncImageView(
                url: urlString,
                contentMode: .fill,
                aspectRatio: Constants.UI.restaurantImageAspectRatio
            )
            .frame(maxWidth: .infinity)

            // Gradient overlay at the bottom for text readability
            // This ensures text placed over the image is always readable
            // Similar to a gradient shader in Flutter/Android
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Restaurant Card Image

/// Compact image for restaurant cards in list/grid views
///
/// Pre-configured with correct aspect ratio and rounded corners for card layout.
struct RestaurantCardImage: View {

    // MARK: - Properties

    /// URL string for the card image
    let urlString: String?

    // MARK: - Body

    var body: some View {
        AsyncImageView(
            url: urlString,
            contentMode: .fill,
            cornerRadius: Constants.UI.cornerRadiusMedium,
            aspectRatio: Constants.UI.restaurantImageAspectRatio
        )
    }
}

// MARK: - Menu Item Image

/// Square image for menu item cards
///
/// Pre-configured as a square with rounded corners for menu item thumbnails.
struct MenuItemImage: View {

    // MARK: - Properties

    /// URL string for the menu item image
    let urlString: String?

    // MARK: - Body

    var body: some View {
        AsyncImageView(
            url: urlString,
            contentMode: .fill,
            cornerRadius: Constants.UI.cornerRadiusSmall,
            aspectRatio: Constants.UI.menuItemImageAspectRatio
        )
        .frame(width: 80, height: 80)
    }
}

// MARK: - Preview

#Preview("Restaurant Card Image") {
    RestaurantCardImage(urlString: nil)
        .frame(maxWidth: .infinity)
        .padding()
}

#Preview("Menu Item Image") {
    MenuItemImage(urlString: nil)
        .padding()
}

