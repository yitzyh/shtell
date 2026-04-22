import Foundation

struct SavedWebPage: Codable, Identifiable, Equatable {
  let userID: String
  let urlString: String
  let title: String
  let domain: String
  let dateSaved: String     // ISO 8601
  let thumbnailURL: String? // og:image — optional until API supports it
  let faviconURL: String?   // favicon — optional until API supports it

  var id: String { urlString }
}
