//
//  GeminiViewModel.swift
//  Pour Rice
//
//  ViewModel for the Gemini AI chat interface
//  Manages conversation state, context-aware prompts, and suggestion chips
//

import Foundation

/// ViewModel for GeminiChatView — manages the AI conversation
@MainActor @Observable
final class GeminiViewModel {

    // MARK: - Properties

    /// Conversation messages for display
    private(set) var messages: [GeminiMessage] = []

    /// Text currently being composed
    var inputText = ""

    /// Whether the AI is generating a response
    private(set) var isLoading = false

    /// Current error
    var error: Error?

    /// Restaurant context (if launched from a restaurant detail page)
    private(set) var restaurantContext: Restaurant?

    // MARK: - Dependencies

    private var geminiService: GeminiService?

    // MARK: - Computed Properties

    /// Context-aware suggestion chips
    var suggestionChips: [String] {
        if restaurantContext != nil {
            return [
                String(localized: "gemini_chip_recommend_dishes"),
                String(localized: "gemini_chip_dietary_options"),
                String(localized: "gemini_chip_restaurant_info"),
                String(localized: "gemini_chip_nearby_similar")
            ]
        } else {
            return [
                String(localized: "gemini_chip_find_restaurant"),
                String(localized: "gemini_chip_vegan_options"),
                String(localized: "gemini_chip_hk_districts"),
                String(localized: "gemini_chip_cuisine_types")
            ]
        }
    }

    /// Welcome message text
    var welcomeMessage: String {
        if let restaurant = restaurantContext {
            return String(localized: "gemini_welcome_restaurant \(restaurant.name.localised)")
        } else {
            return String(localized: "gemini_welcome_general")
        }
    }

    // MARK: - Lifecycle

    /// Initialises the view model with an optional restaurant context.
    func initialise(service: GeminiService, restaurant: Restaurant? = nil) {
        self.geminiService = service
        self.restaurantContext = restaurant

        // Add welcome message
        messages = [
            GeminiMessage(role: .model, content: welcomeMessage)
        ]
    }

    // MARK: - Actions

    /// Sends the current input as a message to Gemini.
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let service = geminiService else { return }

        // Add user message
        messages.append(GeminiMessage(role: .user, content: text))
        inputText = ""
        isLoading = true
        error = nil

        do {
            // Build context-aware prompt if we have restaurant context
            let prompt: String
            if let restaurant = restaurantContext {
                prompt = """
                [Context: The user is asking about "\(restaurant.name.en)" restaurant \
                in \(restaurant.description.en). \
                Please answer in the context of this restaurant.]

                \(text)
                """
            } else {
                prompt = text
            }

            let response = try await service.chat(message: prompt)
            messages.append(GeminiMessage(role: .model, content: response))
        } catch {
            self.error = error
            messages.append(GeminiMessage(
                role: .model,
                content: String(localized: "gemini_error_response")
            ))
        }

        isLoading = false
    }

    /// Sends a suggestion chip as a message.
    func sendSuggestion(_ suggestion: String) async {
        inputText = suggestion
        await sendMessage()
    }

    /// Clears the conversation and starts fresh.
    func clearConversation() {
        geminiService?.clearHistory()
        messages = [
            GeminiMessage(role: .model, content: welcomeMessage)
        ]
    }
}
