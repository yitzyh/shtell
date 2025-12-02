
import Foundation
import CloudKit
import Combine
import SwiftUI
import UIKit


// MARK: - State Structs
struct ContentState {
    var commentCountLookup: [String: Int] = [:]
    var commentSaveDates: [String: Date] = [:]
    var comments: [Comment] = []
    var followedUserComments: [Comment] = []
    var followedUserDates: [String: Date] = [:]
    var followedUsers: [User] = []
    var imageCache: [String: (favicon: Data?, thumbnail: Data?)] = [:]
    var savedComments: [Comment] = []
    var savedWebPages: [WebPage] = []
    var userComments: [Comment] = []
    var viewedUserComments: [Comment] = []
    var webPage: WebPage? = nil
    var webPageSaveDates: [String: Date] = [:]
    var webPages: [WebPage] = []
}

struct UIState {
    var commentLikeCounts: [String: Int] = [:]
    var commentReplyCounts: [String: Int] = [:]
    var commentSaveCounts: [String: Int] = [:]
    var followedUserStates: Set<String> = []
    var likedComments: Set<String> = []
    var likedWebPages: Set<String> = []
    var pendingQuote: (text: String, selector: String, offset: Int)?
    var savedCommentStates: Set<String> = []
    var savedWebPageStates: Set<String> = []
    var selectedComment: Comment?
    var webPageLikeCounts: [String: Int] = [:]
    var webPageSaveCounts: [String: Int] = [:]
}

struct LoadingState {
    var error: ShtellError?
    var isLoadingComments = false
    var isLoadingWebPage = false
    var showErrorAlert = false
    var urlString: String? = "https://www.apple.com"
}

@MainActor
class WebPageViewModel: ObservableObject, Identifiable {
    
    let publicDatabase = CKContainer(identifier: "iCloud.com.yitzy.DumFlow").publicCloudDatabase
    let authViewModel: AuthViewModel
    private let commentService: CommentService
    let webPageService: WebPageService
    let browserHistoryService: BrowserHistoryService

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        self.commentService = CommentService(authViewModel: authViewModel)
        self.webPageService = WebPageService(authViewModel: authViewModel)
        self.browserHistoryService = BrowserHistoryService(authViewModel: authViewModel)
        
        // Load data when user signs in (dependency injection)
        authViewModel.$signedInUser
            .compactMap { $0 } // Only when user is not nil
            .sink { [weak self] user in
                self?.loadAllUserData(for: user)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Like Status Persistence
    // These methods handle saving/loading like status to/from UserDefaults
    // This ensures like status survives app restarts while CloudKit syncs in background
    
    // Simple loading - no UserDefaults persistence for MVP
    private func loadLikedStatusFromUserDefaults() {
        // MVP: Skip persistence, load fresh each time
    }

    // MARK: - Published State Structs
    @Published var contentState = ContentState()
    @Published var uiState = UIState()
    @Published var loadingState = LoadingState()
    
    // MARK: - Private Properties
    var currentWebPageURLString: String?
    var cancellables = Set<AnyCancellable>()
    private var saveCancellables = Set<AnyCancellable>() // Never cleared - ensures saves complete
    private var createWebPageBackgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    weak var webBrowser: WebBrowser?
    

    // MARK: - User Data Loading
    func loadAllUserData(for user: User) {
        // Load only critical data immediately
        loadUserLikes(for: user)
        
        // Defer heavy operations to not block UI
        Task { @MainActor in
            // Wait for UI to settle
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Load saved data in background
            self.fetchSavedWebPages(for: user)
            
            // Stagger the remaining loads
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            self.fetchSavedComments(for: user)
            
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            self.fetchUserComments(for: user)
            
        }
    }
    
    func loadUserLikes(for user: User) {
        
        // Load liked webpages
        let webPagePredicate = NSPredicate(format: "userID == %@", user.userID)
        let webPageQuery = CKQuery(recordType: "WebPageLike", predicate: webPagePredicate)
        
        publicDatabase.fetch(
            withQuery: webPageQuery,
            inZoneWith: nil as CKRecordZone.ID?,
            desiredKeys: ["urlString"],
            resultsLimit: CKQueryOperation.maximumResults
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (matchResults, _)):
                    let likedURLs = matchResults.compactMap { _, recordResult -> String? in
                        if case .success(let record) = recordResult {
                            return record["urlString"] as? String
                        }
                        return nil
                    }
                    self.uiState.likedWebPages = Set(likedURLs)
                case .failure(let error):
                    print("❌ Error loading liked webpages: \(error)")
                }
            }
        }
        
        // Load liked comments
        let commentPredicate = NSPredicate(format: "userID == %@", user.userID)
        let commentQuery = CKQuery(recordType: "CommentLike", predicate: commentPredicate)
        
        publicDatabase.fetch(
            withQuery: commentQuery,
            inZoneWith: nil as CKRecordZone.ID?,
            desiredKeys: ["commentID"],
            resultsLimit: CKQueryOperation.maximumResults
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (matchResults, _)):
                    let likedCommentIDs = matchResults.compactMap { _, recordResult -> String? in
                        if case .success(let record) = recordResult {
                            return record["commentID"] as? String
                        }
                        return nil
                    }
                    self.uiState.likedComments = Set(likedCommentIDs)
                case .failure(let error):
                    print("❌ Error loading liked comments: \(error)")
                }
            }
        }
    }
    
    var urlString: String? {
        get { loadingState.urlString }
        set { 
            loadingState.urlString = newValue
            loadWebPageCK()
        }
    }
    
    
    // MARK: - Core WebPage Logic
    func loadWebPageCK() {
          guard let urlString = urlString?.normalizedURL else { return }

          // ✅ ONLY LOAD existing webpage, don't create
          fetchExistingWebPage(for: urlString) { existingPage in
              if let page = existingPage {
                  DispatchQueue.main.async {
                      self.contentState.webPage = page
                  }
              } else {
                  // ✅ Don't create - just set to nil and let addComment create it later
                  DispatchQueue.main.async {
                      self.contentState.webPage = nil
                  }
              }
          }
          fetchCommentsCK(for: urlString)
      }
        
    func fetchExistingWebPage(for urlString: String, completion: @escaping (WebPage?) -> Void) {
        // OPTIMIZED: Use direct record access with URL as recordName
        let recordID = CKRecord.ID(recordName: urlString)
        
        publicDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let record = record, error == nil {
                    let foundPage = self.makeWebPage(from: record)
                    completion(foundPage)
                } else {
                    // Record not found or error occurred
                    completion(nil)
                }
            }
        }
    }
    
    func createWebPage(for urlString: String, withFirstComment commentText: String? = nil, parentCommentID: String? = nil, completion: @escaping (WebPage?) -> Void) {

        print("🟢 createWebPage: Called for URL: \(urlString), with comment: \(commentText != nil)")

        guard let normalizedURLString = urlString.normalizedURL,
              let _ = URL(string: normalizedURLString) else {
            print("❌ createWebPage: Invalid or failed to normalize urlString: \(urlString)")
            completion(nil)
            return
        }
        print("✅ createWebPage: Normalized URL: \(normalizedURLString)")

        // Create WebPage immediately with basic info, fetch all media asynchronously
        // Tell iOS: "Don't kill this process, I'm doing important work"
        self.createWebPageBackgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            // iOS is about to force-kill us, clean up properly
            Task { @MainActor [weak self] in
                if let self = self, self.createWebPageBackgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(self.createWebPageBackgroundTaskID)
                    self.createWebPageBackgroundTaskID = .invalid
                }
            }
        }

        print("🔄 createWebPage: Starting MediaFetcher for URL: \(normalizedURLString)")
        MediaFetcher.shared.fetchAllMedia(for: normalizedURLString)
            .handleEvents(
                receiveSubscription: { _ in
                    print("📡 createWebPage: MediaFetcher subscription started")
                },
                receiveOutput: { media in
                    print("📦 createWebPage: MediaFetcher received output with title: '\(media.title ?? "nil")'")
                },
                receiveCompletion: { completion in
                    print("🏁 createWebPage: MediaFetcher completion: \(completion)")
                },
                receiveCancel: {
                    print("❌ createWebPage: Combine chain was CANCELLED")
                }
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (media: WebPageMedia) in
                print("🔄 createWebPage: Sink callback received media: title='\(media.title ?? "nil")')")
                guard let self = self else { return }

                // Set title - use custom title for shtell:// URLs
                let title: String
                if normalizedURLString.hasPrefix("shtell://") {
                    title = "Shtell - The comment section for the internet"
                } else {
                    title = media.title ?? "No Title"
                }

                // Create WebPage record with title and media
                let recordID = CKRecord.ID(recordName: normalizedURLString)
                let record = CKRecord(recordType: "WebPage", recordID: recordID)

                record["dateCreated"] = Date() as NSDate
                record["urlString"] = normalizedURLString as NSString
                record["title"] = title as NSString
                record["commentCount"] = 0 as NSNumber
                record["likeCount"] = 0 as NSNumber
                record["saveCount"] = 0 as NSNumber
                record["isReported"] = 0 as NSNumber
                record["reportCount"] = 0 as NSNumber
                // Extract domain - handle custom shtell:// URLs
                let domain: String
                if normalizedURLString.hasPrefix("shtell://") {
                    domain = "shtell"
                } else {
                    domain = URL(string: normalizedURLString)?.host ?? ""
                }
                record["domain"] = domain as NSString

                // Add media if available
                // For shtell:// URLs, use app icon
                if normalizedURLString.hasPrefix("shtell://") {
                    if let appIconData = self.getAppIconData() {
                        record["faviconData"] = appIconData as NSData
                        if let thumbnailData = self.safetyCompressImageData(appIconData, maxSize: 15_000) {
                            record["thumbnailData"] = thumbnailData as NSData
                        }
                    }
                } else {
                    if let faviconData = media.faviconData {
                        record["faviconData"] = faviconData as NSData
                    }
                    if let thumbnailData = self.safetyCompressImageData(media.thumbnailData, maxSize: 15_000) {
                        record["thumbnailData"] = thumbnailData as NSData
                    }
                }

                // Save webpage, and optionally the first comment
                if let commentText = commentText {
                    print("🟡 createWebPage: Saving webpage WITH comment: '\(commentText)'")
                    // Create comment record to save with webpage
                    guard let user = self.authViewModel.signedInUser else {
                        print("❌ createWebPage: No signed in user for comment")
                        completion(nil)
                        return
                    }

                    let commentID = UUID().uuidString
                    let commentRecord = CKRecord(recordType: "Comment", recordID: CKRecord.ID(recordName: commentID))
                    commentRecord["text"] = commentText as NSString
                    commentRecord["urlString"] = normalizedURLString as NSString
                    commentRecord["userID"] = user.userID as NSString
                    commentRecord["username"] = user.username as NSString
                    commentRecord["dateCreated"] = Date() as NSDate
                    commentRecord["commentID"] = commentID as NSString
                    if let parentCommentID = parentCommentID {
                        commentRecord["parentCommentID"] = parentCommentID as NSString
                    }

                    // Update webpage comment count
                    let currentCount = record["commentCount"] as? Int ?? 0
                    let newCount = parentCommentID == nil ? currentCount + 1 : currentCount
                    record["commentCount"] = newCount as NSNumber

                    // Create comment for immediate UI update
                    let newComment = Comment(
                        id: CKRecord.ID(recordName: commentID),
                        commentID: commentID,
                        text: commentText,
                        dateCreated: Date(),
                        userID: user.userID,
                        username: user.username,
                        urlString: normalizedURLString,
                        parentCommentID: parentCommentID,
                        likeCount: 0,
                        saveCount: 0,
                        isReported: 0,
                        reportCount: 0
                    )

                    // Insert comment immediately for smooth UI
                    print("🟢 createWebPage: Adding comment to UI immediately")
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.contentState.comments.insert(newComment, at: 0)
                        }
                        // Ensure loading state is false so "No comments yet" disappears immediately
                        self.loadingState.isLoadingComments = false
                    }

                    // Batch save webpage and comment
                    print("🔄 createWebPage: Starting CloudKit batch save (webpage + comment)")
                    let modifyOp = CKModifyRecordsOperation(recordsToSave: [record, commentRecord], recordIDsToDelete: nil)
                    modifyOp.savePolicy = .changedKeys
                    modifyOp.modifyRecordsResultBlock = { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .failure(let error):
                            print("❌ createWebPage: CloudKit batch save FAILED: \(error)")

                            // Handle CloudKit "Zone Busy" errors with automatic retry
                            if let ckError = error as? CKError,
                               ckError.code == .zoneBusy || ckError.code == .serviceUnavailable {
                                let retryAfter = ckError.retryAfterSeconds ?? 2.0
                                print("🔄 createWebPage: CloudKit zone busy, retrying after \(retryAfter) seconds")

                                DispatchQueue.main.asyncAfter(deadline: .now() + retryAfter) {
                                    // Create a new operation for retry
                                    let retryOp = CKModifyRecordsOperation(recordsToSave: modifyOp.recordsToSave, recordIDsToDelete: modifyOp.recordIDsToDelete)
                                    retryOp.savePolicy = modifyOp.savePolicy
                                    retryOp.modifyRecordsResultBlock = modifyOp.modifyRecordsResultBlock
                                    self.publicDatabase.add(retryOp)
                                }
                                return
                            }

                            print("❌ createWebPage: Calling completion(nil) due to CloudKit error")
                            completion(nil)
                        case .success:
                            print("✅ createWebPage: CloudKit batch save SUCCESS")
                            Task { @MainActor in
                                let newWebPage = self.makeWebPage(from: record)
                                print("✅ createWebPage: Calling completion with new webpage")
                                completion(newWebPage)
                            }
                        }
                    }
                    self.publicDatabase.add(modifyOp)
                } else {
                    // Save webpage only (existing behavior)
                    print("🔄 createWebPage: Starting CloudKit save (webpage only) for URL: \(normalizedURLString)")
                    self.publicDatabase.save(record) { [weak self] savedRecord, error in
                        if let error = error {
                            print("❌ createWebPage: Error creating WebPage record: \(error)")
                            completion(nil)
                            return
                        }
                        guard let saved = savedRecord else {
                            print("❌ createWebPage: No saved record returned from CloudKit")
                            completion(nil)
                            return
                        }
                        print("✅ createWebPage: Successfully saved webpage to CloudKit")

                        Task { @MainActor in
                            guard let self = self else { return }
                            let newWebPage = self.makeWebPage(from: saved)
                            completion(newWebPage)
                        }
                    }
                }

                // Tell iOS: "I'm done with my important work, you can manage my process normally again"
                if self.createWebPageBackgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(self.createWebPageBackgroundTaskID)
                    self.createWebPageBackgroundTaskID = .invalid
                }
            }
            .store(in: &cancellables)
    }

    /// Creates a WebPage for save operations - instant save with just URL and title
    /// UI will generate favicon/thumbnails dynamically like BrowseForward does
    func createWebPageForSave(for urlString: String, title providedTitle: String? = nil, completion: @escaping (WebPage?) -> Void) {
        print("🟢 createWebPageForSave: Called for URL: \(urlString)")

        guard let normalizedURLString = urlString.normalizedURL,
              let _ = URL(string: normalizedURLString) else {
            print("❌ createWebPageForSave: Invalid or failed to normalize urlString: \(urlString)")
            completion(nil)
            return
        }
        print("✅ createWebPageForSave: Normalized URL: \(normalizedURLString)")

        // Run save operation in detached task to prevent cancellation during navigation
        Task.detached { [weak self] in
            guard let self = self else { return }

            // Begin background task to protect against app suspension
            var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
            await MainActor.run {
                backgroundTaskID = UIApplication.shared.beginBackgroundTask {
                    print("⚠️ createWebPageForSave: Background task expired for \(normalizedURLString)")
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }

            // Create WebPage record - no media fetching needed
            let recordID = CKRecord.ID(recordName: normalizedURLString)
            let record = CKRecord(recordType: "WebPage", recordID: recordID)

            // Set title - use provided title from WebView, fallback to domain-based title
            let title: String
            if normalizedURLString.hasPrefix("shtell://") {
                title = "Shtell - The comment section for the internet"
            } else if let providedTitle = providedTitle, !providedTitle.isEmpty {
                title = providedTitle
                print("✅ createWebPageForSave: Using WebView title: \(title)")
            } else {
                title = await MainActor.run {
                    self.extractQuickTitle(from: normalizedURLString)
                }
                print("⚠️ createWebPageForSave: No title provided, using domain: \(title)")
            }

            record["dateCreated"] = Date() as NSDate
            record["urlString"] = normalizedURLString as NSString
            record["title"] = title as NSString
            record["commentCount"] = 0 as NSNumber
            record["likeCount"] = 0 as NSNumber
            record["saveCount"] = 0 as NSNumber
            record["isReported"] = 0 as NSNumber
            record["reportCount"] = 0 as NSNumber

            // Extract domain - handle custom shtell:// URLs
            let domain: String
            if normalizedURLString.hasPrefix("shtell://") {
                domain = "shtell"
            } else {
                domain = URL(string: normalizedURLString)?.host ?? ""
            }
            record["domain"] = domain as NSString

            // Save to CloudKit (instant - no media fetching)
            print("🔄 createWebPageForSave: Saving to CloudKit")

            let publicDatabase = await MainActor.run { self.publicDatabase }
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<(CKRecord?, Error?), Never>) in
                publicDatabase.save(record) { savedRecord, error in
                    continuation.resume(returning: (savedRecord, error))
                }
            }

            // End background task
            await MainActor.run {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    print("✅ createWebPageForSave: Background task ended")
                }
            }

            if let error = result.1 {
                print("❌ createWebPageForSave: Error creating WebPage record: \(error)")
                await MainActor.run {
                    completion(nil)
                }
                return
            }

            guard let saved = result.0 else {
                print("❌ createWebPageForSave: No saved record returned from CloudKit")
                await MainActor.run {
                    completion(nil)
                }
                return
            }

            print("✅ createWebPageForSave: Successfully saved webpage to CloudKit")

            // Update local state and call completion on main thread
            await MainActor.run {
                let newWebPage = self.makeWebPage(from: saved)
                self.contentState.webPage = newWebPage
                completion(newWebPage)
            }
        }
    }

    /// Extract a smart title from URL while media loads (from CommentService)
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
    
    // Light safety compression for CloudKit (images already optimized during fetch)
    nonisolated private func safetyCompressImageData(_ data: Data?, maxSize: Int) -> Data? {
        guard let data = data, data.count > maxSize else { return data }
        
        guard let image = UIImage(data: data) else { return data }
        
        // Light compression - should rarely be needed since images are pre-optimized
        var compressionQuality: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: compressionQuality)
        
        while let currentData = compressedData, currentData.count > maxSize && compressionQuality > 0.5 {
            compressionQuality -= 0.1
            compressedData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        if data.count != compressedData?.count {
            print("⚠️ Safety compression applied: \(data.count) → \(compressedData?.count ?? 0) bytes")
        }
        return compressedData ?? data
    }
    
    // Legacy compression function (kept for compatibility)
    private func compressImageData(_ data: Data?, maxSize: Int) -> Data? {
        return safetyCompressImageData(data, maxSize: maxSize)
    }
    
    /// Converts the CloudKit record into our local WebPage struct.
    private func makeWebPage(from record: CKRecord) -> WebPage {
        
        let id = record.recordID
        let dateCreated = record["dateCreated"] as? Date ?? .now
        let urlString = record["urlString"] as? String ?? ""
        let title = record["title"] as? String ?? ""
        let faviconData = record["faviconData"] as? Data
        let thumbnailData = record["thumbnailData"] as? Data
        
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
            faviconData: faviconData,
            thumbnailData: thumbnailData
        )
    }
    
    func fetchAllWebPages() {
        
        let predicate = NSPredicate(format: "urlString != ''")
        let query = CKQuery(recordType: "WebPage", predicate: predicate)
        
        let sortDescriptor = NSSortDescriptor(key: "dateCreated", ascending: false)
        query.sortDescriptors = [sortDescriptor]
        
        
        publicDatabase.fetch(
            withQuery: query,
            inZoneWith: nil as CKRecordZone.ID?,
            desiredKeys: ["urlString", "title", "domain", "dateCreated", "commentCount", "likeCount", "saveCount", "isReported", "reportCount"],
            resultsLimit: CKQueryOperation.maximumResults
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let (matchResults, _)):
                    var fetchedPages: [WebPage] = []
                    
                    for (_, recordResult) in matchResults {
                        switch recordResult {
                        case .success(let record):
                            let page = self.makeWebPage(from: record)
                            fetchedPages.append(page)
                        case .failure(let error):
                            print("Error reading a WebPage record: \(error)")
                        }
                    }
                    // ✅ ALREADY ON MAIN THREAD: Update UI state directly
                    self.contentState.webPages = fetchedPages
                    
                    // ✅ ADDED: Build comment count lookup for UI performance
                    self.contentState.commentCountLookup = fetchedPages.reduce(into: [:]) { result, webPage in
                        result[webPage.urlString] = webPage.commentCount
                    }
                    
                case .failure(let error):
                    print("Error performing WebPage query: \(error)")
                    self.contentState.webPages = []
                }
            }
        }
    }
    
    func refreshCommentCounts() {
        contentState.commentCountLookup = contentState.webPages.reduce(into: [:]) { result, webPage in
            result[webPage.urlString] = webPage.commentCount
        }
    }
    
    // MARK: - Core Comment Logic
    func fetchCommentsCK(for urlString: String) {
        // Build a CKQuery for comments associated with this URL
        let predicate = NSPredicate(format: "urlString == %@", urlString)
        let query = CKQuery(recordType: "Comment", predicate: predicate)
        
        // Sort comments by dateCreated, newest first
        let sortDescriptor = NSSortDescriptor(key: "dateCreated", ascending: false)
        query.sortDescriptors = [sortDescriptor]

        publicDatabase.fetch(
            withQuery: query,
            inZoneWith: nil as CKRecordZone.ID?,
            desiredKeys: nil as [String]?,
            resultsLimit: CKQueryOperation.maximumResults
        ) { result in
            switch result {
            case .success(let (matchResults, _)):
                // Map each record to your Comment model
                let fetchedComments: [Comment] = matchResults.compactMap { recordID, recordResult in
                    switch recordResult {
                    case .success(let record):
                        do {
                            return try Comment(record: record)
                        } catch {
                            print("Error creating Comment from record: \(error)")
                            return nil
                        }
                    case .failure(let error):
                        print("Error fetching record \(recordID): \(error)")
                        return nil
                    }
                }
                DispatchQueue.main.async {
                    self.contentState.comments = fetchedComments
                    self.loadingState.isLoadingComments = false
                    
                    // Trigger highlighting immediately now that comments are loaded
                    print("🔍 DEBUG fetchCommentsCK: Comments loaded, triggering highlighting")
                    if let coordinator = self.webBrowser?.wkWebView?.navigationDelegate as? WebView.Coordinator {
                        print("🔍 DEBUG fetchCommentsCK: Found coordinator, calling triggerHighlighting()")
                        coordinator.triggerHighlighting()
                    } else {
                        print("🔍 DEBUG fetchCommentsCK: No coordinator found")
                    }
                }

            case .failure(let error):
                print("Error fetching comments: \(error)")
                DispatchQueue.main.async {
                    self.loadingState.isLoadingComments = false
                }
            }
        }
    }
    
    func addComment(text: String, parentCommentID: String? = nil) {
        print("🔵 addComment called for text: '\(text)' parentID: \(parentCommentID ?? "nil")")
        
        guard let user = authViewModel.signedInUser else {
            print("❌ addComment: No signed in user")
            loadingState.error = .authenticationRequired
            loadingState.showErrorAlert = true
            return
        }
        // Ensure we have a URL
        guard let currentURL = self.urlString, !currentURL.isEmpty else {
            loadingState.error = ShtellError.invalidURL
            loadingState.showErrorAlert = true
            return
        }
        // Ensure is not empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            loadingState.error = .commentPostFailed
            loadingState.showErrorAlert = true
            return
        }
        
        // If no WebPage exists yet, use CommentService for atomic creation
        if contentState.webPage == nil {
            print("🟡 addComment: No webpage exists, using CommentService for URL: \(currentURL)")
            let normalizedURL = currentURL.normalizedURL ?? currentURL
            
            Task {
                do {
                    let (newPage, newComment) = try await commentService.addFirstComment(
                        text: text,
                        url: normalizedURL,
                        quotedText: uiState.pendingQuote?.text,
                        quotedTextSelector: uiState.pendingQuote?.selector,
                        quotedTextOffset: uiState.pendingQuote?.offset
                    )
                    await MainActor.run {
                        self.contentState.webPage = newPage
                        self.contentState.comments.insert(newComment, at: 0)
                        self.contentState.userComments.insert(newComment, at: 0)
                        self.loadingState.isLoadingComments = false
                        self.uiState.pendingQuote = nil
                        
                        // Update comment count lookup immediately for UI responsiveness
                        self.contentState.commentCountLookup[normalizedURL] = newPage.commentCount
                        
                        print("✅ addComment: CommentService succeeded")
                        
                        // Trigger media fetching for the new WebPage
                        self.fetchAndUpdateMediaForWebPage(urlString: normalizedURL)
                    }
                } catch {
                    await MainActor.run {
                        print("❌ addComment: CommentService failed: \(error)")
                        self.loadingState.error = ShtellError.loadingFailed
                        self.loadingState.showErrorAlert = true
                    }
                }
            }
            return
        }

        // Existing page is guaranteed
        print("🟢 addComment: Webpage exists, proceeding with normal comment flow")
        guard let webPage = contentState.webPage else { return }
        
        // Create and insert comment immediately for smooth UI
        let commentID = UUID().uuidString
        
        // Debug: Check pending quote
        if let pendingQuote = uiState.pendingQuote {
            print("🔍 DEBUG: Creating comment with quote: '\(pendingQuote.text)'")
        } else {
            print("🔍 DEBUG: No pending quote found")
        }
        
        let newComment = Comment(
            id: CKRecord.ID(recordName: commentID),
            commentID: commentID,
            text: text,
            dateCreated: Date(),
            userID: user.userID,
            username: user.username,
            urlString: currentURL,
            parentCommentID: parentCommentID,
            quotedText: uiState.pendingQuote?.text,
            quotedTextSelector: uiState.pendingQuote?.selector,
            quotedTextOffset: uiState.pendingQuote?.offset,
            likeCount: 0,
            saveCount: 0,
            isReported: 0,
            reportCount: 0
        )

        // Insert immediately on main thread for animation
        print("🟢 addComment: Adding comment to UI (existing webpage)")
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.contentState.comments.insert(newComment, at: 0)
                self.contentState.userComments.insert(newComment, at: 0)
                
                // Update comment count immediately for UI responsiveness
                if parentCommentID == nil { // Only increment for parent comments
                    let currentCount = self.contentState.webPage?.commentCount ?? 0
                    let newCount = currentCount + 1
                    self.contentState.webPage?.commentCount = newCount
                    self.contentState.commentCountLookup[webPage.urlString] = newCount
                }
            }
            // Ensure loading state is false so "No comments yet" disappears immediately
            self.loadingState.isLoadingComments = false
            self.uiState.pendingQuote = nil
        }
        
        // Prepare the new Comment record
        let commentRecord = CKRecord(recordType: "Comment", recordID: CKRecord.ID(recordName: commentID))
        commentRecord["text"] = text as NSString
        commentRecord["urlString"] = webPage.urlString as NSString
        commentRecord["userID"] = user.userID as NSString
        commentRecord["username"] = user.username as NSString
        commentRecord["dateCreated"] = Date() as NSDate
        commentRecord["commentID"] = commentID as NSString
        if let parentCommentID = parentCommentID {
            commentRecord["parentCommentID"] = parentCommentID as NSString
        }
        
        // Add quote metadata
        commentRecord["quotedText"] = uiState.pendingQuote?.text
        commentRecord["quotedTextSelector"] = uiState.pendingQuote?.selector
        commentRecord["quotedTextOffset"] = uiState.pendingQuote?.offset
        
        print("🔍 addComment: Comment record prepared, about to fetch WebPage record for count update")

        // Use async/await for better performance and error handling
        Task {
            do {
                // Fetch and update the WebPage record for comment count
                let pageRecordID = CKRecord.ID(recordName: webPage.urlString)
                let pageRecord = try await publicDatabase.record(for: pageRecordID)
                
                // Increment counter - only for parent comments (not replies)
                let currentCount = pageRecord["commentCount"] as? Int ?? 0
                let newCount = parentCommentID == nil ? currentCount + 1 : currentCount
                pageRecord["commentCount"] = newCount as NSNumber

                // Batch-save comment and updated page using async operation
                _ = try await withCheckedThrowingContinuation { continuation in
                    let modifyOp = CKModifyRecordsOperation(recordsToSave: [commentRecord, pageRecord], recordIDsToDelete: nil)
                    modifyOp.savePolicy = .changedKeys
                    modifyOp.modifyRecordsResultBlock = { result in
                        continuation.resume(with: result)
                    }
                    publicDatabase.add(modifyOp)
                }
                
                await MainActor.run {
                    self.contentState.webPage?.commentCount = newCount
                    
                    // Update comment count lookup
                    self.contentState.commentCountLookup[webPage.urlString] = newCount
                    
                    // Update allWebPages array
                    if let index = self.contentState.webPages.firstIndex(where: { $0.urlString == webPage.urlString }) {
                        self.contentState.webPages[index].commentCount = newCount
                    }
                    
                    // Update savedWebPages array
                    if let index = self.contentState.savedWebPages.firstIndex(where: { $0.urlString == webPage.urlString }) {
                        self.contentState.savedWebPages[index].commentCount = newCount
                    }
                    
                    print("✅ Successfully posted comment")
                }
            } catch {
                await MainActor.run {
                    print("❌ Error posting comment: \(error)")
                    self.loadingState.error = ShtellError.commentPostFailed
                    self.loadingState.showErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - Media Fetching
    private func fetchAndUpdateMediaForWebPage(urlString: String) {
        print("🔄 Starting media fetch for WebPage: \(urlString)")
        
        MediaFetcher.shared.fetchAllMedia(for: urlString)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] media in
                guard let self = self else { return }
                
                print("🔄 Received media, updating WebPage record")
                // Update the CloudKit record with media
                let recordID = CKRecord.ID(recordName: urlString)
                self.publicDatabase.fetch(withRecordID: recordID) { record, error in
                    guard let record = record, error == nil else {
                        print("❌ Failed to fetch WebPage record for media update")
                        return
                    }
                    
                    // Update with real media
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
                        DispatchQueue.main.async {
                            if saveError == nil {
                                print("✅ Successfully updated WebPage with media")
                                // Refresh the local webPage object
                                self.refreshCurrentWebPage()
                            } else {
                                print("❌ Failed to save media to WebPage record")
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func refreshCurrentWebPage() {
        guard let urlString = contentState.webPage?.urlString else { return }
        fetchExistingWebPage(for: urlString) { [weak self] updatedPage in
            DispatchQueue.main.async {
                if let updatedPage = updatedPage {
                    self?.contentState.webPage = updatedPage
                    print("✅ Refreshed WebPage with updated media")
                }
            }
        }
    }
    
    // MARK: - WebPage Social Features
    func toggleSave(on webPage: WebPage, completion: (() -> Void)? = nil) {
        guard let user = authViewModel.signedInUser else {
            completion?()
            return
        }

        // Capture the state BEFORE any updates
        let wasAlreadySaved = hasSaved(webPage)

        // Simple immediate UI update
        if wasAlreadySaved {
            // Unsave: Update state and count immediately
            uiState.savedWebPageStates.remove(webPage.urlString)
            contentState.savedWebPages.removeAll { $0.urlString == webPage.urlString }
            contentState.webPageSaveDates.removeValue(forKey: webPage.urlString)
            uiState.webPageSaveCounts[webPage.urlString] = max(0, (uiState.webPageSaveCounts[webPage.urlString] ?? webPage.saveCount) - 1)
            print("📚 Unsave: Removed save state for \(webPage.urlString)")
        } else {
            // Save: Update count and state immediately (but don't add to savedWebPages yet - wait for actual webpage)
            uiState.webPageSaveCounts[webPage.urlString] = (uiState.webPageSaveCounts[webPage.urlString] ?? webPage.saveCount) + 1
            uiState.savedWebPageStates.insert(webPage.urlString)
            // Don't add webpage to saved list yet - will be added when we get the actual webpage from CloudKit
            print("💾 Save: Updated save count for \(webPage.urlString)")
        }

        // Call completion immediately for fast UI response
        completion?()

        if wasAlreadySaved {
            // Unsave: Delete WebPageSave record by direct access
            let saveRecordName = "websave_\(user.userID)_\(webPage.urlString)"
            let recordID = CKRecord.ID(recordName: saveRecordName)
            
            // Delete save record and update WebPage saveCount
            let pageRecordID = CKRecord.ID(recordName: webPage.urlString)
            self.publicDatabase.fetch(withRecordID: pageRecordID) { [weak self] fetchedPageRecord, error in
                guard let self = self,
                      let pageRecord = fetchedPageRecord,
                      error == nil else {
                    print("Error fetching WebPage for unsave: \(String(describing: error))")
                    return
                }
                
                // Decrement saveCount
                let newCount = max(0, (pageRecord["saveCount"] as? Int ?? 0) - 1)
                pageRecord["saveCount"] = newCount as NSNumber
                
                // Batch operation: delete save record and update page record
                let modifyOp = CKModifyRecordsOperation(recordsToSave: [pageRecord], recordIDsToDelete: [recordID])
                modifyOp.savePolicy = .allKeys
                modifyOp.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .failure(let error):
                            print("❌ Error batch unsave operation: \(error)")
                            // Revert count on failure
                            self.uiState.webPageSaveCounts[webPage.urlString] = webPage.saveCount
                        case .success:
                            print("✅ Successfully unsaved webpage and updated count")
                            // Don't overwrite local cache - trust user's actions
                            // self.webPageSaveCounts[webPage.urlString] = newCount
                            // Update local arrays
                            self.contentState.savedWebPages.removeAll { $0.urlString == webPage.urlString }
                            self.contentState.webPageSaveDates.removeValue(forKey: webPage.urlString)
                            // Update allWebPages array
                            if let index = self.contentState.webPages.firstIndex(where: { $0.urlString == webPage.urlString }) {
                                self.contentState.webPages[index] = WebPage(
                                    id: self.contentState.webPages[index].id,
                                    urlString: self.contentState.webPages[index].urlString,
                                    title: self.contentState.webPages[index].title,
                                    domain: self.contentState.webPages[index].domain,
                                    dateCreated: self.contentState.webPages[index].dateCreated,
                                    commentCount: self.contentState.webPages[index].commentCount,
                                    likeCount: self.contentState.webPages[index].likeCount,
                                    saveCount: newCount,
                                    isReported: self.contentState.webPages[index].isReported,
                                    reportCount: self.contentState.webPages[index].reportCount,
                                    faviconData: self.contentState.webPages[index].faviconData,
                                    thumbnailData: self.contentState.webPages[index].thumbnailData
                                )
                            }
                        }
                    }
                }
                self.publicDatabase.add(modifyOp)
            }

        } else {
            // Save: Create new WebPageSave record
            let webPageSave = WebPageSave(urlString: webPage.urlString, userID: user.userID)
            let record = webPageSave.toRecord()

            // Save record and update WebPage saveCount
            let pageRecordID = CKRecord.ID(recordName: webPage.urlString)
            publicDatabase.fetch(withRecordID: pageRecordID) { [weak self] fetchedPageRecord, error in
                guard let self = self else { return }

                if let pageRecord = fetchedPageRecord, error == nil {
                    // WebPage exists - increment saveCount
                    let newCount = (pageRecord["saveCount"] as? Int ?? 0) + 1
                    pageRecord["saveCount"] = newCount as NSNumber

                    // Batch operation: save record and update page record
                    let modifyOp = CKModifyRecordsOperation(recordsToSave: [record, pageRecord], recordIDsToDelete: nil)
                    modifyOp.savePolicy = .allKeys
                    modifyOp.modifyRecordsResultBlock = { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .failure(let error):
                                print("❌ Error batch save operation: \(error)")
                                // Revert all state on failure
                                self.uiState.webPageSaveCounts[webPage.urlString] = webPage.saveCount
                                self.uiState.savedWebPageStates.remove(webPage.urlString)
                                self.contentState.savedWebPages.removeAll { $0.urlString == webPage.urlString }
                                self.contentState.webPageSaveDates.removeValue(forKey: webPage.urlString)
                            case .success:
                                print("✅ Successfully saved webpage and updated count")
                                // Fetch the updated webpage with proper data
                                self.fetchExistingWebPage(for: webPage.urlString) { updatedWebPage in
                                    DispatchQueue.main.async {
                                        if let updated = updatedWebPage {
                                            // Update local arrays with the fetched webpage that has proper data
                                            if !self.contentState.savedWebPages.contains(where: { $0.urlString == updated.urlString }) {
                                                self.contentState.savedWebPages.append(updated)
                                                self.contentState.webPageSaveDates[updated.urlString] = Date()
                                            }
                                        }
                                    }
                                }
                                // Update allWebPages array
                                if let index = self.contentState.webPages.firstIndex(where: { $0.urlString == webPage.urlString }) {
                                self.contentState.webPages[index] = WebPage(
                                    id: self.contentState.webPages[index].id,
                                    urlString: self.contentState.webPages[index].urlString,
                                    title: self.contentState.webPages[index].title,
                                    domain: self.contentState.webPages[index].domain,
                                    dateCreated: self.contentState.webPages[index].dateCreated,
                                    commentCount: self.contentState.webPages[index].commentCount,
                                    likeCount: self.contentState.webPages[index].likeCount,
                                    saveCount: newCount,
                                    isReported: self.contentState.webPages[index].isReported,
                                    reportCount: self.contentState.webPages[index].reportCount,
                                    faviconData: self.contentState.webPages[index].faviconData,
                                    thumbnailData: self.contentState.webPages[index].thumbnailData
                                )
                            }
                        }
                    }
                }
                self.publicDatabase.add(modifyOp)
                } else {
                    // WebPage doesn't exist - create it first, then save
                    print("📝 WebPage doesn't exist, creating it first for save")
                    Task { @MainActor in
                        self.createWebPageForSave(for: webPage.urlString) { createdWebPage in
                        guard createdWebPage != nil else {
                            print("❌ Failed to create webpage for save")
                            // Revert UI state since we couldn't create the webpage
                            DispatchQueue.main.async {
                                self.uiState.webPageSaveCounts[webPage.urlString] = webPage.saveCount
                                self.uiState.savedWebPageStates.remove(webPage.urlString)
                                self.contentState.savedWebPages.removeAll { $0.urlString == webPage.urlString }
                                self.contentState.webPageSaveDates.removeValue(forKey: webPage.urlString)
                            }
                            return
                        }

                        // Now save the WebPageSave record and update the newly created webpage's saveCount
                        self.publicDatabase.fetch(withRecordID: pageRecordID) { fetchedPageRecord, error in
                            guard let pageRecord = fetchedPageRecord else {
                                print("❌ Failed to fetch newly created webpage")
                                return
                            }

                            // Set saveCount to 1 for the new webpage
                            pageRecord["saveCount"] = 1 as NSNumber

                            // Batch operation: save record and update page record
                            let modifyOp = CKModifyRecordsOperation(recordsToSave: [record, pageRecord], recordIDsToDelete: nil)
                            modifyOp.savePolicy = .allKeys
                            modifyOp.modifyRecordsResultBlock = { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .failure(let error):
                                        print("❌ Error saving after webpage creation: \(error)")
                                        // Revert all state on failure
                                        self.uiState.webPageSaveCounts[webPage.urlString] = webPage.saveCount
                                        self.uiState.savedWebPageStates.remove(webPage.urlString)
                                        self.contentState.savedWebPages.removeAll { $0.urlString == webPage.urlString }
                                        self.contentState.webPageSaveDates.removeValue(forKey: webPage.urlString)
                                    case .success:
                                        print("✅ Successfully created webpage and saved it")
                                        // Update local arrays with the newly created webpage
                                        if let newWebPage = createdWebPage {
                                            if !self.contentState.savedWebPages.contains(where: { $0.urlString == newWebPage.urlString }) {
                                                self.contentState.savedWebPages.append(newWebPage)
                                                self.contentState.webPageSaveDates[newWebPage.urlString] = Date()
                                            }
                                            // Add to allWebPages if not already there
                                            if !self.contentState.webPages.contains(where: { $0.urlString == newWebPage.urlString }) {
                                                self.contentState.webPages.append(newWebPage)
                                            }
                                        }
                                    }
                                }
                            }
                            self.publicDatabase.add(modifyOp)
                        }
                        }
                    }
                }
            }
        }
    }

    /// Performs a direct save operation without toggling state
    /// Used when state is already updated (e.g., during initial save from save button)
    func performDirectSave(on webPage: WebPage) {
        guard let user = authViewModel.signedInUser else { return }

        print("💾 performDirectSave: Saving webpage \(webPage.urlString)")

        // Create WebPageSave record
        let webPageSave = WebPageSave(urlString: webPage.urlString, userID: user.userID)
        let record = webPageSave.toRecord()

        // Update WebPage saveCount
        let pageRecordID = CKRecord.ID(recordName: webPage.urlString)
        publicDatabase.fetch(withRecordID: pageRecordID) { [weak self] fetchedPageRecord, error in
            guard let self = self else { return }

            guard let pageRecord = fetchedPageRecord, error == nil else {
                print("❌ performDirectSave: Failed to fetch webpage: \(String(describing: error))")
                return
            }

            // Increment saveCount
            let newCount = (pageRecord["saveCount"] as? Int ?? 0) + 1
            pageRecord["saveCount"] = newCount as NSNumber

            // Update local count immediately
            DispatchQueue.main.async {
                self.uiState.webPageSaveCounts[webPage.urlString] = newCount
            }

            // Batch operation: save record and update page record with background task protection
            let modifyOp = CKModifyRecordsOperation(recordsToSave: [record, pageRecord], recordIDsToDelete: nil)
            modifyOp.savePolicy = .allKeys

            // Begin background task to ensure save completes even during navigation
            var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
            backgroundTaskID = UIApplication.shared.beginBackgroundTask {
                // Cleanup if task expires
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }

            modifyOp.modifyRecordsResultBlock = { result in
                defer {
                    // Always end the background task
                    if backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = .invalid
                    }
                }

                DispatchQueue.main.async {
                    switch result {
                    case .failure(let error):
                        print("❌ performDirectSave: Error saving: \(error)")
                        // Revert state on failure
                        self.uiState.webPageSaveCounts[webPage.urlString] = webPage.saveCount
                        self.uiState.savedWebPageStates.remove(webPage.urlString)
                        self.contentState.savedWebPages.removeAll { $0.urlString == webPage.urlString }
                        self.contentState.webPageSaveDates.removeValue(forKey: webPage.urlString)
                    case .success:
                        print("✅ performDirectSave: Successfully saved webpage")
                        // Fetch the updated webpage with proper metadata before adding to savedWebPages
                        self.fetchExistingWebPage(for: webPage.urlString) { updatedWebPage in
                            DispatchQueue.main.async {
                                if let updated = updatedWebPage {
                                    // Add to saved webpages array with full metadata
                                    if !self.contentState.savedWebPages.contains(where: { $0.urlString == updated.urlString }) {
                                        self.contentState.savedWebPages.append(updated)
                                        self.contentState.webPageSaveDates[updated.urlString] = Date()
                                    }
                                }
                            }
                        }
                        // Update allWebPages array
                        if let index = self.contentState.webPages.firstIndex(where: { $0.urlString == webPage.urlString }) {
                            self.contentState.webPages[index] = WebPage(
                                id: self.contentState.webPages[index].id,
                                urlString: self.contentState.webPages[index].urlString,
                                title: self.contentState.webPages[index].title,
                                domain: self.contentState.webPages[index].domain,
                                dateCreated: self.contentState.webPages[index].dateCreated,
                                commentCount: self.contentState.webPages[index].commentCount,
                                likeCount: self.contentState.webPages[index].likeCount,
                                saveCount: newCount,
                                isReported: self.contentState.webPages[index].isReported,
                                reportCount: self.contentState.webPages[index].reportCount,
                                faviconData: self.contentState.webPages[index].faviconData,
                                thumbnailData: self.contentState.webPages[index].thumbnailData
                            )
                        }
                    }
                }
            }
            self.publicDatabase.add(modifyOp)
        }
    }

    func hasSaved(_ webPage: WebPage) -> Bool {
        return uiState.savedWebPageStates.contains(webPage.urlString)
    }
    
    func fetchSavedWebPages(for user: User, completion: (() -> Void)? = nil) {
        print("🔍 fetchSavedWebPages: Loading for user \(user.userID)")
        
        let predicate = NSPredicate(format: "userID == %@", user.userID)
        let query = CKQuery(recordType: "WebPageSave", predicate: predicate)
        
        publicDatabase.fetch(
            withQuery: query,
            inZoneWith: nil as CKRecordZone.ID?,
            desiredKeys: ["urlString"],
            resultsLimit: CKQueryOperation.maximumResults
        ) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
            switch result {
            case .success(let (matchResults, _)):
                // Process results on background queue
                DispatchQueue.global(qos: .userInitiated).async {
                    // Collect all webpage URLs and their save dates
                    var webPageIDsToFetch: [CKRecord.ID] = []
                    var saveDates: [String: Date] = [:]
                    
                    for (_, recordResult) in matchResults {
                        switch recordResult {
                        case .success(let record):
                            if let urlString = record["urlString"] as? String,
                               let saveDate = record.creationDate {
                                let recordID = CKRecord.ID(recordName: urlString)
                                webPageIDsToFetch.append(recordID)
                                saveDates[urlString] = saveDate
                            }
                        case .failure(let error):
                            print("Error loading WebPageSave record: \(error)")
                        }
                    }
                    
                    guard !webPageIDsToFetch.isEmpty else {
                        DispatchQueue.main.async {
                            self.contentState.savedWebPages = []
                            self.uiState.savedWebPageStates = []
                            print("✅ No saved webpages found")
                            completion?()
                        }
                        return
                    }
                    
                    print("🔄 Batch fetching \(webPageIDsToFetch.count) webpages...")
                    
                    // BATCH FETCH: Use CKFetchRecordsOperation to fetch all webpages at once
                    let fetchOperation = CKFetchRecordsOperation(recordIDs: webPageIDsToFetch)
                    fetchOperation.desiredKeys = nil // Fetch all fields
                    
                    var fetchedWebPages: [WebPage] = []
                    var failedFetches = 0
                    
                    // Process each fetched record
                               fetchOperation.perRecordResultBlock = { recordID, result in
                        switch result {
                        case .success(let record):
                            // Need to call makeWebPage on main actor
                            DispatchQueue.main.async {
                                let webPage = self.makeWebPage(from: record)
                                fetchedWebPages.append(webPage)
                            }
                        case .failure(let error):
                            if let ckError = error as? CKError, ckError.code == .unknownItem {
                                // Silently skip deleted webpages
                                failedFetches += 1
                            } else {
                                print("Error fetching webpage \(recordID.recordName): \(error)")
                            }
                        }
                    }
                    
                    // Completion handler
                    fetchOperation.fetchRecordsResultBlock = { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                self.contentState.savedWebPages = fetchedWebPages
                                self.uiState.savedWebPageStates = Set(fetchedWebPages.map { $0.urlString })
                                
                                // Update save dates for successfully fetched webpages
                                for webPage in fetchedWebPages {
                                    if let saveDate = saveDates[webPage.urlString] {
                                        self.contentState.webPageSaveDates[webPage.urlString] = saveDate
                                    }
                                }
                                
                                print("✅ Batch loaded \(fetchedWebPages.count) saved WebPages (skipped \(failedFetches) missing)")
                                completion?()
                                
                            case .failure(let error):
                                print("❌ Batch fetch failed: \(error)")
                                self.contentState.savedWebPages = []
                                completion?()
                            }
                        }
                    }
                    
                    // Execute the batch operation
                    self.publicDatabase.add(fetchOperation)
                }
                
            case .failure(let error):
                print("Error fetching saved WebPages: \(error)")
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }
    
    
    func fetchSavedComments(for user: User, completion: (() -> Void)? = nil) {
        print("🔍 fetchSavedComments: Loading for user \(user.userID)")
        
        let predicate = NSPredicate(format: "userID == %@", user.userID)
        let query = CKQuery(recordType: "CommentSave", predicate: predicate)
        
        publicDatabase.fetch(
            withQuery: query,
            inZoneWith: nil as CKRecordZone.ID?,
            desiredKeys: ["commentID"],
            resultsLimit: CKQueryOperation.maximumResults
        ) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
            switch result {
            case .success(let (matchResults, _)):
                // Process results on background queue
                DispatchQueue.global(qos: .userInitiated).async {
                    // Collect all comment IDs and their save dates
                    var commentIDsToFetch: [CKRecord.ID] = []
                    var saveDates: [String: Date] = [:]
                    
                    for (_, recordResult) in matchResults {
                        switch recordResult {
                        case .success(let record):
                            if let commentID = record["commentID"] as? String,
                               let saveDate = record.creationDate {
                                let recordID = CKRecord.ID(recordName: commentID)
                                commentIDsToFetch.append(recordID)
                                saveDates[commentID] = saveDate
                            }
                        case .failure(let error):
                            print("Error loading CommentSave record: \(error)")
                        }
                    }
                    
                    guard !commentIDsToFetch.isEmpty else {
                        DispatchQueue.main.async {
                            self.contentState.savedComments = []
                            self.uiState.savedCommentStates = []
                            print("✅ No saved comments found")
                            completion?()
                        }
                        return
                    }
                    
                    print("🔄 Batch fetching \(commentIDsToFetch.count) comments...")
                    
                    // BATCH FETCH: Use CKFetchRecordsOperation to fetch all comments at once
                    let fetchOperation = CKFetchRecordsOperation(recordIDs: commentIDsToFetch)
                    fetchOperation.desiredKeys = nil // Fetch all fields
                    
                    var fetchedComments: [Comment] = []
                    var failedFetches = 0
                    
                    // Process each fetched record
                    fetchOperation.perRecordResultBlock = { recordID, result in
                        switch result {
                        case .success(let record):
                            do {
                                let comment = try Comment(record: record)
                                fetchedComments.append(comment)
                            } catch {
                                print("Error creating Comment from record: \(error)")
                            }
                        case .failure(let error):
                            if let ckError = error as? CKError, ckError.code == .unknownItem {
                                // Silently skip deleted comments
                                failedFetches += 1
                            } else {
                                print("Error fetching comment \(recordID.recordName): \(error)")
                            }
                        }
                    }
                    
                    // Completion handler
                    fetchOperation.fetchRecordsResultBlock = { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                self.contentState.savedComments = fetchedComments
                                self.uiState.savedCommentStates = Set(fetchedComments.map { $0.commentID })
                                
                                // Update save dates for successfully fetched comments
                                for comment in fetchedComments {
                                    if let saveDate = saveDates[comment.commentID] {
                                        self.contentState.commentSaveDates[comment.commentID] = saveDate
                                    }
                                }
                                
                                print("✅ Batch loaded \(fetchedComments.count) saved Comments (skipped \(failedFetches) missing)")
                                completion?()
                                
                            case .failure(let error):
                                print("❌ Batch fetch failed: \(error)")
                                self.contentState.savedComments = []
                                completion?()
                            }
                        }
                    }
                    
                    // Execute the batch operation
                    self.publicDatabase.add(fetchOperation)
                }
                
            case .failure(let error):
                print("Error fetching saved Comments: \(error)")
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }
    
    func fetchUserComments(for user: User, completion: (() -> Void)? = nil) {
        print("🔍 fetchUserComments: Loading for user \(user.userID)")
        
        let predicate = NSPredicate(format: "userID == %@", user.userID)
        let query = CKQuery(recordType: "Comment", predicate: predicate)
        
        // CloudKit fetch must happen on main thread due to @MainActor
        publicDatabase.fetch(
            withQuery: query,
            inZoneWith: nil as CKRecordZone.ID?,
            desiredKeys: nil as [String]?,
            resultsLimit: CKQueryOperation.maximumResults
        ) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
            
            // Process results on background queue to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                switch result {
                case .success(let (matchResults, _)):
                    var comments: [Comment] = []
                    
                    // Process results off main thread
                    for (_, recordResult) in matchResults {
                        switch recordResult {
                        case .success(let record):
                            do {
                                let comment = try Comment(record: record)
                                comments.append(comment)
                            } catch {
                                print("Error creating Comment from record: \(error)")
                            }
                        case .failure(let error):
                            print("Error loading Comment record: \(error)")
                        }
                    }
                    
                    // Sort comments by date (newest first) since CloudKit doesn't support this
                    comments.sort { $0.dateCreated > $1.dateCreated }
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        self.contentState.userComments = comments
                        print("✅ Loaded \(comments.count) user Comments")
                        completion?()
                    }
                    
                case .failure(let error):
                    print("Error fetching user Comments: \(error)")
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
            }
        }
    }
    
    func fetchViewedUserComments(userID: String, completion: (() -> Void)? = nil) {
        print("🔍 fetchViewedUserComments: Loading for user \(userID)")
        
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "Comment", predicate: predicate)
        // Remove sort descriptor since creationDate is not sortable in CloudKit
        // We'll sort in memory after fetching
        
        publicDatabase.fetch(
            withQuery: query,
            inZoneWith: nil as CKRecordZone.ID?,
            desiredKeys: nil as [String]?,
            resultsLimit: CKQueryOperation.maximumResults
        ) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
            switch result {
            case .success(let (matchResults, _)):
                var comments: [Comment] = []
                
                for (_, recordResult) in matchResults {
                    switch recordResult {
                    case .success(let record):
                        do {
                            let comment = try Comment(record: record)
                            comments.append(comment)
                        } catch {
                            print("Error creating Comment from record: \(error)")
                        }
                    case .failure(let error):
                        print("Error loading Comment record: \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    self.contentState.viewedUserComments = comments
                    print("✅ Loaded \(self.contentState.viewedUserComments.count) viewed user Comments")
                    completion?()
                }
                
            case .failure(let error):
                print("Error fetching viewed user Comments: \(error)")
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }
    
    func toggleLike(on webPage: WebPage, isCurrentlyLiked: Bool, completion: (() -> Void)? = nil) {
        guard let user = authViewModel.signedInUser else {
            completion?()
            return
        }
        
        // Update UI state immediately
        if isCurrentlyLiked {
            // Unlike
            uiState.likedWebPages.remove(webPage.urlString)
            uiState.webPageLikeCounts[webPage.urlString] = max(0, getLikeCount(for: webPage) - 1)
        } else {
            // Like
            uiState.likedWebPages.insert(webPage.urlString)
            uiState.webPageLikeCounts[webPage.urlString] = getLikeCount(for: webPage) + 1
        }
        
        // Call completion immediately for fast UI response
        completion?()
        
        // CloudKit sync - create/delete like record AND update WebPage.likeCount
        if isCurrentlyLiked {
            // Unlike: Delete like record by direct access and decrement WebPage.likeCount
            let likeRecordName = "weblike_\(user.userID)_\(webPage.urlString)"
            let recordID = CKRecord.ID(recordName: likeRecordName)
            
            // Delete like record and update WebPage likeCount
            let pageRecordID = CKRecord.ID(recordName: webPage.urlString)
            self.publicDatabase.fetch(withRecordID: pageRecordID) { [weak self] fetchedPageRecord, error in
                guard let self = self,
                      let pageRecord = fetchedPageRecord,
                      error == nil else {
                    print("Error fetching WebPage for unlike: \(String(describing: error))")
                    return
                }
                
                // Decrement likeCount
                let newCount = max(0, (pageRecord["likeCount"] as? Int ?? 0) - 1)
                pageRecord["likeCount"] = newCount as NSNumber
                
                // Batch operation: delete like record and update page record
                let modifyOp = CKModifyRecordsOperation(recordsToSave: [pageRecord], recordIDsToDelete: [recordID])
                modifyOp.savePolicy = .allKeys
                modifyOp.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .failure(let error):
                            print("❌ Error batch unlike operation: \(error)")
                            print("⚠️ CloudKit unlike sync failed - keeping local unlike state")
                            // Don't revert - let user's intent stand
                            // self.likedWebPages.insert(webPage.urlString)
                            // self.webPageLikeCounts[webPage.urlString] = webPage.likeCount
                        case .success:
                            print("✅ Successfully unliked webpage and updated count")
                            // Don't overwrite local cache - trust user's actions
                            // self.webPageLikeCounts[webPage.urlString] = newCount
                        }
                    }
                }
                self.publicDatabase.add(modifyOp)
            }
        } else {
            // Like: Create like record with composite recordName and increment WebPage.likeCount
            let likeRecordName = "weblike_\(user.userID)_\(webPage.urlString)"
            let likeRecord = CKRecord(recordType: "WebPageLike", recordID: CKRecord.ID(recordName: likeRecordName))
            likeRecord["urlString"] = webPage.urlString
            likeRecord["userID"] = user.userID
            likeRecord["dateCreated"] = Date()
            
            // Fetch and update WebPage likeCount
            let pageRecordID = CKRecord.ID(recordName: webPage.urlString)
            publicDatabase.fetch(withRecordID: pageRecordID) { [weak self] fetchedPageRecord, error in
                guard let self = self,
                      let pageRecord = fetchedPageRecord,
                      error == nil else {
                    print("Error fetching WebPage for like: \(String(describing: error))")
                    return
                }
                
                // Increment likeCount
                let newCount = (pageRecord["likeCount"] as? Int ?? 0) + 1
                pageRecord["likeCount"] = newCount as NSNumber
                
                // Batch operation: save like record and update page record
                let modifyOp = CKModifyRecordsOperation(recordsToSave: [likeRecord, pageRecord], recordIDsToDelete: nil)
                modifyOp.savePolicy = .allKeys
                modifyOp.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .failure(let error):
                            print("❌ Error batch like operation: \(error)")
                            print("⚠️ CloudKit like sync failed - keeping local like state")
                            // Don't revert - let user's intent stand
                            // self.likedWebPages.remove(webPage.urlString)
                            // self.webPageLikeCounts[webPage.urlString] = webPage.likeCount
                        case .success:
                            print("✅ Successfully liked webpage and updated count")
                            // Don't overwrite local cache - trust user's actions
                            // self.webPageLikeCounts[webPage.urlString] = newCount
                        }
                    }
                }
                self.publicDatabase.add(modifyOp)
            }
        }
    }
    
    
    // MARK: - Simple WebPage Like Methods
    func hasLiked(_ webPage: WebPage) -> Bool {
        return uiState.likedWebPages.contains(webPage.urlString)
    }
    
    func getLikeCount(for webPage: WebPage) -> Int {
        return uiState.webPageLikeCounts[webPage.urlString] ?? webPage.likeCount
    }
    
    func getLikeCount(for comment: Comment) -> Int {
        return uiState.commentLikeCounts[comment.commentID] ?? comment.likeCount
    }
    
    func getSaveCount(for webPage: WebPage) -> Int {
        return uiState.webPageSaveCounts[webPage.urlString] ?? webPage.saveCount
    }
    
    func getSaveCount(for comment: Comment) -> Int {
        return uiState.commentSaveCounts[comment.commentID] ?? comment.saveCount
    }
    
    func getReplyCount(for comment: Comment) -> Int {
        return contentState.comments.filter { $0.parentCommentID == comment.commentID }.count
    }
    
    // Removed complex like status checking - MVP uses local state only
    
    
    // MARK: - Comment Social Features
    func toggleSave(on comment: Comment, completion: (() -> Void)? = nil) {
        guard let user = authViewModel.signedInUser else {
            completion?()
            return
        }
        
        // Simple immediate UI update
        let currentlySaved = hasSaved(comment)
        if currentlySaved {
            // Unsave: Update state AND decrement count immediately
            uiState.savedCommentStates.remove(comment.commentID)
            contentState.savedComments.removeAll { $0.commentID == comment.commentID }
            contentState.commentSaveDates.removeValue(forKey: comment.commentID)
            uiState.commentSaveCounts[comment.commentID] = max(0, (uiState.commentSaveCounts[comment.commentID] ?? comment.saveCount) - 1)
            print("📚 Unsave: Removed save state and decremented count for comment \(comment.commentID)")
        } else {
            // Save: Update count and state immediately
            uiState.commentSaveCounts[comment.commentID] = (uiState.commentSaveCounts[comment.commentID] ?? comment.saveCount) + 1
            uiState.savedCommentStates.insert(comment.commentID)
            if !contentState.savedComments.contains(where: { $0.commentID == comment.commentID }) {
                contentState.savedComments.append(comment)
                contentState.commentSaveDates[comment.commentID] = Date()
            }
            print("💾 Save: Updated save count for comment \(comment.commentID)")
        }
        
        // Call completion immediately for fast UI response
        completion?()
        
        if currentlySaved {
            // Unsave: Delete CommentSave record by direct access
            let saveRecordName = "save_\(user.userID)_\(comment.commentID)"
            print("🔍 Looking for CommentSave with recordName: \(saveRecordName)")
            let recordID = CKRecord.ID(recordName: saveRecordName)
            
            // Delete save record and update Comment saveCount by direct fetch
            let commentRecordID = CKRecord.ID(recordName: comment.commentID)
            self.publicDatabase.fetch(withRecordID: commentRecordID) { [weak self] commentRecord, error in
                guard let self = self,
                      let commentRecord = commentRecord,
                      error == nil else {
                    print("Error fetching Comment for unsave: \(String(describing: error))")
                    return
                }
                
                // Decrement saveCount
                let newCount = max(0, (commentRecord["saveCount"] as? Int ?? 0) - 1)
                commentRecord["saveCount"] = newCount as NSNumber
                
                // Batch operation: delete save record and update comment record
                let modifyOp = CKModifyRecordsOperation(recordsToSave: [commentRecord], recordIDsToDelete: [recordID])
                modifyOp.savePolicy = .allKeys
                modifyOp.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .failure(let error):
                            print("❌ Error batch comment unsave operation: \(error)")
                            // Revert count on failure
                            self.uiState.commentSaveCounts[comment.commentID] = comment.saveCount
                        case .success:
                            print("✅ Successfully unsaved comment and updated count")
                            // Don't overwrite local cache - trust user's actions
                            // self.commentSaveCounts[comment.commentID] = newCount
                            // Update local arrays
                            self.contentState.savedComments.removeAll { $0.commentID == comment.commentID }
                            self.contentState.commentSaveDates.removeValue(forKey: comment.commentID)
                        }
                    }
                }
                self.publicDatabase.add(modifyOp)
            }
        } else {
            // Save: Create CommentSave record and increment Comment.saveCount
            let saveRecordName = "save_\(user.userID)_\(comment.commentID)"
            print("🔍 Creating CommentSave with recordName: \(saveRecordName)")
            let saveRecord = CKRecord(recordType: "CommentSave", recordID: CKRecord.ID(recordName: saveRecordName))
            saveRecord["commentID"] = comment.commentID
            saveRecord["userID"] = user.userID
            saveRecord["dateCreated"] = Date()
            
            // Fetch and update Comment saveCount by direct fetch
            let commentRecordID = CKRecord.ID(recordName: comment.commentID)
            publicDatabase.fetch(withRecordID: commentRecordID) { [weak self] commentRecord, error in
                guard let self = self,
                      let commentRecord = commentRecord,
                      error == nil else {
                    print("Error fetching Comment for save: \(String(describing: error))")
                    return
                }
                
                    // Increment saveCount
                    let newCount = (commentRecord["saveCount"] as? Int ?? 0) + 1
                    commentRecord["saveCount"] = newCount as NSNumber
                    
                    // Batch operation: save record and update comment record
                    let modifyOp = CKModifyRecordsOperation(recordsToSave: [saveRecord, commentRecord], recordIDsToDelete: nil)
                    modifyOp.savePolicy = .allKeys
                    modifyOp.modifyRecordsResultBlock = { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .failure(let error):
                                print("❌ Error batch comment save operation: \(error)")
                                // Revert all state on failure
                                self.uiState.commentSaveCounts[comment.commentID] = comment.saveCount
                                self.uiState.savedCommentStates.remove(comment.commentID)
                                self.contentState.savedComments.removeAll { $0.commentID == comment.commentID }
                                self.contentState.commentSaveDates.removeValue(forKey: comment.commentID)
                            case .success:
                                print("✅ Successfully saved comment and updated count")
                                // Don't overwrite local cache - trust user's actions
                                // self.commentSaveCounts[comment.commentID] = newCount
                                // Update local arrays
                                if !self.contentState.savedComments.contains(where: { $0.commentID == comment.commentID }) {
                                    self.contentState.savedComments.append(comment)
                                    self.contentState.commentSaveDates[comment.commentID] = Date()
                                }
                            }
                        }
                    }
                    self.publicDatabase.add(modifyOp)
            }
        }
    }

    
    func hasSaved(_ comment: Comment) -> Bool {
        return uiState.savedCommentStates.contains(comment.commentID)
    }

    func toggleLike(on comment: Comment, isCurrentlyLiked: Bool, completion: (() -> Void)? = nil) {
        guard let user = authViewModel.signedInUser else {
            completion?()
            return
        }
        
        // HYBRID APPROACH - Part 1: Update local cache immediately for instant UI response
        // This eliminates race conditions and provides immediate visual feedback
        // CloudKit sync happens in background without affecting UI responsiveness
        
        if isCurrentlyLiked {
            // Unlike
            uiState.likedComments.remove(comment.commentID)
            uiState.commentLikeCounts[comment.commentID] = max(0, getLikeCount(for: comment) - 1)
            print("💔 Unlike: Removed \(comment.commentID) from cache, updated count")
        } else {
            // Like
            uiState.likedComments.insert(comment.commentID)
            uiState.commentLikeCounts[comment.commentID] = getLikeCount(for: comment) + 1
            print("❤️ Like: Added \(comment.commentID) to cache, updated count")
        }
        
        // Call completion immediately for fast UI response
        completion?()
        
        // CloudKit sync in background
        if isCurrentlyLiked {
            performUnlikeOperationLegacy(comment: comment, user: user) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ CloudKit unlike sync completed for comment \(comment.commentID)")
                    } else {
                        print("⚠️ CloudKit unlike sync failed - keeping local unlike state")
                        // Don't revert immediately - let user's intent stand
                        // The local state will be corrected on next app launch when likes reload
                    }
                }
            }
        } else {
            performLikeOperationLegacy(comment: comment, user: user) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ CloudKit like sync completed for comment \(comment.commentID)")
                    } else {
                        print("⚠️ CloudKit like sync failed - keeping local like state")
                        // Don't revert immediately - let user's intent stand
                        // The local state will be corrected on next app launch when likes reload
                    }
                }
            }
        }
    }
    
    
    // MARK: - Legacy CloudKit Operations (Completion Handler Based)
    // These methods use traditional completion handlers instead of async/await
    // for broader iOS compatibility and easier error handling in background queues
    
    private func performLikeOperationLegacy(comment: Comment, user: User, completion: @escaping (Bool) -> Void) {
        // Create CommentLike record in CloudKit
        let likeRecordName = "like_\(user.userID)_\(comment.commentID)"
        let record = CKRecord(recordType: "CommentLike", recordID: CKRecord.ID(recordName: likeRecordName))
        record["commentID"] = comment.commentID
        record["userID"] = user.userID
        record["dateCreated"] = Date()
        
        // Fetch Comment record by direct access to update likeCount
        let commentRecordID = CKRecord.ID(recordName: comment.commentID)
        publicDatabase.fetch(withRecordID: commentRecordID) { [weak self] commentRecord, error in
            guard let self = self,
                  let commentRecord = commentRecord,
                  error == nil else {
                print("❌ Comment record not found for like operation: \(String(describing: error))")
                completion(false)
                return
            }
                
                // Increment likeCount
                let newCount = (commentRecord["likeCount"] as? Int ?? 0) + 1
                commentRecord["likeCount"] = newCount as NSNumber
                
                // Batch save: CommentLike record + updated Comment record
                let modifyOp = CKModifyRecordsOperation(recordsToSave: [record, commentRecord], recordIDsToDelete: nil)
                modifyOp.savePolicy = .allKeys
                modifyOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("✅ CloudKit like operation completed successfully")
                        // Update local comments array with new count
                        DispatchQueue.main.async {
                            if let index = self.contentState.comments.firstIndex(where: { $0.commentID == comment.commentID }) {
                                self.contentState.comments[index].likeCount = newCount
                            }
                        }
                        completion(true)
                    case .failure(let error):
                        print("❌ CloudKit like operation failed: \(error)")
                        completion(false)
                    }
                }
                self.publicDatabase.add(modifyOp)
        }
    }
    
    private func performUnlikeOperationLegacy(comment: Comment, user: User, completion: @escaping (Bool) -> Void) {
        // Delete existing CommentLike record by direct access
        let likeRecordName = "like_\(user.userID)_\(comment.commentID)"
        let recordID = CKRecord.ID(recordName: likeRecordName)
        
        // Fetch Comment record by direct access to update likeCount
        let commentRecordID = CKRecord.ID(recordName: comment.commentID)
        self.publicDatabase.fetch(withRecordID: commentRecordID) { commentRecord, error in
            guard let commentRecord = commentRecord,
                  error == nil else {
                print("❌ Comment record not found for unlike operation: \(String(describing: error))")
                completion(false)
                return
            }
            
            // Decrement likeCount
            let newCount = max(0, (commentRecord["likeCount"] as? Int ?? 0) - 1)
            commentRecord["likeCount"] = newCount as NSNumber
            
            // Batch operation: delete CommentLike + update Comment record
            let modifyOp = CKModifyRecordsOperation(recordsToSave: [commentRecord], recordIDsToDelete: [recordID])
            modifyOp.savePolicy = .allKeys
            modifyOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("✅ CloudKit unlike operation completed successfully")
                    // Update local comments array with new count
                    DispatchQueue.main.async {
                        if let index = self.contentState.comments.firstIndex(where: { $0.commentID == comment.commentID }) {
                            self.contentState.comments[index].likeCount = newCount
                        }
                    }
                    completion(true)
                case .failure(let error):
                    print("❌ CloudKit unlike operation failed: \(error)")
                    completion(false)
                }
            }
            self.publicDatabase.add(modifyOp)
        }
    }
    
    // MARK: - Legacy WebPage CloudKit Operations (Completion Handler Based)
    // These methods handle WebPage like operations using traditional completion handlers
    
    // Simple CloudKit sync - fire and forget with direct record access
    private func simpleWebPageLikeSync(webPage: WebPage, user: User, shouldLike: Bool, completion: @escaping (Bool) -> Void) {
        if shouldLike {
            // Create like record with composite recordName
            let likeRecordName = "weblike_\(user.userID)_\(webPage.urlString)"
            let record = CKRecord(recordType: "WebPageLike", recordID: CKRecord.ID(recordName: likeRecordName))
            record["urlString"] = webPage.urlString
            record["userID"] = user.userID
            record["dateCreated"] = Date()
            
            publicDatabase.save(record) { _, error in
                completion(error == nil)
            }
        } else {
            // Delete like record by direct access
            let likeRecordName = "weblike_\(user.userID)_\(webPage.urlString)"
            let recordID = CKRecord.ID(recordName: likeRecordName)
            
            self.publicDatabase.delete(withRecordID: recordID) { _, error in
                completion(error == nil)
            }
        }
    }
    
    func hasLiked(_ comment: Comment) -> Bool {
        return uiState.likedComments.contains(comment.commentID)
    }
    
    func checkLikeStatus(for comment: Comment, completion: @escaping (Bool) -> Void) {
        guard let user = authViewModel.signedInUser else {
            completion(false)
            return
        }
        
        // Check like status by direct record access
        let likeRecordName = "like_\(user.userID)_\(comment.commentID)"
        let recordID = CKRecord.ID(recordName: likeRecordName)
        
        publicDatabase.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                if let _ = record, error == nil {
                    // Record exists, user has liked this comment
                    completion(true)
                } else {
                    // Record doesn't exist or error occurred, user hasn't liked
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Comment Management
    func removeComment(_ comment: Comment) {
        guard let user = authViewModel.signedInUser else { return }
        
        // Check if u-ser owns this comment
        guard comment.userID == user.userID else { return }
        
        // Remove from CloudKit
        publicDatabase.delete(withRecordID: comment.id) { [weak self] recordID, error in
            guard let self = self else { return }
            
            if error != nil {
                DispatchQueue.main.async {
                    self.loadingState.error = ShtellError.commentPostFailed
                    self.loadingState.showErrorAlert = true
                }
                return
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                // Remove from local comments array
                self.contentState.comments.removeAll { $0.id == comment.id }
                
                // Update comment count
                if let webPage = self.contentState.webPage {
                    let newCount = max(0, webPage.commentCount - 1)
                    self.contentState.webPage?.commentCount = newCount
                    self.contentState.commentCountLookup[webPage.urlString] = newCount
                    
                    // Update allWebPages array
                    if let index = self.contentState.webPages.firstIndex(where: { $0.urlString == webPage.urlString }) {
                        self.contentState.webPages[index].commentCount = newCount
                    }
                    
                    // Update savedWebPages array
                    if let index = self.contentState.savedWebPages.firstIndex(where: { $0.urlString == webPage.urlString }) {
                        self.contentState.savedWebPages[index].commentCount = newCount
                    }
                    
                    // Also update the WebPage record in CloudKit
                    let pageRecordID = CKRecord.ID(recordName: webPage.urlString)
                    self.publicDatabase.fetch(withRecordID: pageRecordID) { pageRecord, error in
                        guard let record = pageRecord, error == nil else { return }
                        
                        record["commentCount"] = newCount as NSNumber
                        self.publicDatabase.save(record) { _, _ in
                            // Don't need to handle this callback for UI
                        }
                    }
                }
                
                print("✅ Successfully deleted comment")
            }
        }
    }
    
    // MARK: - UI Helper Methods
    var thumbnailImageView: AnyView {
        if let thumbnailData = contentState.webPage?.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 105, height: 79)
                    .clipped()
                    .cornerRadius(5)
            )
        } else {
            return AnyView(
                VStack {
                    Text("\((contentState.webPage?.urlString.shortURL().prefix(1).lowercased()) ?? "a")")
                }
                    .font(.largeTitle)
                    .frame(width: 105, height: 79)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(lineWidth: 0.2)
                    }
            )
        }
    }
    
    // MARK: - Lazy Image Loading
    func loadImages(for webPage: WebPage, completion: @escaping (Data?, Data?) -> Void) {
        let recordID = CKRecord.ID(recordName: webPage.urlString)
        publicDatabase.fetch(withRecordID: recordID) { record, error in
            guard let record = record, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
                return
            }
            
            let faviconData = record["faviconData"] as? Data
            let thumbnailData = record["thumbnailData"] as? Data
            
            DispatchQueue.main.async {
                completion(faviconData, thumbnailData)
            }
        }
    }
    
    // MARK: - Image Caching
    func loadAndCacheImages(for webPage: WebPage) {
        // Check if already cached
        if contentState.imageCache[webPage.urlString] != nil {
            return
        }
        
        // Check if already have images in webPage
        if webPage.faviconData != nil && webPage.thumbnailData != nil {
            contentState.imageCache[webPage.urlString] = (favicon: webPage.faviconData, thumbnail: webPage.thumbnailData)
            return
        }
        
        // Load from CloudKit and cache
        loadImages(for: webPage) { [weak self] favicon, thumbnail in
            self?.contentState.imageCache[webPage.urlString] = (favicon: favicon, thumbnail: thumbnail)
        }
    }
    
    func getCachedImages(for webPage: WebPage) -> (favicon: Data?, thumbnail: Data?) {
        if let cached = contentState.imageCache[webPage.urlString] {
            return cached
        }
        // Fallback to webPage data
        return (favicon: webPage.faviconData, thumbnail: webPage.thumbnailData)
    }
    
    // MARK: - Following Comments
    func fetchFollowedUsersComments(for user: User, completion: @escaping ([Comment]) -> Void) {
        print("🔍 fetchFollowedUsersComments: Loading for user \(user.userID)")
        
        // First, get the list of followed users
        let followService = FollowService(authViewModel: authViewModel)
        Task {
            do {
                let followedUsers = try await followService.getFollowedUsers()
                let followedUserIDs = followedUsers.map { $0.userID }
                
                print("🔍 Found \(followedUserIDs.count) followed users")
                
                guard !followedUserIDs.isEmpty else {
                    await MainActor.run {
                        completion([])
                    }
                    return
                }
                
                // Create predicate to fetch comments from followed users
                let predicate = NSPredicate(format: "userID IN %@", followedUserIDs)
                let query = CKQuery(recordType: "Comment", predicate: predicate)
                
                // Sort by creation date, newest first
                query.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: false)]
                
                // Fetch comments from followed users
                self.publicDatabase.fetch(
                    withQuery: query,
                    inZoneWith: nil as CKRecordZone.ID?,
                    desiredKeys: nil as [String]?,
                    resultsLimit: 100 // Limit to most recent 100 comments
                ) { (result: Result<(matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?), Error>) in
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        switch result {
                        case .success(let (matchResults, _)):
                            var comments: [Comment] = []
                            
                            for (_, recordResult) in matchResults {
                                if case .success(let record) = recordResult {
                                    do {
                                        let comment = try Comment(record: record)
                                        comments.append(comment)
                                    } catch {
                                        print("⚠️ Error parsing comment: \(error)")
                                    }
                                }
                            }
                            
                            // Sort comments by date (newest first)
                            comments.sort { $0.dateCreated > $1.dateCreated }
                            
                            DispatchQueue.main.async {
                                print("✅ fetchFollowedUsersComments: Found \(comments.count) comments from followed users")
                                self.contentState.followedUserComments = comments
                                completion(comments)
                            }
                            
                        case .failure(let error):
                            print("❌ fetchFollowedUsersComments: Error fetching comments: \(error)")
                            DispatchQueue.main.async {
                                completion([])
                            }
                        }
                    }
                }
            } catch {
                print("❌ fetchFollowedUsersComments: Error getting followed users: \(error)")
                await MainActor.run {
                    completion([])
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func getAppIconData() -> Data? {
        // Try to get the app icon from the asset catalog
        guard let appIcon = UIImage(named: "AppIcon") else {
            // Fallback: try to get icon from bundle
            if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
               let lastIcon = iconFiles.last,
               let iconImage = UIImage(named: lastIcon) {
                return iconImage.pngData()
            }
            return nil
        }
        return appIcon.pngData()
    }
}
