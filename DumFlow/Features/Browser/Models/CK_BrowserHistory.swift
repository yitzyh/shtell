//
//  CK_BrowserHistory.swift
//  DumFlow
//
//  Created by Claude on 7/19/25.
//  Browser history tracking with analytics for future algorithm development
//

import CloudKit
import Foundation

struct BrowserHistory: Identifiable {
    let id: CKRecord.ID
    let urlString: String
    let title: String?
    let domain: String
    let dateVisited: Date
    let userID: String
    
    // Analytics data for future algorithm
    var viewDuration: TimeInterval? // How long they spent on page
    var scrollDepth: Double? // How far they scrolled (0.0-1.0)
    var didComment: Bool
    var didLike: Bool
    var didSave: Bool
    var referrerURL: String? // What page brought them here
    var visitCount: Int // How many times they visited this URL
    
    // Future feature fields
    var tags: [String]? // User-applied tags
    var rating: Int? // User rating 1-5
    var notes: String? // User notes about the page
    
    init(record: CKRecord) throws {
        // Required fields
        guard let urlString = record["urlString"] as? String else {
            throw NSError(domain: "BrowserHistory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing urlString"])
        }
        
        guard let userID = record["userID"] as? String else {
            throw NSError(domain: "BrowserHistory", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing userID"])
        }
        
        guard let dateVisited = record["dateVisited"] as? Date else {
            throw NSError(domain: "BrowserHistory", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing dateVisited"])
        }
        
        self.id = record.recordID
        self.urlString = urlString
        self.userID = userID
        self.dateVisited = dateVisited
        
        // Optional fields with defaults
        self.title = record["title"] as? String
        self.domain = record["domain"] as? String ?? URL(string: urlString)?.host ?? "unknown"
        
        // Analytics fields
        self.viewDuration = record["viewDuration"] as? TimeInterval
        self.scrollDepth = record["scrollDepth"] as? Double
        self.didComment = record["didComment"] as? Bool ?? false
        self.didLike = record["didLike"] as? Bool ?? false
        self.didSave = record["didSave"] as? Bool ?? false
        self.referrerURL = record["referrerURL"] as? String
        self.visitCount = record["visitCount"] as? Int ?? 1
        
        // Future feature fields
        self.tags = record["tags"] as? [String]
        self.rating = record["rating"] as? Int
        self.notes = record["notes"] as? String
    }
    
    // Create CloudKit record from BrowserHistory
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "BrowserHistory", recordID: id)
        
        // Required fields
        record["urlString"] = urlString
        record["userID"] = userID
        record["dateVisited"] = dateVisited
        
        // Optional fields
        record["title"] = title
        record["domain"] = domain
        
        // Analytics fields
        record["viewDuration"] = viewDuration
        record["scrollDepth"] = scrollDepth
        record["didComment"] = didComment
        record["didLike"] = didLike
        record["didSave"] = didSave
        record["referrerURL"] = referrerURL
        record["visitCount"] = visitCount
        
        // Future feature fields
        record["tags"] = tags
        record["rating"] = rating
        record["notes"] = notes
        
        return record
    }
}

// Convenience initializer for creating new history entries
extension BrowserHistory {
    init(
        urlString: String,
        title: String?,
        userID: String,
        referrerURL: String? = nil
    ) {
        // Use UUID to ensure unique record IDs and avoid duplicates
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        
        self.id = recordID
        self.urlString = urlString
        self.title = title
        self.userID = userID
        self.dateVisited = Date()
        self.domain = URL(string: urlString)?.host ?? "unknown"
        
        // Analytics defaults
        self.viewDuration = nil
        self.scrollDepth = nil
        self.didComment = false
        self.didLike = false
        self.didSave = false
        self.referrerURL = referrerURL
        self.visitCount = 1
        
        // Future feature defaults
        self.tags = nil
        self.rating = nil
        self.notes = nil
    }
}