import Foundation
import CloudKit

@MainActor
class CommentService: ObservableObject {
    
    // MARK: - Dependencies
    private let publicDatabase = CKContainer(identifier: "iCloud.com.yitzy.DumFlow").publicCloudDatabase
    private let authViewModel: AuthViewModel
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    // MARK: - Core Method
    /// Creates a WebPage AND first comment together in one atomic operation
    /// Media loads in background for fast user experience
    func addFirstComment(text: String, url: String, quotedText: String? = nil, quotedTextSelector: String? = nil, quotedTextOffset: Int? = nil) async throws -> (WebPage, Comment) {
        
        print("🟢 CommentService: Starting addFirstComment for URL: \(url)")
        
        // Debug: Check quote data
        if let quotedText = quotedText {
            print("🔍 DEBUG CommentService: Quote data received: '\(quotedText)'")
        } else {
            print("🔍 DEBUG CommentService: No quote data received")
        }
        
        // Get authenticated user
        guard let user = authViewModel.signedInUser else {
            throw DumFlowError.authenticationRequired
        }
        
        // Step 1: Normalize the URL
        guard let normalizedURL = url.normalizedURL,
              let _ = URL(string: normalizedURL) else {
            throw DumFlowError.invalidURL
        }
        
        // Step 2: Create WebPage record (basic info only)
        let webPageRecord = createWebPageRecord(for: normalizedURL)
        print("✅ CommentService: WebPage record created")
        
        // Step 3: Create Comment record
        let commentRecord = createCommentRecord(text: text, urlString: normalizedURL, user: user, quotedText: quotedText, quotedTextSelector: quotedTextSelector, quotedTextOffset: quotedTextOffset)
        print("✅ CommentService: Comment record created")
        
        // Step 4: Save BOTH to CloudKit together (atomic operation)
        let savedRecords = try await saveBothRecords(webPageRecord: webPageRecord, commentRecord: commentRecord)
        print("✅ CommentService: Both records saved to CloudKit")
        
        // Step 5: Convert CloudKit records back to local objects
        let webPage = makeWebPage(from: savedRecords.webPage)
        let comment = try Comment(record: savedRecords.comment)
        
        // Step 6: Start background media fetching (don't wait for it)
        Task {
            print("🔄 CommentService: Starting background media fetch for \(normalizedURL)")
            await fetchAndUpdateMedia(for: normalizedURL)
        }
        
        print("🎉 CommentService: addFirstComment completed successfully")
        return (webPage, comment)
    }
    
    // MARK: - Private Helper Methods
    
    /// Creates a WebPage record with basic info (media loads later)
    private func createWebPageRecord(for urlString: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: urlString)
        let record = CKRecord(recordType: "WebPage", recordID: recordID)
        
        // Basic required fields - fast to create
        record["dateCreated"] = Date() as NSDate
        record["urlString"] = urlString as NSString
        record["title"] = extractQuickTitle(from: urlString) as NSString  // Smart placeholder
        record["commentCount"] = 1 as NSNumber      // Starting with 1 comment
        record["likeCount"] = 0 as NSNumber
        record["saveCount"] = 0 as NSNumber
        record["isReported"] = 0 as NSNumber
        record["reportCount"] = 0 as NSNumber
        record["domain"] = (URL(string: urlString)?.host ?? "") as NSString
        
        return record
    }
    
    /// Creates a Comment record
    private func createCommentRecord(text: String, urlString: String, user: User, quotedText: String? = nil, quotedTextSelector: String? = nil, quotedTextOffset: Int? = nil) -> CKRecord {
        let commentID = UUID().uuidString
        let record = CKRecord(recordType: "Comment", recordID: CKRecord.ID(recordName: commentID))
        
        record["text"] = text as NSString
        record["urlString"] = urlString as NSString
        record["userID"] = user.userID as NSString
        record["username"] = user.username as NSString
        record["dateCreated"] = Date() as NSDate
        record["commentID"] = commentID as NSString
        // No parentCommentID for first comment
        
        // Quote metadata
        record["quotedText"] = quotedText
        record["quotedTextSelector"] = quotedTextSelector
        record["quotedTextOffset"] = quotedTextOffset
        
        return record
    }
    
    /// Saves both records to CloudKit in one atomic operation
    private func saveBothRecords(webPageRecord: CKRecord, commentRecord: CKRecord) async throws -> (webPage: CKRecord, comment: CKRecord) {
        
        return try await withCheckedThrowingContinuation { continuation in
            let modifyOp = CKModifyRecordsOperation(recordsToSave: [webPageRecord, commentRecord], recordIDsToDelete: nil)
            modifyOp.savePolicy = .changedKeys
            
            modifyOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("✅ CommentService: Batch save successful")
                    continuation.resume(returning: (webPage: webPageRecord, comment: commentRecord))
                case .failure(let error):
                    print("❌ CommentService: Batch save failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            self.publicDatabase.add(modifyOp)
        }
    }
    
    /// Background task: Fetch media and update WebPage
    private func fetchAndUpdateMedia(for urlString: String) async {
        do {
            // Use existing MediaFetcher
            let media = await MediaFetcher.shared.fetchAllMedia(for: urlString)
                .values
                .first { _ in true } // Get first emitted value
            
            guard let media = media else {
                print("⚠️ CommentService: No media fetched for \(urlString)")
                return
            }
            
            // Update WebPage record with real title and media
            try await updateWebPageWithMedia(urlString: urlString, media: media)
            print("✅ CommentService: Media updated for \(urlString)")
            
        } catch {
            print("❌ CommentService: Failed to fetch/update media for \(urlString): \(error)")
        }
    }
    
    /// Updates WebPage record with fetched media
    private func updateWebPageWithMedia(urlString: String, media: WebPageMedia) async throws {
        let recordID = CKRecord.ID(recordName: urlString)
        
        return try await withCheckedThrowingContinuation { continuation in
            publicDatabase.fetch(withRecordID: recordID) { record, error in
                guard let record = record, error == nil else {
                    continuation.resume(throwing: error ?? DumFlowError.loadingFailed)
                    return
                }
                
                // Update with real data
                if let title = media.title, !title.isEmpty {
                    record["title"] = title as NSString
                }
                
                if let faviconData = media.faviconData {
                    record["faviconData"] = faviconData as NSData
                }
                
                if let thumbnailData = media.thumbnailData {
                    record["thumbnailData"] = thumbnailData as NSData
                }
                
                // Save updated record
                self.publicDatabase.save(record) { _, saveError in
                    if let saveError = saveError {
                        continuation.resume(throwing: saveError)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }
    
    /// Extract a smart title from URL while media loads
    private func extractQuickTitle(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return "New Page"
        }
        
        // Remove common prefixes and capitalize
        let cleanHost = host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "m.", with: "")
        
        return cleanHost.capitalized
    }
    
    /// Converts CloudKit record to WebPage object
    private func makeWebPage(from record: CKRecord) -> WebPage {
        let id = record.recordID
        let dateCreated = record["dateCreated"] as? Date ?? .now
        let urlString = record["urlString"] as? String ?? ""
        let title = record["title"] as? String ?? ""
        let commentCount = record["commentCount"] as? Int ?? 0
        let likeCount = record["likeCount"] as? Int ?? 0
        let saveCount = record["saveCount"] as? Int ?? 0
        let isReported = record["isReported"] as? Int ?? 0
        let reportCount = record["reportCount"] as? Int ?? 0
        let domain = record["domain"] as? String ?? (URL(string: urlString)?.host ?? "")
        
        return WebPage(
            id: id,
            urlString: urlString,
            title: title,
            domain: domain,
            dateCreated: dateCreated,
            commentCount: commentCount,
            likeCount: likeCount,
            saveCount: saveCount,
            isReported: isReported,
            reportCount: reportCount,
            faviconData: record["faviconData"] as? Data,
            thumbnailData: record["thumbnailData"] as? Data
        )
    }
}
