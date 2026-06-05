import Foundation

actor LocalStore {
    private let root: URL
    private let encoder = JSONEncoder.qnola
    private let decoder = JSONDecoder.qnola

    init(root: URL? = nil) {
        let base = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.root = base.appendingPathComponent("QnolaLocalStore", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func saveChats(_ chats: [Chat]) throws {
        try write(chats, to: "chats.json")
    }

    func loadChats() throws -> [Chat] {
        try read([Chat].self, from: "chats.json") ?? []
    }

    func saveMessages(_ messages: [Message], chatId: Int64) throws {
        try write(messages, to: "messages-\(chatId).json")
    }

    func loadMessages(chatId: Int64) throws -> [Message] {
        try read([Message].self, from: "messages-\(chatId).json") ?? []
    }

    func savePendingMessage(_ message: PendingMessage) throws {
        var pending = try loadPendingMessages()
        pending.removeAll { $0.id == message.id }
        pending.append(message)
        try write(pending, to: "pending.json")
    }

    func deletePendingMessage(id: UUID) throws {
        var pending = try loadPendingMessages()
        pending.removeAll { $0.id == id }
        try write(pending, to: "pending.json")
    }

    func loadPendingMessages() throws -> [PendingMessage] {
        try read([PendingMessage].self, from: "pending.json") ?? []
    }

    private func write<T: Encodable>(_ value: T, to fileName: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: root.appendingPathComponent(fileName), options: .atomic)
    }

    private func read<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T? {
        let url = root.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(type, from: Data(contentsOf: url))
    }
}

extension JSONDecoder {
    static var qnola: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var qnola: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
