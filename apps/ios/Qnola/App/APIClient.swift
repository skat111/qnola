import Foundation

final class APIClient {
    var baseURL: URL
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

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = "GET"
        return try await perform(request)
    }

    private func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
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

