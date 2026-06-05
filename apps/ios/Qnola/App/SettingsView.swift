import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Профиль") {
                    HStack(spacing: 12) {
                        AvatarView(title: store.profileName, id: 100)
                            .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.streamerMode ? "Скрытый пользователь" : store.profileName)
                                .font(.headline)
                                .lineLimit(1)
                            Text(store.streamerMode ? "@hidden" : store.profileUsername)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    TextField("Имя", text: $store.profileName)
                    TextField("Username", text: $store.profileUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("О себе", text: $store.profileBio, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Демо") {
                    Toggle("Демо-режим", isOn: $store.demoMode)
                    if store.demoMode {
                        Text("Демо-режим использует локальные чаты и позволяет писать в Избранное без backend.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Подключение") {
                    TextField("Адрес backend", text: $store.backendURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .disabled(store.demoMode)
                    Toggle("Синхронизация Telegram", isOn: $store.telegramSyncMode)
                        .disabled(store.demoMode)
                    Button {
                        Task { await store.refreshAuth() }
                    } label: {
                        Label("Проверить сессию", systemImage: "checkmark.shield")
                    }
                    .disabled(store.demoMode)
                }

                Section("Приватность интерфейса") {
                    Toggle("Стример-режим", isOn: $store.streamerMode)
                    Toggle("Liquid Glass сообщения", isOn: $store.liquidGlassMessages)
                }

                Section("Аккаунт") {
                    LabeledContent("Статус", value: store.authState.authorized ? "Авторизован" : "Не вошел")
                    if let phone = store.authState.phone {
                        LabeledContent("Телефон", value: store.streamerMode ? "Скрыт" : phone)
                    }
                    if let name = store.authState.userDisplayName {
                        LabeledContent("Пользователь", value: store.streamerMode ? "Скрыт" : name)
                    }
                }
            }
            .navigationTitle("qnola")
        }
    }
}
