import Foundation

@MainActor
class FollowService: ObservableObject {

    // MARK: - Dependencies
    private let authViewModel: AuthViewModel

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    // MARK: - Core Methods (stubs — follows deferred to 1.4)

    /// Toggle follow status for a user (stub — deferred to 1.4)
    func toggleFollow(followedUserID: String) async throws -> Bool {
        print("⚠️ FollowService: toggleFollow deferred to 1.4")
        return false
    }

    /// Check if current user is following a specific user (stub — deferred to 1.4)
    func isFollowing(followedUserID: String) async throws -> Bool {
        return false
    }

    /// Get all users that the current user is following (stub — deferred to 1.4)
    func getFollowedUsers() async throws -> [User] {
        return []
    }

    /// Get all users that are following the current user (stub — deferred to 1.4)
    func getFollowers() async throws -> [User] {
        return []
    }
}
