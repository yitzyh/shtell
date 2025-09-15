//
//  CommentSave.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/24/25.
//

import CloudKit
import Foundation


struct CommentSave {
    let id: CKRecord.ID
    let commentID: String
    let userID: String
    let dateCreated: Date
    
    init(record: CKRecord) throws {
        guard let commentID = record["commentID"] as? String,
              let userID = record["userID"] as? String,
              let dateCreated = record["dateCreated"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        self.id = record.recordID
        self.commentID = commentID
        self.userID = userID
        self.dateCreated = dateCreated
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "CommentSave", recordID: id)
        record["commentID"] = commentID
        record["userID"] = userID
        record["dateCreated"] = dateCreated
        return record
    }
}

extension CommentSave: Identifiable {}
//extension CommentSave: CloudKitConvertible {}

extension CommentSave {
    init(commentID: String, userID: String) {
        self.init(
            id: CKRecord.ID(recordName: UUID().uuidString),
            commentID: commentID,
            userID: userID,
            dateCreated: Date()
        )
    }
    
    private init(id: CKRecord.ID, commentID: String, userID: String, dateCreated: Date) {
        self.id = id
        self.commentID = commentID
        self.userID = userID
        self.dateCreated = dateCreated
    }
}