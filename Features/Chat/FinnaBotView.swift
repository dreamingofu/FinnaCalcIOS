//
//  FinnaBotView.swift
//  FinnaCalcIOS
//
//  FinnaBot chat, ported from components/Chatbot.tsx. Streams /api/chat (plain
//  UTF-8 text) via APIClient.postTextStream. The view model lives at the app
//  shell so the conversation survives closing/reopening the panel (the iOS
//  equivalent of the web's per-session persistence).
//

import SwiftUI

private let kWelcome =
    "Hi! I'm FinnaBot. Ask me about budgeting, investing, taxes, or any of the calculators on this site. I'm not a licensed advisor, so verify anything important with a professional."

@MainActor
final class ChatViewModel: ObservableObject {
    struct Message: Identifiable, Equatable {
        enum Role { case user, assistant }
        let id: String
        let role: Role
        var content: String
    }

    @Published var messages: [Message]
    @Published var input = ""
    @Published var isLoading = false
    @Published var error: String?

    private let welcomeID = "welcome"

    init() {
        messages = [Message(id: welcomeID, role: .assistant, content: kWelcome)]
    }

    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        error = nil
        messages.append(Message(id: UUID().uuidString, role: .user, content: trimmed))
        input = ""
        isLoading = true

        // Drop the welcome message so the model conversation starts with a user turn.
        let payload = messages
            .filter { $0.id != welcomeID }
            .map { ChatTurn(role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        let assistantID = UUID().uuidString
        Task { @MainActor in
            var appended = false
            do {
                for try await text in APIClient.shared.postTextStream("/api/chat", body: ChatRequest(messages: payload)) {
                    if !appended {
                        messages.append(Message(id: assistantID, role: .assistant, content: ""))
                        appended = true
                    }
                    if let i = messages.firstIndex(where: { $0.id == assistantID }) {
                        messages[i].content = text
                    }
                }
                let streamedText = messages.first(where: { $0.id == assistantID })?.content ?? ""
                if streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messages.removeAll { $0.id == assistantID }
                    error = "No response received. Please try again."
                }
            } catch {
                messages.removeAll { $0.id == assistantID }
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
            isLoading = false
        }
    }

    private struct ChatRequest: Encodable { let messages: [ChatTurn] }
    private struct ChatTurn: Encodable { let role: String; let content: String }
}

struct FinnaBotView: View {
    @ObservedObject var chat: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messages
                Divider().background(Theme.border)
                inputBar
            }
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        (Text("Finna").foregroundColor(Theme.foreground) + Text("Bot").foregroundColor(Theme.primary))
                            .font(Theme.sans(16, weight: .bold))
                        Text("Personal finance & business AI assistant")
                            .font(Theme.sans(Theme.FontSize.xs))
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.tint(Theme.primary)
                }
            }
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(chat.messages) { message in
                        bubble(message).id(message.id)
                    }
                    if chat.isLoading {
                        HStack { TypingDots(); Spacer() }.id("typing")
                    }
                    if let error = chat.error {
                        Text(error)
                            .font(Theme.sans(Theme.FontSize.xs))
                            .foregroundColor(Theme.destructive)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.destructive.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }
                }
                .padding(16)
            }
            .onChange(of: chat.messages) { _ in scrollToEnd(proxy) }
            .onChange(of: chat.isLoading) { _ in scrollToEnd(proxy) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if chat.isLoading {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = chat.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func bubble(_ message: ChatViewModel.Message) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.content)
                .font(Theme.sans(Theme.FontSize.sm))
                .foregroundColor(message.role == .user ? .white : Theme.foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(message.role == .user ? Theme.primary : Theme.muted)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: 300, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask FinnaBot anything…", text: $chat.input, axis: .vertical)
                .font(Theme.sans(Theme.FontSize.sm))
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.background)
                .overlay(Capsule().strokeBorder(Theme.input, lineWidth: 1))
                .clipShape(Capsule())
                .disabled(chat.isLoading)
                .onSubmit(chat.send)

            Button(action: chat.send) {
                Image(systemName: "paperplane.fill")
                    .font(Theme.sans(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.primary)
                    .clipShape(Circle())
            }
            .disabled(chat.isLoading || chat.input.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(chat.isLoading || chat.input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(12)
        .background(Theme.background)
    }
}

private struct TypingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.mutedForeground)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.muted)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

#Preview {
    FinnaBotView(chat: ChatViewModel())
}
