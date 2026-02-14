//
//  APIEndpoint.swift
//  Pour Rice
//
//  Defines all API endpoints for the Pour Rice backend.
//  Each case represents a specific API operation with required parameters.
//

import Foundation

/// Enumeration of all available API endpoints.
/// Provides type-safe endpoint definitions with associated parameters.
/// Each case automatically configures path, method, query items, and body.
enum APIEndpoint {

    // MARK: - Restaurant Endpoints

    /// Fetch restaurants near a geographical location.
    /// Uses geospatial search to find restaurants within the specified radius.
    /// - Parameters:
    ///   - lat: Latitude coordinate (e.g., 51.5074 for London)
    ///   - lng: Longitude coordinate (e.g., -0.1278 for London)
    ///   - radius: Search radius in metres (e.g., 5000 for 5km)
    case fetchNearbyRestaurants(lat: Double, lng: Double, radius: Double)

    /// Fetch detailed information for a specific restaurant.
    /// Returns full restaurant data including hours, contact info, and menu.
    /// - Parameter id: Unique restaurant identifier
    case fetchRestaurant(id: String)

    /// Fetch featured restaurants for the home screen.
    /// Returns curated list of highlighted or promoted restaurants.
    case fetchFeaturedRestaurants

    // MARK: - Menu Endpoints

    /// Fetch menu items for a specific restaurant.
    /// Returns all menu items with bilingual names and prices.
    /// - Parameters:
    ///   - restaurantId: Unique restaurant identifier
    ///   - limit: Maximum number of items to return (optional, for pagination)
    case fetchMenuItems(restaurantId: String, limit: Int?)

    // MARK: - Review Endpoints

    /// Fetch reviews for a specific restaurant.
    /// Returns user-submitted ratings and comments.
    /// - Parameters:
    ///   - restaurantId: Unique restaurant identifier
    ///   - limit: Maximum number of reviews to return (optional, for pagination)
    case fetchReviews(restaurantId: String, limit: Int?)

    /// Submit a new review for a restaurant.
    /// Requires authentication (Firebase ID token).
    /// - Parameter request: Review data including rating (1-5) and comment
    case submitReview(ReviewRequest)

    // MARK: - User Endpoints

    /// Fetch user profile by user ID.
    /// Returns user's display name, preferences, and review history.
    /// - Parameter userId: Unique user identifier (Firebase UID)
    case fetchUserProfile(userId: String)

    /// Create a new user profile.
    /// Called after successful Firebase authentication signup.
    /// - Parameter request: User profile data (display name, preferences, etc.)
    case createUserProfile(CreateUserRequest)

    /// Update existing user profile.
    /// Allows users to modify display name, dietary preferences, etc.
    /// - Parameters:
    ///   - userId: Unique user identifier (Firebase UID)
    ///   - request: Updated profile data
    case updateUserProfile(userId: String, UpdateUserRequest)

    // MARK: - Endpoint Properties

    /// Returns the URL path component for each endpoint.
    /// Combines base paths from Constants with dynamic parameters (e.g., IDs).
    var path: String {
        switch self {
        case .fetchNearbyRestaurants:
            // GET /API/Restaurants/nearby
            return Constants.API.Endpoints.nearbyRestaurants

        case .fetchRestaurant(let id):
            // GET /API/Restaurants/:id
            return "\(Constants.API.Endpoints.restaurantDetail)/\(id)"

        case .fetchFeaturedRestaurants:
            // GET /API/Restaurants/featured
            return "/API/Restaurants/featured"

        case .fetchMenuItems(let restaurantId, _):
            // GET /API/Restaurants/:id/menu
            return "\(Constants.API.Endpoints.restaurantDetail)/\(restaurantId)\(Constants.API.Endpoints.restaurantMenu)"

        case .fetchReviews:
            // GET /API/Reviews?restaurantId=:id
            return Constants.API.Endpoints.reviews

        case .submitReview:
            // POST /API/Reviews
            return Constants.API.Endpoints.reviews

        case .fetchUserProfile(let userId):
            // GET /API/Users/:userId
            return "\(Constants.API.Endpoints.userProfile)/\(userId)"

        case .createUserProfile:
            // POST /API/Users
            return Constants.API.Endpoints.userProfile

        case .updateUserProfile(let userId, _):
            // PUT /API/Users/:userId
            return "\(Constants.API.Endpoints.userProfile)/\(userId)"
        }
    }

    /// Returns the HTTP method for each endpoint.
    /// Follows REST conventions: GET for retrieval, POST for creation, PUT for updates.
    var method: HTTPMethod {
        switch self {
        case .submitReview,
             .createUserProfile:
            // POST for creating new resources
            return .post

        case .updateUserProfile:
            // PUT for full resource replacement
            return .put

        case .fetchNearbyRestaurants,
             .fetchRestaurant,
             .fetchFeaturedRestaurants,
             .fetchMenuItems,
             .fetchReviews,
             .fetchUserProfile:
            // GET for safe, read-only operations
            return .get
        }
    }

    /// Returns query parameters for GET requests.
    /// Converts endpoint parameters into URL query items (e.g., ?lat=51.5&lng=-0.1).
    var queryItems: [URLQueryItem]? {
        switch self {
        case .fetchNearbyRestaurants(let lat, let lng, let radius):
            // Example: ?lat=51.5074&lng=-0.1278&radius=5000
            return [
                URLQueryItem(name: "lat", value: String(lat)),
                URLQueryItem(name: "lng", value: String(lng)),
                URLQueryItem(name: "radius", value: String(radius))
            ]

        case .fetchMenuItems(_, let limit):
            // Optional limit parameter for pagination (e.g., ?limit=20)
            guard let limit = limit else { return nil }
            return [URLQueryItem(name: "limit", value: String(limit))]

        case .fetchReviews(let restaurantId, let limit):
            // Example: ?restaurantId=abc123&limit=10
            var items = [URLQueryItem(name: "restaurantId", value: restaurantId)]
            if let limit = limit {
                items.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            return items

        default:
            // GET requests without query parameters
            return nil
        }
    }

    /// Returns the request body for POST/PUT requests.
    /// Automatically encodes request objects to JSON in APIClient.
    var body: Encodable? {
        switch self {
        case .submitReview(let request):
            // Review data (rating, comment, restaurantId, etc.)
            return request

        case .createUserProfile(let request):
            // User profile data (displayName, preferences, etc.)
            return request

        case .updateUserProfile(_, let request):
            // Updated user profile data
            return request

        default:
            // GET requests don't have request bodies
            return nil
        }
    }
}
