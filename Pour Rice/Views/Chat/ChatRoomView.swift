//
//  ChatRoomView.swift
//  Pour Rice
//
//  Individual chat room conversation view
//  Supports real-time messaging via Socket.IO with REST fallback
//  Supports image attachments with live upload-progress indicators
//

import SwiftUI
import PhotosUI

/// Chat conversation view with messages, input bar, typing indicators, and image attachments
struct ChatRoomView: View {

    // MARK: - Parameters

    let room: ChatRoom

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var viewModel = ChatRoomViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var selectedPhotos: [PhotosPickerItem] = []

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

            // Attachment preview strip (shown when images are selected)
            if !viewModel.pendingAttachments.isEmpty {
                attachmentPreviewStrip
            }

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
                LazyVStack(spacing: 12) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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

    // MARK: - Attachment Preview Strip

    private var attachmentPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.pendingAttachments) { attachment in
                    AttachmentPreviewCell(attachment: attachment) {
                        viewModel.cancelAttachment(attachment)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            // Photo picker button
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: selectedPhotos) { _, newItems in
                guard !newItems.isEmpty else { return }
                let items = newItems
                selectedPhotos = []
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    await viewModel.addImages(images)
                }
            }

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
                    .foregroundStyle(isSendEnabled ? Color.accentColor : Color.secondary)
            }
            .disabled(!isSendEnabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    /// Send is enabled when there is text or at least one ready attachment
    private var isSendEnabled: Bool {
        !viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.pendingAttachments.contains { $0.imageUrl != nil && !$0.failed }
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
            socketService: services.socketService,
            imageUploadService: services.imageUploadService
        )
    }
}

// MARK: - AttachmentPreviewCell

/// Thumbnail card for a pending image attachment in the horizontal strip.
/// Shows upload progress (circular ring + percentage) while uploading,
/// an X dismiss button when ready, and a red failure overlay on error.
private struct AttachmentPreviewCell: View {

    @State var attachment: PendingAttachment
    let onCancel: () -> Void

    private let size: CGFloat = 72

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            Image(uiImage: attachment.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if attachment.failed {
                // Failure overlay — tap to cancel
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.6))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                    }
                    .onTapGesture { onCancel() }

            } else if attachment.isUploading {
                // Progress ring overlay (shimmer while < 5 %, ring afterwards)
                if attachment.progress < 0.05 {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: size, height: size)
                        .shimmerEffect()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: size, height: size)
                        .overlay {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                    .frame(width: 32, height: 32)
                                Circle()
                                    .trim(from: 0, to: attachment.progress)
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 32, height: 32)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 0.1), value: attachment.progress)
                                Text("\(Int(attachment.progress * 100))%")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                }

            } else {
                // Ready — X dismiss button
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.6))
                }
                .offset(x: 6, y: -6)
            }
        }
        .frame(width: size, height: size)
    }
}
