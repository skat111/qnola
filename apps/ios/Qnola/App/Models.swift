import Foundation

enum MessageKind: String, Codable, Hashable {
    case text
    case photo
    case file
    case sticker
    case video
    case audio
    case voice
    case unsupported
}

enum MessageStatus: String, Codable, Hashable {
    case pending
    case sent
    case delivered
    case read
    case failed
}

enum ChatType: String, Codable, Hashable {
    case `private`
    case group
}

struct AuthState: Codable {
    let authorized: Bool
    let phone: String?
    let userDisplayName: String?
}

struct UserProfile: Codable, Identifiable, Hashable {
    let id: Int64
    let phone: String
    var displayName: String
    var username: String?
    var bio: String
}

struct AuthTokens: Codable, Hashable {
    let accessToken: String
    let refreshToken: String
    let user: UserProfile
}

struct ChatParticipant: Codable, Identifiable, Hashable {
    let id: Int64
    let user: UserProfile
    let role: String
    let lastReadMessageId: Int64?
}

struct MessageAttachment: Codable, Identifiable, Hashable {
    let id: String
    let fileName: String
    let mimeType: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case id = "fileId"
        case fileName
        case mimeType
        case url
    }
}

struct MessageReaction: Codable, Identifiable, Hashable {
    let id: String
    let emoji: String
    let count: Int
    let selected: Bool
}

struct Message: Codable, Identifiable, Hashable {
    let id: Int64
    let chatId: Int64
    let sender: UserProfile?
    let kind: MessageKind
    var text: String
    var status: MessageStatus
    let replyToId: Int64?
    let attachment: MessageAttachment?
    let createdAt: Date
    var editedAt: Date?
    var deletedAt: Date?
    let outgoing: Bool
}

struct Chat: Codable, Identifiable, Hashable {
    let id: Int64
    let type: ChatType
    var title: String
    var participants: [UserProfile]
    var lastMessage: Message?
    var unreadCount: Int
    var isMuted: Bool
    var isPinned: Bool
    var isArchived: Bool
    var updatedAt: Date
}

struct PendingMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let chatId: Int64
    let kind: MessageKind
    let text: String
    let attachment: MessageAttachment?
    let createdAt: Date
    var retryCount: Int
}

struct SyncCursor: Codable, Hashable {
    let chatId: Int64
    var lastMessageId: Int64?
    var updatedAt: Date
}

struct DialogItem: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let lastMessage: String?
    let unreadCount: Int
    let isMuted: Bool
    let avatarUrl: String?
}

struct MessageItem: Codable, Identifiable, Hashable {
    let id: Int64
    let senderName: String?
    let text: String
    let date: Date
    let outgoing: Bool
    let kind: MessageKind
    let mediaUrl: String?
    let fileName: String?
    let mimeType: String?
    let thumbnailUrl: String?

    init(
        id: Int64,
        senderName: String?,
        text: String,
        date: Date,
        outgoing: Bool,
        kind: MessageKind = .text,
        mediaUrl: String? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        thumbnailUrl: String? = nil
    ) {
        self.id = id
        self.senderName = senderName
        self.text = text
        self.date = date
        self.outgoing = outgoing
        self.kind = kind
        self.mediaUrl = mediaUrl
        self.fileName = fileName
        self.mimeType = mimeType
        self.thumbnailUrl = thumbnailUrl
    }
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

struct AuthSendCodeRequest: Codable {
    let phone: String
}

struct AuthVerifyCodeRequest: Codable {
    let phone: String
    let code: String
    let displayName: String?
    let username: String?
    let deviceName: String?
}

struct AuthRefreshRequest: Codable {
    let refreshToken: String
}

struct PatchMeRequest: Codable {
    let displayName: String?
    let username: String?
    let bio: String?
}

struct CreatePrivateChatRequest: Codable {
    let userId: Int64
}

struct CreateGroupChatRequest: Codable {
    let title: String
    let participantIds: [Int64]
}

struct PatchChatRequest: Codable {
    let title: String?
    let isMuted: Bool?
    let isPinned: Bool?
    let isArchived: Bool?
}

struct SendV1MessageRequest: Codable {
    let kind: MessageKind
    let text: String
    let replyToId: Int64?
    let fileId: String?
    let fileName: String?
    let mimeType: String?
}

struct PatchMessageRequest: Codable {
    let text: String
}

struct UploadResponse: Codable, Hashable {
    let fileId: String
    let fileName: String
    let mimeType: String
    let size: Int
    let url: String
}

struct APIErrorPayload: Codable {
    let detail: String
}

struct PushTokenRequest: Codable {
    let token: String
    let platform: String
}

struct TelegramAuthState: Codable, Hashable {
    let enabled: Bool
    let authorized: Bool
    let phone: String?
    let userDisplayName: String?
}

struct TelegramDialog: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let lastMessage: String?
    let unreadCount: Int
    let isMuted: Bool
    let avatarUrl: String?
    let source: String?
}

struct TelegramMessage: Codable, Identifiable, Hashable {
    let id: Int64
    let senderName: String?
    let text: String
    let date: Date
    let outgoing: Bool
    let kind: MessageKind?
    let mediaUrl: String?
    let fileName: String?
    let mimeType: String?
    let thumbnailUrl: String?
    let source: String?
}

struct TelegramSendCodeRequest: Codable {
    let phone: String
}

struct TelegramVerifyCodeRequest: Codable {
    let phone: String
    let code: String
    let password: String?
}

struct TelegramSendTextRequest: Codable {
    let text: String
}
