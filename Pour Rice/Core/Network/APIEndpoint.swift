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
    case fetchNearbyRestaurants(lat: Double, lng: Double, radius: Double)

    /// Fetch detailed information for a specific restaurant.
    case fetchRestaurant(id: String)

    /// Claim ownership of a restaurant (POST /API/Restaurants/:id/claim).
    case claimRestaurant(id: String)

    /// Update restaurant details (PUT /API/Restaurants/:id).
    case updateRestaurant(id: String, UpdateRestaurantRequest)

    // MARK: - Menu Endpoints

    /// Fetch menu items for a specific restaurant.
    case fetchMenuItems(restaurantId: String)

    /// Create a new menu item (POST /API/Menu/Items).
    case createMenuItem(CreateMenuItemRequest)

    /// Update an existing menu item (PUT /API/Menu/Items/:id).
    case updateMenuItem(id: String, UpdateMenuItemRequest)

    /// Delete a menu item (DELETE /API/Menu/Items/:id).
    case deleteMenuItem(id: String)

    // MARK: - Review Endpoints

    /// Fetch reviews for a specific restaurant.
    case fetchReviews(restaurantId: String, limit: Int?)

    /// Submit a new review for a restaurant.
    case submitReview(ReviewRequest)

    // MARK: - User Endpoints

    /// Fetch user profile by user ID.
    case fetchUserProfile(userId: String)

    /// Create a new user profile.
    case createUserProfile(CreateUserRequest)

    /// Update existing user profile.
    case updateUserProfile(userId: String, UpdateUserRequest)

    /// Update only the user type field (Diner / Restaurant) — used by the type-selection sheet.
    case updateUserType(userId: String, UpdateUserTypeRequest)

    // MARK: - Booking Endpoints

    /// Fetch all bookings for the authenticated diner (GET /API/Bookings).
    case fetchBookings

    /// Fetch a single booking by ID (GET /API/Bookings/:id).
    case fetchBooking(id: String)

    /// Fetch all bookings for a restaurant (GET /API/Bookings/restaurant/:restaurantId).
    case fetchRestaurantBookings(restaurantId: String)

    /// Create a new booking (POST /API/Bookings).
    case createBooking(CreateBookingRequest)

    /// Update booking status or details (PUT /API/Bookings/:id).
    case updateBooking(id: String, UpdateBookingRequest)

    /// Delete a booking (DELETE /API/Bookings/:id). Only if 30+ days old.
    case deleteBooking(id: String)

    // MARK: - Chat Endpoints

    /// Fetch all chat records for a user (GET /API/Chat/Records/:uid).
    case fetchChatRecords(uid: String)

    /// Fetch a single chat room (GET /API/Chat/Rooms/:roomId).
    case fetchChatRoom(roomId: String)

    /// Create a new chat room (POST /API/Chat/Rooms).
    case createChatRoom(CreateRoomRequest)

    /// Fetch messages in a chat room (GET /API/Chat/Rooms/:roomId/Messages).
    case fetchChatMessages(roomId: String, limit: Int?)

    /// Send a message to a chat room (POST /API/Chat/Rooms/:roomId/Messages).
    case sendChatMessage(roomId: String, SendMessageRequest)

    /// Edit a chat message (PUT /API/Chat/Rooms/:roomId/Messages/:messageId).
    case editChatMessage(roomId: String, messageId: String, EditMessageRequest)

    /// Soft-delete a chat message (DELETE /API/Chat/Rooms/:roomId/Messages/:messageId).
    case deleteChatMessage(roomId: String, messageId: String, DeleteMessageRequest)

    /// Create a new restaurant (POST /API/Restaurants). No auth required; ownerId set in body.
    case createRestaurant(CreateRestaurantRequest)

    // MARK: - Gemini AI Endpoints

    /// Multi-turn Gemini chat (POST /API/Gemini/chat). No auth required.
    case geminiChat(GeminiChatRequest)

    /// One-shot Gemini text generation (POST /API/Gemini/generate).
    case geminiGenerate(GeminiGenerateRequest)

    /// Generate AI restaurant description (POST /API/Gemini/restaurant-description). No auth required.
    case geminiRestaurantDescription(GeminiRestaurantDescriptionRequest)

    /// Generate bilingual ad content (POST /API/Gemini/restaurant-advertisement). Auth required.
    case geminiAdvertisement(GeminiAdvertisementRequest)

    // MARK: - Advertisement Endpoints

    /// Fetch all ads, optionally filtered by restaurant (GET /API/Advertisements). No auth.
    case fetchAdvertisements(restaurantId: String?)

    /// Create a new advertisement (POST /API/Advertisements). Auth required.
    case createAdvertisement(CreateAdvertisementRequest)

    /// Update an advertisement (PUT /API/Advertisements/:id). Auth required.
    case updateAdvertisement(id: String, UpdateAdvertisementRequest)

    /// Delete an advertisement (DELETE /API/Advertisements/:id). Auth required.
    case deleteAdvertisement(id: String)

    // MARK: - Stripe Endpoints

    /// Create a Stripe Checkout session for an ad payment (POST /API/Stripe/create-ad-checkout-session). Auth required.
    case createStripeCheckoutSession(StripeCheckoutRequest)

    // MARK: - Endpoint Properties

    /// Whether this endpoint requires a Firebase ID token in the Authorization header.
    var requiresAuth: Bool {
        switch self {
        // Auth-required endpoints
        case .submitReview, .fetchUserProfile, .createUserProfile, .updateUserProfile, .updateUserType,
             .fetchBookings, .fetchBooking, .fetchRestaurantBookings,
             .createBooking, .updateBooking, .deleteBooking,
             .claimRestaurant, .updateRestaurant,
             .createMenuItem, .updateMenuItem, .deleteMenuItem,
             .geminiGenerate,
             .geminiAdvertisement,
             .createAdvertisement, .updateAdvertisement, .deleteAdvertisement,
             .createStripeCheckoutSession:
            return true

        // Public/no-auth endpoints
        case .fetchNearbyRestaurants, .fetchRestaurant, .fetchMenuItems, .fetchReviews,
             .fetchChatRecords, .fetchChatRoom, .createChatRoom,
             .fetchChatMessages, .sendChatMessage, .editChatMessage, .deleteChatMessage,
             .geminiChat, .geminiRestaurantDescription, .createRestaurant,
             .fetchAdvertisements:
            return false
        }
    }

    /// Returns the URL path component for each endpoint.
    var path: String {
        switch self {
        // Restaurant
        case .fetchNearbyRestaurants:
            return Constants.API.Endpoints.nearbyRestaurants

        case .fetchRestaurant(let id):
            return "\(Constants.API.Endpoints.restaurantDetail)/\(id)"

        case .createRestaurant:
            return Constants.API.Endpoints.restaurantDetail

        case .claimRestaurant(let id):
            return "\(Constants.API.Endpoints.restaurantDetail)/\(id)\(Constants.API.Endpoints.claimRestaurant)"

        case .updateRestaurant(let id, _):
            return "\(Constants.API.Endpoints.restaurantDetail)/\(id)"

        // Menu
        case .fetchMenuItems(let restaurantId):
            return "\(Constants.API.Endpoints.restaurantDetail)/\(restaurantId)\(Constants.API.Endpoints.restaurantMenu)"

        case .createMenuItem:
            return Constants.API.Endpoints.menuItems

        case .updateMenuItem(let id, _):
            return "\(Constants.API.Endpoints.menuItems)/\(id)"

        case .deleteMenuItem(let id):
            return "\(Constants.API.Endpoints.menuItems)/\(id)"

        // Reviews
        case .fetchReviews:
            return Constants.API.Endpoints.reviews

        case .submitReview:
            return Constants.API.Endpoints.reviews

        // Users
        case .fetchUserProfile(let userId):
            return "\(Constants.API.Endpoints.userProfile)/\(userId)"

        case .createUserProfile:
            return Constants.API.Endpoints.userProfile

        case .updateUserProfile(let userId, _):
            return "\(Constants.API.Endpoints.userProfile)/\(userId)"

        case .updateUserType(let userId, _):
            return "\(Constants.API.Endpoints.userProfile)/\(userId)"

        // Bookings
        case .fetchBookings:
            return Constants.API.Endpoints.bookings

        case .fetchBooking(let id):
            return "\(Constants.API.Endpoints.bookings)/\(id)"

        case .fetchRestaurantBookings(let restaurantId):
            return "\(Constants.API.Endpoints.restaurantBookings)/\(restaurantId)"

        case .createBooking:
            return Constants.API.Endpoints.bookings

        case .updateBooking(let id, _):
            return "\(Constants.API.Endpoints.bookings)/\(id)"

        case .deleteBooking(let id):
            return "\(Constants.API.Endpoints.bookings)/\(id)"

        // Chat
        case .fetchChatRecords(let uid):
            return "\(Constants.API.Endpoints.chatRecords)/\(uid)"

        case .fetchChatRoom(let roomId):
            return "\(Constants.API.Endpoints.chatRooms)/\(roomId)"

        case .createChatRoom:
            return Constants.API.Endpoints.chatRooms

        case .fetchChatMessages(let roomId, _):
            return "\(Constants.API.Endpoints.chatRooms)/\(roomId)\(Constants.API.Endpoints.chatMessages)"

        case .sendChatMessage(let roomId, _):
            return "\(Constants.API.Endpoints.chatRooms)/\(roomId)\(Constants.API.Endpoints.chatMessages)"

        case .editChatMessage(let roomId, let messageId, _):
            return "\(Constants.API.Endpoints.chatRooms)/\(roomId)\(Constants.API.Endpoints.chatMessages)/\(messageId)"

        case .deleteChatMessage(let roomId, let messageId, _):
            return "\(Constants.API.Endpoints.chatRooms)/\(roomId)\(Constants.API.Endpoints.chatMessages)/\(messageId)"

        // Gemini
        case .geminiChat:
            return Constants.API.Endpoints.geminiChat

        case .geminiGenerate:
            return Constants.API.Endpoints.geminiGenerate

        case .geminiRestaurantDescription:
            return Constants.API.Endpoints.geminiRestaurantDescription

        case .geminiAdvertisement:
            return "/API/Gemini/restaurant-advertisement"

        // Advertisements
        case .fetchAdvertisements:
            return "/API/Advertisements"

        case .createAdvertisement:
            return "/API/Advertisements"

        case .updateAdvertisement(let id, _):
            return "/API/Advertisements/\(id)"

        case .deleteAdvertisement(let id):
            return "/API/Advertisements/\(id)"

        // Stripe
        case .createStripeCheckoutSession:
            return "/API/Stripe/create-ad-checkout-session"
        }
    }

    /// Returns the HTTP method for each endpoint.
    var method: HTTPMethod {
        switch self {
        // POST — creating new resources
        case .submitReview, .createUserProfile, .createBooking,
             .claimRestaurant, .createMenuItem,
             .createChatRoom, .sendChatMessage,
             .geminiChat, .geminiGenerate, .geminiRestaurantDescription,
             .geminiAdvertisement,
             .createRestaurant,
             .createAdvertisement,
             .createStripeCheckoutSession:
            return .post

        // PUT — updating existing resources
        case .updateUserProfile, .updateUserType, .updateBooking, .updateRestaurant,
             .updateMenuItem, .editChatMessage,
             .updateAdvertisement:
            return .put

        // DELETE — removing resources
        case .deleteBooking, .deleteMenuItem, .deleteChatMessage,
             .deleteAdvertisement:
            return .delete

        // GET — safe, read-only operations
        case .fetchNearbyRestaurants, .fetchRestaurant, .fetchMenuItems,
             .fetchReviews, .fetchUserProfile,
             .fetchBookings, .fetchBooking, .fetchRestaurantBookings,
             .fetchChatRecords, .fetchChatRoom, .fetchChatMessages:
            return .get
        }
    }

    /// Returns query parameters for GET requests.
    var queryItems: [URLQueryItem]? {
        switch self {
        case .fetchNearbyRestaurants(let lat, let lng, let radius):
            return [
                URLQueryItem(name: "lat", value: String(lat)),
                URLQueryItem(name: "lng", value: String(lng)),
                URLQueryItem(name: "radius", value: String(radius))
            ]

        case .fetchReviews(let restaurantId, let limit):
            var items = [URLQueryItem(name: "restaurantId", value: restaurantId)]
            if let limit = limit {
                items.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            return items

        case .fetchChatMessages(_, let limit):
            guard let limit = limit else { return nil }
            return [URLQueryItem(name: "limit", value: String(limit))]

        // Optional restaurantId filter for advertisement list
        case .fetchAdvertisements(let restaurantId):
            guard let restaurantId = restaurantId else { return nil }
            return [URLQueryItem(name: "restaurantId", value: restaurantId)]

        default:
            return nil
        }
    }

    /// Returns the request body for POST/PUT/DELETE requests.
    var body: Encodable? {
        switch self {
        // Reviews
        case .submitReview(let request):
            return request

        // Users
        case .createUserProfile(let request):
            return request
        case .updateUserProfile(_, let request):
            return request
        case .updateUserType(_, let request):
            return request

        // Bookings
        case .createBooking(let request):
            return request
        case .updateBooking(_, let request):
            return request

        // Restaurant management
        case .updateRestaurant(_, let request):
            return request
        case .createMenuItem(let request):
            return request
        case .updateMenuItem(_, let request):
            return request

        // Chat
        case .createChatRoom(let request):
            return request
        case .sendChatMessage(_, let request):
            return request
        case .editChatMessage(_, _, let request):
            return request
        case .deleteChatMessage(_, _, let request):
            return request

        // Gemini
        case .geminiChat(let request):
            return request
        case .geminiGenerate(let request):
            return request
        case .geminiRestaurantDescription(let request):
            return request
        case .geminiAdvertisement(let request):
            return request

        // Restaurant creation
        case .createRestaurant(let request):
            return request

        // Advertisements
        case .createAdvertisement(let request):
            return request
        case .updateAdvertisement(_, let request):
            return request

        // Stripe
        case .createStripeCheckoutSession(let request):
            return request

        default:
            return nil
        }
    }
}

// MARK: - Restaurant Management Request Models

/// Contacts sub-object for UpdateRestaurantRequest
struct RestaurantContactsUpdate: Codable, Sendable {
    var phone: String?
    var email: String?
    var website: String?
    enum CodingKeys: String, CodingKey {
        case phone   = "Phone"
        case email   = "Email"
        case website = "Website"
    }
}

/// Request body for PUT /API/Restaurants/:id
struct UpdateRestaurantRequest: Codable, Sendable {
    var nameEN: String?
    var nameTC: String?
    var descriptionEN: String?
    var descriptionTC: String?
    var addressEN: String?
    var addressTC: String?
    var districtEN: String?
    var districtTC: String?
    var keywordEN: [String]?
    var keywordTC: [String]?
    var seats: Int?
    var contacts: RestaurantContactsUpdate?
    var imageUrl: String?
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case nameEN        = "Name_EN"
        case nameTC        = "Name_TC"
        case descriptionEN = "Description_EN"
        case descriptionTC = "Description_TC"
        case addressEN     = "Address_EN"
        case addressTC     = "Address_TC"
        case districtEN    = "District_EN"
        case districtTC    = "District_TC"
        case keywordEN     = "Keyword_EN"
        case keywordTC     = "Keyword_TC"
        case seats         = "Seats"
        case contacts      = "Contacts"
        case imageUrl      = "ImageUrl"
        case latitude      = "Latitude"
        case longitude     = "Longitude"
    }
}

// MARK: - Menu CRUD Request Models

/// Request body for POST /API/Menu/Items
struct CreateMenuItemRequest: Codable, Sendable {
    let restaurantId: String
    let nameEN: String
    let nameTC: String
    let descriptionEN: String?
    let descriptionTC: String?
    let price: Double?
    let image: String?

    enum CodingKeys: String, CodingKey {
        case restaurantId
        case nameEN = "Name_EN"
        case nameTC = "Name_TC"
        case descriptionEN = "Description_EN"
        case descriptionTC = "Description_TC"
        case price = "Price"
        case image = "Image"
    }
}

/// Request body for PUT /API/Menu/Items/:id
struct UpdateMenuItemRequest: Codable, Sendable {
    var nameEN: String?
    var nameTC: String?
    var descriptionEN: String?
    var descriptionTC: String?
    var price: Double?
    var image: String?

    enum CodingKeys: String, CodingKey {
        case nameEN = "Name_EN"
        case nameTC = "Name_TC"
        case descriptionEN = "Description_EN"
        case descriptionTC = "Description_TC"
        case price = "Price"
        case image = "Image"
    }
}

// MARK: - Chat Edit/Delete Request Models

/// Request body for PUT /API/Chat/Rooms/:roomId/Messages/:messageId
struct EditMessageRequest: Codable, Sendable {
    let message: String
    let userId: String
}

/// Request body for DELETE /API/Chat/Rooms/:roomId/Messages/:messageId
struct DeleteMessageRequest: Codable, Sendable {
    let userId: String
}

// MARK: - Claim Restaurant Response

/// Response from POST /API/Restaurants/:id/claim
struct ClaimRestaurantResponse: Codable, Sendable {
    let message: String?
    let restaurantId: String?
    let userId: String?
}

// MARK: - Create Restaurant Request/Response

/// Request body for POST /API/Restaurants (no auth required; ownerId set in body)
struct CreateRestaurantRequest: Codable, Sendable {
    var Name_EN: String?
    var Name_TC: String?
    var Address_EN: String?
    var Address_TC: String?
    var District_EN: String?
    var District_TC: String?
    var Latitude: Double?
    var Longitude: Double?
    var Keyword_EN: [String]?
    var Keyword_TC: [String]?
    var Seats: Int?
    var Contacts: NewRestaurantContacts?
    var Payments: [String]?
    var Opening_Hours: [String: String]?
    var ownerId: String
}

/// Contact information for a new restaurant
struct NewRestaurantContacts: Codable, Sendable {
    var Phone: String?
    var Email: String?
    var Website: String?
}

/// Response from POST /API/Restaurants
struct CreateRestaurantResponse: Codable, Sendable {
    let id: String
}
