import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Backend URL", text: $store.backendURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button {
                        Task { await store.refreshAuth() }
                    } label: {
                        Label("Check Session", systemImage: "checkmark.shield")
                    }
                }

                Section("Privacy UI") {
                    Toggle("Streamer Mode", isOn: $store.streamerMode)
                    Toggle("Liquid Glass Messages", isOn: $store.liquidGlassMessages)
                }

                Section("Account") {
                    LabeledContent("Status", value: store.authState.authorized ? "Authorized" : "Signed out")
                    if let phone = store.authState.phone {
                        LabeledContent("Phone", value: store.streamerMode ? "Hidden" : phone)
                    }
                    if let name = store.authState.userDisplayName {
                        LabeledContent("User", value: store.streamerMode ? "Hidden" : name)
                    }
                }
            }
            .navigationTitle("qnola")
        }
    }
}
