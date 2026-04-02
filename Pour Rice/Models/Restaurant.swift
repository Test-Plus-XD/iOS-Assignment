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

    /// Maps API response field names to Swift property names.
    enum CodingKeys: String, CodingKey {
        case id

        case nameEN      = "Name_EN"
        case nameTC      = "Name_TC"

        case descriptionEN = "Description_EN"
        case descriptionTC = "Description_TC"

        case addressEN   = "Address_EN"
        case addressTC   = "Address_TC"

        case districtEN  = "District_EN"
        case districtTC  = "District_TC"

        case cuisineEN   = "Cuisine_EN"
        case cuisineTC   = "Cuisine_TC"

        case keywordEN   = "Keyword_EN"
        case keywordTC   = "Keyword_TC"

        case imageUrl    = "ImageUrl"

        case latitude    = "Latitude"
        case longitude   = "Longitude"

        case seats       = "Seats"

        // Opening hours dict: { "Monday": "11:30-21:30", ... }
        case openingHoursDict = "Opening_Hours"

        // Contacts nested object: { "Phone": "...", "Email": "...", "Website": "..." }
        case contacts = "Contacts"

        // Price range, rating, review count
        case priceRange   = "PriceRange"
        case rating       = "Rating"
        case reviewCount  = "ReviewCount"
    }

    // MARK: - Private Contacts Decoder

    private struct APIContacts: Decodable {
        let phone: String?
        let email: String?
        let website: String?
        enum CodingKeys: String, CodingKey {
            case phone = "Phone"
            case email = "Email"
            case website = "Website"
        }
    }

    // MARK: - Time Range Parser

    /// Parses "HH:MM-HH:MM" or first range of "HH:MM-HH:MM, HH:MM-HH:MM"
    private static func parseFirstTimeRange(_ hoursStr: String) -> (open: String, close: String)? {
        let firstSegment = hoursStr.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !firstSegment.isEmpty else { return nil }
        // Find the dash that is the time-range separator (after exactly one colon)
        var colonCount = 0
        for (i, char) in firstSegment.enumerated() {
            if char == ":" { colonCount += 1 }
            if char == "-" && colonCount == 1 {
                let open  = String(firstSegment.prefix(i)).trimmingCharacters(in: .whitespaces)
                let close = String(firstSegment.suffix(firstSegment.count - i - 1))
                    .trimmingCharacters(in: .whitespaces)
                return (open, close)
            }
        }
        return nil
    }

    /// Custom decoder that maps the API's flat field structure to this model.
    ///
    /// The API returns bilingual data as separate _EN / _TC top-level keys rather
    /// than nested objects, and ImageUrl as a single String rather than an array.
    /// This initialiser assembles those flat pieces into BilingualText values and
    /// wraps the single URL into imageURLs so the rest of the app is unaffected.
    ///
    /// Fields not returned by the API are set to safe empty/zero defaults here.
    /// They will be populated if the API is extended in a future version.
    ///
    // ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
    // This is equivalent to a custom fromJson factory constructor.
    // Instead of: name = BilingualText.fromJson(json['name'])
    // We build:   name = BilingualText(en: json['Name_EN'], tc: json['Name_TC'])
    // ===========================================================
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        // ── Bilingual text fields ──────────────────────────────────────────
        let nameEN  = (try? container.decode(String.self, forKey: .nameEN))    ?? ""
        let nameTC  = (try? container.decode(String.self, forKey: .nameTC))    ?? nameEN
        name        = BilingualText(en: nameEN, tc: nameTC)

        let descEN  = (try? container.decode(String.self, forKey: .descriptionEN)) ?? ""
        let descTC  = (try? container.decode(String.self, forKey: .descriptionTC)) ?? descEN
        description = BilingualText(en: descEN, tc: descTC)

        let addrEN  = (try? container.decode(String.self, forKey: .addressEN)) ?? ""
        let addrTC  = (try? container.decode(String.self, forKey: .addressTC)) ?? addrEN
        address     = BilingualText(en: addrEN, tc: addrTC)

        let distEN  = (try? container.decode(String.self, forKey: .districtEN)) ?? ""
        let distTC  = (try? container.decode(String.self, forKey: .districtTC)) ?? distEN
        district    = BilingualText(en: distEN, tc: distTC)

        let cuisEN  = (try? container.decode(String.self, forKey: .cuisineEN)) ?? ""
        let cuisTC  = (try? container.decode(String.self, forKey: .cuisineTC)) ?? cuisEN
        cuisine     = BilingualText(en: cuisEN, tc: cuisTC)

        // ── Keywords ──────────────────────────────────────────────────────
        let kwEN = (try? container.decode([String].self, forKey: .keywordEN)) ?? []
        let kwTC = (try? container.decode([String].self, forKey: .keywordTC)) ?? []
        keywords = kwEN.enumerated().map { idx, en in
            BilingualText(en: en, tc: idx < kwTC.count ? kwTC[idx] : en)
        }

        // ── Image ─────────────────────────────────────────────────────────
        let imageUrlStr = try? container.decode(String.self, forKey: .imageUrl)
        imageURLs       = imageUrlStr.map { [$0] } ?? []

        // ── Location ──────────────────────────────────────────────────────
        let lat  = (try? container.decode(Double.self, forKey: .latitude))  ?? 0.0
        let lng  = (try? container.decode(Double.self, forKey: .longitude)) ?? 0.0
        location = Location(latitude: lat, longitude: lng)

        // ── Seats ─────────────────────────────────────────────────────────
        seats = (try? container.decode(Int.self, forKey: .seats)) ?? 0

        // ── Rating / ReviewCount / PriceRange ─────────────────────────────
        rating      = (try? container.decode(Double.self, forKey: .rating))     ?? 0.0
        reviewCount = (try? container.decode(Int.self,    forKey: .reviewCount)) ?? 0
        priceRange  = (try? container.decode(String.self, forKey: .priceRange)) ?? ""

        // ── Opening Hours: decode {"Monday": "11:30-21:30", ...} ──────────
        let hoursDict = (try? container.decode([String: String].self, forKey: .openingHoursDict)) ?? [:]
        openingHours = hoursDict.compactMap { day, hoursStr -> OpeningHour? in
            let trimmed = hoursStr.trimmingCharacters(in: .whitespaces).lowercased()
            if trimmed == "closed" || trimmed.isEmpty {
                return OpeningHour(day: day, open: "", close: "", isClosed: true)
            }
            if let (open, close) = Restaurant.parseFirstTimeRange(hoursStr) {
                return OpeningHour(day: day, open: open, close: close, isClosed: false)
            }
            // Fallback: store raw string as open, empty close
            return OpeningHour(day: day, open: hoursStr, close: "", isClosed: false)
        }.sorted { lhs, rhs in
            // Sort by standard weekday order (Monday first)
            let order = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
            let li = order.firstIndex(of: lhs.day) ?? 99
            let ri = order.firstIndex(of: rhs.day) ?? 99
            return li < ri
        }

        // ── Contacts ──────────────────────────────────────────────────────
        let apiContacts = try? container.decode(APIContacts.self, forKey: .contacts)
        phoneNumber = apiContacts?.phone ?? ""
        email       = apiContacts?.email
        website     = apiContacts?.website
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name.en, forKey: .nameEN)
        try container.encode(name.tc, forKey: .nameTC)
        try container.encodeIfPresent(description.en.isEmpty ? nil : description.en, forKey: .descriptionEN)
        try container.encodeIfPresent(description.tc.isEmpty ? nil : description.tc, forKey: .descriptionTC)
        try container.encode(address.en, forKey: .addressEN)
        try container.encode(address.tc, forKey: .addressTC)
        try container.encode(district.en, forKey: .districtEN)
        try container.encode(district.tc, forKey: .districtTC)
        try container.encodeIfPresent(cuisine.en.isEmpty ? nil : cuisine.en, forKey: .cuisineEN)
        try container.encodeIfPresent(cuisine.tc.isEmpty ? nil : cuisine.tc, forKey: .cuisineTC)
        let kwEN = keywords.map { $0.en }
        let kwTC = keywords.map { $0.tc }
        try container.encode(kwEN, forKey: .keywordEN)
        try container.encode(kwTC, forKey: .keywordTC)
        if let firstImage = imageURLs.first {
            try container.encode(firstImage, forKey: .imageUrl)
        }
        try container.encode(location.latitude, forKey: .latitude)
        try container.encode(location.longitude, forKey: .longitude)
        try container.encode(seats, forKey: .seats)
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
            return String(localized: "closed", bundle: L10n.bundle)
        }
        if close.isEmpty {
            return open  // raw hours string stored in open
        }
        return "\(open) – \(close)"
    }
}

// MARK: - Convenience Initialisation (Algolia Search Hits)

extension Restaurant {
    /// Creates a Restaurant from pre-parsed data.
    /// Used when mapping Algolia search hits to the model, where only a
    /// subset of fields is available from the search index.
    /// Fields not present in Algolia receive sensible empty defaults;
    /// the full data is loaded by the detail endpoint when the user taps a result.
    init(
        id: String,
        name: BilingualText,
        description: BilingualText,
        address: BilingualText,
        district: BilingualText,
        cuisine: BilingualText,
        keywords: [BilingualText],
        priceRange: String,
        rating: Double,
        reviewCount: Int,
        imageURLs: [String],
        location: Location,
        openingHours: [OpeningHour],
        phoneNumber: String,
        email: String?,
        website: String?,
        seats: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.address = address
        self.district = district
        self.cuisine = cuisine
        self.keywords = keywords
        self.priceRange = priceRange
        self.rating = rating
        self.reviewCount = reviewCount
        self.imageURLs = imageURLs
        self.location = location
        self.openingHours = openingHours
        self.phoneNumber = phoneNumber
        self.email = email
        self.website = website
        self.seats = seats
    }
}

// MARK: - Location Helpers

import CoreLocation

extension Restaurant {

    /// Calculates the straight-line distance in metres from the restaurant to a given location.
    /// Returns nil when the user's location is unavailable or the restaurant has no valid coordinates.
    func distance(from userLocation: CLLocation?) -> Double? {
        guard let userLocation,
              location.latitude != 0.0 || location.longitude != 0.0 else { return nil }
        let restaurantLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return userLocation.distance(from: restaurantLocation)
    }
}

