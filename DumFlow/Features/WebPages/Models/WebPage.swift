import Foundation

struct WebPage: Codable, Identifiable, Equatable {
  let urlString: String
  let title: String
  let domain: String
  let dateCreated: Date
  var commentCount: Int
  var faviconData: Data?
  var thumbnailData: Data?

  var id: String { urlString }

  init(
    urlString: String,
    title: String,
    domain: String,
    dateCreated: Date = Date(),
    commentCount: Int = 0,
    faviconData: Data? = nil,
    thumbnailData: Data? = nil
  ) {
    self.urlString = urlString
    self.title = title
    self.domain = domain
    self.dateCreated = dateCreated
    self.commentCount = commentCount
    self.faviconData = faviconData
    self.thumbnailData = thumbnailData
  }

  /// Convenience init from a SavedWebPage (for display in saved lists)
  init(savedPage: SavedWebPage) {
    let date = ISO8601DateFormatter().date(from: savedPage.dateSaved) ?? Date()
    self.init(
      urlString: savedPage.urlString,
      title: savedPage.title,
      domain: savedPage.domain,
      dateCreated: date
    )
  }
}

extension WebPage {
  var shortURL: String { urlString.shortURL() }
}
