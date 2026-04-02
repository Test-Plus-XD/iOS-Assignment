//
//  ChatListView.swift
//  Pour Rice
//
//  Chat room list tab showing all conversations
//  Sorted by most recent message with relative timestamps
//

import SwiftUI

/// Tab-level view displaying the user's chat conversations
struct ChatListView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel = ChatListViewModel()

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.rooms.isEmpty {
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sortedRooms.isEmpty {
                emptyState
            } else {
                roomList
            }
        }
        .navigationTitle("chat_title")
        .task {
            if let userId = authService.currentUser?.id {
                await viewModel.loadRooms(userId: userId, service: services.chatService)
            }
        }
        .refreshable {
            if let userId = authService.currentUser?.id {
                await viewModel.refresh(userId: userId)
            }
        }
        .errorAlert(error: $viewModel.error)
        .toast(message: viewModel.toastMessage, style: viewModel.toastStyle, isPresented: Binding(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        ))
    }

    // MARK: - Room List

    private var roomList: some View {
        List(viewModel.sortedRooms) { room in
            NavigationLink(value: room) {
                chatRoomRow(room)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Room Row

    private func chatRoomRow(_ room: ChatRoom) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(avatarInitials(for: room))
                        .font(.headline)
                        .foregroundStyle(.accent)
                }

            // Name and preview
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if let name = room.roomName {
                        Text(name)
                    } else {
                        Text("chat_unnamed_room")
                    }
                }
                .font(.headline)
                .lineLimit(1)

                if let lastMessage = room.lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Timestamp
            VStack(alignment: .trailing, spacing: 4) {
                if let time = room.lastMessageRelativeTime {
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if room.messageCount > 0 {
                    Text("\(room.messageCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("chat_empty_title")
            } icon: {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(.secondary)
            }
        } description: {
            Text("chat_empty_description")
        }
    }

    // MARK: - Helpers

    private func avatarInitials(for room: ChatRoom) -> String {
        let name = room.roomName ?? ""
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
