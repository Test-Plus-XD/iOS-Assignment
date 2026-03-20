//
//  SocketService.swift
//  Pour Rice
//
//  Lightweight Socket.IO v4 client using native URLSessionWebSocketTask
//  Handles real-time chat messaging, typing indicators, and presence
//
//  Socket.IO v4 wire format (Engine.IO v4):
//  - "0"           → Engine.IO open (server sends sid, pingInterval, etc.)
//  - "2"           → Engine.IO ping (server → client)
//  - "3"           → Engine.IO pong (client → server, reply to ping)
//  - "40"          → Socket.IO connect to default namespace
//  - "42[...]"     → Socket.IO event with JSON array payload
//

import Foundation

/// Service for real-time Socket.IO communication with the Railway chat server
@MainActor
final class SocketService {

    // MARK: - Properties

    /// Whether the socket is currently connected
    private(set) var isConnected = false

    /// WebSocket task for the current connection
    private var webSocketTask: URLSessionWebSocketTask?

    /// Continuation for the incoming messages stream
    private var messageContinuation: AsyncStream<ChatMessage>.Continuation?

    /// Continuation for typing indicator updates
    private var typingContinuation: AsyncStream<(userId: String, displayName: String, isTyping: Bool)>.Continuation?

    /// Background task for receiving messages
    private var receiveTask: Task<Void, Never>?

    /// Ping timer task
    private var pingTask: Task<Void, Never>?

    /// Ping interval from server handshake (default 25s)
    private var pingInterval: TimeInterval = 25

    // MARK: - Streams

    /// Stream of incoming chat messages (from Socket.IO 'new-message' events)
    lazy var incomingMessages: AsyncStream<ChatMessage> = {
        AsyncStream { continuation in
            self.messageContinuation = continuation
        }
    }()

    /// Stream of typing indicator updates
    lazy var typingIndicators: AsyncStream<(userId: String, displayName: String, isTyping: Bool)> = {
        AsyncStream { continuation in
            self.typingContinuation = continuation
        }
    }()

    // MARK: - Connection

    /// Connects to the Socket.IO server and registers the user.
    func connect(userId: String, displayName: String, authToken: String) {
        guard !isConnected else { return }

        // Socket.IO v4 initial connection uses HTTP polling, then upgrades to WebSocket.
        // For simplicity, connect directly to the WebSocket transport.
        let socketURL = Constants.Chat.socketURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let urlString = "\(socketURL)/socket.io/?EIO=4&transport=websocket"

        guard let url = URL(string: urlString) else {
            print("❌ SocketService: Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        // Set Origin header required by Socket.IO CORS validation
        request.setValue(Constants.Chat.socketURL, forHTTPHeaderField: "Origin")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Start receiving messages
        receiveTask = Task { [weak self] in
            await self?.receiveLoop(userId: userId, displayName: displayName, authToken: authToken)
        }

        print("🔌 SocketService: Connecting to \(socketURL)...")
    }

    /// Disconnects from the Socket.IO server.
    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        print("🔌 SocketService: Disconnected")
    }

    // MARK: - Room Operations

    /// Joins a chat room to receive its broadcasts.
    func joinRoom(roomId: String, userId: String) {
        emit(event: "join-room", data: ["roomId": roomId, "userId": userId])
    }

    /// Leaves a chat room.
    func leaveRoom(roomId: String, userId: String) {
        emit(event: "leave-room", data: ["roomId": roomId, "userId": userId])
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
        emit(event: "send-message", data: data)
    }

    /// Sends a typing indicator.
    func sendTyping(roomId: String, userId: String, displayName: String, isTyping: Bool) {
        emit(event: "typing", data: [
            "roomId": roomId,
            "userId": userId,
            "displayName": displayName,
            "isTyping": isTyping
        ])
    }

    // MARK: - Private — Socket.IO Protocol

    /// Main receive loop — processes incoming WebSocket frames.
    private func receiveLoop(userId: String, displayName: String, authToken: String) async {
        guard let ws = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await ws.receive()

                switch message {
                case .string(let text):
                    await handlePacket(text, userId: userId, displayName: displayName, authToken: authToken)
                case .data:
                    break // Binary frames not used
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    print("❌ SocketService: Receive error: \(error.localizedDescription)")
                    isConnected = false
                }
                break
            }
        }
    }

    /// Parses and handles Engine.IO / Socket.IO packets.
    private func handlePacket(_ packet: String, userId: String, displayName: String, authToken: String) async {
        if packet.hasPrefix("0") {
            // Engine.IO open — parse pingInterval
            if let jsonStart = packet.firstIndex(of: "{"),
               let data = packet[jsonStart...].data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let interval = json["pingInterval"] as? Double {
                pingInterval = interval / 1000.0
            }

            // Send Socket.IO connect to default namespace
            send(raw: "40")
        } else if packet == "2" {
            // Engine.IO ping → respond with pong
            send(raw: "3")
        } else if packet.hasPrefix("40") {
            // Socket.IO connected — register the user
            isConnected = true
            print("✅ SocketService: Connected")

            emit(event: "register", data: [
                "userId": userId,
                "displayName": displayName,
                "authToken": authToken
            ])

            // Start ping timer
            startPingTimer()
        } else if packet.hasPrefix("42") {
            // Socket.IO event
            handleEvent(packet)
        }
    }

    /// Parses a Socket.IO event packet (42["eventName", {payload}]).
    private func handleEvent(_ packet: String) {
        let jsonString = String(packet.dropFirst(2)) // Remove "42" prefix
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let eventName = array.first as? String else {
            return
        }

        let payload = array.count > 1 ? array[1] : nil

        switch eventName {
        case "new-message":
            if let dict = payload as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: dict),
               let message = try? JSONDecoder.iso8601Decoder.decode(ChatMessage.self, from: jsonData) {
                messageContinuation?.yield(message)
            }

        case "user-typing":
            if let dict = payload as? [String: Any],
               let uid = dict["userId"] as? String,
               let name = dict["displayName"] as? String,
               let isTyping = dict["isTyping"] as? Bool {
                typingContinuation?.yield((userId: uid, displayName: name, isTyping: isTyping))
            }

        case "registered":
            if let dict = payload as? [String: Any],
               let success = dict["success"] as? Bool {
                print("🔑 SocketService: Registration \(success ? "successful" : "failed")")
            }

        case "joined-room":
            if let dict = payload as? [String: Any],
               let roomId = dict["roomId"] as? String {
                print("🚪 SocketService: Joined room \(roomId)")
            }

        default:
            break
        }
    }

    /// Emits a Socket.IO event (42["eventName", {payload}]).
    private func emit(event: String, data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let packet = "42[\"\(event)\",\(jsonString)]"
        send(raw: packet)
    }

    /// Sends a raw string frame over the WebSocket.
    private func send(raw: String) {
        webSocketTask?.send(.string(raw)) { error in
            if let error = error {
                print("❌ SocketService: Send error: \(error.localizedDescription)")
            }
        }
    }

    /// Starts a periodic ping to keep the connection alive.
    private func startPingTimer() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.pingInterval ?? 25) * 1_000_000_000))
                self?.send(raw: "3")
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
