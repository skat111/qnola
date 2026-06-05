import Foundation

@MainActor
final class MessageSyncService: ObservableObject {
    @Published private(set) var isConnected = false

    private let client: APIClient
    private var task: URLSessionWebSocketTask?

    init(client: APIClient) {
        self.client = client
    }

    func connect(onEvent: @escaping @Sendable (RealtimeEvent) -> Void) {
        guard let token = client.accessToken else { return }
        guard var components = URLComponents(url: client.baseURL, resolvingAgainstBaseURL: false) else { return }
        let currentScheme = components.scheme
        components.scheme = currentScheme == "https" ? "wss" : "ws"
        components.path = "/v1/realtime"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        task.resume()
        isConnected = true
        receive(onEvent: onEvent)
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    func sendTyping(chatId: Int64) {
        send(["type": "typing", "chatId": chatId])
    }

    func sendRead(chatId: Int64) {
        send(["type": "read", "chatId": chatId])
    }

    private func receive(onEvent: @escaping @Sendable (RealtimeEvent) -> Void) {
        task?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case let .success(.string(text)):
                    if let data = text.data(using: .utf8), let event = try? JSONDecoder.qnola.decode(RealtimeEvent.self, from: data) {
                        onEvent(event)
                    }
                    self.receive(onEvent: onEvent)
                case .success:
                    self.receive(onEvent: onEvent)
                case .failure:
                    self.isConnected = false
                }
            }
        }
    }

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }
}

struct RealtimeEvent: Codable, Hashable {
    let type: String
    let chatId: Int64?
    let userId: Int64?
    let message: Message?
}
