import Foundation

struct PageMetadata: Codable, Identifiable {
  let urlString: String
  let title: String?
  let domain: String?
  let faviconURL: String?
  let thumbnailURL: String?
  let commentCount: Int
  let lastCommentAt: String?

  var id: String { urlString }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    urlString = try c.decode(String.self, forKey: .urlString)
    title = try c.decodeIfPresent(String.self, forKey: .title)
    domain = try c.decodeIfPresent(String.self, forKey: .domain)
    faviconURL = try c.decodeIfPresent(String.self, forKey: .faviconURL)
    thumbnailURL = try c.decodeIfPresent(String.self, forKey: .thumbnailURL)
    commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
    lastCommentAt = try c.decodeIfPresent(String.self, forKey: .lastCommentAt)
  }
}
