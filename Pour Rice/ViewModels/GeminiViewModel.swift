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

    /// Toast message to display
    var toastMessage = ""

    /// Toast visual style
    var toastStyle: ToastStyle = .info

    /// Whether the toast is currently visible
    var showToast = false

    /// Restaurant context (if launched from a restaurant detail page)
    private(set) var restaurantContext: Restaurant?

    // MARK: - Dependencies

    private var geminiService: GeminiService?

    // MARK: - Computed Properties

    /// Context-aware suggestion chips
    var suggestionChips: [String] {
        if restaurantContext != nil {
            return [
                String(localized: "gemini_chip_recommend_dishes", bundle: L10n.bundle),
                String(localized: "gemini_chip_dietary_options", bundle: L10n.bundle),
                String(localized: "gemini_chip_restaurant_info", bundle: L10n.bundle),
                String(localized: "gemini_chip_nearby_similar", bundle: L10n.bundle)
            ]
        } else {
            return [
                String(localized: "gemini_chip_find_restaurant", bundle: L10n.bundle),
                String(localized: "gemini_chip_vegan_options", bundle: L10n.bundle),
                String(localized: "gemini_chip_hk_districts", bundle: L10n.bundle),
                String(localized: "gemini_chip_cuisine_types", bundle: L10n.bundle)
            ]
        }
    }

    /// Welcome message text
    var welcomeMessage: String {
        if let restaurant = restaurantContext {
            return String(localized: "gemini_welcome_restaurant \(restaurant.name.localised)", bundle: L10n.bundle)
        } else {
            return String(localized: "gemini_welcome_general", bundle: L10n.bundle)
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
                content: String(localized: "gemini_error_response", bundle: L10n.bundle)
            ))
            showToast(String(localized: "toast_gemini_error", bundle: L10n.bundle), .error)
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
        showToast(String(localized: "toast_gemini_cleared", bundle: L10n.bundle), .info)
    }

    // MARK: - Private Helpers

    private func showToast(_ message: String, _ style: ToastStyle) {
        toastMessage = message
        toastStyle = style
        showToast = true
    }
}
