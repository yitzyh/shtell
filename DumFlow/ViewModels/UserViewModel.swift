//
//  UserViewModel.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/5/25.
//

import Foundation
import CloudKit
import Combine

@MainActor
class UserViewModel: ObservableObject {
    
    let publicDatabase = CKContainer(identifier: "iCloud.com.yitzy.DumFlow").publicCloudDatabase
    
    // MARK: - Published Properties
    @Published var user: User? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // MARK: - User Lookup
    
    func fetchUser(by userID: String) {
        
        guard !userID.isEmpty else {
            print("❌ UserViewModel: Empty userID provided")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let recordID = CKRecord.ID(recordName: userID)
        
        publicDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            Task { @MainActor in
                self?.isLoading = false
                
                if let error = error {
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        print("❌ UserViewModel: User not found: \(userID)")
                        self?.errorMessage = "User not found"
                    } else {
                        print("❌ UserViewModel: CloudKit fetch failed: \(error)")
                        self?.errorMessage = "Network error occurred"
                    }
                    return
                }
                
                guard let record = record else {
                    print("❌ UserViewModel: No record returned for userID: \(userID)")
                    self?.errorMessage = "User not found"
                    return
                }
                
                do {
                    let user = try User(record: record)
                    self?.user = user
                    print("✅ UserViewModel: Successfully fetched user: \(user.username)")
                } catch {
                    print("❌ UserViewModel: Failed to parse user record: \(error)")
                    self?.errorMessage = "Failed to parse user data"
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func clearUser() {
        user = nil
        errorMessage = nil
    }
    
    func reset() {
        user = nil
        isLoading = false
        errorMessage = nil
    }
}