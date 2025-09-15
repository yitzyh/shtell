//
//  UserFollow.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/12/25.
//

import CloudKit
import Foundation


struct UserFollow {
    let id: CKRecord.ID
    let followerUserID: String
    let followedUserID: String
    let dateCreated: Date
    
    init(record: CKRecord) throws {
        guard let followerUserID = record["followerUserID"] as? String,
              let followedUserID = record["followedUserID"] as? String,
              let dateCreated = record["dateCreated"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        self.id = record.recordID
        self.followerUserID = followerUserID
        self.followedUserID = followedUserID
        self.dateCreated = dateCreated
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "UserFollow", recordID: id)
        record["followerUserID"] = followerUserID
        record["followedUserID"] = followedUserID
        record["dateCreated"] = dateCreated
        return record
    }
}

extension UserFollow: Identifiable {}

extension UserFollow {
    init(followerUserID: String, followedUserID: String) {
        // OPTIMIZED: Use composite recordName for direct CloudKit access
        let followRecordName = "follow_\(followerUserID)_\(followedUserID)"
        self.init(
            id: CKRecord.ID(recordName: followRecordName),
            followerUserID: followerUserID,
            followedUserID: followedUserID,
            dateCreated: Date()
        )
    }
    
    private init(id: CKRecord.ID, followerUserID: String, followedUserID: String, dateCreated: Date) {
        self.id = id
        self.followerUserID = followerUserID
        self.followedUserID = followedUserID
        self.dateCreated = dateCreated
    }
}