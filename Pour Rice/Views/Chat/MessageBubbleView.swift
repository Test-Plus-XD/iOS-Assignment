//
//  MessageBubbleView.swift
//  Pour Rice
//
//  Individual chat message bubble component
//  Supports user/other alignment, edit/delete context menus, and image attachments
//

import SwiftUI

/// A single chat message bubble with sender info, optional image, content, and timestamp
struct MessageBubbleView: View {

    let message: ChatMessage
    let isCurrentUser: Bool
    var onEdit: ((String) -> Void)?
    var onDelete: (() -> Void)?

    @State private var showEditSheet = false
    @State private var editText = ""
    @State private var showFullScreenImage = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                // Sender name (for other users' messages)
                if !isCurrentUser {
                    Text(message.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Image attachment (shown above text bubble when present)
                if let imageUrl = message.imageUrl, !message.deleted {
                    AsyncImageView(url: imageUrl, contentMode: .fill)
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        .onTapGesture {
                            showFullScreenImage = true
                        }
                        // For image-only messages the text bubble branch is skipped,
                        // so the delete action must live here on the rendered image.
                        .contextMenu {
                            if isCurrentUser && message.message.isEmpty {
                                Button(role: .destructive) {
                                    onDelete?()
                                } label: {
                                    Label("chat_delete", systemImage: "trash")
                                }
                            }
                        }
                }

                // Text bubble (hidden for image-only messages)
                if !message.deleted && !message.message.isEmpty {
                    Text(message.message)
                        .font(.body)
                        .foregroundStyle(isCurrentUser ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            isCurrentUser
                                ? Color.accentColor
                                : Color(.secondarySystemBackground),
                            in: bubbleShape
                        )
                        .contextMenu {
                            if isCurrentUser {
                                Button {
                                    editText = message.message
                                    showEditSheet = true
                                } label: {
                                    Label("chat_edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    onDelete?()
                                } label: {
                                    Label("chat_delete", systemImage: "trash")
                                }
                            }
                        }
                } else if message.deleted {
                    // Deleted message placeholder
                    Text(message.displayText)
                        .font(.body)
                        .foregroundStyle(isCurrentUser ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            isCurrentUser
                                ? Color.accentColor
                                : Color(.secondarySystemBackground),
                            in: bubbleShape
                        )
                }

                // Metadata row
                HStack(spacing: 4) {
                    if message.edited {
                        Text("chat_edited")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
        .sheet(isPresented: $showEditSheet) {
            editSheet
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let imageUrl = message.imageUrl {
                FullScreenImageView(url: imageUrl)
            }
        }
    }

    // MARK: - Bubble Shape

    private var bubbleShape: some Shape {
        RoundedRectangle(cornerRadius: 18)
    }

    // MARK: - Edit Sheet

    private var editSheet: some View {
        NavigationStack {
            Form {
                TextField("chat_edit_message", text: $editText, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle("chat_edit_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        onEdit?(editText)
                        showEditSheet = false
                    }
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - FullScreenImageView

/// Full-screen image viewer with pinch-to-zoom, double-tap zoom, and drag-to-pan.
/// Presented from `MessageBubbleView` when the user taps a chat image attachment.
private struct FullScreenImageView: View {

    let url: String

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var liveMagnification: CGFloat = 1.0
    @GestureState private var liveDrag: CGSize = .zero

    private var currentScale: CGFloat { scale * liveMagnification }
    private var currentOffset: CGSize {
        CGSize(width: offset.width + liveDrag.width, height: offset.height + liveDrag.height)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            AsyncImageView(url: url, contentMode: .fit)
                .scaleEffect(currentScale)
                .offset(currentOffset)
                .gesture(magnifyGesture)
                .simultaneousGesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                        } else {
                            scale = 2.5
                        }
                    }
                }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($liveMagnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3)) {
                    scale = max(1.0, min(scale * value.magnification, 5.0))
                    if scale == 1.0 { offset = .zero }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($liveDrag) { value, state, _ in
                guard scale > 1.0 else { return }
                state = value.translation
            }
            .onEnded { value in
                guard scale > 1.0 else { return }
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }
}
