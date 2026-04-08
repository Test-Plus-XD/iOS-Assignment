//
//  GeminiMessage.swift
//  Pour Rice
//
//  Data models for Gemini AI conversational features
//  Supports multi-turn chat with conversation history
//

import Foundation

// MARK: - Local Display Model

/// Represents a single message in the Gemini AI conversation (local display model)
/// Not sent to the API directly — used for rendering the chat interface
struct GeminiMessage: Identifiable, Hashable, Sendable {

    /// Unique local identifier
    let id: UUID

    /// Who sent the message
    let role: Role

    /// Message text content (may contain Markdown formatting)
    let content: String

    /// When the message was created locally
    let timestamp: Date

    /// Sender role
    enum Role: String, Sendable {
        case user
        case model
    }

    init(role: Role, content: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - API History Entry

/// A single entry in the Gemini conversation history sent to the API
/// Format: { "role": "user"|"model", "parts": [{ "text": "..." }] }
struct GeminiHistoryEntry: Codable, Sendable {
    let role: String
    let parts: [GeminiTextPart]

    init(role: String, text: String) {
        self.role = role
        self.parts = [GeminiTextPart(text: text)]
    }
}

/// Text part within a Gemini history entry
struct GeminiTextPart: Codable, Sendable {
    let text: String
}

// MARK: - API Request Models

/// Request body for POST /API/Gemini/chat
struct GeminiChatRequest: Codable, Sendable {
    let message: String
    let history: [GeminiHistoryEntry]?
    let model: String?

    init(message: String, history: [GeminiHistoryEntry]? = nil, model: String? = nil) {
        self.message = message
        self.history = history
        self.model = model
    }
}

/// Request body for POST /API/Gemini/generate
struct GeminiGenerateRequest: Codable, Sendable {
    let prompt: String
    let model: String?
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let topK: Int?

    init(
        prompt: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        topK: Int? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.topK = topK
    }
}

/// Request body for POST /API/Gemini/restaurant-description
struct GeminiRestaurantDescriptionRequest: Codable, Sendable {
    let restaurantId: String
    let name: String
    let district: String?
    let keywords: [String]?
    let language: String?

    init(
        restaurantId: String,
        name: String,
        district: String? = nil,
        keywords: [String]? = nil,
        language: String? = nil
    ) {
        self.restaurantId = restaurantId
        self.name = name
        self.district = district
        self.keywords = keywords
        self.language = language
    }
}

/// Request body for POST /API/Gemini/restaurant-description (chat mode)
/// Used when the user is chatting about a specific restaurant — the server fetches
/// restaurant info and menu from Firestore and injects them as context automatically.
struct GeminiRestaurantChatRequest: Codable, Sendable {
    let restaurantId: String
    let message: String
    let history: [GeminiHistoryEntry]?
    let model: String?

    init(restaurantId: String, message: String, history: [GeminiHistoryEntry]? = nil, model: String? = nil) {
        self.restaurantId = restaurantId
        self.message = message
        self.history = history
        self.model = model
    }
}

// MARK: - API Response Models

/// Response from POST /API/Gemini/chat
struct GeminiChatResponse: Codable, Sendable {
    let result: String
    let model: String?
    let history: [GeminiHistoryEntry]?
}

/// Response from POST /API/Gemini/generate
struct GeminiGenerateResponse: Codable, Sendable {
    let result: String
    let model: String?
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

/// Response from POST /API/Gemini/restaurant-description
struct GeminiRestaurantDescriptionResponse: Codable, Sendable {
    let description: String
    let restaurant: [String: String]?
}
