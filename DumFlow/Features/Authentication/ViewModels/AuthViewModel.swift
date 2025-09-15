//
// AuthViewModel.swift
// Manages user authentication via Sign in with Apple and persists user data in CloudKit.
//
//  DumFlow
//
//  Created by Isaac Herskowitz on 5/12/25.
//

import AuthenticationServices
import CloudKit
import SwiftUI
// ❌ REMOVED: import CoreData - No longer using Core Data

/// ViewModel for handling Sign in with Apple authentication,
/// restoring previous sessions, and saving/loading the user record from CloudKit.
@MainActor
final class AuthViewModel: ObservableObject {

    // Persist the Apple-assigned user ID across app launches.
    @AppStorage("appleUserID") private var appleUserID: String?
    // Persist the CKRecord ID of the User record for session restoration
    @AppStorage("cloudKitRecordName") private var cloudKitRecordName: String?

    // ✅ UPDATED: Now uses CloudKit User model instead of Core Data
    @Published var signedInUser: User? = nil
    // Holds any authentication or CloudKit error messages for display.
    @Published var errorMessage: String? = nil
    // Controls whether to show username selection view
    @Published var needsUsernameSelection = false
    // Holds pending user data during username selection process
    @Published var pendingUserData: PendingUserData?
    
    // ❌ REMOVED: let viewContext: NSManagedObjectContext - No Core Data context needed
    // ✅ ADDED: CloudKit service for user operations
//    private let userService = UserService()

    // MARK: - Supporting Types
    
    struct PendingUserData {
        let displayName: String
        // REMOVED: email field - no longer stored in User record
        let recordToSave: CKRecord
        let appleUserID: String
        let cloudKitUserRecordID: CKRecord.ID
    }
    
    enum AuthError: LocalizedError {
        case usernameTaken
        case networkFailure
        case invalidCredentials
        case cloudKitUnavailable
        
        var errorDescription: String? {
            switch self {
            case .usernameTaken: return "Username is already taken"
            case .networkFailure: return "Network connection failed"
            case .invalidCredentials: return "Invalid Apple ID credentials"
            case .cloudKitUnavailable: return "iCloud is required for this app"
            }
        }
    }

    // ✅ UPDATED: Simplified init - no Core Data context parameter
    init() {
        restoreSession()
    }
    
    /// Returns a SwiftUI SignInWithAppleButton.
    func signInButton() -> some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                self.handleAuthorization(auth)
            case .failure(let error):
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        .signInWithAppleButtonStyle(.white)
    }

    private func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                self.errorMessage = "Invalid Apple ID credential"
            }
            return
        }
        
        self.appleUserID = credential.user

        let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
        container.fetchUserRecordID { [weak self] recordID, fetchError in
            guard let recordID = recordID else {
                Task { @MainActor in
                    self?.errorMessage = fetchError?.localizedDescription ?? "Failed to get CloudKit user ID"
                }
                return
            }

            Task {
                await self?.searchForExistingUser(appleUserID: credential.user, credential: credential, recordID: recordID)
            }
        }
    }

    // CHANGED: Search by appleUserID instead of email array
    private func searchForExistingUser(appleUserID: String, credential: ASAuthorizationAppleIDCredential, recordID: CKRecord.ID) async {
        let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
        
        // CHANGED: Query by appleUserID field instead of email
        let predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        let query = CKQuery(recordType: "User", predicate: predicate)
        
        container.publicCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    if !response.matchResults.isEmpty {
                        for (_, matchResult) in response.matchResults {
                            if case .success(let record) = matchResult {
                                self.completeSignIn(
                                    with: record,
                                    appleUserID: credential.user,
                                    cloudKitUserRecordID: recordID
                                )
                                self.needsUsernameSelection = false
                                self.pendingUserData = nil
                                self.errorMessage = nil
                                return
                            }
                        }
                    }
                    
                    // CHANGED: No existing user found, create new one
                    self.createNewUserFlow(credential: credential, cloudKitUserRecordID: recordID)
                    
                case .failure(let error):
                    print("Error searching for Apple ID \(appleUserID): \(error)")
                    self.errorMessage = "Failed to check existing account: \(error.localizedDescription)"
                }
            }
        }
    }

    private func createNewUserFlow(credential: ASAuthorizationAppleIDCredential, cloudKitUserRecordID: CKRecord.ID) {
        // ADDED: Generate unique userID for new user
        let userID = UUID().uuidString
        
        // OPTIMIZED: Use userID as recordName for direct CloudKit access
        let recordToSave = CKRecord(recordType: "User", recordID: CKRecord.ID(recordName: userID))
        recordToSave["userID"] = userID
        
        // ADDED: Store Apple's user identifier for authentication
        recordToSave["appleUserID"] = credential.user
        
        recordToSave["dateCreated"] = Date()
        
        // ADDED: Initialize user status flags (1 = active, 0 = inactive/banned)
        recordToSave["isActive"] = 1
        recordToSave["isBanned"] = 0
        
        let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        // REMOVED: email field - no longer stored in User record per new schema
        recordToSave["displayName"] = displayName.isEmpty ? "User" : displayName
        
        self.pendingUserData = PendingUserData(
            displayName: displayName.isEmpty ? "User" : displayName,
            // REMOVED: email parameter - no longer stored
            recordToSave: recordToSave,
            appleUserID: credential.user,
            cloudKitUserRecordID: cloudKitUserRecordID
        )
        self.needsUsernameSelection = true
        self.errorMessage = nil
    }
    
    func completeSignup(with username: String, displayName: String) async {
        guard let pending = pendingUserData else {
            self.errorMessage = "Missing signup data"
            return
        }
        
        let isAvailable = await checkUsernameAvailability(username)
        
        if !isAvailable {
            self.errorMessage = "Username is no longer available"
            return
        }
        
        let recordToSave = pending.recordToSave
        recordToSave["username"] = username
        recordToSave["displayName"] = displayName
        
        let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
        
        do {
            let savedRecord = try await container.publicCloudDatabase.save(recordToSave)
            await MainActor.run {
                self.completeSignIn(with: savedRecord, appleUserID: pending.appleUserID, cloudKitUserRecordID: pending.cloudKitUserRecordID)
                
                self.pendingUserData = nil
                self.needsUsernameSelection = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// ✅ UPDATED: Now creates CloudKit User model instead of Core Data
    func completeSignIn(with record: CKRecord, appleUserID: String, cloudKitUserRecordID: CKRecord.ID) {
        do {
            // ✅ ADDED: Convert CloudKit record to our CK_User model
            let user = try User(record: record)
            
            self.cloudKitRecordName = record.recordID.recordName
            self.signedInUser = user
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to parse user data: \(error.localizedDescription)"
        }
    }
    
    func checkUsernameAvailability(_ username: String) async -> Bool {
        let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
        let predicate = NSPredicate(format: "username == %@", username)
        let query = CKQuery(recordType: "User", predicate: predicate)
        
        return await withCheckedContinuation { continuation in
            container.publicCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["username"], resultsLimit: 1) { result in
                switch result {
                case .success(let response):
                    let isAvailable = response.matchResults.isEmpty
                    continuation.resume(returning: isAvailable)
                case .failure:
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func cancelUsernameSelection() {
        self.pendingUserData = nil
        self.needsUsernameSelection = false
        self.errorMessage = nil
    }

    /// ✅ UPDATED: Pure CloudKit session restoration (no Core Data)
    private func restoreSession() {
        guard let recordName = cloudKitRecordName else { return }
        
        let recordID = CKRecord.ID(recordName: recordName)
        let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
        
        container.publicCloudDatabase.fetch(withRecordID: recordID) { record, error in
            Task { @MainActor in
                if let error = error {
                    self.errorMessage = "Failed to restore user: \(error.localizedDescription)"
                    self.signedInUser = nil
                    return
                }
                guard let record = record else {
                    self.errorMessage = "No CloudKit record found."
                    self.signedInUser = nil
                    return
                }
                
                do {
                    let user = try User(record: record)
                    self.signedInUser = user
                } catch {
                    self.errorMessage = "Failed to restore user: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // ❌ REMOVED: deleteAllLocalUsers() - No Core Data to delete from

    func signOut() {
        appleUserID = nil
        cloudKitRecordName = nil
        
        self.signedInUser = nil
        self.errorMessage = nil
        self.needsUsernameSelection = false
        self.pendingUserData = nil
    }
    
    func refreshUserData() async {
        guard let recordName = cloudKitRecordName else { return }
        
        let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
        let recordID = CKRecord.ID(recordName: recordName)
        
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
            await MainActor.run {
                do {
                    let updatedUser = try User(record: record)
                    self.signedInUser = updatedUser
                    self.errorMessage = nil
                } catch {
                    self.errorMessage = "Failed to parse updated user data: \(error.localizedDescription)"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to refresh user data: \(error.localizedDescription)"
            }
        }
    }
}
