import Foundation

struct BinblogLoginClient {
    var session: URLSession = .shared

    func login(username: String, password: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://khuonvien.vn/api/login")!, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(Credentials(username: username, password: password))
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw DeviceAPIError.invalidResponse }
        guard response.statusCode == 200 else { throw DeviceAPIError.httpStatus(response.statusCode) }
        let result = try JSONDecoder().decode(LoginResponse.self, from: data)
        guard !result.token.isEmpty else { throw DeviceAPIError.missingAccessToken }
        return result.token
    }

    private struct Credentials: Encodable { let username: String; let password: String }
    private struct LoginResponse: Decodable { let token: String }
}
