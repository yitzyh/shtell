//
//  SignInView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 5/12/25.
//

import SwiftUI
import CloudKit

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                if authViewModel.needsUsernameSelection {
                    // Show username selection view
                    if let pendingData = authViewModel.pendingUserData {
                        UsernameSelectionView(
                            displayName: pendingData.displayName,
                            onUsernameSelected: { username, displayName in
                                Task {
                                    await authViewModel.completeSignup(with: username, displayName: displayName)
                                }
                            }
                        )
                        .environmentObject(authViewModel)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    authViewModel.cancelUsernameSelection()
                                }
                            }
                        }
                    }
                } else if authViewModel.signedInUser != nil {
                    // Show signed-in user info
                    ProfileView()
                        .environmentObject(authViewModel)
                } else {
                    // Show sign-in screen
                    signInView
                }
            }
//            .toolbar {
//                // Debug delete button in top right
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("🗑️") {
//                        showDeleteConfirmation = true
//                    }
//                    .foregroundColor(.red)
//                }
//            }
            .confirmationDialog(
                "Delete All Users",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All Users", role: .destructive) {
                    deleteAllUsers()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all user accounts from CloudKit. This action cannot be undone.")
            }
        }
        .onReceive(authViewModel.$needsUsernameSelection) { needsSelection in
            print("SignInView: needsUsernameSelection changed to: \(needsSelection)")
        }
        .onReceive(authViewModel.$signedInUser) { user in
            print("SignInView: signedInUser changed to: \(user?.username ?? "nil")")
        }
    }
    
    private func deleteAllUsers() {
        let container = CKContainer(identifier: "iCloud.com.yitzy.DumFlow")
        
        print("🗑️ Starting to delete all users...")
        
        let predicate = NSPredicate(format: "dateCreated != %@", Date.distantPast as NSDate)
        let query = CKQuery(recordType: "User", predicate: predicate)
        
        container.publicCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: ["recordName"], resultsLimit: 100) { result in
            switch result {
            case .success(let response):
                let recordIDs = response.matchResults.compactMap { $0.0 }
                
                print("🗑️ Found \(recordIDs.count) users to delete:")
                for recordID in recordIDs {
                    print("   - \(recordID.recordName)")
                }
                
                if recordIDs.isEmpty {
                    print("✅ No users to delete")
                    return
                }
                
                container.publicCloudDatabase.modifyRecords(saving: [], deleting: recordIDs) { deleteResult in
                    DispatchQueue.main.async {
                        switch deleteResult {
                        case .success:
                            print("✅ Successfully deleted all \(recordIDs.count) users from CloudKit")
                            // ❌ REMOVED: deleteAllLocalUsers() - No Core Data
                            self.authViewModel.signOut()
                        case .failure(let error):
                            print("❌ Failed to delete users from CloudKit: \(error)")
                        }
                    }
                }
            case .failure(let error):
                print("❌ Failed to fetch users for deletion: \(error)")
            }
        }
    }
    
    private var signInView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo/Header
            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Welcome to Shtell")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Connect and share with your community")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Sign In Button
            VStack(spacing: 16) {
                authViewModel.signInButton()
                    .frame(height: 50)
                    .cornerRadius(10)
                
                Text("Sign in to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Error Message
            if let msg = authViewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
    
}

#Preview {
    let authViewModel = AuthViewModel()
    
    SignInView()
        .environmentObject(authViewModel)
}
