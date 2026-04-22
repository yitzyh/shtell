import Foundation

final class PagesAPIService {
  static let shared = PagesAPIService()
  private init() {}

  private let client = ShtellAPIClient.shared
  private let path = "/api/pages"

  func fetchTrending() async throws -> [PageMetadata] {
    let response: TrendingPagesResponse = try await client.get(path, query: ["trending": "true"])
    return response.pages
  }

  func fetchPageMetadata(for urlString: String) async throws -> PageMetadata? {
    do {
      let response: SinglePageResponse = try await client.get(path, query: ["urlString": urlString])
      return response.page
    } catch ShtellAPIError.httpError(let code, _) where code == 404 {
      return nil
    }
  }
}

private struct TrendingPagesResponse: Decodable {
  let pages: [PageMetadata]
}

private struct SinglePageResponse: Decodable {
  let page: PageMetadata
}
