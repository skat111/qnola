import Foundation

@MainActor
final class ChatService: ObservableObject {
    @Published private(set) var chats: [Chat] = []
    @Published private(set) var selectedMessages: [Int64: [Message]] = [:]
    @Published var lastError: String?

    private let client: APIClient
    private let localStore: LocalStore

    init(client: APIClient, localStore: LocalStore) {
        self.client = client
        self.localStore = localStore
    }

    func loadCached() async {
        chats = (try? await localStore.loadChats()) ?? []
        for chat in chats {
            selectedMessages[chat.id] = (try? await localStore.loadMessages(chatId: chat.id)) ?? []
        }
    }

    func refreshChats() async {
        do {
            chats = try await client.chats()
            try await localStore.saveChats(chats)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadMessages(chatId: Int64) async {
        do {
            let cached = try await localStore.loadMessages(chatId: chatId)
            if !cached.isEmpty {
                selectedMessages[chatId] = cached
            }
            let remote = try await client.v1Messages(chatId: chatId)
            selectedMessages[chatId] = remote
            try await localStore.saveMessages(remote, chatId: chatId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func sendText(_ text: String, chatId: Int64) async {
        let pending = PendingMessage(id: UUID(), chatId: chatId, kind: .text, text: text, attachment: nil, createdAt: Date(), retryCount: 0)
        try? await localStore.savePendingMessage(pending)
        do {
            let sent = try await client.v1SendMessage(chatId: chatId, request: SendV1MessageRequest(kind: .text, text: text, replyToId: nil, fileId: nil, fileName: nil, mimeType: nil))
            var messages = selectedMessages[chatId] ?? []
            messages.append(sent)
            selectedMessages[chatId] = messages
            try await localStore.deletePendingMessage(id: pending.id)
            try await localStore.saveMessages(messages, chatId: chatId)
            await refreshChats()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createPrivateChat(userId: Int64) async {
        do {
            let chat = try await client.createPrivateChat(userId: userId)
            chats.insert(chat, at: 0)
            try await localStore.saveChats(chats)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
