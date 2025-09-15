import Foundation
import CloudKit
import Combine

// MARK: - Comment Reporting Extension (MVP - Pure CloudKit)
extension WebPageViewModel {
    
    /// Reports a comment - MVP version
    func reportComment(_ comment: Comment, reason: String, details: String, completion: @escaping (Comment?, Bool) -> Void) {
        guard authViewModel.signedInUser != nil else {
            completion(nil, false)
            return
        }
        
        let commentRecordID = comment.id
        
        let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
        let database = container.publicCloudDatabase
        
        database.fetch(withRecordID: commentRecordID) { record, error in
            guard let commentRecord = record else {
                DispatchQueue.main.async { completion(nil, false) }
                return
            }
            
            commentRecord["isReported"] = true
            let currentCount = commentRecord["reportCount"] as? Int64 ?? 0
            commentRecord["reportCount"] = currentCount + 1
            
            database.save(commentRecord) { _, saveError in
                DispatchQueue.main.async {
                    if saveError == nil {
                        // ✅ Create updated comment and return it
                        var updatedComment = comment
                        updatedComment.isReported = 1
                        updatedComment.reportCount += 1
                        completion(updatedComment, true)
                    } else {
                        completion(nil, false)
                    }
                }
            }
        }
    }
}
