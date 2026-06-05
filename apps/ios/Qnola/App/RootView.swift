import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        Group {
            if store.authState.authorized {
                MainShellView()
            } else {
                LoginView()
            }
        }
        .task {
            await store.refreshAuth()
        }
        .alert("qnola", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

struct MainShellView: View {
    var body: some View {
        TabView {
            DialogsView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
            SettingsView()
                .tabItem { Label("qnola", systemImage: "slider.horizontal.3") }
        }
        .tint(.primary)
    }
}
