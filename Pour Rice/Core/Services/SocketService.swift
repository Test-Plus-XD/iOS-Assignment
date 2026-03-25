//
//  SocketService.swift
//  Pour Rice
//
//  Socket.IO client using the socket.io-client-swift library
//  Handles real-time chat messaging, typing indicators, and presence
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  FLUTTER EQUIVALENT: socket_io_client package with IO.io() factory
//
//  KEY IOS DIFFERENCES:
//  - SocketManager + SocketIOClient = IO.io() from socket_io_client
//  - socket.on("event") { data, _ in } = socket.on("event", (data) { })
//  - AsyncStream = StreamController.broadcast()
//  - @MainActor = ensures UI updates on main thread (like setState in Flutter)
//  ============================================================================
//

import Foundation
import SocketIO

/// Service for real-time Socket.IO communication with the Railway chat server
@MainActor
final class SocketService {

    // MARK: - Properties

    /// Whether the socket is currently connected
    private(set) var isConnected = false

    /// Whether the user has been successfully registered with the server
    private(set) var isRegistered = false

    /// Socket.IO manager (owns the connection lifecycle)
    private var manager: SocketManager?

    /// The default namespace socket client
    private var socket: SocketIOClient?

    /// Continuation for the incoming messages stream
    private var messageContinuation: AsyncStream<ChatMessage>.Continuation?

    /// Continuation for typing indicator updates
    private var typingContinuation: AsyncStream<(userId: String, displayName: String, isTyping: Bool)>.Continuation?

    /// Continuation for connection state changes
    private var connectionStateContinuation: AsyncStream<Bool>.Continuation?

    /// Stored connection credentials for reconnection
    private var lastUserId: String?
    private var lastDisplayName: String?
    private var lastAuthToken: String?

    // MARK: - Streams

    /// Stream of incoming chat messages (from Socket.IO 'new-message' events).
    /// Recreated on each `connect()` call so the stream is fresh for each session.
    private(set) var incomingMessages: AsyncStream<ChatMessage> = AsyncStream { _ in }

    /// Stream of typing indicator updates.
    /// Recreated on each `connect()` call so the stream is fresh for each session.
    private(set) var typingIndicators: AsyncStream<(userId: String, displayName: String, isTyping: Bool)> = AsyncStream { _ in }

    /// Stream of connection state changes (true = connected, false = disconnected).
    /// Used by ChatRoomViewModel to switch between socket and polling modes.
    private(set) var connectionStateChanges: AsyncStream<Bool> = AsyncStream { _ in }

    // MARK: - Connection

    /// Connects to the Socket.IO server and registers the user.
    func connect(userId: String, displayName: String, authToken: String) {
        guard !isConnected else { return }

        // Store credentials for reconnection
        lastUserId = userId
        lastDisplayName = displayName
        lastAuthToken = authToken

        // Reset registration state
        isRegistered = false

        // Create fresh AsyncStreams for this connection session
        incomingMessages = AsyncStream { continuation in
            self.messageContinuation = continuation
        }
        typingIndicators = AsyncStream { continuation in
            self.typingContinuation = continuation
        }
        connectionStateChanges = AsyncStream { continuation in
            self.connectionStateContinuation = continuation
        }

        // Configure Socket.IO manager
        guard let url = URL(string: Constants.Chat.socketURL) else {
            print("❌ SocketService: Invalid URL")
            return
        }

        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectAttempts(5),
            .reconnectWait(2)
        ])

        socket = manager?.defaultSocket

        // Set up event listeners before connecting
        setupEventListeners(userId: userId, displayName: displayName, authToken: authToken)

        // Connect
        socket?.connect()
        print("🔌 SocketService: Connecting to \(Constants.Chat.socketURL)...")
    }

    /// Disconnects from the Socket.IO server.
    func disconnect() {
        socket?.disconnect()
        socket?.removeAllHandlers()
        manager?.disconnect()
        manager = nil
        socket = nil

        let wasConnected = isConnected
        isConnected = false
        isRegistered = false

        // Finish streams so any `for await` loops exit cleanly
        messageContinuation?.finish()
        messageContinuation = nil
        typingContinuation?.finish()
        typingContinuation = nil

        // Notify observers of disconnection
        if wasConnected {
            connectionStateContinuation?.yield(false)
        }

        print("🔌 SocketService: Disconnected")
    }

    /// Attempts to reconnect using stored credentials.
    /// Call after a disconnect to re-establish the socket connection.
    func reconnect() {
        guard !isConnected,
              let userId = lastUserId,
              let displayName = lastDisplayName,
              let authToken = lastAuthToken else { return }

        // Clean up old connection state without finishing the connection state stream
        socket?.disconnect()
        socket?.removeAllHandlers()
        manager?.disconnect()
        manager = nil
        socket = nil
        isRegistered = false
        messageContinuation?.finish()
        messageContinuation = nil
        typingContinuation?.finish()
        typingContinuation = nil

        // Re-connect with stored credentials
        print("🔄 SocketService: Attempting reconnect...")
        connect(userId: userId, displayName: displayName, authToken: authToken)
    }

    // MARK: - Room Operations

    /// Joins a chat room to receive its broadcasts.
    func joinRoom(roomId: String, userId: String) {
        socket?.emit("join-room", ["roomId": roomId, "userId": userId])
    }

    /// Leaves a chat room.
    func leaveRoom(roomId: String, userId: String) {
        socket?.emit("leave-room", ["roomId": roomId, "userId": userId])
    }

    // MARK: - Messaging

    /// Sends a message via Socket.IO (preferred real-time path).
    func sendMessage(roomId: String, userId: String, displayName: String, message: String, imageUrl: String? = nil) {
        var data: [String: Any] = [
            "roomId": roomId,
            "userId": userId,
            "displayName": displayName,
            "message": message
        ]
        if let imageUrl = imageUrl {
            data["imageUrl"] = imageUrl
        }
        socket?.emit("send-message", data)
    }

    /// Sends a typing indicator.
    func sendTyping(roomId: String, userId: String, displayName: String, isTyping: Bool) {
        socket?.emit("typing", [
            "roomId": roomId,
            "userId": userId,
            "displayName": displayName,
            "isTyping": isTyping
        ])
    }

    // MARK: - Private — Event Listeners

    /// Sets up all Socket.IO event listeners.
    private func setupEventListeners(userId: String, displayName: String, authToken: String) {
        guard let socket else { return }

        // Connection established
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isConnected = true
                self.connectionStateContinuation?.yield(true)
                print("✅ SocketService: Connected")

                // Register with server immediately after connection
                socket.emit("register", [
                    "userId": userId,
                    "displayName": displayName,
                    "authToken": authToken
                ])
            }
        }

        // Disconnection
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isConnected = false
                self.isRegistered = false
                self.connectionStateContinuation?.yield(false)
                print("🔌 SocketService: Connection lost")
            }
        }

        // Connection error
        socket.on(clientEvent: .error) { _, _ in
            print("❌ SocketService: Connection error")
        }

        // Registration response
        socket.on("registered") { [weak self] data, _ in
            Task { @MainActor in
                guard let self,
                      let dict = data.first as? [String: Any],
                      let success = dict["success"] as? Bool else { return }
                self.isRegistered = success
                print("🔑 SocketService: Registration \(success ? "successful" : "failed")")
            }
        }

        // New message received
        socket.on("new-message") { [weak self] data, _ in
            Task { @MainActor in
                guard let self,
                      let dict = data.first as? [String: Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                      let message = try? JSONDecoder.iso8601Decoder.decode(ChatMessage.self, from: jsonData) else { return }
                self.messageContinuation?.yield(message)
            }
        }

        // Typing indicator
        socket.on("user-typing") { [weak self] data, _ in
            Task { @MainActor in
                guard let self,
                      let dict = data.first as? [String: Any],
                      let uid = dict["userId"] as? String,
                      let name = dict["displayName"] as? String,
                      let typing = dict["isTyping"] as? Bool else { return }
                self.typingContinuation?.yield((userId: uid, displayName: name, isTyping: typing))
            }
        }

        // Room join confirmation
        socket.on("joined-room") { data, _ in
            if let dict = data.first as? [String: Any],
               let roomId = dict["roomId"] as? String {
                print("🚪 SocketService: Joined room \(roomId)")
            }
        }

        // Message delivery confirmation
        socket.on("message-sent") { data, _ in
            if let dict = data.first as? [String: Any],
               let success = dict["success"] as? Bool {
                if success {
                    let msgId = dict["messageId"] as? String ?? "unknown"
                    print("📨 SocketService: Message delivered (\(msgId))")
                } else {
                    let error = dict["error"] as? String ?? "unknown"
                    print("❌ SocketService: Message delivery failed: \(error)")
                }
            }
        }
    }
}

// MARK: - JSONDecoder Extension

private extension JSONDecoder {
    /// Decoder configured for ISO 8601 date strings from the API.
    static let iso8601Decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
