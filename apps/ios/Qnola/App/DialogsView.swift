import SwiftUI

struct DialogsView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var query = ""
    @State private var path: [DialogItem] = []

    private var visibleDialogs: [DialogItem] {
        guard !query.isEmpty else { return store.dialogs }
        return store.dialogs.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.lastMessage ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    ConnectionStatusBar()
                        .padding(.horizontal, 14)
                        .padding(.top, 2)
                        .padding(.bottom, 2)

                    List(visibleDialogs) { dialog in
                        Button {
                            path.append(dialog)
                        } label: {
                            DialogRow(dialog: dialog)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                        .listRowSeparator(.visible)
                        .listRowBackground(Color.black)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .overlay {
                        if visibleDialogs.isEmpty {
                            ContentUnavailableView("Нет чатов", systemImage: "bubble.left.and.bubble.right")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .navigationTitle("Чаты")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск")
            .tint(.telegramBlue)
            .refreshable {
                await store.refreshDialogs()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Править") {}
                        .disabled(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refreshDialogs() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("Обновить")
                }
            }
            .task {
                await store.refreshDialogs()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                    if !Task.isCancelled {
                        await store.refreshDialogs()
                    }
                }
            }
            .navigationDestination(for: DialogItem.self) { dialog in
                ChatView(dialog: dialog)
            }
        }
    }
}

struct DialogRow: View {
    @EnvironmentObject private var store: SessionStore
    let dialog: DialogItem

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(title: store.streamerMode ? "Скрытый чат" : dialog.title, id: dialog.id, avatarUrl: store.streamerMode ? nil : dialog.avatarUrl)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(store.streamerMode ? "Скрытый чат" : dialog.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if dialog.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(dialog.id == 1 ? "Избр." : "сейчас")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(store.streamerMode ? "Предпросмотр скрыт" : (dialog.lastMessage ?? "Сообщений пока нет"))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if dialog.unreadCount > 0 {
                        Text("\(dialog.unreadCount)")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 7)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Color.telegramBlue, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(minHeight: 74)
        .contentShape(Rectangle())
    }
}

struct ConnectionStatusBar: View {
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 24, height: 24)
                if store.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                } else {
                    Image(systemName: store.isConnected ? "checkmark" : "exclamationmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(statusColor)
                }
            }

            Text(store.connectionStatus)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)

            Text(store.connectionSubtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 36)
        .modifier(LiquidGlassCapsule())
    }

    private var statusColor: Color {
        store.isConnected ? .green : .orange
    }
}

struct AvatarView: View {
    @StateObject private var cache = MediaCache.shared
    let title: String
    let id: Int64
    var avatarUrl: String? = nil

    var body: some View {
        Circle()
            .fill(avatarGradient)
            .frame(width: 52, height: 52)
            .overlay {
                if id == 1 {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                } else if let image = cache.image(for: avatarUrl) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(initials)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .task(id: avatarUrl) {
                await cache.loadImage(avatarUrl)
            }
    }

    private var initials: String {
        let value = title
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? "Q" : value
    }

    private var avatarGradient: LinearGradient {
        LinearGradient(colors: avatarColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var avatarColors: [Color] {
        if id == 1 {
            return [Color.telegramBlue.opacity(0.9), .blue]
        }
        let palettes: [[Color]] = [
            [.cyan, .blue],
            [.green, .teal],
            [.orange, .red],
            [.pink, .purple],
            [.indigo, .blue],
            [.mint, .cyan]
        ]
        return palettes[Int(abs(id)) % palettes.count]
    }
}

extension Color {
    static let telegramBlue = Color(red: 0.0, green: 0.53, blue: 0.86)
    static let qnolaChrome = Color(red: 0.095, green: 0.095, blue: 0.10)
}
