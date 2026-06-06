import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        Group {
            if store.isCheckingSession {
                LaunchLoadingView()
            } else if store.authState.authorized {
                MainShellView()
            } else {
                LoginView()
            }
        }
        .task {
            await store.refreshAuth()
        }
        .alert("qnola", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
        .preferredColorScheme(.dark)
    }
}

struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.1)
        }
    }
}

struct MainShellView: View {
    var body: some View {
        TabView {
            DialogsView()
                .tabItem { Label("Чаты", systemImage: "bubble.left.and.bubble.right") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "slider.horizontal.3") }
        }
        .tint(.telegramBlue)
    }
}
