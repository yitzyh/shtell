//
//  CK_User.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/14/25.
//

import CloudKit
import Foundation

struct User {
    let id: CKRecord.ID
    let userID: String            // ✅ NEW: Custom user identifier
    let appleUserID: String       // ✅ NEW: Apple authentication ID
    let username: String
    let displayName: String
    let dateCreated: Date
    let bio: String?
    let profileImageData: Data?   // ✅ NEW: Profile image data
    var isActive: Int             // ✅ NEW: 0/1 for active status
    var isBanned: Int             // ✅ NEW: 0/1 for banned status
    
    init(record: CKRecord) throws {
        guard let userID = record["userID"] as? String,
              let appleUserID = record["appleUserID"] as? String,
              let username = record["username"] as? String,
              let displayName = record["displayName"] as? String,
              let dateCreated = record["dateCreated"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        self.id = record.recordID
        self.userID = userID
        self.appleUserID = appleUserID
        self.username = username
        self.displayName = displayName
        self.dateCreated = dateCreated
        self.bio = record["bio"] as? String
        self.profileImageData = record["profileImageData"] as? Data
        self.isActive = record["isActive"] as? Int ?? 1
        self.isBanned = record["isBanned"] as? Int ?? 0
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "User", recordID: id)
        record["userID"] = userID
        record["appleUserID"] = appleUserID
        record["username"] = username
        record["displayName"] = displayName
        record["dateCreated"] = dateCreated
        record["bio"] = bio
        record["profileImageData"] = profileImageData
        record["isActive"] = isActive
        record["isBanned"] = isBanned
        return record
    }
}

extension User: Identifiable {}

extension User: Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.userID == rhs.userID
    }
}

extension User {
    var firstLetter: String {
        return String(username.prefix(1).uppercased())
    }
}

//extension User: CloudKitConvertible {}

// MARK: - User Relationship Models

struct UserBlock {
    let id: CKRecord.ID
    let blockerUserID: String
    let blockedUserID: String
    let dateCreated: Date
    
    init(record: CKRecord) throws {
        guard let blockerUserID = record["blockerUserID"] as? String,
              let blockedUserID = record["blockedUserID"] as? String,
              let dateCreated = record["dateCreated"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        self.id = record.recordID
        self.blockerUserID = blockerUserID
        self.blockedUserID = blockedUserID
        self.dateCreated = dateCreated
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "UserBlock", recordID: id)
        record["blockerUserID"] = blockerUserID
        record["blockedUserID"] = blockedUserID
        record["dateCreated"] = dateCreated
        return record
    }
}

extension UserBlock: Identifiable {}
//extension UserBlock: CloudKitConvertible {}

extension UserBlock {
    init(blockerUserID: String, blockedUserID: String) {
        // OPTIMIZED: Use composite recordName for direct CloudKit access
        let blockRecordName = "block_\(blockerUserID)_\(blockedUserID)"
        self.init(
            id: CKRecord.ID(recordName: blockRecordName),
            blockerUserID: blockerUserID,
            blockedUserID: blockedUserID,
            dateCreated: Date()
        )
    }
    
    private init(id: CKRecord.ID, blockerUserID: String, blockedUserID: String, dateCreated: Date) {
        self.id = id
        self.blockerUserID = blockerUserID
        self.blockedUserID = blockedUserID
        self.dateCreated = dateCreated
    }
}

struct UserMute {
    let id: CKRecord.ID
    let muterUserID: String
    let mutedUserID: String
    let dateCreated: Date
    
    init(record: CKRecord) throws {
        guard let muterUserID = record["muterUserID"] as? String,
              let mutedUserID = record["mutedUserID"] as? String,
              let dateCreated = record["dateCreated"] as? Date else {
            throw CloudKitError.invalidRecord
        }
        
        self.id = record.recordID
        self.muterUserID = muterUserID
        self.mutedUserID = mutedUserID
        self.dateCreated = dateCreated
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "UserMute", recordID: id)
        record["muterUserID"] = muterUserID
        record["mutedUserID"] = mutedUserID
        record["dateCreated"] = dateCreated
        return record
    }
}

extension UserMute: Identifiable {}
//extension UserMute: CloudKitConvertible {}

extension UserMute {
    init(muterUserID: String, mutedUserID: String) {
        self.init(
            id: CKRecord.ID(recordName: UUID().uuidString),
            muterUserID: muterUserID,
            mutedUserID: mutedUserID,
            dateCreated: Date()
        )
    }
    
    private init(id: CKRecord.ID, muterUserID: String, mutedUserID: String, dateCreated: Date) {
        self.id = id
        self.muterUserID = muterUserID
        self.mutedUserID = mutedUserID
        self.dateCreated = dateCreated
    }
}


