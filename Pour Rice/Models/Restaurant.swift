//
//  Restaurant.swift
//  Pour Rice
//
//  Core data model representing a restaurant with all its properties
//  Includes custom decoding to handle the backend API's specific field naming
//

import Foundation

/// Represents a restaurant with complete details including location, hours, and ratings
/// Conforms to Identifiable for use in SwiftUI lists and navigation
/// Includes custom decoding to map backend field names to Swift property names
struct Restaurant: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the restaurant
    let id: String

    /// Restaurant name in both British English and Traditional Chinese
    let name: BilingualText

    /// Detailed description of the restaurant
    let description: BilingualText

    /// Full address of the restaurant
    let address: BilingualText

    /// District or area where the restaurant is located
    let district: BilingualText

    /// Type of cuisine served (e.g., Italian, Chinese, Japanese)
    let cuisine: BilingualText

    /// Search keywords for the restaurant
    let keywords: [BilingualText]

    /// Price range indicator (e.g., "$", "$$", "$$$", "$$$$")
    let priceRange: String

    /// Average rating from 0.0 to 5.0
    let rating: Double

    /// Total number of reviews submitted
    let reviewCount: Int

    /// URLs of restaurant images for display in carousel
    let imageURLs: [String]

    /// Geographical location coordinates
    let location: Location

    /// Weekly opening hours schedule
    let openingHours: [OpeningHour]

    /// Contact phone number
    let phoneNumber: String

    /// Contact email address (optional)
    let email: String?

    /// Restaurant website URL (optional)
    let website: String?

    /// Total seating capacity
    let seats: Int

    // MARK: - Computed Properties

    /// Returns the price range as a readable string with dollar signs
    var priceRangeDisplay: String {
        return priceRange
    }

    /// Returns the rating formatted to one decimal place
    var ratingDisplay: String {
        return String(format: "%.1f", rating)
    }

    /// Determines if the restaurant is currently open based on current time
    /// - Returns: true if currently open, false if closed
    var isOpenNow: Bool {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        // Convert weekday (1 = Sunday, 2 = Monday, etc.) to day name
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let todayName = dayNames[weekday - 1]

        // Find today's opening hours
        guard let todayHours = openingHours.first(where: { $0.day == todayName }) else {
            return false
        }

        // Check if closed for the day
        if todayHours.isClosed {
            return false
        }

        // Parse current time and opening hours
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        guard let openTime = timeFormatter.date(from: todayHours.open),
              let closeTime = timeFormatter.date(from: todayHours.close) else {
            return false
        }

        let currentTime = timeFormatter.date(from: timeFormatter.string(from: now))!

        return currentTime >= openTime && currentTime < closeTime
    }

    // MARK: - Custom Decoding

    /// Maps API response field names to Swift property names
    /// Backend uses capitalised field names with _EN/_TC suffixes for bilingual content
    enum CodingKeys: String, CodingKey {
        case id = "restaurantId"
        case name
        case description
        case address
        case district
        case cuisine
        case keywords
        case priceRange
        case rating
        case reviewCount
        case imageURLs = "imageUrls"
        case location
        case openingHours
        case phoneNumber
        case email
        case website
        case seats
    }

    /// Custom decoder to handle complex bilingual field structure from API
    /// Combines _EN and _TC fields into BilingualText objects
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode simple fields
        id = try container.decode(String.self, forKey: .id)
        priceRange = try container.decode(String.self, forKey: .priceRange)
        rating = try container.decode(Double.self, forKey: .rating)
        reviewCount = try container.decode(Int.self, forKey: .reviewCount)
        imageURLs = try container.decode([String].self, forKey: .imageURLs)
        location = try container.decode(Location.self, forKey: .location)
        openingHours = try container.decode([OpeningHour].self, forKey: .openingHours)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        email = try? container.decode(String.self, forKey: .email)
        website = try? container.decode(String.self, forKey: .website)
        seats = try container.decode(Int.self, forKey: .seats)

        // Decode bilingual fields
        name = try container.decode(BilingualText.self, forKey: .name)
        description = try container.decode(BilingualText.self, forKey: .description)
        address = try container.decode(BilingualText.self, forKey: .address)
        district = try container.decode(BilingualText.self, forKey: .district)
        cuisine = try container.decode(BilingualText.self, forKey: .cuisine)
        keywords = try container.decode([BilingualText].self, forKey: .keywords)
    }
}

// MARK: - Location

/// Represents geographical coordinates for a restaurant
/// Used for map display and distance calculations
struct Location: Codable, Hashable, Sendable {

    /// Latitude coordinate (-90 to 90)
    let latitude: Double

    /// Longitude coordinate (-180 to 180)
    let longitude: Double

    // MARK: - Custom Decoding

    /// Maps capitalised API field names to Swift property names
    enum CodingKeys: String, CodingKey {
        case latitude = "Latitude"
        case longitude = "Longitude"
    }
}

// MARK: - Opening Hour

/// Represents opening hours for a specific day of the week
/// Includes support for closed days and custom hours
struct OpeningHour: Codable, Hashable, Sendable {

    /// Day of the week (Monday, Tuesday, etc.)
    let day: String

    /// Opening time in 24-hour format (e.g., "09:00")
    let open: String

    /// Closing time in 24-hour format (e.g., "22:00")
    let close: String

    /// Indicates if the restaurant is closed on this day
    let isClosed: Bool

    // MARK: - Computed Properties

    /// Returns formatted opening hours for display
    /// - Returns: "Closed" if isClosed is true, otherwise "HH:mm - HH:mm"
    var displayText: String {
        if isClosed {
            return String(localized: "closed")
        }
        return "\(open) - \(close)"
    }
}

// MARK: - API Response Wrappers

/// Wrapper for API responses that return an array of restaurants
/// Used for nearby restaurants and search results endpoints
struct RestaurantListResponse: Codable {
    let restaurants: [Restaurant]
}
