//
//  ChatRoomViewModel.swift
//  Pour Rice
//
//  ViewModel for an individual chat room conversation
//  Manages message history, real-time Socket.IO updates, and typing indicators
//

import Foundation

/// ViewModel for ChatRoomView — manages messages and real-time communication
@MainActor @Observable
final class ChatRoomViewModel {

    // MARK: - Properties

    /// Messages in chronological order (oldest first)
    private(set) var messages: [ChatMessage] = []

    /// Text currently being composed
    var messageText = ""

    /// Whether messages are loading
    private(set) var isLoading = false

    /// Users currently typing (userId → displayName)
    private(set) var typingUsers: [String: String] = [:]

    /// Current error
    var error: Error?

    // MARK: - Dependencies

    private var chatService: ChatService?
    private var socketService: SocketService?
    private var roomId: String?
    private var currentUserId: String?
    private var currentDisplayName: String?

    /// Background tasks for listening to socket streams
    private var messageListenerTask: Task<Void, Never>?
    private var typingListenerTask: Task<Void, Never>?
    private var typingDebounceTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Whether there are other users typing
    var isOtherTyping: Bool { !typingUsers.isEmpty }

    /// Display string for typing indicator (e.g. "Alice is typing...")
    var typingIndicatorText: String? {
        guard !typingUsers.isEmpty else { return nil }
        let names = Array(typingUsers.values)
        if names.count == 1 {
            return String(localized: "chat_typing_single \(names[0])")
        } else {
            return String(localized: "chat_typing_multiple")
        }
    }

    // MARK: - Lifecycle

    /// Loads message history and starts listening for real-time updates.
    func start(
        roomId: String,
        userId: String,
        displayName: String,
        authToken: String,
        chatService: ChatService,
        socketService: SocketService
    ) async {
        self.roomId = roomId
        self.currentUserId = userId
        self.currentDisplayName = displayName
        self.chatService = chatService
        self.socketService = socketService

        // Load history
        isLoading = true
        do {
            messages = try await chatService.fetchMessages(roomId: roomId, limit: Constants.Chat.messagePageSize)
        } catch {
            self.error = error
        }
        isLoading = false

        // Connect socket if not already connected
        if !socketService.isConnected {
            socketService.connect(userId: userId, displayName: displayName, authToken: authToken)
            // Give the socket a moment to connect before joining
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // Join room
        socketService.joinRoom(roomId: roomId, userId: userId)

        // Listen for incoming messages
        messageListenerTask = Task { [weak self] in
            guard let self = self else { return }
            for await message in socketService.incomingMessages {
                if message.roomId == roomId || message.roomId == nil {
                    // Avoid duplicates
                    if !self.messages.contains(where: { $0.id == message.id }) {
                        self.messages.append(message)
                    }
                }
            }
        }

        // Listen for typing indicators
        typingListenerTask = Task { [weak self] in
            guard let self = self else { return }
            for await (uid, name, isTyping) in socketService.typingIndicators {
                guard uid != userId else { continue } // Ignore own typing
                if isTyping {
                    self.typingUsers[uid] = name
                } else {
                    self.typingUsers.removeValue(forKey: uid)
                }
            }
        }
    }

    /// Stops listening and leaves the room.
    func stop() {
        messageListenerTask?.cancel()
        messageListenerTask = nil
        typingListenerTask?.cancel()
        typingListenerTask = nil
        typingDebounceTask?.cancel()
        typingDebounceTask = nil

        if let roomId = roomId, let userId = currentUserId {
            socketService?.leaveRoom(roomId: roomId, userId: userId)
        }
    }

    // MARK: - Actions

    /// Sends the current message text.
    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let roomId = roomId,
              let userId = currentUserId,
              let displayName = currentDisplayName else { return }

        messageText = ""

        // Send via Socket.IO for real-time delivery
        if let socket = socketService, socket.isConnected {
            socket.sendMessage(roomId: roomId, userId: userId, displayName: displayName, message: text)
        } else {
            // Fallback to REST
            do {
                let request = SendMessageRequest(message: text, userId: userId, displayName: displayName)
                _ = try await chatService?.sendMessage(roomId: roomId, request: request)
            } catch {
                self.error = error
            }
        }

        // Stop typing indicator
        socketService?.sendTyping(roomId: roomId, userId: userId, displayName: displayName, isTyping: false)
    }

    /// Called when the user is typing to send typing indicators.
    func onTypingChanged() {
        guard let roomId = roomId,
              let userId = currentUserId,
              let displayName = currentDisplayName,
              let socket = socketService else { return }

        let isTyping = !messageText.isEmpty
        socket.sendTyping(roomId: roomId, userId: userId, displayName: displayName, isTyping: isTyping)

        // Auto-stop typing after debounce interval
        typingDebounceTask?.cancel()
        if isTyping {
            typingDebounceTask = Task {
                try? await Task.sleep(nanoseconds: Constants.Chat.typingDebounceNs * 6)
                socket.sendTyping(roomId: roomId, userId: userId, displayName: displayName, isTyping: false)
            }
        }
    }

    /// Edits a message.
    func editMessage(id: String, newText: String) async {
        guard let roomId = roomId, let userId = currentUserId else { return }
        do {
            try await chatService?.editMessage(roomId: roomId, messageId: id, newText: newText, userId: userId)
            if let index = messages.firstIndex(where: { $0.id == id }) {
                messages[index].message = newText
            }
        } catch {
            self.error = error
        }
    }

    /// Soft-deletes a message.
    func deleteMessage(id: String) async {
        guard let roomId = roomId, let userId = currentUserId else { return }
        do {
            try await chatService?.deleteMessage(roomId: roomId, messageId: id, userId: userId)
            if let index = messages.firstIndex(where: { $0.id == id }) {
                messages[index] = ChatMessage(
                    id: messages[index].id,
                    roomId: roomId,
                    userId: messages[index].userId,
                    displayName: messages[index].displayName,
                    message: messages[index].message,
                    timestamp: messages[index].timestamp,
                    edited: messages[index].edited,
                    deleted: true
                )
            }
        } catch {
            self.error = error
        }
    }
}
