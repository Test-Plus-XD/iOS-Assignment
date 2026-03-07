//
//  Date+Extensions.swift
//  Pour Rice
//
//  Utility extensions on Date and TimeInterval for human-readable formatting
//  Used throughout the app to display review dates, restaurant hours, etc.
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  Swift extensions add new methods to existing types without subclassing.
//  This is equivalent to Kotlin extension functions or Dart extension methods.
//
//  KOTLIN EQUIVALENT:
//  fun Date.timeAgoDisplay(): String { ... }
//  fun Date.shortDateDisplay(): String { ... }
//
//  DART EQUIVALENT:
//  extension DateExtension on DateTime {
//    String get timeAgoDisplay { ... }
//    String get shortDateDisplay { ... }
//  }
//  ============================================================================
//

import Foundation

// MARK: - Date Extensions

extension Date {

    // MARK: - Relative Time Display

    /// Returns a human-readable relative time string (e.g. "2 hours ago", "3 days ago")
    ///
    /// WHAT THIS DOES:
    /// Compares this date to now and returns a user-friendly string like:
    /// - "Just now" (less than 60 seconds ago)
    /// - "5 minutes ago"
    /// - "3 hours ago"
    /// - "2 days ago"
    /// - "1 week ago"
    /// - "Jan 15, 2024" (if more than 4 weeks ago)
    ///
    /// Used primarily to display review submission dates.
    ///
    /// FLUTTER EQUIVALENT:
    /// The 'timeago' package provides similar functionality.
    /// Here we build it ourselves for full control and no extra dependency.
    var timeAgoDisplay: String {
        // Calculate seconds elapsed since this date
        // Date().timeIntervalSince(self) = seconds from self to now
        let secondsAgo = Date().timeIntervalSince(self)

        // Return "Just now" for very recent events (under 1 minute)
        if secondsAgo < 60 {
            return String(localized: "time_just_now")
        }

        // Convert to minutes (1 minute = 60 seconds)
        let minutesAgo = Int(secondsAgo / 60)
        if minutesAgo < 60 {
            // Singular vs plural: "1 minute ago" vs "5 minutes ago"
            return minutesAgo == 1
                ? String(localized: "time_1_minute_ago")
                : String(localized: "time_minutes_ago \(minutesAgo)")
        }

        // Convert to hours (1 hour = 3600 seconds)
        let hoursAgo = Int(secondsAgo / 3600)
        if hoursAgo < 24 {
            return hoursAgo == 1
                ? String(localized: "time_1_hour_ago")
                : String(localized: "time_hours_ago \(hoursAgo)")
        }

        // Convert to days (1 day = 86400 seconds)
        let daysAgo = Int(secondsAgo / 86400)
        if daysAgo < 7 {
            return daysAgo == 1
                ? String(localized: "time_1_day_ago")
                : String(localized: "time_days_ago \(daysAgo)")
        }

        // Convert to weeks
        let weeksAgo = Int(secondsAgo / 604800)
        if weeksAgo < 4 {
            return weeksAgo == 1
                ? String(localized: "time_1_week_ago")
                : String(localized: "time_weeks_ago \(weeksAgo)")
        }

        // For older dates, display the actual date (e.g. "Jan 15, 2024")
        // DateFormatter converts Date objects to human-readable strings
        let formatter = DateFormatter()
        formatter.dateStyle = .medium   // e.g. "Jan 15, 2024"
        formatter.timeStyle = .none     // No time component (just the date)
        return formatter.string(from: self)
    }

    // MARK: - Short Date Display

    /// Returns a short date string (e.g. "Jan 2024" or "15 Jan")
    ///
    /// Used in review headers and compact date displays.
    ///
    /// EXAMPLE OUTPUT:
    /// - "15 Jan 2024" for dates this year
    /// - "Jan 2024" for older dates
    var shortDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"  // e.g. "15 Jan 2024"
        return formatter.string(from: self)
    }

    // MARK: - Month Year Display

    /// Returns month and year only (e.g. "January 2024")
    ///
    /// Used in review statistics and grouping by month.
    var monthYearDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"  // e.g. "January 2024"
        return formatter.string(from: self)
    }

    // MARK: - ISO 8601 Parsing

    /// Attempts to parse an ISO 8601 date string from the API
    ///
    /// WHY THIS IS NEEDED:
    /// The backend API returns dates as ISO 8601 strings like "2024-01-15T10:30:00.000Z"
    /// We need to convert these strings to Swift Date objects for display and comparison.
    ///
    /// WHAT IS ISO 8601:
    /// A standard date format used in APIs worldwide.
    /// Format: "YYYY-MM-DDTHH:MM:SS.sssZ"
    /// Example: "2024-01-15T10:30:00.000Z" = 15 January 2024 at 10:30 AM UTC
    ///
    /// FLUTTER EQUIVALENT:
    /// DateTime.parse("2024-01-15T10:30:00.000Z")
    ///
    /// - Parameter isoString: ISO 8601 date string from API
    /// - Returns: Optional Date (nil if parsing fails)
    static func fromISO8601(_ isoString: String) -> Date? {
        // ISO8601DateFormatter is Apple's built-in parser for ISO dates
        let formatter = ISO8601DateFormatter()

        // Try standard format first (with milliseconds)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) { return date }

        // Try without milliseconds (some APIs omit them)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString)
    }
}

// MARK: - String to Date Extension

extension String {

    /// Converts an ISO 8601 date string to a Date object
    ///
    /// Convenience method for converting API date strings directly.
    ///
    /// USAGE:
    /// ```swift
    /// let date = "2024-01-15T10:30:00.000Z".toDate()
    /// let display = date?.timeAgoDisplay  // "3 days ago"
    /// ```
    ///
    /// FLUTTER EQUIVALENT:
    /// extension String { DateTime? get toDate => DateTime.tryParse(this); }
    var toDate: Date? {
        return Date.fromISO8601(self)
    }
}
