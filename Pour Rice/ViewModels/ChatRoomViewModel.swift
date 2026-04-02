//
//  ChatRoomViewModel.swift
//  Pour Rice
//
//  ViewModel for an individual chat room conversation
//  Uses Socket.IO for real-time messaging with REST polling as fallback
//  Supports image attachments with live upload-progress tracking
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
import UIKit

// MARK: - PendingAttachment

/// Represents an image selected by the user that is being (or has been) uploaded.
/// Held in `ChatRoomViewModel.pendingAttachments` until the message is sent or the room is exited.
@MainActor @Observable
final class PendingAttachment: Identifiable {

    /// Stable identity for SwiftUI `ForEach`
    let id = UUID()

    /// Thumbnail shown in the attachment strip (full resolution not needed)
    let thumbnail: UIImage

    /// Upload progress 0.0–1.0 (only meaningful while `isUploading`)
    var progress: Double = 0

    /// Public CDN URL set once the upload completes successfully
    var imageUrl: String?

    /// Server-side file path returned alongside `imageUrl`, used for deletion on exit
    var filePath: String?

    /// Set to true if the upload failed (allows user to cancel and re-attach)
    var failed = false

    /// True while the upload is still in flight (no URL yet and not failed)
    var isUploading: Bool { imageUrl == nil && !failed }

    init(thumbnail: UIImage) {
        self.thumbnail = thumbnail
    }
}

// MARK: - ChatRoomViewModel

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

    // MARK: - Image Attachments

    /// Images selected by the user, ordered by selection time.
    /// Each entry progresses through: uploading → ready (imageUrl set) → sent (removed)
    var pendingAttachments: [PendingAttachment] = []

    // MARK: - Toast

    /// Toast message to display
    var toastMessage = ""

    /// Toast visual style
    var toastStyle: ToastStyle = .info

    /// Whether the toast is currently visible
    var showToast = false

    // MARK: - Dependencies

    private var chatService: ChatService?
    private var socketService: SocketService?
    private var imageUploadService: ImageUploadService?
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
        socketService: SocketService,
        imageUploadService: ImageUploadService
    ) async {
        self.roomId = roomId
        self.currentUserId = userId
        self.currentDisplayName = displayName
        self.authToken = authToken
        self.chatService = chatService
        self.socketService = socketService
        self.imageUploadService = imageUploadService

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

        // Wait for socket to register (up to ~5 seconds)
        // Must wait for isRegistered, not just isConnected, because the server
        // rejects join-room requests from unregistered sockets
        var registered = false
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if socketService.isRegistered {
                registered = true
                break
            }
        }

        if registered {
            // Real-time path — join room and start stream listeners
            socketService.joinRoom(roomId: roomId, userId: userId)
            startSocketListeners()
            isUsingSocket = true
            showToast(String(localized: "toast_chat_connected", bundle: L10n.bundle), .success)
            print("💬 ChatRoomViewModel: Using Socket.IO for room \(roomId)")
        } else {
            // Fallback — socket failed, use REST polling
            isUsingSocket = false
            startPolling()
            showToast(String(localized: "toast_chat_offline_mode", bundle: L10n.bundle), .info)
            print("💬 ChatRoomViewModel: Socket unavailable, falling back to REST polling")
        }

        // Listen for connection state changes to switch between socket and polling
        startConnectionListener()
    }

    /// Stops all listeners, leaves the room, disconnects the socket,
    /// and schedules cleanup of any unsent uploaded images.
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

        // Delete any uploaded-but-unsent attachments (fire-and-forget)
        Task { await self.deleteUnsentAttachments() }
    }

    // MARK: - Image Attachments

    /// Compresses each image to JPEG, creates a PendingAttachment, and begins uploading concurrently.
    func addImages(_ images: [UIImage]) async {
        for image in images {
            let attachment = PendingAttachment(thumbnail: image)
            pendingAttachments.append(attachment)

            // Start upload in a detached task so all images upload concurrently
            Task {
                await uploadAttachment(attachment, image: image)
            }
        }
    }

    /// Removes the attachment from the strip. The already-uploaded file is intentionally
    /// left on the server — the user may re-attach it without re-uploading.
    /// Definitive cleanup happens in `deleteUnsentAttachments()` on room exit.
    func cancelAttachment(_ attachment: PendingAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
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

            if self.socketService?.isRegistered == true, !Task.isCancelled {
                // Reconnected — re-join room and restart listeners
                if let roomId = self.roomId, let userId = self.currentUserId {
                    self.socketService?.joinRoom(roomId: roomId, userId: userId)
                }
                self.isUsingSocket = true
                self.startSocketListeners()
                self.showToast(String(localized: "toast_chat_reconnected", bundle: L10n.bundle), .success)
                print("💬 ChatRoomViewModel: Reconnected to Socket.IO")
            } else if !Task.isCancelled {
                // Reconnect failed — fall back to polling
                self.showToast(String(localized: "toast_chat_offline_mode", bundle: L10n.bundle), .info)
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
                    // Socket reconnected — wait for registration before joining room
                    var didRegister = false
                    for _ in 0..<30 {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        if socketService.isRegistered {
                            didRegister = true
                            break
                        }
                    }

                    guard didRegister, !Task.isCancelled else { continue }

                    // Switch from polling to socket
                    self.pollingTask?.cancel()
                    self.pollingTask = nil

                    if let roomId = self.roomId, let userId = self.currentUserId {
                        socketService.joinRoom(roomId: roomId, userId: userId)
                    }
                    self.startSocketListeners()
                    self.isUsingSocket = true
                    self.showToast(String(localized: "toast_chat_reconnected", bundle: L10n.bundle), .success)
                    print("💬 ChatRoomViewModel: Socket reconnected, switched from polling to socket")
                } else if !connected && self.isUsingSocket {
                    self.isUsingSocket = false
                    self.showToast(String(localized: "toast_chat_connection_lost", bundle: L10n.bundle), .info)
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

    /// Sends the current message text (and any ready image attachments) via Socket.IO.
    /// Images require an active socket connection — they cannot be sent via the REST fallback.
    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let readyAttachments = pendingAttachments.filter { $0.imageUrl != nil && !$0.failed }

        guard !text.isEmpty || !readyAttachments.isEmpty,
              let roomId = roomId,
              let userId = currentUserId,
              let displayName = currentDisplayName else { return }

        // Images can only be sent via socket (no imageUrl field in SendMessageRequest)
        if !readyAttachments.isEmpty && socketService?.isConnected != true {
            showToast(
                String(localized: "toast_chat_images_require_connection", bundle: L10n.bundle),
                .info
            )
            // Still allow sending the text portion via REST if there is text
            if text.isEmpty { return }
        }

        messageText = ""

        // Stop typing indicator
        if isLocallyTyping {
            isLocallyTyping = false
            typingDebounceTask?.cancel()
            socketService?.sendTyping(roomId: roomId, userId: userId, displayName: displayName, isTyping: false)
        }

        if socketService?.isConnected == true {
            // Real-time path — send via socket
            // Server broadcasts new-message back to all participants (including sender),
            // which our socketListenerTask picks up and appends to messages.

            if readyAttachments.isEmpty {
                // Text-only message (unchanged path)
                socketService?.sendMessage(roomId: roomId, userId: userId, displayName: displayName, message: text)
            } else {
                // First message carries the text + first image
                socketService?.sendMessage(
                    roomId: roomId,
                    userId: userId,
                    displayName: displayName,
                    message: text,
                    imageUrl: readyAttachments[0].imageUrl
                )
                // Each additional image is a separate message with empty text
                for attachment in readyAttachments.dropFirst() {
                    socketService?.sendMessage(
                        roomId: roomId,
                        userId: userId,
                        displayName: displayName,
                        message: "",
                        imageUrl: attachment.imageUrl
                    )
                }
            }

            // Clear attachment strip after successful socket send
            pendingAttachments.removeAll()

        } else {
            // REST fallback — text only (images already blocked above if present)
            do {
                let request = SendMessageRequest(message: text, userId: userId, displayName: displayName)
                _ = try await chatService?.sendMessage(roomId: roomId, request: request)
                await pollMessages()
            } catch {
                self.error = error
                showToast(String(localized: "toast_chat_send_failed", bundle: L10n.bundle), .error)
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
            showToast(String(localized: "toast_chat_message_edited", bundle: L10n.bundle), .success)
        } catch {
            self.error = error
            showToast(String(localized: "toast_chat_edit_failed", bundle: L10n.bundle), .error)
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
            showToast(String(localized: "toast_chat_message_deleted", bundle: L10n.bundle), .success)
        } catch {
            self.error = error
            showToast(String(localized: "toast_chat_delete_failed", bundle: L10n.bundle), .error)
        }
    }

    // MARK: - Private Helpers

    /// Compresses and uploads a single image attachment, updating its progress live.
    private func uploadAttachment(_ attachment: PendingAttachment, image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            attachment.failed = true
            return
        }

        let filename = "chat_\(UUID().uuidString).jpg"

        do {
            let result = try await imageUploadService?.uploadChatImage(
                imageData,
                mimeType: "image/jpeg",
                filename: filename
            ) { [weak attachment] progress in
                attachment?.progress = progress
            }
            attachment.imageUrl = result?.imageUrl
            attachment.filePath = result?.filePath
            attachment.progress = 1.0
            print("📸 ChatRoomViewModel: Uploaded attachment \(filename)")
        } catch {
            attachment.failed = true
            print("❌ ChatRoomViewModel: Upload failed for \(filename): \(error.localizedDescription)")
        }
    }

    /// Deletes successfully uploaded attachments that were never sent.
    /// Called from `stop()` via a fire-and-forget Task.
    private func deleteUnsentAttachments() async {
        let toDelete = pendingAttachments.filter { $0.filePath != nil }
        for attachment in toDelete {
            guard let filePath = attachment.filePath else { continue }
            await imageUploadService?.deleteImage(filePath: filePath)
        }
        pendingAttachments.removeAll()
    }

    /// Triggers a toast notification with the given message and style.
    private func showToast(_ message: String, _ style: ToastStyle) {
        toastMessage = message
        toastStyle = style
        showToast = true
    }
}
