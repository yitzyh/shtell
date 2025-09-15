//
//  Comment.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/14/25.
//


import CloudKit
import Foundation

struct Comment {
    
    let id: CKRecord.ID
    let commentID: String
    let text: String
    let dateCreated: Date
    let userID: String
    let username: String
    let urlString: String
    
    let parentCommentID: String?
    
    // Quote metadata
    let quotedText: String?
    let quotedTextSelector: String?
    let quotedTextOffset: Int?
    
    var likeCount: Int
    var saveCount: Int        
    var isReported: Int
    var reportCount: Int
    
    init(record: CKRecord) throws {
        guard let commentID = record["commentID"] as? String,
              let text = record["text"] as? String,
              let dateCreated = record["dateCreated"] as? Date,
              let userID = record["userID"] as? String,
              let urlString = record["urlString"] as? String else {
            throw CloudKitError.invalidRecord
        }
        
        self.id = record.recordID
        self.commentID = commentID
        self.text = text
        self.dateCreated = dateCreated
        self.userID = userID
        self.username = record["username"] as? String ?? userID.prefix(8).description
        self.urlString = urlString
        self.parentCommentID = record["parentCommentID"] as? String
        self.quotedText = record["quotedText"] as? String
        self.quotedTextSelector = record["quotedTextSelector"] as? String
        self.quotedTextOffset = record["quotedTextOffset"] as? Int
        self.likeCount = record["likeCount"] as? Int ?? 0
        self.saveCount = record["saveCount"] as? Int ?? 0
        self.isReported = record["isReported"] as? Int ?? 0
        self.reportCount = record["reportCount"] as? Int ?? 0
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "Comment", recordID: id)
        record["commentID"] = commentID
        record["text"] = text
        record["dateCreated"] = dateCreated
        record["userID"] = userID
        record["username"] = username
        record["urlString"] = urlString
        record["parentCommentID"] = parentCommentID
        record["quotedText"] = quotedText
        record["quotedTextSelector"] = quotedTextSelector
        record["quotedTextOffset"] = quotedTextOffset
        record["likeCount"] = likeCount
        record["saveCount"] = saveCount
        record["isReported"] = isReported
        record["reportCount"] = reportCount
        return record
    }
    
}

extension Comment: Identifiable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(commentID)
    }
    
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.commentID == rhs.commentID
    }
}

extension Comment {
    var timeAgoShort: String {
        return dateCreated.timeAgoShort()
    }
    
    // Convenience initializer for previews and testing
    init(id: CKRecord.ID, commentID: String, text: String, dateCreated: Date, userID: String, username: String, urlString: String, parentCommentID: String? = nil, quotedText: String? = nil, quotedTextSelector: String? = nil, quotedTextOffset: Int? = nil, likeCount: Int, saveCount: Int, isReported: Int, reportCount: Int) {
        self.id = id
        self.commentID = commentID
        self.text = text
        self.dateCreated = dateCreated
        self.userID = userID
        self.username = username
        self.urlString = urlString
        self.parentCommentID = parentCommentID
        self.quotedText = quotedText
        self.quotedTextSelector = quotedTextSelector
        self.quotedTextOffset = quotedTextOffset
        self.likeCount = likeCount
        self.saveCount = saveCount
        self.isReported = isReported
        self.reportCount = reportCount
    }
}
