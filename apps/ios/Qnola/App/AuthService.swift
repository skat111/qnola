import Foundation
import UIKit

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var isAuthenticated = false

    private let client: APIClient
    private let defaults: UserDefaults

    init(client: APIClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        self.client.accessToken = defaults.string(forKey: "accessToken")
        self.isAuthenticated = self.client.accessToken != nil
    }

    func sendCode(phone: String) async throws {
        try await client.v1SendCode(phone: phone)
    }

    func verifyCode(phone: String, code: String, displayName: String?, username: String?) async throws {
        let tokens = try await client.v1VerifyCode(phone: phone, code: code, displayName: displayName, username: username, deviceName: UIDevice.current.name)
        store(tokens)
    }

    func refreshIfPossible() async {
        guard let refreshToken = defaults.string(forKey: "refreshToken") else { return }
        do {
            let tokens = try await client.v1Refresh(refreshToken: refreshToken)
            store(tokens)
        } catch {
            signOutLocally()
        }
    }

    func loadMe() async throws {
        currentUser = try await client.me()
        isAuthenticated = true
    }

    func updateProfile(displayName: String?, username: String?, bio: String?) async throws {
        currentUser = try await client.patchMe(displayName: displayName, username: username, bio: bio)
    }

    func signOut() async {
        try? await client.v1Logout()
        signOutLocally()
    }

    private func store(_ tokens: AuthTokens) {
        defaults.set(tokens.accessToken, forKey: "accessToken")
        defaults.set(tokens.refreshToken, forKey: "refreshToken")
        client.accessToken = tokens.accessToken
        currentUser = tokens.user
        isAuthenticated = true
    }

    private func signOutLocally() {
        defaults.removeObject(forKey: "accessToken")
        defaults.removeObject(forKey: "refreshToken")
        client.accessToken = nil
        currentUser = nil
        isAuthenticated = false
    }
}
