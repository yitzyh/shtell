//
//  BrowserHistoryService.swift
//  DumFlow
//
//  Created by Claude on 7/19/25.
//  Service for managing browser history with analytics tracking
//

import Foundation
import CloudKit
import Combine

@MainActor
class BrowserHistoryService: ObservableObject {
    
    // MARK: - Dependencies
    private let publicDatabase = CKContainer(identifier: "iCloud.com.yitzy.DumFlow").publicCloudDatabase
    internal let authViewModel: AuthViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published var recentHistory: [BrowserHistory] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreData = true
    
    // MARK: - Pagination
    internal var currentCursor: CKQueryOperation.Cursor?
    internal let pageSize = 20
    
    // MARK: - Analytics Tracking
    private var pageStartTime: Date?
    private var currentURL: String?
    private var scrollDepthTracker: Double = 0.0
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    // MARK: - Core History Functions
    
    /// Add a new page visit to history
    func addToHistory(
        urlString: String,
        title: String?,
        referrerURL: String? = nil
    ) {
        print("🟢 BrowserHistoryService: Adding to history - \(urlString)")
        
        guard let userID = authViewModel.signedInUser?.userID else {
            print("❌ BrowserHistoryService: No authenticated user")
            return
        }
        
        // Track page start time for duration analytics
        pageStartTime = Date()
        currentURL = urlString
        scrollDepthTracker = 0.0
        
        // Create history entry
        let historyEntry = BrowserHistory(
            urlString: urlString,
            title: title,
            userID: userID,
            referrerURL: referrerURL
        )
        
        // Check if we already have this URL in recent history (update visit count)
        if let existingIndex = recentHistory.firstIndex(where: { $0.urlString == urlString }) {
            var updatedEntry = recentHistory[existingIndex]
            updatedEntry.visitCount += 1
            recentHistory[existingIndex] = updatedEntry
            
            // Update in CloudKit
            updateHistoryEntry(updatedEntry)
        } else {
            // Add new entry
            recentHistory.insert(historyEntry, at: 0)
            
            // Save to CloudKit
            saveHistoryEntry(historyEntry)
        }
        
        // Keep only recent 100 entries in memory
        if recentHistory.count > 100 {
            recentHistory = Array(recentHistory.prefix(100))
        }
    }
    
    /// Update analytics when user leaves a page
    func trackPageExit(didComment: Bool = false, didLike: Bool = false, didSave: Bool = false) {
        guard let currentURL = currentURL,
              let pageStartTime = pageStartTime,
              authViewModel.signedInUser?.userID != nil else { return }
        
        let viewDuration = Date().timeIntervalSince(pageStartTime)
        
        print("🟢 BrowserHistoryService: Tracking page exit - duration: \(viewDuration)s, scroll: \(scrollDepthTracker)")
        
        // Find the history entry and update analytics
        if let index = recentHistory.firstIndex(where: { $0.urlString == currentURL }) {
            var entry = recentHistory[index]
            entry.viewDuration = viewDuration
            entry.scrollDepth = scrollDepthTracker
            entry.didComment = didComment
            entry.didLike = didLike
            entry.didSave = didSave
            
            recentHistory[index] = entry
            updateHistoryEntry(entry)
        }
        
        // Reset tracking
        self.pageStartTime = nil
        self.currentURL = nil
        self.scrollDepthTracker = 0.0
    }
    
    /// Update scroll depth for current page
    func updateScrollDepth(_ depth: Double) {
        scrollDepthTracker = max(scrollDepthTracker, depth)
    }
    
    // MARK: - CloudKit Operations
    
    private func saveHistoryEntry(_ entry: BrowserHistory) {
        let record = entry.toRecord()
        
        publicDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ BrowserHistoryService: Failed to save history - \(error.localizedDescription)")
                } else {
                    print("✅ BrowserHistoryService: History saved successfully")
                }
            }
        }
    }
    
    private func updateHistoryEntry(_ entry: BrowserHistory) {
        let record = entry.toRecord()
        
        publicDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ BrowserHistoryService: Failed to update history - \(error.localizedDescription)")
                } else {
                    print("✅ BrowserHistoryService: History updated successfully")
                }
            }
        }
    }
    
    /// Reset pagination state (called before fresh fetch)
    private func resetPagination() {
        currentCursor = nil
        hasMoreData = true
        isLoadingMore = false
    }
    
    /// Fetch user's browser history from CloudKit (last week only for performance)
    func fetchHistory(limit: Int = 20) {
        // Reset pagination state for fresh fetch
        resetPagination()
        guard let userID = authViewModel.signedInUser?.userID else {
            print("❌ BrowserHistoryService: No authenticated user for fetch")
            return
        }
        
        isLoading = true
        
        // Only fetch last week's history for better performance
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "userID == %@ AND dateVisited >= %@", userID, oneWeekAgo as CVarArg)
        let query = CKQuery(recordType: "BrowserHistory", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "dateVisited", ascending: false)]
        
        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: pageSize) { [weak self] results in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch results {
                case .success(let (matchResults, cursor)):
                    let records = matchResults.compactMap { _, result in
                        try? result.get()
                    }
                    
                    let historyEntries = records.compactMap { record -> BrowserHistory? in
                        do {
                            return try BrowserHistory(record: record)
                        } catch {
                            print("❌ BrowserHistoryService: Failed to parse record - \(error)")
                            return nil
                        }
                    }
                    
                    self.recentHistory = historyEntries
                    self.currentCursor = cursor
                    self.hasMoreData = cursor != nil
                    print("✅ BrowserHistoryService: Fetched \(self.recentHistory.count) history entries, hasMore: \(self.hasMoreData)")
                    
                case .failure(let error):
                    print("❌ BrowserHistoryService: Failed to fetch history - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Search history by domain or title
    func searchHistory(query: String) -> [BrowserHistory] {
        let lowercaseQuery = query.lowercased()
        return recentHistory.filter { entry in
            entry.domain.lowercased().contains(lowercaseQuery) ||
            entry.title?.lowercased().contains(lowercaseQuery) == true ||
            entry.urlString.lowercased().contains(lowercaseQuery)
        }
    }
    
    /// Get history grouped by domain
    func getHistoryByDomain() -> [String: [BrowserHistory]] {
        return Dictionary(grouping: recentHistory) { $0.domain }
    }
    
    /// Load more history when user scrolls (call this when near bottom of list)
    func loadMoreIfNeeded() {
        guard let cursor = currentCursor,
              hasMoreData,
              !isLoadingMore else { return }
        
        isLoadingMore = true
        
        let operation = CKQueryOperation(cursor: cursor)
        operation.resultsLimit = pageSize
        operation.desiredKeys = nil
        
        operation.recordMatchedBlock = { [weak self] recordID, result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let record):
                    do {
                        let historyEntry = try BrowserHistory(record: record)
                        self.recentHistory.append(historyEntry)
                    } catch {
                        print("❌ BrowserHistoryService: Failed to parse record - \(error)")
                    }
                case .failure(let error):
                    print("❌ BrowserHistoryService: Failed to fetch record - \(error.localizedDescription)")
                }
            }
        }
        
        operation.queryResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingMore = false
                
                switch result {
                case .success(let cursor):
                    self.currentCursor = cursor
                    self.hasMoreData = cursor != nil
                    print("✅ BrowserHistoryService: Loaded more entries, hasMore: \(self.hasMoreData)")
                case .failure(let error):
                    print("❌ BrowserHistoryService: Failed to load more - \(error.localizedDescription)")
                }
            }
        }
        
        publicDatabase.add(operation)
    }
    
    /// Clear all history (for privacy)
    func clearHistory() {
        guard let userID = authViewModel.signedInUser?.userID else { return }
        
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "BrowserHistory", predicate: predicate)
        
        publicDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { [weak self] results in
            switch results {
            case .success(let (matchResults, _)):
                let records = matchResults.compactMap { _, result in
                    try? result.get()
                }
                
                let recordIDs = records.map { $0.recordID }
                
                let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                deleteOperation.modifyRecordsResultBlock = { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self?.recentHistory.removeAll()
                            print("✅ BrowserHistoryService: History cleared successfully")
                        case .failure(let error):
                            print("❌ BrowserHistoryService: Failed to clear history - \(error)")
                        }
                    }
                }
                
                self?.publicDatabase.add(deleteOperation)
                
            case .failure(let error):
                print("❌ BrowserHistoryService: Failed to fetch history for deletion - \(error)")
            }
        }
    }
}
