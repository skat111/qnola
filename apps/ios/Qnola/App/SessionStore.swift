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
                connectionStatus = "Не подключено"
            }
        }
    }

    @Published var telegramSyncMode = UserDefaults.standard.object(forKey: "telegramSyncMode") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(telegramSyncMode, forKey: "telegramSyncMode")
            if !demoMode {
                authState = AuthState(authorized: false, phone: nil, userDisplayName: nil)
                dialogs = []
                selectedDialog = nil
                messages = []
                connectionStatus = "Не подключено"
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
    @Published var liquidGlassMessages = false {
        didSet { UserDefaults.standard.set(liquidGlassMessages, forKey: "liquidGlassMessages") }
    }
    @Published var lastError: String?
    @Published var isLoading = false
    @Published var connectionStatus = "Демо-режим"
    @Published var lastSyncedAt: Date?

    private var client: APIClient
    private var demoMessages: [Int64: [MessageItem]] = [:]
    private var nextDemoMessageId: Int64 = 10_000

    init() {
        let savedURL = UserDefaults.standard.string(forKey: "backendURLString") ?? "http://127.0.0.1:8000"
        self.profileName = UserDefaults.standard.string(forKey: "profileName") ?? "Алекс"
        self.profileUsername = UserDefaults.standard.string(forKey: "profileUsername") ?? "@alex"
        self.profileBio = UserDefaults.standard.string(forKey: "profileBio") ?? "Профиль qnola"
        self.backendURLString = savedURL
        self.liquidGlassMessages = UserDefaults.standard.object(forKey: "liquidGlassMessages") as? Bool ?? false
        self.client = APIClient(baseURL: URL(string: savedURL) ?? URL(string: "http://127.0.0.1:8000")!)
        seedDemoData()
        if demoMode {
            enterDemoMode()
        }
    }

    var connectionSubtitle: String {
        guard let lastSyncedAt else { return "Синхронизация еще не выполнялась" }
        return "Обновлено \(lastSyncedAt.shortTime)"
    }

    func refreshAuth() async {
        if demoMode {
            enterDemoMode()
            return
        }
        await run {
            if telegramSyncMode {
                let state = try await client.telegramState()
                authState = AuthState(authorized: state.authorized, phone: state.phone, userDisplayName: state.userDisplayName)
                if !state.enabled {
                    lastError = "Telegram-мост не настроен на backend."
                }
            } else {
                authState = try await client.authState()
            }
        }
    }

    func sendCode(phone: String) async {
        if demoMode {
            enterDemoMode()
            return
        }
        await run {
            if telegramSyncMode {
                try await client.telegramSendLoginCode(phone: phone)
            } else {
                try await client.sendLoginCode(phone: phone)
            }
            authState = AuthState(authorized: false, phone: phone, userDisplayName: nil)
        }
    }

    func completeLogin(phone: String, code: String, password: String?) async {
        if demoMode {
            enterDemoMode()
            return
        }
        await run {
            if telegramSyncMode {
                let state = try await client.telegramVerifyCode(phone: phone, code: code, password: password?.isEmpty == true ? nil : password)
                authState = AuthState(authorized: state.authorized, phone: state.phone, userDisplayName: state.userDisplayName)
            } else {
                authState = try await client.completeLogin(phone: phone, code: code, password: password?.isEmpty == true ? nil : password)
            }
        }
    }

    func refreshDialogs() async {
        if demoMode {
            dialogs = demoDialogs()
            markConnected("Демо-режим")
            return
        }
        await run {
            if telegramSyncMode {
                dialogs = try await client.telegramDialogs()
            } else {
                dialogs = try await client.dialogs()
            }
        }
    }

    func loadMessages(for dialog: DialogItem) async {
        selectedDialog = dialog
        if demoMode {
            messages = demoMessages[dialog.id] ?? []
            markConnected("Демо-режим")
            return
        }
        await run {
            if telegramSyncMode {
                messages = try await client.telegramMessages(chatId: dialog.id)
            } else {
                messages = try await client.messages(chatId: dialog.id)
            }
        }
    }

    func sendMessage(_ text: String) async {
        guard let dialog = selectedDialog else { return }
        if demoMode {
            let sent = MessageItem(id: nextDemoMessageId, senderName: nil, text: text, date: Date(), outgoing: true)
            nextDemoMessageId += 1
            demoMessages[dialog.id, default: []].append(sent)
            messages = demoMessages[dialog.id] ?? []
            dialogs = demoDialogs()
            selectedDialog = dialogs.first { $0.id == dialog.id } ?? dialog
            markConnected("Демо-режим")
            return
        }
        await run {
            let sent: MessageItem
            if telegramSyncMode {
                sent = try await client.telegramSendMessage(chatId: dialog.id, text: text)
            } else {
                sent = try await client.sendMessage(chatId: dialog.id, text: text)
            }
            messages.append(sent)
            if telegramSyncMode {
                dialogs = try await client.telegramDialogs()
            } else {
                dialogs = try await client.dialogs()
            }
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
            markConnected(demoMode ? "Демо-режим" : (telegramSyncMode ? "Telegram подключен" : "Сервер подключен"))
        } catch {
            lastError = error.localizedDescription
            connectionStatus = "Нет подключения"
        }
        isLoading = false
    }

    private func markConnected(_ status: String) {
        connectionStatus = status
        lastSyncedAt = Date()
    }

    private func enterDemoMode() {
        authState = AuthState(authorized: true, phone: nil, userDisplayName: profileName)
        markConnected("Демо-режим")
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
                MessageItem(id: 2, senderName: nil, text: "Это локальный демо-чат Избранное.", date: now.addingTimeInterval(-3300), outgoing: false)
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
            demoDialog(id: 1, title: "Избранное", muted: false),
            demoDialog(id: 2, title: "Mira", muted: false),
            demoDialog(id: 3, title: "Qnola Team", muted: true),
            demoDialog(id: 4, title: "Nika", muted: false)
        ]
    }

    private func demoDialog(id: Int64, title: String, muted: Bool) -> DialogItem {
        let latest = demoMessages[id]?.max { $0.date < $1.date }
        return DialogItem(id: id, title: title, lastMessage: latest?.text, unreadCount: id == 1 ? 0 : (id == 3 ? 1 : 0), isMuted: muted, avatarUrl: nil)
    }
}

private extension Date {
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
