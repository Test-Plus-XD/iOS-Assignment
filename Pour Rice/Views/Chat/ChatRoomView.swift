//
//  ChatRoomView.swift
//  Pour Rice
//
//  Individual chat room conversation view
//  Supports real-time messaging via Socket.IO with REST fallback
//

import SwiftUI

/// Chat conversation view with messages, input bar, and typing indicators
struct ChatRoomView: View {

    // MARK: - Parameters

    let room: ChatRoom

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel = ChatRoomViewModel()
    @FocusState private var isInputFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            messagesScrollView

            // Typing indicator
            if let typingText = viewModel.typingIndicatorText {
                HStack {
                    Text(typingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .transition(.opacity)
            }

            Divider()

            // Input bar
            inputBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(room.roomName ?? String(localized: "chat_conversation", bundle: L10n.bundle))
                        .font(.headline)
                    if !viewModel.isUsingSocket {
                        Text("chat_reconnecting")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            await startChat()
        }
        .onDisappear {
            viewModel.stop()
        }
        .toast(message: viewModel.toastMessage, style: viewModel.toastStyle, isPresented: Binding(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        ))
    }

    // MARK: - Messages ScrollView

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isCurrentUser: message.isFromUser(authService.currentUser?.id ?? ""),
                            onEdit: { newText in
                                Task { await viewModel.editMessage(id: message.id, newText: newText) }
                            },
                            onDelete: {
                                Task { await viewModel.deleteMessage(id: message.id) }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("chat_message_placeholder", text: $viewModel.messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onChange(of: viewModel.messageText) { _, _ in
                    viewModel.onTypingChanged()
                }

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : Color.accentColor
                    )
            }
            .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Start Chat

    private func startChat() async {
        guard let user = authService.currentUser else { return }

        let token: String
        do {
            token = try await authService.getIDToken()
        } catch {
            token = ""
        }

        await viewModel.start(
            roomId: room.id,
            userId: user.id,
            displayName: user.displayName,
            authToken: token,
            chatService: services.chatService,
            socketService: services.socketService
        )
    }
}
