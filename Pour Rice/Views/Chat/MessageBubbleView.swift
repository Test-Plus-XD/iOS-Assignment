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
                        .frame(maxWidth: 240)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                } else if message.imageUrl != nil {
                    // Image-only message: no text bubble, but allow delete via context menu on image
                    EmptyView()
                        .contextMenu {
                            if isCurrentUser {
                                Button(role: .destructive) {
                                    onDelete?()
                                } label: {
                                    Label("chat_delete", systemImage: "trash")
                                }
                            }
                        }
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
