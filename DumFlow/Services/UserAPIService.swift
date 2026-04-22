import Foundation

final class UserAPIService {
  static let shared = UserAPIService()
  private init() {}

  private let client = ShtellAPIClient.shared
  private let path = "/api/users"

  // MARK: - Lookup

  func lookupByAppleUserID(_ appleUserID: String) async throws -> User {
    let response: UserResponse = try await client.get(path, query: ["appleUserID": appleUserID])
    return response.user
  }

  func lookupByUserID(_ userID: String) async throws -> User {
    let response: UserResponse = try await client.get(path, query: ["userID": userID])
    return response.user
  }

  func isUsernameAvailable(_ username: String) async throws -> Bool {
    let response: AvailabilityResponse = try await client.get(
      path,
      query: ["username": username, "checkAvailability": "true"]
    )
    return response.available
  }

  // MARK: - Create

  func createUser(appleUserID: String, username: String, displayName: String) async throws -> User {
    let body = CreateUserBody(appleUserID: appleUserID, username: username, displayName: displayName)
    let response: UserResponse = try await client.post(path, body: body)
    return response.user
  }
}

// MARK: - Codable Helpers

private struct UserResponse: Decodable {
  let user: User
}

private struct AvailabilityResponse: Decodable {
  let available: Bool
}

private struct CreateUserBody: Encodable {
  let appleUserID: String
  let username: String
  let displayName: String
}
