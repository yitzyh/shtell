import Foundation
import CloudKit

@MainActor
class FollowService: ObservableObject {
    
    // MARK: - Dependencies
    private let publicDatabase = CKContainer(identifier: "iCloud.com.yitzy.DumFlow").publicCloudDatabase
    private let authViewModel: AuthViewModel
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    // MARK: - Core Methods
    
    /// Toggle follow status for a user
    func toggleFollow(followedUserID: String) async throws -> Bool {
        guard let currentUser = authViewModel.signedInUser else {
            throw DumFlowError.authenticationRequired
        }
        
        guard followedUserID != currentUser.userID else {
            throw DumFlowError.invalidOperation
        }
        
        let isCurrentlyFollowing = try await isFollowing(followedUserID: followedUserID)
        
        if isCurrentlyFollowing {
            try await unfollowUser(followedUserID: followedUserID)
            return false
        } else {
            try await followUser(followedUserID: followedUserID)
            return true
        }
    }
    
    /// Check if current user is following a specific user using direct record access
    func isFollowing(followedUserID: String) async throws -> Bool {
        guard let currentUser = authViewModel.signedInUser else {
            return false
        }
        
        let followRecordName = "follow_\(currentUser.userID)_\(followedUserID)"
        let recordID = CKRecord.ID(recordName: followRecordName)
        
        return try await withCheckedThrowingContinuation { continuation in
            publicDatabase.fetch(withRecordID: recordID) { record, error in
                if let error = error {
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        // Record not found = not following
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                // Record exists = following
                continuation.resume(returning: record != nil)
            }
        }
    }
    
    /// Get all users that the current user is following
    func getFollowedUsers() async throws -> [User] {
        guard let currentUser = authViewModel.signedInUser else {
            throw DumFlowError.authenticationRequired
        }
        
        let predicate = NSPredicate(format: "followerUserID == %@", currentUser.userID)
        let query = CKQuery(recordType: "UserFollow", predicate: predicate)
        
        // Get follow records
        let followRecords = try await fetchFollowRecords(query: query)
        
        // Get user records for each followed user
        var users: [User] = []
        for followRecord in followRecords {
            if let followedUserID = followRecord["followedUserID"] as? String {
                if let user = try await fetchUser(userID: followedUserID) {
                    users.append(user)
                }
            }
        }
        
        return users
    }
    
    /// Get all users that are following the current user
    func getFollowers() async throws -> [User] {
        guard let currentUser = authViewModel.signedInUser else {
            throw DumFlowError.authenticationRequired
        }
        
        let predicate = NSPredicate(format: "followedUserID == %@", currentUser.userID)
        let query = CKQuery(recordType: "UserFollow", predicate: predicate)
        
        // Get follow records
        let followRecords = try await fetchFollowRecords(query: query)
        
        // Get user records for each follower
        var users: [User] = []
        for followRecord in followRecords {
            if let followerUserID = followRecord["followerUserID"] as? String {
                if let user = try await fetchUser(userID: followerUserID) {
                    users.append(user)
                }
            }
        }
        
        return users
    }
    
    // MARK: - Private Helper Methods
    
    /// Follow a user
    private func followUser(followedUserID: String) async throws {
        guard let currentUser = authViewModel.signedInUser else {
            throw DumFlowError.authenticationRequired
        }
        
        let userFollow = UserFollow(followerUserID: currentUser.userID, followedUserID: followedUserID)
        let record = userFollow.toRecord()
        
        return try await withCheckedThrowingContinuation { continuation in
            publicDatabase.save(record) { _, error in
                if let error = error {
                    print("❌ FollowService: Error following user: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ FollowService: Successfully followed user")
                    continuation.resume()
                }
            }
        }
    }
    
    /// Unfollow a user using direct record access
    private func unfollowUser(followedUserID: String) async throws {
        guard let currentUser = authViewModel.signedInUser else {
            throw DumFlowError.authenticationRequired
        }
        
        let followRecordName = "follow_\(currentUser.userID)_\(followedUserID)"
        let recordID = CKRecord.ID(recordName: followRecordName)
        
        return try await withCheckedThrowingContinuation { continuation in
            publicDatabase.delete(withRecordID: recordID) { _, error in
                if let error = error {
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        // Record already doesn't exist - that's fine
                        print("⚠️ FollowService: Follow record already deleted")
                        continuation.resume()
                    } else {
                        print("❌ FollowService: Error unfollowing user: \(error)")
                        continuation.resume(throwing: error)
                    }
                } else {
                    print("✅ FollowService: Successfully unfollowed user")
                    continuation.resume()
                }
            }
        }
    }
    
    /// Fetch follow records from CloudKit
    private func fetchFollowRecords(query: CKQuery) async throws -> [CKRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            publicDatabase.fetch(
                withQuery: query,
                inZoneWith: nil as CKRecordZone.ID?,
                desiredKeys: nil as [String]?,
                resultsLimit: CKQueryOperation.maximumResults
            ) { result in
                switch result {
                case .success(let (matchResults, _)):
                    let records = matchResults.compactMap { _, recordResult -> CKRecord? in
                        if case .success(let record) = recordResult {
                            return record
                        }
                        return nil
                    }
                    continuation.resume(returning: records)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Fetch a specific user by userID using direct record access
    private func fetchUser(userID: String) async throws -> User? {
        let recordID = CKRecord.ID(recordName: userID)
        
        return try await withCheckedThrowingContinuation { continuation in
            publicDatabase.fetch(withRecordID: recordID) { record, error in
                if let error = error {
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        // User not found - return nil instead of throwing
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                guard let record = record else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let user = try User(record: record)
                    continuation.resume(returning: user)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}