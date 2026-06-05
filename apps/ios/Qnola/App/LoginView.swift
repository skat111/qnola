import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var phone = ""
    @State private var code = ""
    @State private var password = ""
    @State private var codeSent = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Backend URL", text: $store.backendURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    if codeSent {
                        TextField("Code", text: $code)
                            .keyboardType(.numberPad)
                        SecureField("2FA password", text: $password)
                    }
                }

                Section {
                    Button {
                        store.demoMode = true
                    } label: {
                        Label("Open Demo Mode", systemImage: "play.circle")
                    }

                    Button {
                        Task {
                            if codeSent {
                                await store.completeLogin(phone: phone, code: code, password: password)
                            } else {
                                await store.sendCode(phone: phone)
                                codeSent = true
                            }
                        }
                    } label: {
                        Label(codeSent ? "Sign In" : "Send Code", systemImage: codeSent ? "checkmark.circle" : "paperplane")
                    }
                    .disabled(store.isLoading || phone.isEmpty || (codeSent && code.isEmpty))
                }
            }
            .navigationTitle("qnola")
        }
    }
}
