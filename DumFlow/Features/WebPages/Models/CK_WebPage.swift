//
//  CK_WebPage.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/14/25.
//  UPDATED: Added resilient parsing and better error handling for CloudKit records

import CloudKit
import Foundation

struct WebPage {
    let id: CKRecord.ID
    let urlString: String
    let title: String
    let domain: String
    let dateCreated: Date
    var commentCount: Int
    var likeCount: Int
    var saveCount: Int
    var isReported: Int
    var reportCount: Int           
    var faviconData: Data?
    var thumbnailData: Data?
    
    // ✅ UPDATED: Strict parsing with detailed error reporting
    init(record: CKRecord) throws {
        print("🔍 Parsing record: \(record.recordID.recordName)")
        
        // ✅ ADDED: Log all available keys for debugging
        let availableKeys = record.allKeys()
        print("🔍 Available keys in record: \(availableKeys)")
        
        guard let urlString = record["urlString"] as? String else {
            print("❌ Missing or invalid 'urlString' field in record \(record.recordID.recordName)")
            print("❌ Expected: String, Got: \(type(of: record["urlString"]))")
            throw CloudKitError.invalidRecord
        }
        
        guard let title = record["title"] as? String else {
            print("❌ Missing or invalid 'title' field in record \(record.recordID.recordName)")
            print("❌ Expected: String, Got: \(type(of: record["title"]))")
            throw CloudKitError.invalidRecord
        }
        
        guard let domain = record["domain"] as? String else {
            print("❌ Missing or invalid 'domain' field in record \(record.recordID.recordName)")
            print("❌ Expected: String, Got: \(type(of: record["domain"]))")
            throw CloudKitError.invalidRecord
        }
        
        guard let dateCreated = record["dateCreated"] as? Date else {
            print("❌ Missing or invalid 'dateCreated' field in record \(record.recordID.recordName)")
            print("❌ Expected: Date, Got: \(type(of: record["dateCreated"]))")
            throw CloudKitError.invalidRecord
        }
        
        // ✅ UPDATED: Set required fields
        self.id = record.recordID
        self.urlString = urlString
        self.title = title
        self.domain = domain
        self.dateCreated = dateCreated
        
        // ✅ UPDATED: Safe parsing with defaults for optional numeric fields
        self.commentCount = record["commentCount"] as? Int ?? 0
        self.likeCount = record["likeCount"] as? Int ?? 0
        self.saveCount = record["saveCount"] as? Int ?? 0
        self.isReported = record["isReported"] as? Int ?? 0
        self.reportCount = record["reportCount"] as? Int ?? 0
        
        // ✅ UPDATED: Handle binary data assets safely
        if let faviconAsset = record["faviconData"] as? CKAsset,
           let faviconURL = faviconAsset.fileURL {
            self.faviconData = try? Data(contentsOf: faviconURL)
        } else {
            self.faviconData = nil
        }
        
        if let thumbnailAsset = record["thumbnailData"] as? CKAsset,
           let thumbnailURL = thumbnailAsset.fileURL {
            self.thumbnailData = try? Data(contentsOf: thumbnailURL)
        } else {
            self.thumbnailData = nil
        }
        
        print("✅ Successfully parsed: \(title) (Comments: \(commentCount), Likes: \(likeCount))")
    }
    
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "WebPage", recordID: id)
        record["urlString"] = urlString
        record["title"] = title
        record["domain"] = domain
        record["dateCreated"] = dateCreated
        record["commentCount"] = commentCount
        record["likeCount"] = likeCount
        record["saveCount"] = saveCount
        record["isReported"] = isReported
        record["reportCount"] = reportCount
        
        // ✅ Handle binary data
//        if let faviconData = faviconData {
//            record["faviconData"] = faviconData
//        }
        
        if let bytes = faviconData {
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".ico")
            try? bytes.write(to: tmpURL)
            record["faviconData"] = CKAsset(fileURL: tmpURL)
        }
        
        if let thumbnailData = thumbnailData {
            record["thumbnailData"] = thumbnailData
        }
        
        return record
    }
}

// ✅ ADDED: Extension for resilient parsing
extension WebPage {
    /// ✅ ADDED: Resilient parsing that handles incomplete/corrupted records
    /// This method tries to salvage as much data as possible from broken records
    static func safeInit(from record: CKRecord) -> WebPage? {
        print("🔍 Safe parsing record: \(record.recordID.recordName)")
        
        // ✅ REQUIRED: Extract URL string (fallback to record name)
        let urlString: String
        if let recordURL = record["urlString"] as? String {
            urlString = recordURL
        } else {
            // ✅ FALLBACK: Use record name as URL (often the case in your CloudKit)
            urlString = record.recordID.recordName
            print("⚠️ Using record name as URL: \(urlString)")
        }
        
        // ✅ REQUIRED: Extract title (fallback to URL domain)
        let title: String
        if let recordTitle = record["title"] as? String, !recordTitle.isEmpty {
            title = recordTitle
        } else {
            // ✅ FALLBACK: Generate title from URL
            if let host = URL(string: urlString)?.host {
                title = host.replacingOccurrences(of: "www.", with: "").capitalized
            } else {
                title = "Untitled Page"
            }
            print("⚠️ Generated title from URL: \(title)")
        }
        
        // ✅ REQUIRED: Extract domain (fallback to URL parsing)
        let domain: String
        if let recordDomain = record["domain"] as? String, !recordDomain.isEmpty {
            domain = recordDomain
        } else {
            // ✅ FALLBACK: Extract domain from URL
            domain = URL(string: urlString)?.host ?? "unknown.domain"
            print("⚠️ Generated domain from URL: \(domain)")
        }
        
        // ✅ REQUIRED: Extract date (fallback to creation date or now)
        let dateCreated: Date
        if let recordDate = record["dateCreated"] as? Date {
            dateCreated = recordDate
        } else if let creationDate = record.creationDate {
            // ✅ FALLBACK: Use CloudKit's creation date
            dateCreated = creationDate
            print("⚠️ Using CloudKit creation date: \(creationDate)")
        } else {
            // ✅ FALLBACK: Use current date
            dateCreated = Date()
            print("⚠️ Using current date as fallback")
        }
        
        // ✅ OPTIONAL: Extract numeric fields (safe defaults)
        let commentCount = record["commentCount"] as? Int ?? 0
        let likeCount = record["likeCount"] as? Int ?? 0
        let saveCount = record["saveCount"] as? Int ?? 0
        let isReported = record["isReported"] as? Int ?? 0
        let reportCount = record["reportCount"] as? Int ?? 0
        
        // ✅ OPTIONAL: Extract binary data (safe handling)
        let faviconData: Data?
        if let faviconAsset = record["faviconData"] as? CKAsset,
           let faviconURL = faviconAsset.fileURL {
            faviconData = try? Data(contentsOf: faviconURL)
        } else {
            faviconData = nil
        }
        
        let thumbnailData: Data?
        if let thumbnailAsset = record["thumbnailData"] as? CKAsset,
           let thumbnailURL = thumbnailAsset.fileURL {
            thumbnailData = try? Data(contentsOf: thumbnailURL)
        } else {
            thumbnailData = nil
        }
        
        // ✅ CREATE: WebPage with all extracted/fallback data
        let webPage = WebPage(
            id: record.recordID,
            urlString: urlString,
            title: title,
            domain: domain,
            dateCreated: dateCreated,
            commentCount: commentCount,
            likeCount: likeCount,
            saveCount: saveCount,
            isReported: isReported,
            reportCount: reportCount,
            faviconData: faviconData,
            thumbnailData: thumbnailData
        )
        
        print("✅ Safe parsed: \(title) from \(domain)")
        return webPage
    }
}

// ✅ KEPT: Protocol conformance
extension WebPage: Identifiable {}

extension WebPage: Equatable {
    static func == (lhs: WebPage, rhs: WebPage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.urlString == rhs.urlString &&
               lhs.title == rhs.title &&
               lhs.domain == rhs.domain &&
               lhs.dateCreated == rhs.dateCreated &&
               lhs.commentCount == rhs.commentCount &&
               lhs.likeCount == rhs.likeCount &&
               lhs.saveCount == rhs.saveCount &&
               lhs.isReported == rhs.isReported &&
               lhs.reportCount == rhs.reportCount &&
               lhs.faviconData == rhs.faviconData &&
               lhs.thumbnailData == rhs.thumbnailData
    }
}

extension WebPage {
    var shortURL: String {
        return urlString.shortURL()
    }
}

//extension WebPage: CloudKitConvertible {}

// ✅ ADDED: Convenience initializer for creating new WebPages
extension WebPage {
    init(id: CKRecord.ID, urlString: String, title: String, domain: String, dateCreated: Date, commentCount: Int, likeCount: Int, saveCount: Int, isReported: Int, reportCount: Int, faviconData: Data?, thumbnailData: Data?) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.domain = domain
        self.dateCreated = dateCreated
        self.commentCount = commentCount
        self.likeCount = likeCount
        self.saveCount = saveCount
        self.isReported = isReported
        self.reportCount = reportCount
        self.faviconData = faviconData
        self.thumbnailData = thumbnailData
    }
}

// ✅ ADDED: Debug helpers
extension WebPage {
    /// ✅ ADDED: Debug description for logging
    var debugDescription: String {
        return """
        WebPage(
            id: \(id.recordName),
            title: \(title),
            domain: \(domain),
            url: \(urlString),
            comments: \(commentCount),
            likes: \(likeCount),
            saves: \(saveCount),
            created: \(dateCreated)
        )
        """
    }
}
