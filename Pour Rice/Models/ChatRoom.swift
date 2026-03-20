//
//  ChatRoom.swift
//  Pour Rice
//
//  Data models for real-time chat functionality
//  Supports both REST persistence and Socket.IO real-time messaging
//

import Foundation

// MARK: - Chat Room

/// Represents a chat conversation between users
/// Can be a direct (1-on-1) or group conversation
struct ChatRoom: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the chat room
    let id: String

    /// Array of participant user IDs
    let participants: [String]

    /// Display name for the room
    let roomName: String?

    /// Room type: "direct" for 1-on-1, "group" for multi-participant
    let type: String

    /// User ID of the room creator
    let createdBy: String?

    /// Date when the room was created
    let createdAt: Date?

    /// Preview text of the most recent message
    let lastMessage: String?

    /// Timestamp of the most recent message
    let lastMessageAt: Date?

    /// Total number of messages in the room
    let messageCount: Int

    /// Enriched participant user profiles (from API)
    let participantsData: [ChatParticipant]?

    /// Recent messages cached with the room (from /API/Chat/Records/:uid)
    let recentMessages: [ChatMessage]?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id = "roomId"
        case participants
        case roomName
        case type
        case createdBy
        case createdAt
        case lastMessage
        case lastMessageAt
        case messageCount
        case participantsData
        case recentMessages
    }

    // MARK: - Custom Decoding

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id               = try c.decode(String.self, forKey: .id)
        participants     = try c.decodeIfPresent([String].self, forKey: .participants) ?? []
        roomName         = try c.decodeIfPresent(String.self, forKey: .roomName)
        type             = try c.decodeIfPresent(String.self, forKey: .type) ?? "direct"
        createdBy        = try c.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt        = try? c.decode(Date.self, forKey: .createdAt)
        lastMessage      = try c.decodeIfPresent(String.self, forKey: .lastMessage)
        lastMessageAt    = try? c.decode(Date.self, forKey: .lastMessageAt)
        messageCount     = try c.decodeIfPresent(Int.self, forKey: .messageCount) ?? 0
        participantsData = try c.decodeIfPresent([ChatParticipant].self, forKey: .participantsData)
        recentMessages   = try c.decodeIfPresent([ChatMessage].self, forKey: .recentMessages)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        participants: [String] = [],
        roomName: String? = nil,
        type: String = "direct",
        createdBy: String? = nil,
        createdAt: Date? = nil,
        lastMessage: String? = nil,
        lastMessageAt: Date? = nil,
        messageCount: Int = 0,
        participantsData: [ChatParticipant]? = nil,
        recentMessages: [ChatMessage]? = nil
    ) {
        self.id = id
        self.participants = participants
        self.roomName = roomName
        self.type = type
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
        self.participantsData = participantsData
        self.recentMessages = recentMessages
    }

    // MARK: - Factory

    /// Creates a placeholder room used as a navigation value before the room is loaded.
    /// ChatRoomView creates or fetches the real room on appear using the roomId.
    static func placeholder(roomId: String, name: String) -> ChatRoom {
        ChatRoom(id: roomId, roomName: name, type: "direct")
    }

    // MARK: - Computed Properties

    /// Relative timestamp for the last message (e.g. "5m ago", "2d ago")
    var lastMessageRelativeTime: String? {
        guard let date = lastMessageAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Chat Participant

/// Lightweight participant profile embedded in chat room responses
struct ChatParticipant: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String?
    let email: String?
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id = "uid"
        case displayName
        case email
        case photoURL
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        email       = try c.decodeIfPresent(String.self, forKey: .email)
        photoURL    = try c.decodeIfPresent(String.self, forKey: .photoURL)
    }

    init(id: String, displayName: String? = nil, email: String? = nil, photoURL: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
    }
}

// MARK: - Chat Message

/// Represents a single message in a chat room
/// Supports text messages with edit and soft-delete capabilities
struct ChatMessage: Codable, Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique message identifier
    let id: String

    /// ID of the room this message belongs to
    let roomId: String?

    /// ID of the user who sent the message
    let userId: String

    /// Display name of the sender
    let displayName: String

    /// Message text content
    var message: String

    /// Message timestamp
    let timestamp: Date

    /// Whether the message has been edited
    let edited: Bool

    /// Whether the message has been soft-deleted
    let deleted: Bool

    /// Optional image URL attached to the message
    let imageUrl: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id = "messageId"
        case roomId
        case userId
        case displayName
        case message
        case timestamp
        case edited
        case deleted
        case imageUrl
    }

    // MARK: - Custom Decoding

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id          = try c.decode(String.self, forKey: .id)
        roomId      = try c.decodeIfPresent(String.self, forKey: .roomId)
        userId      = try c.decode(String.self, forKey: .userId)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        message     = try c.decode(String.self, forKey: .message)
        timestamp   = (try? c.decode(Date.self, forKey: .timestamp)) ?? Date()
        edited      = try c.decodeIfPresent(Bool.self, forKey: .edited) ?? false
        deleted     = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        imageUrl    = try c.decodeIfPresent(String.self, forKey: .imageUrl)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        roomId: String? = nil,
        userId: String,
        displayName: String,
        message: String,
        timestamp: Date = Date(),
        edited: Bool = false,
        deleted: Bool = false,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.roomId = roomId
        self.userId = userId
        self.displayName = displayName
        self.message = message
        self.timestamp = timestamp
        self.edited = edited
        self.deleted = deleted
        self.imageUrl = imageUrl
    }

    // MARK: - Computed Properties

    /// Whether this message was sent by the given user
    func isFromUser(_ uid: String) -> Bool { userId == uid }

    /// Display text, showing "[Message deleted]" for soft-deleted messages
    var displayText: String {
        deleted ? String(localized: "chat_message_deleted") : message
    }

    /// Formatted timestamp for display (e.g. "14:30")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Request Models

/// Request body for POST /API/Chat/Rooms
struct CreateRoomRequest: Codable, Sendable {
    let participants: [String]
    let roomName: String
    let type: String
    let roomId: String?

    init(participants: [String], roomName: String, type: String = "direct", roomId: String? = nil) {
        self.participants = participants
        self.roomName = roomName
        self.type = type
        self.roomId = roomId
    }
}

/// Request body for POST /API/Chat/Rooms/:roomId/Messages
struct SendMessageRequest: Codable, Sendable {
    let message: String
    let userId: String
    let displayName: String
}

// MARK: - Response Models

/// Response for GET /API/Chat/Records/:uid
struct ChatRecordsResponse: Codable, Sendable {
    let userId: String
    let totalRooms: Int
    let rooms: [ChatRoom]
}

/// Response for room creation
struct CreateRoomResponse: Codable, Sendable {
    let roomId: String
    let message: String?
}

/// Response for message list — API returns { "roomId": "...", "count": N, "messages": [...] }
struct ChatMessagesResponse: Codable, Sendable {
    let messages: [ChatMessage]
}
