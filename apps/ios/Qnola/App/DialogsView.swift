import SwiftUI

struct DialogsView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var query = ""
    @State private var path: [DialogItem] = []

    private var visibleDialogs: [DialogItem] {
        let source = store.dialogs
        guard !query.isEmpty else { return source }
        return source.filter { $0.title.localizedCaseInsensitiveContains(query) || ($0.lastMessage ?? "").localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.black
                    .ignoresSafeArea()

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
                        ContentUnavailableView("No chats", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
            .navigationTitle("Chats")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .tint(.telegramBlue)
            .refreshable {
                await store.refreshDialogs()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {}
                        .disabled(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refreshDialogs() }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("New chat")
                }
            }
            .task {
                await store.refreshDialogs()
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
            AvatarView(title: store.streamerMode ? "Hidden Chat" : dialog.title, id: dialog.id, avatarUrl: store.streamerMode ? nil : dialog.avatarUrl)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(store.streamerMode ? "Hidden Chat" : dialog.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if dialog.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(dialog.id == 1 ? "Saved" : "now")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(store.streamerMode ? "Preview hidden" : (dialog.lastMessage ?? "No messages yet"))
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

struct AvatarView: View {
    let title: String
    let id: Int64
    var avatarUrl: String? = nil

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: avatarColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 52, height: 52)
            .overlay {
                if let avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            placeholder
                        }
                    }
                    .clipShape(Circle())
                } else if id == 1 {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    placeholder
                }
            }
    }

    private var placeholder: some View {
        Text(initials)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.white)
    }

    private var initials: String {
        let value = title
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? "M" : value
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
            [.indigo, .blue]
        ]
        return palettes[Int(abs(id)) % palettes.count]
    }
}

extension Color {
    static let telegramBlue = Color(red: 0.0, green: 0.53, blue: 0.86)
    static let qnolaChrome = Color(red: 0.095, green: 0.095, blue: 0.10)
}
