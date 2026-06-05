import Foundation

@MainActor
final class APIClient {
    var baseURL: URL
    var accessToken: String?
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func authState() async throws -> AuthState {
        try await get("/auth/state")
    }

    func sendLoginCode(phone: String) async throws {
        let request = LoginCodeRequest(phone: phone)
        let _: EmptyResponse = try await post("/auth/send-code", body: request)
    }

    func completeLogin(phone: String, code: String, password: String?) async throws -> AuthState {
        try await post("/auth/complete", body: CompleteLoginRequest(phone: phone, code: code, password: password))
    }

    func dialogs() async throws -> [DialogItem] {
        try await get("/dialogs")
    }

    func messages(chatId: Int64) async throws -> [MessageItem] {
        try await get("/dialogs/\(chatId)/messages")
    }

    func sendMessage(chatId: Int64, text: String) async throws -> MessageItem {
        try await post("/messages/send", body: SendMessageRequest(chatId: chatId, text: text))
    }

    func v1SendCode(phone: String) async throws {
        let _: EmptyResponse = try await post("/v1/auth/send-code", body: AuthSendCodeRequest(phone: phone))
    }

    func v1VerifyCode(phone: String, code: String, displayName: String?, username: String?, deviceName: String?) async throws -> AuthTokens {
        try await post("/v1/auth/verify-code", body: AuthVerifyCodeRequest(phone: phone, code: code, displayName: displayName, username: username, deviceName: deviceName))
    }

    func v1Refresh(refreshToken: String) async throws -> AuthTokens {
        try await post("/v1/auth/refresh", body: AuthRefreshRequest(refreshToken: refreshToken))
    }

    func v1Logout() async throws {
        let _: EmptyResponse = try await post("/v1/auth/logout", body: EmptyResponse())
    }

    func me() async throws -> UserProfile {
        try await get("/v1/me")
    }

    func patchMe(displayName: String?, username: String?, bio: String?) async throws -> UserProfile {
        try await patch("/v1/me", body: PatchMeRequest(displayName: displayName, username: username, bio: bio))
    }

    func searchUsers(username: String) async throws -> [UserProfile] {
        try await get("/v1/users/search?username=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username)")
    }

    func chats() async throws -> [Chat] {
        try await get("/v1/chats")
    }

    func createPrivateChat(userId: Int64) async throws -> Chat {
        try await post("/v1/chats/private", body: CreatePrivateChatRequest(userId: userId))
    }

    func createGroupChat(title: String, participantIds: [Int64]) async throws -> Chat {
        try await post("/v1/chats/group", body: CreateGroupChatRequest(title: title, participantIds: participantIds))
    }

    func patchChat(id: Int64, title: String?, isMuted: Bool?, isPinned: Bool?, isArchived: Bool?) async throws -> Chat {
        try await patch("/v1/chats/\(id)", body: PatchChatRequest(title: title, isMuted: isMuted, isPinned: isPinned, isArchived: isArchived))
    }

    func v1Messages(chatId: Int64, before: Int64? = nil, after: Int64? = nil, limit: Int = 50) async throws -> [Message] {
        var query = ["limit=\(limit)"]
        if let before { query.append("before=\(before)") }
        if let after { query.append("after=\(after)") }
        return try await get("/v1/chats/\(chatId)/messages?\(query.joined(separator: "&"))")
    }

    func v1SendMessage(chatId: Int64, request: SendV1MessageRequest) async throws -> Message {
        try await post("/v1/chats/\(chatId)/messages", body: request)
    }

    func patchMessage(id: Int64, text: String) async throws -> Message {
        try await patch("/v1/messages/\(id)", body: PatchMessageRequest(text: text))
    }

    func deleteMessage(id: Int64) async throws {
        try await delete("/v1/messages/\(id)")
    }

    func telegramState() async throws -> TelegramAuthState {
        try await get("/v1/telegram/state")
    }

    func telegramSendLoginCode(phone: String) async throws {
        let _: EmptyResponse = try await post("/v1/telegram/send-code", body: TelegramSendCodeRequest(phone: phone))
    }

    func telegramVerifyCode(phone: String, code: String, password: String?) async throws -> TelegramAuthState {
        try await post("/v1/telegram/verify-code", body: TelegramVerifyCodeRequest(phone: phone, code: code, password: password))
    }

    func telegramDialogs() async throws -> [DialogItem] {
        let items: [TelegramDialog] = try await get("/v1/telegram/dialogs")
        return items.map { dialog in
            DialogItem(
                id: dialog.id,
                title: dialog.title,
                lastMessage: dialog.lastMessage,
                unreadCount: dialog.unreadCount,
                isMuted: dialog.isMuted,
                avatarUrl: absoluteURLString(dialog.avatarUrl)
            )
        }
    }

    func telegramMessages(chatId: Int64) async throws -> [MessageItem] {
        let items: [TelegramMessage] = try await get("/v1/telegram/dialogs/\(chatId)/messages")
        return items.map {
            MessageItem(id: $0.id, senderName: $0.senderName, text: $0.text, date: $0.date, outgoing: $0.outgoing)
        }
    }

    func telegramSendMessage(chatId: Int64, text: String) async throws -> MessageItem {
        let sent: TelegramMessage = try await post("/v1/telegram/dialogs/\(chatId)/send", body: TelegramSendTextRequest(text: text))
        return MessageItem(id: sent.id, senderName: sent.senderName, text: sent.text, date: sent.date, outgoing: sent.outgoing)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = "GET"
        return try await perform(request)
    }

    private func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func patch<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func delete(_ path: String) async throws {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = "DELETE"
        let _: EmptyResponse = try await perform(request)
    }

    private func makeURL(_ path: String) -> URL {
        URL(string: path, relativeTo: baseURL)?.absoluteURL ?? baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private func absoluteURLString(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL.absoluteString
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        var request = request
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            if let payload = try? decoder.decode(APIErrorPayload.self, from: data) {
                throw APIClientError.server(payload.detail)
            }
            throw APIClientError.server("HTTP \(http.statusCode)")
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }
}

struct EmptyResponse: Codable {}

enum APIClientError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case let .server(message):
            return message
        }
    }
}
