//
//  ChatRoomViewModel.swift
//  Pour Rice
//
//  ViewModel for an individual chat room conversation
//  Uses Socket.IO for real-time messaging with REST polling as fallback
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  FLUTTER EQUIVALENT:
//  class ChatRoomViewModel extends ChangeNotifier {
//    late StreamSubscription _messageSub;
//    late StreamSubscription _typingSub;
//    void start() {
//      _messageSub = chatService.messageStream.listen(_onMessage);
//      _typingSub = chatService.typingStream.listen(_onTyping);
//    }
//  }
//
//  KEY IOS DIFFERENCES:
//  - AsyncStream + for await = StreamSubscription + listen()
//  - Task {} = Future.microtask() or StreamSubscription
//  - @Observable = ChangeNotifier
//  ============================================================================
//

import Foundation

/// ViewModel for ChatRoomView — manages messages via Socket.IO with REST fallback
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

    /// Whether the real-time socket is active (false = using REST polling fallback)
    private(set) var isUsingSocket = false

    // MARK: - Dependencies

    private var chatService: ChatService?
    private var socketService: SocketService?
    private var roomId: String?
    private var currentUserId: String?
    private var currentDisplayName: String?
    private var authToken: String?

    /// Background task for polling new messages (fallback when socket unavailable)
    private var pollingTask: Task<Void, Never>?

    /// Background task listening to incoming socket messages
    private var socketListenerTask: Task<Void, Never>?

    /// Background task listening to typing indicator events
    private var typingListenerTask: Task<Void, Never>?

    /// Background task listening to connection state changes
    private var connectionListenerTask: Task<Void, Never>?

    /// Background task for debouncing local typing emission
    private var typingDebounceTask: Task<Void, Never>?

    /// Whether we are currently emitting typing = true
    private var isLocallyTyping = false

    /// Polling interval in seconds (REST fallback only)
    private let pollingInterval: TimeInterval = 3

    // MARK: - Computed Properties

    /// Whether there are other users typing
    var isOtherTyping: Bool { !typingUsers.isEmpty }

    /// Display string for typing indicator (e.g. "Alice is typing...")
    var typingIndicatorText: String? {
        guard !typingUsers.isEmpty else { return nil }
        let names = Array(typingUsers.values)
        if names.count == 1 {
            return String(localized: "chat_typing_single \(names[0])", bundle: L10n.bundle)
        } else {
            return String(localized: "chat_typing_multiple", bundle: L10n.bundle)
        }
    }

    // MARK: - Lifecycle

    /// Loads message history, connects socket, and starts listening for real-time events.
    /// Falls back to REST polling if the socket fails to connect.
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
        self.authToken = authToken
        self.chatService = chatService
        self.socketService = socketService

        // Load initial message history via REST (reliable baseline)
        isLoading = true
        do {
            messages = try await chatService.fetchMessages(roomId: roomId, limit: Constants.Chat.messagePageSize)
        } catch {
            self.error = error
        }
        isLoading = false

        // Attempt socket connection
        socketService.connect(userId: userId, displayName: displayName, authToken: authToken)

        // Wait for socket to connect (up to ~5 seconds)
        var connected = false
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if socketService.isConnected {
                connected = true
                break
            }
        }

        if connected {
            // Real-time path — join room and start stream listeners
            socketService.joinRoom(roomId: roomId, userId: userId)
            startSocketListeners()
            isUsingSocket = true
            print("💬 ChatRoomViewModel: Using Socket.IO for room \(roomId)")
        } else {
            // Fallback — socket failed, use REST polling
            isUsingSocket = false
            startPolling()
            print("💬 ChatRoomViewModel: Socket unavailable, falling back to REST polling")
        }

        // Listen for connection state changes to switch between socket and polling
        startConnectionListener()
    }

    /// Stops all listeners, leaves the room, and disconnects the socket.
    func stop() {
        // Cancel all background tasks
        pollingTask?.cancel()
        pollingTask = nil
        socketListenerTask?.cancel()
        socketListenerTask = nil
        typingListenerTask?.cancel()
        typingListenerTask = nil
        connectionListenerTask?.cancel()
        connectionListenerTask = nil
        typingDebounceTask?.cancel()
        typingDebounceTask = nil

        // Stop typing indicator if active
        if isLocallyTyping, let roomId, let userId = currentUserId, let displayName = currentDisplayName {
            socketService?.sendTyping(roomId: roomId, userId: userId, displayName: displayName, isTyping: false)
        }
        isLocallyTyping = false

        // Leave room and disconnect socket
        if let roomId, let userId = currentUserId {
            socketService?.leaveRoom(roomId: roomId, userId: userId)
        }
        socketService?.disconnect()
    }

    // MARK: - Socket Listeners

    /// Starts background tasks that iterate over the socket's AsyncStreams.
    private func startSocketListeners() {
        guard let socketService else { return }

        // Cancel any existing listeners before starting new ones
        socketListenerTask?.cancel()
        typingListenerTask?.cancel()

        // Listen for incoming messages
        socketListenerTask = Task { [weak self] in
            for await message in socketService.incomingMessages {
                guard let self, !Task.isCancelled else { break }
                guard message.roomId == self.roomId else { continue }

                // Deduplicate: skip if we already have this message
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                }
            }

            // Stream ended (socket disconnected) — attempt reconnect before polling
            guard let self, !Task.isCancelled else { return }
            self.isUsingSocket = false

            print("💬 ChatRoomViewModel: Socket stream ended, attempting reconnect...")
            self.socketService?.reconnect()

            // Wait up to 3 seconds for reconnect
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            if self.socketService?.isConnected == true, !Task.isCancelled {
                // Reconnected — re-join room and restart listeners
                if let roomId = self.roomId, let userId = self.currentUserId {
                    self.socketService?.joinRoom(roomId: roomId, userId: userId)
                }
                self.isUsingSocket = true
                self.startSocketListeners()
                print("💬 ChatRoomViewModel: Reconnected to Socket.IO")
            } else if !Task.isCancelled {
                // Reconnect failed — fall back to polling
                print("💬 ChatRoomViewModel: Reconnect failed, falling back to REST polling")
                self.startPolling()
            }
        }

        // Listen for typing indicators
        typingListenerTask = Task { [weak self] in
            for await (userId, displayName, isTyping) in socketService.typingIndicators {
                guard let self, !Task.isCancelled else { break }

                // Ignore own typing echoes
                guard userId != self.currentUserId else { continue }

                if isTyping {
                    self.typingUsers[userId] = displayName
                } else {
                    self.typingUsers.removeValue(forKey: userId)
                }
            }
        }
    }

    /// Listens for socket connection state changes to switch between socket and polling.
    private func startConnectionListener() {
        guard let socketService else { return }

        connectionListenerTask = Task { [weak self] in
            for await connected in socketService.connectionStateChanges {
                guard let self, !Task.isCancelled else { break }

                if connected && !self.isUsingSocket {
                    // Socket reconnected — switch from polling to socket
                    self.pollingTask?.cancel()
                    self.pollingTask = nil

                    if let roomId = self.roomId, let userId = self.currentUserId {
                        socketService.joinRoom(roomId: roomId, userId: userId)
                    }
                    self.startSocketListeners()
                    self.isUsingSocket = true
                    print("💬 ChatRoomViewModel: Socket reconnected, switched from polling to socket")
                } else if !connected && self.isUsingSocket {
                    self.isUsingSocket = false
                }
            }
        }
    }

    // MARK: - Polling (REST Fallback)

    /// Periodically fetches messages from REST API to pick up new messages.
    private func startPolling() {
        pollingTask?.cancel()
        isUsingSocket = false
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.pollingInterval ?? 3) * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.pollMessages()
            }
        }
    }

    /// Fetches latest messages and merges with existing list.
    private func pollMessages() async {
        guard let roomId = roomId, let chatService = chatService else { return }

        do {
            let fetched = try await chatService.fetchMessages(roomId: roomId, limit: Constants.Chat.messagePageSize)

            // Merge: replace entire list to pick up edits/deletes too
            // Only update if there are actual changes to avoid unnecessary SwiftUI redraws
            if fetched.count != messages.count || fetched.map(\.id) != messages.map(\.id) {
                messages = fetched
            } else {
                // Same IDs — check if any message content changed (edits/deletes)
                for (index, msg) in fetched.enumerated() {
                    if index < messages.count,
                       msg.message != messages[index].message || msg.deleted != messages[index].deleted {
                        messages = fetched
                        break
                    }
                }
            }
        } catch {
            // Silently ignore polling errors to avoid spamming the user
            #if DEBUG
            print("⚠️ ChatRoomViewModel: Polling error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Actions

    /// Sends the current message text via Socket.IO (preferred) or REST (fallback).
    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let roomId = roomId,
              let userId = currentUserId,
              let displayName = currentDisplayName else { return }

        messageText = ""

        // Stop typing indicator
        if isLocallyTyping {
            isLocallyTyping = false
            typingDebounceTask?.cancel()
            socketService?.sendTyping(roomId: roomId, userId: userId, displayName: displayName, isTyping: false)
        }

        if socketService?.isConnected == true {
            // Real-time path: send via socket
            // Server broadcasts new-message back to all participants (including sender),
            // which our socketListenerTask picks up and appends to messages.
            socketService?.sendMessage(roomId: roomId, userId: userId, displayName: displayName, message: text)
        } else {
            // REST fallback
            do {
                let request = SendMessageRequest(message: text, userId: userId, displayName: displayName)
                _ = try await chatService?.sendMessage(roomId: roomId, request: request)
                await pollMessages()
            } catch {
                self.error = error
            }
        }
    }

    /// Called when the user's input text changes — emits typing indicators via socket.
    func onTypingChanged() {
        guard let roomId, let userId = currentUserId, let displayName = currentDisplayName,
              socketService?.isConnected == true else { return }

        // Cancel previous debounce
        typingDebounceTask?.cancel()

        // Emit typing = true if not already
        if !isLocallyTyping {
            isLocallyTyping = true
            socketService?.sendTyping(roomId: roomId, userId: userId, displayName: displayName, isTyping: true)
        }

        // Debounce: stop typing after inactivity
        typingDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Constants.Chat.typingDebounceNs)
            guard let self, !Task.isCancelled else { return }
            self.isLocallyTyping = false
            self.socketService?.sendTyping(roomId: roomId, userId: userId, displayName: displayName, isTyping: false)
        }
    }

    /// Edits a message via REST API.
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

    /// Soft-deletes a message via REST API.
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
