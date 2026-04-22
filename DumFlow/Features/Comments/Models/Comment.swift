import Foundation

struct Comment: Codable, Identifiable, Hashable {
  let commentID: String
  let urlString: String
  let text: String
  let userID: String
  let username: String
  let dateCreated: String // ISO 8601

  let parentCommentID: String?

  // Quote metadata
  let quotedText: String?
  let quotedTextSelector: String?
  let quotedTextOffset: Int?

  // Kept for 1.4 — not wired to backend yet
  var likeCount: Int
  var saveCount: Int
  var isReported: Int
  var reportCount: Int

  var id: String { commentID }

  init(
    commentID: String,
    urlString: String,
    text: String,
    userID: String,
    username: String,
    dateCreated: String,
    parentCommentID: String? = nil,
    quotedText: String? = nil,
    quotedTextSelector: String? = nil,
    quotedTextOffset: Int? = nil,
    likeCount: Int = 0,
    saveCount: Int = 0,
    isReported: Int = 0,
    reportCount: Int = 0
  ) {
    self.commentID = commentID
    self.urlString = urlString
    self.text = text
    self.userID = userID
    self.username = username
    self.dateCreated = dateCreated
    self.parentCommentID = parentCommentID
    self.quotedText = quotedText
    self.quotedTextSelector = quotedTextSelector
    self.quotedTextOffset = quotedTextOffset
    self.likeCount = likeCount
    self.saveCount = saveCount
    self.isReported = isReported
    self.reportCount = reportCount
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    commentID = try c.decode(String.self, forKey: .commentID)
    urlString = try c.decode(String.self, forKey: .urlString)
    text = try c.decode(String.self, forKey: .text)
    userID = try c.decode(String.self, forKey: .userID)
    username = try c.decode(String.self, forKey: .username)
    dateCreated = try c.decode(String.self, forKey: .dateCreated)
    parentCommentID = try c.decodeIfPresent(String.self, forKey: .parentCommentID)
    quotedText = try c.decodeIfPresent(String.self, forKey: .quotedText)
    quotedTextSelector = try c.decodeIfPresent(String.self, forKey: .quotedTextSelector)
    quotedTextOffset = try c.decodeIfPresent(Int.self, forKey: .quotedTextOffset)
    likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
    saveCount = try c.decodeIfPresent(Int.self, forKey: .saveCount) ?? 0
    isReported = try c.decodeIfPresent(Int.self, forKey: .isReported) ?? 0
    reportCount = try c.decodeIfPresent(Int.self, forKey: .reportCount) ?? 0
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(commentID)
  }

  static func == (lhs: Comment, rhs: Comment) -> Bool {
    lhs.commentID == rhs.commentID
  }
}

extension Comment {
  var timeAgoShort: String {
    guard let date = ISO8601DateFormatter().date(from: dateCreated) else { return "" }
    return date.timeAgoShort()
  }
}
