//
//  ChatService.swift
//  Pour Rice
//
//  Service for chat room and message operations via REST API
//  Provides message persistence complementing real-time Socket.IO delivery
//

import Foundation

/// Service responsible for chat REST API operations (room management, message persistence)
@MainActor
final class ChatService {

    // MARK: - Properties

    private let apiClient: APIClient

    // MARK: - Initialisation

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Room Operations

    /// Fetches all chat rooms and recent messages for a user.
    func fetchChatRecords(uid: String) async throws -> [ChatRoom] {
        print("🔍 Fetching chat records for user: \(uid)")

        let response = try await apiClient.request(
            .fetchChatRecords(uid: uid),
            responseType: ChatRecordsResponse.self,
            callerService: "ChatService"
        )

        print("✅ Fetched \(response.rooms.count) chat rooms")
        return response.rooms
    }

    /// Fetches a single chat room by ID.
    func fetchRoom(roomId: String) async throws -> ChatRoom {
        print("🔍 Fetching chat room: \(roomId)")

        let room = try await apiClient.request(
            .fetchChatRoom(roomId: roomId),
            responseType: ChatRoom.self,
            callerService: "ChatService"
        )

        print("✅ Fetched chat room: \(room.id)")
        return room
    }

    /// Creates a new chat room.
    /// - Returns: The room ID of the created room.
    func createRoom(_ request: CreateRoomRequest) async throws -> String {
        print("📝 Creating chat room: \(request.roomName)")

        let response = try await apiClient.request(
            .createChatRoom(request),
            responseType: CreateRoomResponse.self,
            callerService: "ChatService"
        )

        print("✅ Created chat room: \(response.roomId)")
        return response.roomId
    }

    // MARK: - Message Operations

    /// Fetches message history for a chat room.
    func fetchMessages(roomId: String, limit: Int? = nil) async throws -> [ChatMessage] {
        print("🔍 Fetching messages for room: \(roomId)")

        let response = try await apiClient.request(
            .fetchChatMessages(roomId: roomId, limit: limit),
            responseType: ChatMessagesResponse.self,
            callerService: "ChatService"
        )

        print("✅ Fetched \(response.messages.count) messages")
        return response.messages
    }

    /// Sends a message via REST API (fallback when Socket.IO is unavailable).
    func sendMessage(roomId: String, request: SendMessageRequest) async throws -> String {
        print("📤 Sending message to room: \(roomId)")

        struct SendResponse: Codable {
            let messageId: String
            let message: String?
        }

        let response = try await apiClient.request(
            .sendChatMessage(roomId: roomId, request),
            responseType: SendResponse.self,
            callerService: "ChatService"
        )

        print("✅ Sent message: \(response.messageId)")
        return response.messageId
    }

    /// Edits an existing message (ownership verified by userId).
    func editMessage(roomId: String, messageId: String, newText: String, userId: String) async throws {
        print("✏️ Editing message: \(messageId)")

        let request = EditMessageRequest(message: newText, userId: userId)
        try await apiClient.requestVoid(
            .editChatMessage(roomId: roomId, messageId: messageId, request),
            callerService: "ChatService"
        )

        print("✅ Edited message: \(messageId)")
    }

    /// Soft-deletes a message (ownership verified by userId).
    func deleteMessage(roomId: String, messageId: String, userId: String) async throws {
        print("🗑️ Deleting message: \(messageId)")

        let request = DeleteMessageRequest(userId: userId)
        try await apiClient.requestVoid(
            .deleteChatMessage(roomId: roomId, messageId: messageId, request),
            callerService: "ChatService"
        )

        print("✅ Deleted message: \(messageId)")
    }
}
