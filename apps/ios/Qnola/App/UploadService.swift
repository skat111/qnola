import Foundation

@MainActor
final class UploadService: ObservableObject {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func upload(data: Data, fileName: String, mimeType: String) async throws -> UploadResponse {
        var request = URLRequest(url: URL(string: "/v1/uploads", relativeTo: client.baseURL)!.absoluteURL)
        request.httpMethod = "POST"
        if let accessToken = client.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(data: data, fileName: fileName, mimeType: mimeType, boundary: boundary)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIClientError.invalidResponse
        }
        return try JSONDecoder.qnola.decode(UploadResponse.self, from: responseData)
    }

    private func multipartBody(data: Data, fileName: String, mimeType: String, boundary: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
