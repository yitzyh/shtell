import Foundation

final class CommentAPIService {
  static let shared = CommentAPIService()
  private init() {}

  private let client = ShtellAPIClient.shared
  private let path = "/api/comments"

  // MARK: - Fetch

  func fetchComments(for urlString: String) async throws -> [Comment] {
    let response: CommentsResponse = try await client.get(path, query: ["urlString": urlString])
    return response.comments
  }

  func fetchComments(byUserID userID: String) async throws -> [Comment] {
    let response: CommentsResponse = try await client.get(path, query: ["userID": userID])
    return response.comments
  }

  // MARK: - Delete

  func deleteComment(urlString: String, commentID: String) async throws {
    let body = DeleteCommentBody(urlString: urlString, commentID: commentID)
    try await client.delete(path, body: body)
  }

  // MARK: - Post

  func postComment(
    urlString: String,
    text: String,
    userID: String,
    username: String,
    parentCommentID: String? = nil,
    quotedText: String? = nil,
    quotedTextSelector: String? = nil,
    quotedTextOffset: Int? = nil,
    pageTitle: String? = nil,
    domain: String? = nil,
    faviconURL: String? = nil,
    thumbnailURL: String? = nil
  ) async throws -> Comment {
    let body = PostCommentBody(
      urlString: urlString,
      text: text,
      userID: userID,
      username: username,
      parentCommentID: parentCommentID,
      quotedText: quotedText,
      quotedTextSelector: quotedTextSelector,
      quotedTextOffset: quotedTextOffset,
      pageTitle: pageTitle,
      domain: domain,
      faviconURL: faviconURL,
      thumbnailURL: thumbnailURL
    )
    let response: CommentResponse = try await client.post(path, body: body)
    return response.comment
  }
}

// MARK: - Codable Helpers

private struct CommentsResponse: Decodable {
  let comments: [Comment]
}

private struct CommentResponse: Decodable {
  let comment: Comment
}

private struct DeleteCommentBody: Encodable {
  let urlString: String
  let commentID: String
}

private struct PostCommentBody: Encodable {
  let urlString: String
  let text: String
  let userID: String
  let username: String
  let parentCommentID: String?
  let quotedText: String?
  let quotedTextSelector: String?
  let quotedTextOffset: Int?
  let pageTitle: String?
  let domain: String?
  let faviconURL: String?
  let thumbnailURL: String?
}
