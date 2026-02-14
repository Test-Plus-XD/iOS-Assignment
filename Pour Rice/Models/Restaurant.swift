//
//  Restaurant.swift
//  Pour Rice
//
//  Core data model representing a restaurant with all its properties
//  Includes custom decoding to handle the backend API's specific field naming
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is like a complex data class with nested objects and computed properties.
//  Similar to having a Restaurant model with custom JSON parsing in Flutter.
//  Contains business logic (like isOpenNow) directly in the model.
//  ============================================================================
//

import Foundation  // For Date, Calendar, and other foundation types

/// Represents a restaurant with complete details including location, hours, and ratings
/// Conforms to Identifiable for use in SwiftUI lists and navigation
/// Includes custom decoding to map backend field names to Swift property names
///
/// KEY FEATURES:
/// - Bilingual support (English & Traditional Chinese)
/// - Real-time open/closed status calculation
/// - Custom JSON decoding for backend API compatibility
/// - Ready for SwiftUI List display (Identifiable)
///
/// FLUTTER EQUIVALENT:
/// class Restaurant {
///   final String id;
///   final BilingualText name;
///   // ... etc
/// }
struct Restaurant: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the restaurant
    /// Used as the primary key for fetching details, reviews, menu items
    let id: String

    /// Restaurant name in both British English and Traditional Chinese
    /// Automatically displays in the correct language based on user's locale
    /// See BilingualText.swift for how automatic language selection works
    let name: BilingualText

    /// Detailed description of the restaurant
    /// Contains information about the restaurant's specialty, ambiance, etc.
    let description: BilingualText

    /// Full address of the restaurant
    /// Bilingual format for proper display in both languages
    let address: BilingualText

    /// District or area where the restaurant is located
    /// Used for filtering and categorizing restaurants by region
    let district: BilingualText

    /// Type of cuisine served (e.g., Italian, Chinese, Japanese)
    /// Bilingual to support both language displays
    let cuisine: BilingualText

    /// Search keywords for the restaurant
    ///
    /// WHAT IS [BilingualText]:
    /// Array of BilingualText objects (like List<BilingualText> in Dart)
    /// Used for search functionality and categorization
    ///
    /// EXAMPLE:
    /// ["dim sum", "seafood", "casual dining"]
    let keywords: [BilingualText]

    /// Price range indicator (e.g., "$", "$$", "$$$", "$$$$")
    /// String representation where more $ symbols = more expensive
    let priceRange: String

    /// Average rating from 0.0 to 5.0
    ///
    /// WHAT IS Double:
    /// 64-bit floating point number (like 'double' in Dart/Kotlin)
    /// Used for precise decimal values like ratings
    let rating: Double

    /// Total number of reviews submitted
    /// Used to display review count and calculate rating reliability
    let reviewCount: Int

    /// URLs of restaurant images for display in carousel
    ///
    /// ARRAY OF STRINGS:
    /// [String] = Array of image URLs
    /// Each string is a full URL to an image hosted online
    ///
    /// FLUTTER EQUIVALENT:
    /// List<String> imageURLs
    let imageURLs: [String]

    /// Geographical location coordinates
    /// Contains latitude and longitude for map display and distance calculations
    /// See Location struct below for details
    let location: Location

    /// Weekly opening hours schedule
    ///
    /// ARRAY OF CUSTOM TYPE:
    /// [OpeningHour] = Array of OpeningHour structs
    /// One entry per day of the week
    /// Used to determine if restaurant is currently open
    let openingHours: [OpeningHour]

    /// Contact phone number
    /// String format to preserve international formatting
    let phoneNumber: String

    /// Contact email address (optional)
    ///
    /// OPTIONAL:
    /// String? means this can be nil if restaurant doesn't provide email
    let email: String?

    /// Restaurant website URL (optional)
    /// nil if the restaurant doesn't have a website
    let website: String?

    /// Total seating capacity
    /// Number of available seats for reservation purposes
    let seats: Int

    // MARK: - Computed Properties
    //
    // WHAT ARE COMPUTED PROPERTIES:
    // Like getters in Dart/Kotlin that calculate a value on-the-fly
    // Don't store data, just return calculated results
    //
    // FLUTTER EQUIVALENT:
    // String get priceRangeDisplay => priceRange;
    //
    // They're defined with 'var' but have no '=' sign, just a code block {}

    /// Returns the price range as a readable string with dollar signs
    // Currently just returns the raw priceRange value
    // Could be enhanced to format it differently in the future
    var priceRangeDisplay: String {
        return priceRange  // Returns "$", "$$", etc. as-is
    }

    /// Returns the rating formatted to one decimal place
    //
    // WHAT IS String(format:):
    // Similar to printf or String.format in other languages
    // "%.1f" means: format as floating point with 1 decimal place
    //
    // EXAMPLE:
    // If rating = 4.567, this returns "4.6"
    var ratingDisplay: String {
        return String(format: "%.1f", rating)  // Format to 1 decimal place
    }

    /// Determines if the restaurant is currently open based on current time
    // This is BUSINESS LOGIC inside the model
    // Calculates in real-time whether the restaurant is open right now
    //
    // ALGORITHM:
    // 1. Get current day of week
    // 2. Find today's opening hours
    // 3. Check if restaurant is marked as closed today
    // 4. Compare current time with opening/closing times
    //
    // - Returns: true if currently open, false if closed
    var isOpenNow: Bool {
        // Get current date and time
        let now = Date()  // Creates a Date object representing "now"

        // Get calendar for date calculations
        // Calendar.current = user's calendar (handles time zones, etc.)
        let calendar = Calendar.current

        // Extract day of week from current date
        // .weekday returns: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let weekday = calendar.component(.weekday, from: now)

        // Convert weekday number (1-7) to day name string
        // Array is 0-indexed, so weekday-1 gives correct index
        // weekday=1 (Sunday) → dayNames[0] = "Sunday"
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let todayName = dayNames[weekday - 1]  // Get today's name

        // Find today's opening hours from the openingHours array
        //
        // WHAT IS guard let:
        // Similar to 'if let' but exits early if the condition fails
        // Like: if (value == null) return false; but more elegant
        //
        // WHAT IS .first(where:):
        // Searches the array and returns the first matching element
        // Like .firstWhere() in Dart or .find() in Kotlin
        // { $0.day == todayName } is a closure (like a lambda)
        guard let todayHours = openingHours.first(where: { $0.day == todayName }) else {
            return false  // No hours found for today = closed
        }

        // Check if restaurant is marked as closed for this day
        if todayHours.isClosed {
            return false  // Explicitly closed today
        }

        // Parse times from strings to Date objects for comparison
        // DateFormatter converts string times like "09:00" to Date objects
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"  // 24-hour format with minutes

        // Try to parse opening and closing times
        // guard ensures both succeed or we return false
        guard let openTime = timeFormatter.date(from: todayHours.open),
              let closeTime = timeFormatter.date(from: todayHours.close) else {
            return false  // Invalid time format = assume closed
        }

        // Parse current time to match format of open/close times
        // We format 'now' to a string and back to a Date to remove date portion
        // This allows us to compare just the time components
        let currentTime = timeFormatter.date(from: timeFormatter.string(from: now))!

        // Compare current time with opening hours
        // >= openTime: Current time is at or after opening
        // < closeTime: Current time is before closing
        // Both must be true to be open
        return currentTime >= openTime && currentTime < closeTime
    }

    // MARK: - Custom Decoding
    //
    // WHY CUSTOM DECODING:
    // The backend API returns "restaurantId" but we want to use "id" in Swift
    // Also handles converting bilingual fields into BilingualText objects
    //
    // FLUTTER EQUIVALENT:
    // @JsonKey(name: 'restaurantId') String id;

    /// Maps API response field names to Swift property names
    // This enum tells Codable how to map JSON keys to struct properties
    //
    // FORMAT:
    // case swiftName = "jsonName"  → JSON has different name
    // case propertyName            → JSON has same name as Swift property
    enum CodingKeys: String, CodingKey {
        case id = "restaurantId"       // JSON: "restaurantId" → Swift: "id"
        case name                      // Same in JSON and Swift
        case description               // Same in JSON and Swift
        case address                   // Same in JSON and Swift
        case district                  // Same in JSON and Swift
        case cuisine                   // Same in JSON and Swift
        case keywords                  // Same in JSON and Swift
        case priceRange                // Same in JSON and Swift
        case rating                    // Same in JSON and Swift
        case reviewCount               // Same in JSON and Swift
        case imageURLs = "imageUrls"   // JSON: "imageUrls" → Swift: "imageURLs"
        case location                  // Same in JSON and Swift
        case openingHours              // Same in JSON and Swift
        case phoneNumber               // Same in JSON and Swift
        case email                     // Same in JSON and Swift
        case website                   // Same in JSON and Swift
        case seats                     // Same in JSON and Swift
    }

    /// Custom decoder to handle complex bilingual field structure from API
    // Manually decodes JSON into struct properties
    // Necessary because we have custom logic for handling BilingualText
    //
    // WHAT IS init(from decoder:):
    // This is a special initializer required by Codable protocol
    // Called automatically when decoding JSON
    //
    // WHAT IS 'throws':
    // Can throw errors if decoding fails (like missing required field)
    // Similar to 'throws' in Kotlin or try-catch in Dart
    //
    // Combines _EN and _TC fields into BilingualText objects
    init(from decoder: Decoder) throws {
        // Get the container holding all the JSON key-value pairs
        // 'try' means this can fail and throw an error
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode simple fields
        // Each 'try container.decode' reads a value from the JSON
        //
        // SYNTAX:
        // try container.decode(Type.self, forKey: .key)
        // - Type.self: The Swift type to decode to
        // - forKey: Which JSON field to read from
        id = try container.decode(String.self, forKey: .id)
        priceRange = try container.decode(String.self, forKey: .priceRange)
        rating = try container.decode(Double.self, forKey: .rating)
        reviewCount = try container.decode(Int.self, forKey: .reviewCount)
        imageURLs = try container.decode([String].self, forKey: .imageURLs)
        location = try container.decode(Location.self, forKey: .location)
        openingHours = try container.decode([OpeningHour].self, forKey: .openingHours)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)

        // Decode optional fields using 'try?'
        //
        // WHAT IS try?:
        // 'try?' returns nil if decoding fails instead of throwing an error
        // Perfect for optional fields that might not exist in the JSON
        //
        // FLUTTER EQUIVALENT:
        // email = json['email'];  // Handles missing fields gracefully
        email = try? container.decode(String.self, forKey: .email)
        website = try? container.decode(String.self, forKey: .website)
        seats = try container.decode(Int.self, forKey: .seats)

        // Decode bilingual fields
        // These are automatically handled by BilingualText's custom decoder
        // BilingualText knows how to parse { "EN": "...", "TC": "..." } format
        name = try container.decode(BilingualText.self, forKey: .name)
        description = try container.decode(BilingualText.self, forKey: .description)
        address = try container.decode(BilingualText.self, forKey: .address)
        district = try container.decode(BilingualText.self, forKey: .district)
        cuisine = try container.decode(BilingualText.self, forKey: .cuisine)
        keywords = try container.decode([BilingualText].self, forKey: .keywords)
    }
}

// MARK: - Location
//
// NESTED STRUCT:
// This struct is defined inside the same file but independent of Restaurant
// Used as a property type in Restaurant model
//
// FLUTTER EQUIVALENT:
// class Location {
//   final double latitude;
//   final double longitude;
// }

/// Represents geographical coordinates for a restaurant
// Used for map display and distance calculations
// Simple structure containing just latitude and longitude
//
// USAGE EXAMPLE:
// let location = Location(latitude: 22.3193, longitude: 114.1694)  // Hong Kong
struct Location: Codable, Hashable, Sendable {

    /// Latitude coordinate (-90 to 90)
    // Positive values = North of equator
    // Negative values = South of equator
    // Used with MapKit for displaying restaurant on map
    let latitude: Double

    /// Longitude coordinate (-180 to 180)
    // Positive values = East of Prime Meridian
    // Negative values = West of Prime Meridian
    // Used with MapKit for displaying restaurant on map
    let longitude: Double

    // MARK: - Custom Decoding

    /// Maps capitalised API field names to Swift property names
    //
    // WHY NEEDED:
    // Backend API returns "Latitude" and "Longitude" with capital letters
    // We prefer lowercase "latitude" and "longitude" in Swift (convention)
    enum CodingKeys: String, CodingKey {
        case latitude = "Latitude"    // JSON: "Latitude" → Swift: "latitude"
        case longitude = "Longitude"  // JSON: "Longitude" → Swift: "longitude"
    }
}

// MARK: - Opening Hour
//
// REPRESENTS ONE DAY'S HOURS:
// Each restaurant has an array of 7 OpeningHour objects (one per day)
//
// FLUTTER EQUIVALENT:
// class OpeningHour {
//   final String day;
//   final String open;
//   final String close;
//   final bool isClosed;
// }

/// Represents opening hours for a specific day of the week
// Contains opening time, closing time, and whether the restaurant is closed
// Used to determine if restaurant is currently open (see isOpenNow above)
//
// EXAMPLE JSON:
// {
//   "day": "Monday",
//   "open": "09:00",
//   "close": "22:00",
//   "isClosed": false
// }
struct OpeningHour: Codable, Hashable, Sendable {

    /// Day of the week (Monday, Tuesday, etc.)
    // Full English day name as a string
    // Used to match against current day to determine if open
    let day: String

    /// Opening time in 24-hour format (e.g., "09:00")
    // String format for easy display and parsing
    // 24-hour format avoids AM/PM confusion
    let open: String

    /// Closing time in 24-hour format (e.g., "22:00")
    // Can be after midnight (e.g., "01:00" for late-night restaurants)
    let close: String

    /// Indicates if the restaurant is closed on this day
    // true = closed all day (ignore open/close times)
    // false = follow open/close times
    let isClosed: Bool

    // MARK: - Computed Properties

    /// Returns formatted opening hours for display in UI
    //
    // LOGIC:
    // If closed → show "Closed" (localized)
    // If open → show "09:00 - 22:00" format
    //
    // FLUTTER EQUIVALENT:
    // String get displayText {
    //   if (isClosed) return 'Closed';
    //   return '$open - $close';
    // }
    //
    // - Returns: "Closed" if isClosed is true, otherwise "HH:mm - HH:mm"
    var displayText: String {
        if isClosed {
            // String(localized:) automatically selects English or Chinese
            // based on user's device language setting
            return String(localized: "closed")
        }
        // String interpolation: \(variable) inserts the variable's value
        // Similar to "$open - $close" in Dart or "${open} - ${close}" in Kotlin
        return "\(open) - \(close)"
    }
}

// MARK: - API Response Wrappers
//
// WHY A WRAPPER:
// The API doesn't return a plain array of restaurants
// It returns a JSON object with a "restaurants" field containing the array
//
// EXAMPLE API RESPONSE:
// {
//   "restaurants": [
//     { "restaurantId": "1", "name": { "EN": "...", "TC": "..." }, ... },
//     { "restaurantId": "2", "name": { "EN": "...", "TC": "..." }, ... }
//   ]
// }
//
// Without this wrapper, we'd have to manually extract the array from the response

/// Wrapper for API responses that return an array of restaurants
// Used for nearby restaurants and search results endpoints
// Codable automatically handles decoding the JSON structure
//
// USAGE:
// let response = try await apiClient.request(..., responseType: RestaurantListResponse.self)
// let restaurants = response.restaurants  // Extract the array
//
// FLUTTER EQUIVALENT:
// class RestaurantListResponse {
//   final List<Restaurant> restaurants;
//   RestaurantListResponse.fromJson(Map<String, dynamic> json)
//     : restaurants = (json['restaurants'] as List).map((e) => Restaurant.fromJson(e)).toList();
// }
struct RestaurantListResponse: Codable {
    let restaurants: [Restaurant]  // Array of Restaurant objects from the API
}
