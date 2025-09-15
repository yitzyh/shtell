import Foundation
import CloudKit
import Combine

/// Fast WebPage creation service using completion handlers (compatible approach)
@MainActor
class WebPageService: ObservableObject {
    
    // MARK: - Dependencies
    private let publicDatabase = CKContainer(identifier: "iCloud.com.yitzy.DumFlow").publicCloudDatabase
    private let authViewModel: AuthViewModel
    private weak var webPageViewModel: WebPageViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    init(authViewModel: AuthViewModel, webPageViewModel: WebPageViewModel? = nil) {
        self.authViewModel = authViewModel
        self.webPageViewModel = webPageViewModel
    }
    
    // MARK: - Fast WebPage Creation (Completion Handler)
    
    /// Creates a WebPage quickly for saving (no comment)
    func createWebPageQuickly(url: String, completion: @escaping (WebPage?) -> Void) {
        print("🟢 WebPageService: Starting createWebPageQuickly for URL: \(url)")
        
        // Step 1: Normalize the URL
        guard let normalizedURL = url.normalizedURL,
              let _ = URL(string: normalizedURL) else {
            print("❌ WebPageService: Invalid URL")
            completion(nil)
            return
        }
        
        // Step 2: Create WebPage record (basic info only)
        let webPageRecord = createBasicWebPageRecord(for: normalizedURL)
        print("✅ WebPageService: WebPage record created")
        
        // Step 3: Save to CloudKit quickly
        Task {
            do {
                let savedRecord = try await publicDatabase.save(webPageRecord)
                print("✅ WebPageService: WebPage saved to CloudKit")
                
                // Step 4: Convert to local object
                let webPage = self.makeWebPage(from: savedRecord)
                
                // Step 5: Start background media fetching (don't wait for it)
                print("🔄 WebPageService: Starting background media fetch for \(normalizedURL)")
                self.fetchAndUpdateMedia(for: normalizedURL)
                
                print("🎉 WebPageService: createWebPageQuickly completed successfully")
                DispatchQueue.main.async {
                    completion(webPage)
                }
            } catch {
                print("❌ WebPageService: Save failed: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Creates a basic WebPage record with fast placeholder data
    private func createBasicWebPageRecord(for urlString: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: urlString)
        let record = CKRecord(recordType: "WebPage", recordID: recordID)
        
        // Basic required fields - fast to create
        record["dateCreated"] = Date() as NSDate
        record["urlString"] = urlString as NSString
        record["title"] = extractQuickTitle(from: urlString) as NSString  // Smart placeholder
        record["commentCount"] = 0 as NSNumber      // No comments yet
        record["likeCount"] = 0 as NSNumber
        record["saveCount"] = 0 as NSNumber
        record["isReported"] = 0 as NSNumber
        record["reportCount"] = 0 as NSNumber
        record["domain"] = (URL(string: urlString)?.host ?? "") as NSString
        
        return record
    }
    
    /// Background task: Fetch media and update WebPage
    private func fetchAndUpdateMedia(for urlString: String) {
        print("🔵 WebPageService: fetchAndUpdateMedia called for \(urlString)")
        
        Task {
                // Use the same reliable pattern as CommentService
                let media = await MediaFetcher.shared.fetchAllMedia(for: urlString)
                    .values
                    .first { _ in true } // Get first emitted value
                
                guard let media = media else {
                    print("⚠️ WebPageService: No media fetched for \(urlString)")
                    return
                }
                
                print("🔄 WebPageService: Received media - title: '\(media.title ?? "nil")', favicon: \(media.faviconData?.count ?? 0) bytes, thumbnail: \(media.thumbnailData?.count ?? 0) bytes")
                
                // Update the CloudKit record with media
                await MainActor.run {
                    let recordID = CKRecord.ID(recordName: urlString)
                    self.publicDatabase.fetch(withRecordID: recordID) { record, error in
                        guard let record = record, error == nil else {
                            print("❌ WebPageService: Failed to fetch record for media update: \(error?.localizedDescription ?? "unknown")")
                            return
                        }
                        
                        print("🔄 WebPageService: Fetched record, updating with media...")
                        
                        // Update with real media
                        if let title = media.title, !title.isEmpty {
                            print("📝 WebPageService: Setting title to '\(title)'")
                            record["title"] = title as NSString
                        }
                        if let faviconData = media.faviconData {
                            print("🖼️ WebPageService: Setting favicon (\(faviconData.count) bytes)")
                            record["faviconData"] = faviconData as NSData
                        }
                        if let thumbnailData = media.thumbnailData {
                            print("🖼️ WebPageService: Setting thumbnail (\(thumbnailData.count) bytes)")
                            record["thumbnailData"] = thumbnailData as NSData
                        }
                        
                        // Save updated record
                        self.publicDatabase.save(record) { _, saveError in
                            DispatchQueue.main.async {
                                if let saveError = saveError {
                                    print("❌ WebPageService: Failed to save media to record: \(saveError.localizedDescription)")
                                } else {
                                    print("✅ WebPageService: Successfully updated record with media for \(urlString)")
                                }
                            }
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