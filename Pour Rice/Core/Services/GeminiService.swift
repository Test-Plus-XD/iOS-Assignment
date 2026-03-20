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
    /// - Parameter message: The user's message text
    /// - Returns: The AI's response text
    func chat(message: String) async throws -> String {
        print("🤖 Gemini chat: \(message.prefix(50))...")

        let request = GeminiChatRequest(
            message: message,
            history: conversationHistory.isEmpty ? nil : conversationHistory
        )

        let response = try await apiClient.request(
            .geminiChat(request),
            responseType: GeminiChatResponse.self,
            callerService: "GeminiService"
        )

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
