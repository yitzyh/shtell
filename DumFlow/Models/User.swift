import Foundation

struct User: Codable, Identifiable, Equatable {
  let userID: String
  let appleUserID: String
  let username: String
  let displayName: String
  let dateCreated: String // ISO 8601

  var id: String { userID }

  static func == (lhs: User, rhs: User) -> Bool {
    lhs.userID == rhs.userID
  }
}

extension User {
  var firstLetter: String {
    String(username.prefix(1).uppercased())
  }
}
