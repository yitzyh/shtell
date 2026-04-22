import Foundation

final class SavedWebPagesAPIService {
  static let shared = SavedWebPagesAPIService()
  private init() {}

  private let client = ShtellAPIClient.shared
  private let path = "/api/saved-webpages"

  // MARK: - Fetch

  func fetchSavedPages(for userID: String) async throws -> [SavedWebPage] {
    let response: SavedPagesResponse = try await client.get(path, query: ["userID": userID])
    return response.savedPages
  }

  func isSaved(userID: String, urlString: String) async throws -> Bool {
    let response: IsSavedResponse = try await client.get(
      path,
      query: ["userID": userID, "urlString": urlString]
    )
    return response.saved
  }

  // MARK: - Save

  func savePage(
    userID: String,
    urlString: String,
    title: String,
    domain: String,
    thumbnailURL: String? = nil,
    faviconURL: String? = nil
  ) async throws -> SavedWebPage {
    let body = SavePageBody(
      userID: userID,
      urlString: urlString,
      title: title,
      domain: domain,
      thumbnailURL: thumbnailURL,
      faviconURL: faviconURL
    )
    let response: SavedPageResponse = try await client.post(path, body: body)
    return response.savedPage
  }

  // MARK: - Unsave

  func unsavePage(userID: String, urlString: String) async throws {
    let body = UnsavePageBody(userID: userID, urlString: urlString)
    try await client.delete(path, body: body)
  }
}

// MARK: - Codable Helpers

private struct SavedPagesResponse: Decodable {
  let savedPages: [SavedWebPage]
}

private struct IsSavedResponse: Decodable {
  let saved: Bool
}

private struct SavedPageResponse: Decodable {
  let savedPage: SavedWebPage
}

private struct SavePageBody: Encodable {
  let userID: String
  let urlString: String
  let title: String
  let domain: String
  let thumbnailURL: String?
  let faviconURL: String?
}

private struct UnsavePageBody: Encodable {
  let userID: String
  let urlString: String
}
