//
//  WebPageLike.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/24/25.
//

import CloudKit
import Foundation


struct WebPageLike {
    let id: CKRecord.ID
    let urlString: String
    let userID: String
    let dateCreated: Date
    
    init(record: CKRecord) throws {
        guard let urlString = record["urlString"] as? String,
              let userID = record["userID"] as? String,
              let dateCreated = record["dateCreated"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        self.id = record.recordID
        self.urlString = urlString
        self.userID = userID
        self.dateCreated = dateCreated
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "WebPageLike", recordID: id)
        record["urlString"] = urlString
        record["userID"] = userID
        record["dateCreated"] = dateCreated
        return record
    }
}

extension WebPageLike: Identifiable {}
//extension WebPageLike: CloudKitConvertible {}

extension WebPageLike {
    init(urlString: String, userID: String) {
        // OPTIMIZED: Use composite recordName for direct CloudKit access
        let likeRecordName = "weblike_\(userID)_\(urlString)"
        self.init(
            id: CKRecord.ID(recordName: likeRecordName),
            urlString: urlString,
            userID: userID,
            dateCreated: Date()
        )
    }
    
    private init(id: CKRecord.ID, urlString: String, userID: String, dateCreated: Date) {
        self.id = id
        self.urlString = urlString
        self.userID = userID
        self.dateCreated = dateCreated
    }
}