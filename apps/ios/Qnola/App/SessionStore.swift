import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published var backendURLString: String {
        didSet {
            UserDefaults.standard.set(backendURLString, forKey: "backendURLString")
            resetClient()
        }
    }
    @Published var authState = AuthState(authorized: false, phone: nil, userDisplayName: nil)
    @Published var dialogs: [DialogItem] = []
    @Published var selectedDialog: DialogItem?
    @Published var messages: [MessageItem] = []
    @Published var streamerMode = UserDefaults.standard.bool(forKey: "streamerMode") {
        didSet { UserDefaults.standard.set(streamerMode, forKey: "streamerMode") }
    }
    @Published var liquidGlassMessages = true {
        didSet { UserDefaults.standard.set(liquidGlassMessages, forKey: "liquidGlassMessages") }
    }
    @Published var lastError: String?
    @Published var isLoading = false

    private var client: APIClient

    init() {
        let savedURL = UserDefaults.standard.string(forKey: "backendURLString") ?? "http://127.0.0.1:8000"
        self.backendURLString = savedURL
        self.liquidGlassMessages = UserDefaults.standard.object(forKey: "liquidGlassMessages") as? Bool ?? true
        self.client = APIClient(baseURL: URL(string: savedURL) ?? URL(string: "http://127.0.0.1:8000")!)
    }

    func refreshAuth() async {
        await run {
            authState = try await client.authState()
        }
    }

    func sendCode(phone: String) async {
        await run {
            try await client.sendLoginCode(phone: phone)
            authState = AuthState(authorized: false, phone: phone, userDisplayName: nil)
        }
    }

    func completeLogin(phone: String, code: String, password: String?) async {
        await run {
            authState = try await client.completeLogin(phone: phone, code: code, password: password?.isEmpty == true ? nil : password)
        }
    }

    func refreshDialogs() async {
        await run {
            dialogs = try await client.dialogs()
        }
    }

    func loadMessages(for dialog: DialogItem) async {
        selectedDialog = dialog
        await run {
            messages = try await client.messages(chatId: dialog.id)
        }
    }

    func sendMessage(_ text: String) async {
        guard let dialog = selectedDialog else { return }
        await run {
            let sent = try await client.sendMessage(chatId: dialog.id, text: text)
            messages.append(sent)
            dialogs = try await client.dialogs()
        }
    }

    private func resetClient() {
        client = APIClient(baseURL: URL(string: backendURLString) ?? URL(string: "http://127.0.0.1:8000")!)
    }

    private func run(_ operation: () async throws -> Void) async {
        isLoading = true
        lastError = nil
        do {
            try await operation()
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }
}

