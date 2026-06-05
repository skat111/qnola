import Foundation

struct AuthState: Codable {
    let authorized: Bool
    let phone: String?
    let userDisplayName: String?
}

struct DialogItem: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let lastMessage: String?
    let unreadCount: Int
    let isMuted: Bool
}

struct MessageItem: Codable, Identifiable, Hashable {
    let id: Int64
    let senderName: String?
    let text: String
    let date: Date
    let outgoing: Bool
}

struct SendMessageRequest: Codable {
    let chatId: Int64
    let text: String
}

struct LoginCodeRequest: Codable {
    let phone: String
}

struct CompleteLoginRequest: Codable {
    let phone: String
    let code: String
    let password: String?
}

struct APIErrorPayload: Codable {
    let detail: String
}

