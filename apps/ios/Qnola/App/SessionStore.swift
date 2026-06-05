import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published var backendURLString: String {
        didSet {
            UserDefaults.standard.set(backendURLString, forKey: "backendURLString")
            resetClient()
        }
    }
    @Published var demoMode = UserDefaults.standard.object(forKey: "demoMode") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(demoMode, forKey: "demoMode")
            if demoMode {
                enterDemoMode()
            } else {
                dialogs = []
                selectedDialog = nil
                messages = []
                authState = AuthState(authorized: false, phone: nil, userDisplayName: nil)
            }
        }
    }
    @Published var profileName: String {
        didSet {
            UserDefaults.standard.set(profileName, forKey: "profileName")
            if demoMode {
                authState = AuthState(authorized: true, phone: nil, userDisplayName: profileName)
            }
        }
    }
    @Published var profileUsername: String {
        didSet { UserDefaults.standard.set(profileUsername, forKey: "profileUsername") }
    }
    @Published var profileBio: String {
        didSet { UserDefaults.standard.set(profileBio, forKey: "profileBio") }
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
    private var demoMessages: [Int64: [MessageItem]] = [:]
    private var nextDemoMessageId: Int64 = 10_000

    init() {
        let savedURL = UserDefaults.standard.string(forKey: "backendURLString") ?? "http://127.0.0.1:8000"
        self.profileName = UserDefaults.standard.string(forKey: "profileName") ?? "Alex"
        self.profileUsername = UserDefaults.standard.string(forKey: "profileUsername") ?? "@alex"
        self.profileBio = UserDefaults.standard.string(forKey: "profileBio") ?? "qnola demo profile"
        self.backendURLString = savedURL
        self.liquidGlassMessages = UserDefaults.standard.object(forKey: "liquidGlassMessages") as? Bool ?? true
        self.client = APIClient(baseURL: URL(string: savedURL) ?? URL(string: "http://127.0.0.1:8000")!)
        seedDemoData()
        if demoMode {
            enterDemoMode()
        }
    }

    func refreshAuth() async {
        if demoMode {
            enterDemoMode()
            return
        }
        await run {
            authState = try await client.authState()
        }
    }

    func sendCode(phone: String) async {
        if demoMode {
            enterDemoMode()
            return
        }
        await run {
            try await client.sendLoginCode(phone: phone)
            authState = AuthState(authorized: false, phone: phone, userDisplayName: nil)
        }
    }

    func completeLogin(phone: String, code: String, password: String?) async {
        if demoMode {
            enterDemoMode()
            return
        }
        await run {
            authState = try await client.completeLogin(phone: phone, code: code, password: password?.isEmpty == true ? nil : password)
        }
    }

    func refreshDialogs() async {
        if demoMode {
            dialogs = demoDialogs()
            return
        }
        await run {
            dialogs = try await client.dialogs()
        }
    }

    func loadMessages(for dialog: DialogItem) async {
        selectedDialog = dialog
        if demoMode {
            messages = demoMessages[dialog.id] ?? []
            return
        }
        await run {
            messages = try await client.messages(chatId: dialog.id)
        }
    }

    func sendMessage(_ text: String) async {
        guard let dialog = selectedDialog else { return }
        if demoMode {
            guard dialog.id == 1 else { return }
            let sent = MessageItem(id: nextDemoMessageId, senderName: nil, text: text, date: Date(), outgoing: true)
            nextDemoMessageId += 1
            demoMessages[dialog.id, default: []].append(sent)
            messages = demoMessages[dialog.id] ?? []
            dialogs = demoDialogs()
            selectedDialog = dialogs.first { $0.id == dialog.id } ?? dialog
            return
        }
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

    private func enterDemoMode() {
        authState = AuthState(authorized: true, phone: nil, userDisplayName: profileName)
        dialogs = demoDialogs()
        if selectedDialog == nil {
            selectedDialog = dialogs.first
        }
        if let selectedDialog {
            messages = demoMessages[selectedDialog.id] ?? []
        }
    }

    private func seedDemoData() {
        let now = Date()
        demoMessages = [
            1: [
                MessageItem(id: 1, senderName: nil, text: "Здесь можно писать заметки, ссылки и черновики.", date: now.addingTimeInterval(-3600), outgoing: false),
                MessageItem(id: 2, senderName: nil, text: "Это локальный демо-чат Избранные.", date: now.addingTimeInterval(-3300), outgoing: false)
            ],
            2: [
                MessageItem(id: 3, senderName: "Mira", text: "Посмотри новый экран чата.", date: now.addingTimeInterval(-7200), outgoing: false),
                MessageItem(id: 4, senderName: nil, text: "Да, уже похоже на нормальный мессенджер.", date: now.addingTimeInterval(-7100), outgoing: true)
            ],
            3: [
                MessageItem(id: 5, senderName: "Qnola Team", text: "Демо-режим работает без сервера.", date: now.addingTimeInterval(-18_000), outgoing: false)
            ],
            4: [
                MessageItem(id: 6, senderName: "Nika", text: "Backend потом подключим по контракту API.", date: now.addingTimeInterval(-86_000), outgoing: false),
                MessageItem(id: 7, senderName: nil, text: "Сначала доделаю профиль и базовые чаты.", date: now.addingTimeInterval(-85_900), outgoing: true)
            ]
        ]
    }

    private func demoDialogs() -> [DialogItem] {
        [
            demoDialog(id: 1, title: "Избранные", muted: false),
            demoDialog(id: 2, title: "Mira", muted: false),
            demoDialog(id: 3, title: "Qnola Team", muted: true),
            demoDialog(id: 4, title: "Nika", muted: false)
        ]
    }

    private func demoDialog(id: Int64, title: String, muted: Bool) -> DialogItem {
        let latest = demoMessages[id]?.max { $0.date < $1.date }
        return DialogItem(id: id, title: title, lastMessage: latest?.text, unreadCount: id == 1 ? 0 : (id == 3 ? 1 : 0), isMuted: muted)
    }
}
