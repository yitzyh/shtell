import Foundation

extension WebPageViewModel {

  func reportComment(_ comment: Comment, reason: String, details: String, completion: @escaping (Comment?, Bool) -> Void) {
    guard authViewModel.signedInUser != nil else { completion(nil, false); return }
    // TODO: Add report API in 1.4
    var updated = comment
    updated.isReported = 1
    updated.reportCount += 1
    completion(updated, true)
  }
}
