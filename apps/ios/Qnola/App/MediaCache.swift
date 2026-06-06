import SwiftUI
import UIKit

@MainActor
final class MediaCache: ObservableObject {
    static let shared = MediaCache()

    @Published private var images: [String: UIImage] = [:]
    private let directory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = caches.appendingPathComponent("QnolaMediaCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func image(for urlString: String?) -> UIImage? {
        guard let urlString else { return nil }
        if let image = images[urlString] { return image }
        let file = fileURL(for: urlString)
        guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
        images[urlString] = image
        return image
    }

    func loadImage(_ urlString: String?) async {
        guard let urlString, images[urlString] == nil, let url = URL(string: urlString) else { return }
        let file = fileURL(for: urlString)
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            images[urlString] = image
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode, let image = UIImage(data: data) else { return }
            try? data.write(to: file, options: .atomic)
            images[urlString] = image
        } catch {
            return
        }
    }

    private func fileURL(for value: String) -> URL {
        let safe = value.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") ?? UUID().uuidString
        return directory.appendingPathComponent(safe).appendingPathExtension("cache")
    }
}
