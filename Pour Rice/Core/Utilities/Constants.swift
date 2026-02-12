//
//  Constants.swift
//  Pour Rice
//
//  Core application constants for API configuration and application settings
//  Contains all external service URLs, API keys, and app-wide configuration values
//

import Foundation

/// Global constants used throughout the Pour Rice application
/// Centralises all configuration values for easy maintenance and updates
enum Constants {

    // MARK: - API Configuration

    /// Backend API configuration for restaurant data and user operations
    enum API {
        /// Base URL for the Vercel Express backend API
        /// All API endpoints are relative to this base URL
        static let baseURL = "https://vercel-express-api-alpha.vercel.app"

        /// Required API passcode header value for all API requests
        /// Must be included in the 'x-api-passcode' header
        static let passcode = "PourRice"

        /// API endpoint paths for different resources
        enum Endpoints {
            /// Endpoint for fetching nearby restaurants based on location
            /// Query parameters: lat, lng, radius (in metres)
            static let nearbyRestaurants = "/API/Restaurants/nearby"

            /// Endpoint for fetching individual restaurant details
            /// Format: /API/Restaurants/{restaurantId}
            static let restaurantDetail = "/API/Restaurants"

            /// Endpoint for fetching restaurant menu items
            /// Format: /API/Restaurants/{restaurantId}/menu
            static let restaurantMenu = "/menu"

            /// Endpoint for submitting and fetching reviews
            static let reviews = "/API/Reviews"

            /// Endpoint for user profile operations
            static let userProfile = "/API/Users"
        }

        /// HTTP header names used in API requests
        enum Headers {
            /// Header name for API passcode authentication
            static let apiPasscode = "x-api-passcode"

            /// Header name for Firebase ID token authentication
            static let authorization = "Authorization"

            /// Header name for content type
            static let contentType = "Content-Type"
        }
    }

    // MARK: - Algolia Configuration

    /// Algolia search service configuration
    enum Algolia {
        /// Algolia application ID for search service
        static let applicationID = "V9HMGL1VIZ"

        /// Algolia search-only API key (safe for client-side use)
        /// Note: This should be replaced with your actual search key
        static let searchAPIKey = "YOUR_ALGOLIA_SEARCH_KEY"

        /// Name of the Algolia index containing restaurant data
        static let indexName = "Restaurants"

        /// Default search radius in metres for location-based queries
        static let defaultSearchRadius = 5000
    }

    // MARK: - Firebase Configuration

    /// Firebase service configuration
    /// Note: GoogleService-Info.plist must be added to the project
    enum Firebase {
        /// Firestore collection names
        enum Collections {
            static let users = "users"
            static let restaurants = "restaurants"
            static let reviews = "reviews"
        }
    }

    // MARK: - Application Settings

    /// General application configuration
    enum App {
        /// Supported language codes
        static let supportedLanguages = ["en", "zh-Hant"]

        /// Default language code (British English)
        static let defaultLanguage = "en"

        /// App version number
        static let version = "1.0.0"

        /// Bundle identifier
        static let bundleIdentifier = "Pour-Rice.Pour-Rice"
    }

    // MARK: - Location Settings

    /// Location service configuration
    enum Location {
        /// Default search radius in metres for nearby restaurant queries
        static let defaultRadius: Double = 5000

        /// Maximum search radius in metres
        static let maxRadius: Double = 10000

        /// Minimum search radius in metres
        static let minRadius: Double = 500

        /// Location update accuracy threshold in metres
        static let desiredAccuracy: Double = 100
    }

    // MARK: - UI Configuration

    /// User interface constants and styling values
    enum UI {
        /// Standard spacing values following iOS design guidelines
        static let spacingSmall: CGFloat = 8
        static let spacingMedium: CGFloat = 16
        static let spacingLarge: CGFloat = 24
        static let spacingExtraLarge: CGFloat = 32

        /// Corner radius values for UI elements
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16

        /// Animation duration values
        static let animationDurationShort: Double = 0.2
        static let animationDurationMedium: Double = 0.3
        static let animationDurationLong: Double = 0.5

        /// Image aspect ratios
        static let restaurantImageAspectRatio: CGFloat = 16/9
        static let menuItemImageAspectRatio: CGFloat = 1
    }

    // MARK: - Cache Configuration

    /// Caching settings for images and data
    enum Cache {
        /// Maximum number of cached restaurant objects in memory
        static let restaurantCacheLimit = 50

        /// Cache expiration time in seconds (1 hour)
        static let cacheExpirationInterval: TimeInterval = 3600
    }

    // MARK: - Search Configuration

    /// Search and filtering configuration
    enum Search {
        /// Debounce delay in milliseconds for search queries
        static let debounceDelay: Int = 300

        /// Maximum number of search results to display
        static let maxResults = 50

        /// Minimum search query length to trigger search
        static let minQueryLength = 2
    }
}
