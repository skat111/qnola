import SwiftUI

struct DialogsView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var query = ""

    private var visibleDialogs: [DialogItem] {
        let source = store.dialogs
        guard !query.isEmpty else { return source }
        return source.filter { $0.title.localizedCaseInsensitiveContains(query) || ($0.lastMessage ?? "").localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationSplitView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                List(visibleDialogs) { dialog in
                    Button {
                        store.selectedDialog = dialog
                    } label: {
                        DialogRow(dialog: dialog)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                    .listRowSeparator(.visible)
                    .listRowBackground(Color(.systemBackground))
                }
                .listStyle(.plain)
                .overlay {
                    if visibleDialogs.isEmpty {
                        ContentUnavailableView("No chats", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
            .navigationTitle("Chats")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
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
                    }
                    .accessibilityLabel("New chat")
                }
            }
            .task {
                await store.refreshDialogs()
            }
        } detail: {
            if let dialog = store.selectedDialog {
                ChatView(dialog: dialog)
            } else {
                ContentUnavailableView("Select a chat", systemImage: "bubble.left.and.bubble.right")
            }
        }
    }
}

struct DialogRow: View {
    @EnvironmentObject private var store: SessionStore
    let dialog: DialogItem

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(title: store.streamerMode ? "Hidden Chat" : dialog.title, id: dialog.id)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(store.streamerMode ? "Hidden Chat" : dialog.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if dialog.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text("now")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(store.streamerMode ? "Preview hidden" : (dialog.lastMessage ?? "No messages yet"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
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
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }
}

struct AvatarView: View {
    let title: String
    let id: Int64

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
                Text(initials)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
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
        return value.isEmpty ? "M" : value
    }

    private var avatarColors: [Color] {
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
}
