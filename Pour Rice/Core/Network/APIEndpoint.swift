//
//  APIEndpoint.swift
//  Pour Rice
//
//  Defines all API endpoints for the Pour Rice backend
//  Each case represents a specific API operation with required parameters
//

import Foundation

/// Enumeration of all available API endpoints
/// Provides type-safe endpoint definitions with associated parameters
enum APIEndpoint {

    // MARK: - Restaurant Endpoints

    /// Fetch restaurants near a geographical location
    /// - Parameters:
    ///   - lat: Latitude coordinate
    ///   - lng: Longitude coordinate
    ///   - radius: Search radius in metres (default: 5000)
    case fetchNearbyRestaurants(lat: Double, lng: Double, radius: Double)

    /// Fetch detailed information for a specific restaurant
    /// - Parameter id: Unique restaurant identifier
    case fetchRestaurant(id: String)

    /// Fetch featured restaurants for the home screen
    case fetchFeaturedRestaurants

    // MARK: - Menu Endpoints

    /// Fetch menu items for a specific restaurant
    /// - Parameters:
    ///   - restaurantId: Unique restaurant identifier
    ///   - limit: Maximum number of items to return (optional)
    case fetchMenuItems(restaurantId: String, limit: Int?)

    // MARK: - Review Endpoints

    /// Fetch reviews for a specific restaurant
    /// - Parameters:
    ///   - restaurantId: Unique restaurant identifier
    ///   - limit: Maximum number of reviews to return (optional)
    case fetchReviews(restaurantId: String, limit: Int?)

    /// Submit a new review for a restaurant
    /// - Parameter request: Review data including rating and comment
    case submitReview(ReviewRequest)

    // MARK: - User Endpoints

    /// Fetch user profile by user ID
    /// - Parameter userId: Unique user identifier
    case fetchUserProfile(userId: String)

    /// Create a new user profile
    /// - Parameter request: User profile data
    case createUserProfile(CreateUserRequest)

    /// Update existing user profile
    /// - Parameters:
    ///   - userId: Unique user identifier
    ///   - request: Updated profile data
    case updateUserProfile(userId: String, UpdateUserRequest)

    // MARK: - Endpoint Properties

    /// Returns the URL path component for each endpoint
    var path: String {
        switch self {
        case .fetchNearbyRestaurants:
            return Constants.API.Endpoints.nearbyRestaurants

        case .fetchRestaurant(let id):
            return "\(Constants.API.Endpoints.restaurantDetail)/\(id)"

        case .fetchFeaturedRestaurants:
            return "/API/Restaurants/featured"

        case .fetchMenuItems(let restaurantId, _):
            return "\(Constants.API.Endpoints.restaurantDetail)/\(restaurantId)\(Constants.API.Endpoints.restaurantMenu)"

        case .fetchReviews:
            return Constants.API.Endpoints.reviews

        case .submitReview:
            return Constants.API.Endpoints.reviews

        case .fetchUserProfile(let userId):
            return "\(Constants.API.Endpoints.userProfile)/\(userId)"

        case .createUserProfile:
            return Constants.API.Endpoints.userProfile

        case .updateUserProfile(let userId, _):
            return "\(Constants.API.Endpoints.userProfile)/\(userId)"
        }
    }

    /// Returns the HTTP method for each endpoint
    var method: HTTPMethod {
        switch self {
        case .submitReview,
             .createUserProfile:
            return .post

        case .updateUserProfile:
            return .put

        case .fetchNearbyRestaurants,
             .fetchRestaurant,
             .fetchFeaturedRestaurants,
             .fetchMenuItems,
             .fetchReviews,
             .fetchUserProfile:
            return .get
        }
    }

    /// Returns query parameters for GET requests
    var queryItems: [URLQueryItem]? {
        switch self {
        case .fetchNearbyRestaurants(let lat, let lng, let radius):
            return [
                URLQueryItem(name: "lat", value: String(lat)),
                URLQueryItem(name: "lng", value: String(lng)),
                URLQueryItem(name: "radius", value: String(radius))
            ]

        case .fetchMenuItems(_, let limit):
            guard let limit = limit else { return nil }
            return [URLQueryItem(name: "limit", value: String(limit))]

        case .fetchReviews(let restaurantId, let limit):
            var items = [URLQueryItem(name: "restaurantId", value: restaurantId)]
            if let limit = limit {
                items.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            return items

        default:
            return nil
        }
    }

    /// Returns the request body for POST/PUT requests
    var body: Encodable? {
        switch self {
        case .submitReview(let request):
            return request

        case .createUserProfile(let request):
            return request

        case .updateUserProfile(_, let request):
            return request

        default:
            return nil
        }
    }
}
