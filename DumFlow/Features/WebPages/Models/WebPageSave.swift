//
//  WebPageSave.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/19/25.
//

import CloudKit
import Foundation


struct WebPageSave {
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
        let record = CKRecord(recordType: "WebPageSave", recordID: id)
        record["urlString"] = urlString
        record["userID"] = userID
        record["dateCreated"] = dateCreated
        return record
    }
}

extension WebPageSave: Identifiable {}

extension WebPageSave {
    init(urlString: String, userID: String) {
        // OPTIMIZED: Use composite recordName for direct CloudKit access
        let saveRecordName = "websave_\(userID)_\(urlString)"
        self.init(
            id: CKRecord.ID(recordName: saveRecordName),
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
