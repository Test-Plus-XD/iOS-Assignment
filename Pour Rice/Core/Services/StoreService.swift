//
//  StoreService.swift
//  Pour Rice
//
//  Service for restaurant owner management operations
//  Handles restaurant claiming, info editing, image uploads, and menu CRUD
//

import Foundation

/// Service responsible for restaurant owner/store management operations
@MainActor
final class StoreService {

    // MARK: - Properties

    private let apiClient: APIClient

    // MARK: - Initialisation

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Restaurant Ownership

    /// Claims ownership of a restaurant.
    /// The user must be of type 'Restaurant' and not already own another restaurant.
    func claimRestaurant(id: String) async throws -> ClaimRestaurantResponse {
        print("🏪 Claiming restaurant: \(id)")

        let response = try await apiClient.request(
            .claimRestaurant(id: id),
            responseType: ClaimRestaurantResponse.self,
            callerService: "StoreService"
        )

        print("✅ Claimed restaurant: \(id)")
        return response
    }

    // MARK: - Restaurant Info

    /// Fetches the restaurant details for the owner's restaurant.
    func fetchRestaurant(id: String) async throws -> Restaurant {
        print("🔍 Fetching owned restaurant: \(id)")

        let restaurant = try await apiClient.request(
            .fetchRestaurant(id: id),
            responseType: Restaurant.self,
            callerService: "StoreService"
        )

        print("✅ Fetched restaurant: \(restaurant.id)")
        return restaurant
    }

    /// Updates restaurant information.
    func updateRestaurant(id: String, request: UpdateRestaurantRequest) async throws {
        print("📝 Updating restaurant: \(id)")

        try await apiClient.requestVoid(
            .updateRestaurant(id: id, request),
            callerService: "StoreService"
        )

        print("✅ Updated restaurant: \(id)")
    }

    /// Uploads a restaurant image via multipart form data.
    /// This bypasses the standard APIClient since it requires multipart encoding.
    /// - Returns: The URL of the uploaded image.
    func uploadRestaurantImage(id: String, imageData: Data, filename: String = "image.jpg") async throws -> String {
        print("📸 Uploading image for restaurant: \(id)")

        let urlString = "\(Constants.API.baseURL)\(Constants.API.Endpoints.restaurantDetail)/\(id)\(Constants.API.Endpoints.restaurantImage)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: Constants.API.Headers.contentType)
        request.setValue(Constants.API.passcode, forHTTPHeaderField: Constants.API.Headers.apiPasscode)

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        struct ImageResponse: Codable {
            let imageUrl: String
        }

        let decoder = JSONDecoder()
        let imageResponse = try decoder.decode(ImageResponse.self, from: data)

        print("✅ Uploaded image: \(imageResponse.imageUrl.prefix(50))...")
        return imageResponse.imageUrl
    }

    // MARK: - Menu CRUD

    /// Creates a new menu item for a restaurant.
    func createMenuItem(_ request: CreateMenuItemRequest) async throws {
        print("📝 Creating menu item for restaurant: \(request.restaurantId)")

        // API returns a response with the created item ID
        struct CreateResponse: Codable {
            let id: String?
            let message: String?
        }

        _ = try await apiClient.request(
            .createMenuItem(request),
            responseType: CreateResponse.self,
            callerService: "StoreService"
        )

        print("✅ Created menu item")
    }

    /// Updates an existing menu item.
    func updateMenuItem(id: String, request: UpdateMenuItemRequest) async throws {
        print("📝 Updating menu item: \(id)")

        try await apiClient.requestVoid(
            .updateMenuItem(id: id, request),
            callerService: "StoreService"
        )

        print("✅ Updated menu item: \(id)")
    }

    /// Deletes a menu item.
    func deleteMenuItem(id: String) async throws {
        print("🗑️ Deleting menu item: \(id)")

        try await apiClient.requestVoid(
            .deleteMenuItem(id: id),
            callerService: "StoreService"
        )

        print("✅ Deleted menu item: \(id)")
    }
}
