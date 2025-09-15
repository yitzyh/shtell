//
//  UserService.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 6/14/25.
//

import CloudKit
import Foundation

class UserService: ObservableObject {
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
    
    // MARK: - User Updates
    
    func updateUsername(_ newUsername: String, for user: User) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        // Check username availability first
        let isAvailable = await checkUsernameAvailability(newUsername)
        if !isAvailable {
            throw UserServiceError.usernameTaken
        }
        
        try await updateUserRecord(user: user, newUsername: newUsername, newDisplayName: nil)
    }
    
    func updateDisplayName(_ newDisplayName: String, for user: User) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        try await updateUserRecord(user: user, newUsername: nil, newDisplayName: newDisplayName)
    }
    
    func updateBio(_ newBio: String, for user: User) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        try await updateUserRecord(user: user, newUsername: nil, newDisplayName: nil, newBio: newBio)
    }
    
    private func updateUserRecord(user: User, newUsername: String?, newDisplayName: String?, newBio: String? = nil) async throws {
        // First fetch the existing record
        let userRecord = try await container.publicCloudDatabase.record(for: user.id)
        
        // Update the record with new values
        if let newUsername = newUsername {
            print("🔄 UserService: Updating username to: \(newUsername)")
            userRecord["username"] = newUsername
        }
        if let newDisplayName = newDisplayName {
            print("🔄 UserService: Updating displayName to: \(newDisplayName)")
            userRecord["displayName"] = newDisplayName
        }
        if let newBio = newBio {
            print("🔄 UserService: Updating bio to: \(newBio)")
            userRecord["bio"] = newBio
        }
        
        // Save the updated record
        _ = try await container.publicCloudDatabase.save(userRecord)
        print("✅ UserService: CloudKit update successful")
        
        await MainActor.run {
            self.errorMessage = nil
        }
    }
    
    func checkUsernameAvailability(_ username: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let predicate = NSPredicate(format: "username == %@", username)
            let query = CKQuery(recordType: "User", predicate: predicate)
            
            container.publicCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.matchResults.isEmpty)
                case .failure(_):
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

// MARK: - UserService Errors

enum UserServiceError: LocalizedError {
    case usernameTaken
    case networkFailure
    case recordNotFound
    
    var errorDescription: String? {
        switch self {
        case .usernameTaken:
            return "Username is already taken"
        case .networkFailure:
            return "Network connection failed"
        case .recordNotFound:
            return "User record not found"
        }
    }
}