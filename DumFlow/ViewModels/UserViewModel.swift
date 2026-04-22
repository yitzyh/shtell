//
//  UserViewModel.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/5/25.
//

import Foundation
import Combine

@MainActor
class UserViewModel: ObservableObject {

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
        Task {
            do {
                let user = try await UserAPIService.shared.fetchUser(by: userID)
                self.user = user
                self.isLoading = false
                print("✅ UserViewModel: Successfully fetched user: \(user.username)")
            } catch {
                self.isLoading = false
                self.errorMessage = "User not found"
                print("❌ UserViewModel: fetchUser failed: \(error)")
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
