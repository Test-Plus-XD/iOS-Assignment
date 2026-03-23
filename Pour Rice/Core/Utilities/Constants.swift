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

            /// Vercel-proxied Algolia restaurant search endpoint
            /// Query parameters: query, districts, keywords, page, hitsPerPage
            /// Replaces direct Algolia SDK calls — credentials remain server-side
            static let algoliaSearch = "/API/Algolia/Restaurants"

            // MARK: Booking Endpoints

            /// Endpoint for diner booking operations
            static let bookings = "/API/Bookings"

            /// Endpoint for restaurant-side booking list (append /:restaurantId)
            static let restaurantBookings = "/API/Bookings/restaurant"

            // MARK: Restaurant Management Endpoints

            /// Suffix appended to restaurantDetail + /:id for claiming ownership
            static let claimRestaurant = "/claim"

            /// Suffix appended to restaurantDetail + /:id for image upload
            static let restaurantImage = "/image"

            // MARK: Menu CRUD Endpoints

            /// Endpoint for menu item CRUD operations
            static let menuItems = "/API/Menu/Items"

            // MARK: Chat Endpoints

            /// Endpoint for fetching a user's chat records (append /:uid)
            static let chatRecords = "/API/Chat/Records"

            /// Endpoint for chat room operations (append /:roomId)
            static let chatRooms = "/API/Chat/Rooms"

            /// Suffix appended to chatRooms + /:roomId for messages
            static let chatMessages = "/Messages"

            // MARK: Gemini AI Endpoints

            /// Endpoint for multi-turn Gemini chat
            static let geminiChat = "/API/Gemini/chat"

            /// Endpoint for one-shot Gemini text generation
            static let geminiGenerate = "/API/Gemini/generate"

            /// Endpoint for AI-generated restaurant descriptions
            static let geminiRestaurantDescription = "/API/Gemini/restaurant-description"
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

    // MARK: - Algolia Configuration (Commented Out — No Longer Used)
    //
    // Search is now routed through the Vercel proxy endpoint (/API/Algolia/Restaurants)
    // so direct Algolia SDK calls and client-side credentials are no longer required.
    //
    // enum Algolia {
    //     /// Name of the Algolia Restaurants index
    //     static let indexName = "Restaurants"
    //
    //     /// Default search radius in metres (used in advanced geo-search requests)
    //     static let defaultSearchRadius = 2500
    // }

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
        static let defaultRadius: Double = 2500

        /// Maximum search radius in metres
        static let maxRadius: Double = 10000

        /// Minimum search radius in metres
        static let minRadius: Double = 500

        /// Location update accuracy threshold in metres
        static let desiredAccuracy: Double = 100

        /// Maximum number of nearby restaurants shown on the home screen
        static let nearbyLimit = 10
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

    // MARK: - Chat Configuration

    /// Real-time chat and Socket.IO settings
    enum Chat {
        /// Socket.IO server URL (Railway backend)
        static let socketURL = "https://railway-socket-production.up.railway.app"

        /// Number of messages to fetch per page
        static let messagePageSize = 50

        /// Debounce interval for typing indicators (nanoseconds)
        static let typingDebounceNs: UInt64 = 500_000_000
    }

    // MARK: - Deep Link Configuration

    /// Deep link URL scheme used for QR code navigation between the iOS app and Android app.
    ///
    /// Both iOS and Android apps share the same URL format so QR codes generated
    /// on one platform are scannable on the other.
    ///
    /// Full URL format: pourrice://menu/{restaurantId}
    ///
    /// ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
    /// Android uses the same scheme string in the QR URL but does NOT register
    /// OS-level intent filters (no <intent-filter> in AndroidManifest.xml).
    /// iOS MUST register the scheme in Info.plist CFBundleURLTypes for the OS
    /// to route external URLs (e.g. from Safari or another app) to Pour Rice.
    /// Without the Info.plist entry, only in-app scanning works — the device
    /// would not know to open Pour Rice when another app fires pourrice://.
    /// =============================================================
    enum DeepLink {
        /// Custom URL scheme registered in Info.plist CFBundleURLTypes.
        /// Must match the scheme component of every QR-encoded URL.
        static let scheme = "pourrice"

        /// URL host component that identifies a menu deep link.
        /// The path segment after the host carries the restaurantId:
        ///   pourrice://menu/{restaurantId}
        static let menuHost = "menu"
    }

    // MARK: - Search Configuration

    /// Search and filtering configuration
    enum Search {
        /// Debounce delay in milliseconds for search queries
        static let debounceDelay: Int = 300

        /// Maximum number of search results to display (legacy — replaced by pageSize for paginated search)
        static let maxResults = 50

        /// Number of results fetched per page in paginated search
        static let pageSize = 8

        /// Minimum search query length to trigger search
        static let minQueryLength = 2
    }
}
