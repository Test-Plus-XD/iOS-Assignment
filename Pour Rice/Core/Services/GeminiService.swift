//
//  GeminiService.swift
//  Pour Rice
//
//  Service for Gemini AI conversational features
//  Manages conversation history and provides context-aware restaurant Q&A
//

import Foundation

/// Service responsible for Gemini AI API operations
/// Maintains conversation history for multi-turn chat sessions
@MainActor
final class GeminiService {

    // MARK: - Properties

    private let apiClient: APIClient

    /// Conversation history maintained across turns within a session
    private(set) var conversationHistory: [GeminiHistoryEntry] = []

    // MARK: - Initialisation

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Chat

    /// Sends a message in a multi-turn conversation.
    /// Automatically manages conversation history.
    /// - Parameters:
    ///   - message: The user's message text
    ///   - restaurantId: When non-nil, routes to the restaurant-description endpoint (chat mode).
    ///     The server fetches restaurant info + menu from Firestore and injects them as context automatically.
    ///     When nil, uses the general `/chat` endpoint.
    /// - Returns: The AI's response text
    func chat(message: String, restaurantId: String? = nil) async throws -> String {
        print("🤖 Gemini chat: \(message.prefix(50))...")

        let response: GeminiChatResponse

        if let restaurantId {
            // Restaurant-specific chat: server fetches context from Firestore automatically
            let request = GeminiRestaurantChatRequest(
                restaurantId: restaurantId,
                message: message,
                history: conversationHistory.isEmpty ? nil : conversationHistory
            )
            response = try await apiClient.request(
                .geminiRestaurantChat(request),
                responseType: GeminiChatResponse.self,
                callerService: "GeminiService"
            )
        } else {
            // General chat: no restaurant context
            let request = GeminiChatRequest(
                message: message,
                history: conversationHistory.isEmpty ? nil : conversationHistory
            )
            response = try await apiClient.request(
                .geminiChat(request),
                responseType: GeminiChatResponse.self,
                callerService: "GeminiService"
            )
        }

        // Update history from API response (includes the latest turn)
        if let updatedHistory = response.history {
            conversationHistory = updatedHistory
        } else {
            // Manually append if API doesn't return updated history
            conversationHistory.append(GeminiHistoryEntry(role: "user", text: message))
            conversationHistory.append(GeminiHistoryEntry(role: "model", text: response.result))
        }

        print("✅ Gemini response received (\(response.result.count) chars)")
        return response.result
    }

    /// Clears the conversation history for a fresh session.
    func clearHistory() {
        conversationHistory.removeAll()
        print("🧹 Gemini conversation history cleared")
    }

    // MARK: - One-Shot Generation

    /// Generates text from a single prompt (no conversation history).
    func generate(prompt: String, maxTokens: Int? = nil) async throws -> String {
        print("🤖 Gemini generate: \(prompt.prefix(50))...")

        let request = GeminiGenerateRequest(prompt: prompt, maxTokens: maxTokens)

        let response = try await apiClient.request(
            .geminiGenerate(request),
            responseType: GeminiGenerateResponse.self,
            callerService: "GeminiService"
        )

        print("✅ Generated \(response.result.count) chars")
        return response.result
    }

    // MARK: - Advertisement Generation

    /// Generates bilingual (EN/TC) advertisement content for a restaurant using Gemini AI.
    /// The server fetches the restaurant's menu from Firestore and uses it to craft
    /// compelling ad copy.  Returns structured title + content in both languages.
    ///
    /// Corresponds to POST /API/Gemini/restaurant-advertisement (auth required).
    ///
    /// - Parameters:
    ///   - restaurantId: The restaurant's Firestore document ID
    ///   - name: Display name of the restaurant (used as context for the model)
    ///   - district: Optional district (e.g. "Central") for localised ad copy
    ///   - keywords: Optional cuisine/style keywords for targeted generation
    ///   - message: Optional custom instruction from the user (e.g. "focus on our dim sum")
    /// - Returns: An AdvertisementGenerationResponse with Title_EN/TC and Content_EN/TC
    func generateAdvertisement(
        restaurantId: String,
        name: String,
        district: String? = nil,
        keywords: [String]? = nil,
        message: String? = nil
    ) async throws -> AdvertisementGenerationResponse {
        print("🤖 GeminiService: Generating advertisement for restaurant: \(name)")

        let request = GeminiAdvertisementRequest(
            restaurantId: restaurantId,
            name: name,
            district: district,
            keywords: keywords,
            message: message
        )

        let response = try await apiClient.request(
            .geminiAdvertisement(request),
            responseType: AdvertisementGenerationResponse.self,
            callerService: "GeminiService"
        )

        print("✅ GeminiService: Advertisement generated for \(name)")
        return response
    }

    // MARK: - Restaurant-Specific

    /// Generates an AI marketing description for a restaurant.
    /// Menu items are fetched server-side from Firestore using the restaurantId.
    func generateRestaurantDescription(
        restaurantId: String,
        name: String,
        district: String? = nil,
        keywords: [String]? = nil,
        language: String? = nil
    ) async throws -> String {
        print("🤖 Generating description for restaurant: \(name)")

        let request = GeminiRestaurantDescriptionRequest(
            restaurantId: restaurantId,
            name: name,
            district: district,
            keywords: keywords,
            language: language
        )

        let response = try await apiClient.request(
            .geminiRestaurantDescription(request),
            responseType: GeminiRestaurantDescriptionResponse.self,
            callerService: "GeminiService"
        )

        print("✅ Generated restaurant description (\(response.description.count) chars)")
        return response.description
    }
}
