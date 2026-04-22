import Foundation

enum ShtellAPIError: Error, LocalizedError {
  case invalidURL
  case httpError(statusCode: Int, message: String)
  case decodingError(Error)
  case noData

  var errorDescription: String? {
    switch self {
    case .invalidURL:               return "Invalid URL"
    case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
    case .decodingError(let err):   return "Decode error: \(err.localizedDescription)"
    case .noData:                   return "No data received"
    }
  }
}

final class ShtellAPIClient {
  static let shared = ShtellAPIClient()
  private init() {}

  private let baseURL = "https://vercel-backend-azure-three.vercel.app"
  private let session = URLSession.shared
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  // MARK: - GET

  func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
    var components = URLComponents(string: baseURL + path)!
    if !query.isEmpty {
      components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    guard let url = components.url else { throw ShtellAPIError.invalidURL }

    let (data, response) = try await session.data(from: url)
    try validate(response, data)

    do { return try decoder.decode(T.self, from: data) }
    catch { throw ShtellAPIError.decodingError(error) }
  }

  // MARK: - POST

  func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
    guard let url = URL(string: baseURL + path) else { throw ShtellAPIError.invalidURL }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try encoder.encode(body)

    let (data, response) = try await session.data(for: request)
    try validate(response, data)

    do { return try decoder.decode(T.self, from: data) }
    catch { throw ShtellAPIError.decodingError(error) }
  }

  // MARK: - DELETE

  func delete<Body: Encodable>(_ path: String, body: Body) async throws {
    guard let url = URL(string: baseURL + path) else { throw ShtellAPIError.invalidURL }

    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try encoder.encode(body)

    let (data, response) = try await session.data(for: request)
    try validate(response, data)
  }

  // MARK: - Private

  private func validate(_ response: URLResponse, _ data: Data) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200...299).contains(http.statusCode) else {
      let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
        ?? String(data: data, encoding: .utf8)
        ?? "Unknown error"
      throw ShtellAPIError.httpError(statusCode: http.statusCode, message: message)
    }
  }
}
