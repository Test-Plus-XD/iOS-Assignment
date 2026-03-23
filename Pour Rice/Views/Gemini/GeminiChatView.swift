//
//  GeminiChatView.swift
//  Pour Rice
//
//  Conversational AI interface powered by Gemini
//  Context-aware when launched from a restaurant detail page
//  No authentication required — accessible to guests
//

import SwiftUI

/// Gemini AI chat view with conversation history and suggestion chips
struct GeminiChatView: View {

    // MARK: - Parameters

    /// Optional restaurant context (passed when launched from RestaurantView)
    var restaurant: Restaurant?

    // MARK: - Environment

    @Environment(\.services) private var services

    // MARK: - State

    @State private var viewModel = GeminiViewModel()
    @FocusState private var isInputFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            messagesScrollView

            // Suggestion chips (only shown when few messages)
            if viewModel.messages.count <= 2 {
                suggestionChips
            }

            Divider()

            // Input bar
            inputBar
        }
        .navigationTitle("gemini_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.clearConversation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
        }
        .task {
            viewModel.initialise(service: services.geminiService, restaurant: restaurant)
        }
        .toast(message: viewModel.toastMessage, style: viewModel.toastStyle, isPresented: Binding(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        ))
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        geminiMessageRow(message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("gemini_thinking")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .italic()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("loading")
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
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Message Row

    private func geminiMessageRow(_ message: GeminiMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                // AI avatar
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Try to render markdown, fall back to plain text.
                // Pre-process: convert single newlines to Markdown hard breaks (trailing double-space)
                // so that line breaks and emojis from the AI response are preserved.
                if message.role == .model,
                   let attributed = try? AttributedString(
                       markdown: message.content
                           .components(separatedBy: "\n")
                           .joined(separator: "  \n"),
                       options: AttributedString.MarkdownParsingOptions(
                           interpretedSyntax: .inlineOnlyPreservingWhitespace
                       )
                   ) {
                    Text(attributed)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(message.role == .user ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.role == .user
                                ? AnyShapeStyle(Color.accentColor)
                                : AnyShapeStyle(Color(.secondarySystemBackground)),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }
            }

            if message.role == .model {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Suggestion Chips

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.suggestionChips, id: \.self) { chip in
                    Button {
                        Task { await viewModel.sendSuggestion(chip) }
                    } label: {
                        Text(chip)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("gemini_placeholder", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading
                            ? Color.secondary
                            : Color.accentColor
                    )
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}
