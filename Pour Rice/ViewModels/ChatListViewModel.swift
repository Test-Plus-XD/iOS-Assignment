//
//  ChatListViewModel.swift
//  Pour Rice
//
//  ViewModel for the chat room list
//  Manages fetching rooms and creating new conversations
//

import Foundation

/// ViewModel for ChatListView — manages the user's chat room list
@MainActor @Observable
final class ChatListViewModel {

    // MARK: - Properties

    /// All chat rooms for the current user
    private(set) var rooms: [ChatRoom] = []

    /// Whether rooms are loading
    private(set) var isLoading = false

    /// Current error
    var error: Error?

    /// Toast message to display
    var toastMessage = ""

    /// Toast visual style
    var toastStyle: ToastStyle = .success

    /// Whether the toast is currently visible
    var showToast = false

    // MARK: - Dependencies

    private var chatService: ChatService?

    // MARK: - Computed Properties

    /// Rooms sorted by most recent message first
    var sortedRooms: [ChatRoom] {
        rooms.sorted { room1, room2 in
            let date1 = room1.lastMessageAt ?? room1.createdAt ?? .distantPast
            let date2 = room2.lastMessageAt ?? room2.createdAt ?? .distantPast
            return date1 > date2
        }
    }

    // MARK: - Actions

    /// Loads all chat rooms for the given user.
    func loadRooms(userId: String, service: ChatService) async {
        self.chatService = service
        isLoading = true
        error = nil

        do {
            rooms = try await service.fetchChatRecords(uid: userId)
        } catch {
            self.error = error
            print("❌ ChatListVM: Failed to load rooms: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Refreshes the room list.
    func refresh(userId: String) async {
        guard let service = chatService else { return }
        await loadRooms(userId: userId, service: service)
    }

    /// Creates a new direct chat room with a restaurant.
    /// - Returns: The room ID if creation succeeds.
    func createRoom(
        currentUserId: String,
        restaurantOwnerId: String,
        roomName: String,
        service: ChatService
    ) async -> String? {
        do {
            let request = CreateRoomRequest(
                participants: [currentUserId, restaurantOwnerId],
                roomName: roomName,
                type: "direct"
            )
            let roomId = try await service.createRoom(request)
            // Refresh rooms to include the new one
            await refresh(userId: currentUserId)
            showToast(String(localized: "toast_chat_room_created", bundle: L10n.bundle), .success)
            return roomId
        } catch {
            self.error = error
            showToast(String(localized: "toast_chat_room_failed", bundle: L10n.bundle), .error)
            print("❌ ChatListVM: Failed to create room: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Helpers

    private func showToast(_ message: String, _ style: ToastStyle) {
        toastMessage = message
        toastStyle = style
        showToast = true
    }
}
