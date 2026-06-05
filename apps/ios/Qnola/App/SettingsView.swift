import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack(spacing: 12) {
                        AvatarView(title: store.profileName, id: 100)
                            .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.streamerMode ? "Hidden User" : store.profileName)
                                .font(.headline)
                                .lineLimit(1)
                            Text(store.streamerMode ? "@hidden" : store.profileUsername)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    TextField("Name", text: $store.profileName)
                    TextField("Username", text: $store.profileUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Bio", text: $store.profileBio, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Demo") {
                    Toggle("Demo Mode", isOn: $store.demoMode)
                    if store.demoMode {
                        Text("Demo mode uses local chats and lets you write to Favorites without a backend.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Connection") {
                    TextField("Backend URL", text: $store.backendURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .disabled(store.demoMode)
                    Button {
                        Task { await store.refreshAuth() }
                    } label: {
                        Label("Check Session", systemImage: "checkmark.shield")
                    }
                    .disabled(store.demoMode)
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
