import AuthenticationServices
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {

  @AppStorage("appleUserID") private var storedAppleUserID: String?
  @AppStorage("userID") private var storedUserID: String?

  @Published var signedInUser: User? = nil
  @Published var errorMessage: String? = nil
  @Published var needsUsernameSelection = false
  @Published var pendingUserData: PendingUserData?

  // MARK: - Supporting Types

  struct PendingUserData {
    let displayName: String
    let appleUserID: String
  }

  enum AuthError: LocalizedError {
    case usernameTaken
    case networkFailure
    case invalidCredentials

    var errorDescription: String? {
      switch self {
      case .usernameTaken: return "Username is already taken"
      case .networkFailure: return "Network connection failed"
      case .invalidCredentials: return "Invalid Apple ID credentials"
      }
    }
  }

  init() {
    DispatchQueue.main.async { [weak self] in
      self?.restoreSession()
    }
  }

  func signInButton() -> some View {
    SignInWithAppleButton(.signIn) { request in
      request.requestedScopes = [.fullName, .email]
    } onCompletion: { result in
      switch result {
      case .success(let auth):
        Task { @MainActor in self.handleAuthorization(auth) }
      case .failure(let error):
        Task { @MainActor in self.errorMessage = error.localizedDescription }
      }
    }
    .signInWithAppleButtonStyle(.white)
  }

  private func handleAuthorization(_ authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      self.errorMessage = "Invalid Apple ID credential"
      return
    }
    self.storedAppleUserID = credential.user
    Task {
      await lookupOrCreateUser(appleUserID: credential.user, credential: credential)
    }
  }

  private func lookupOrCreateUser(appleUserID: String, credential: ASAuthorizationAppleIDCredential) async {
    do {
      let user = try await UserAPIService.shared.lookupByAppleUserID(appleUserID)
      completeSignIn(with: user)
    } catch {
      // User not found — start signup flow
      let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
        .compactMap { $0 }
        .joined(separator: " ")
      self.pendingUserData = PendingUserData(
        displayName: displayName.isEmpty ? "User" : displayName,
        appleUserID: appleUserID
      )
      self.needsUsernameSelection = true
      self.errorMessage = nil
    }
  }

  func completeSignup(with username: String, displayName: String) async {
    guard let pending = pendingUserData else {
      self.errorMessage = "Missing signup data"
      return
    }

    let isAvailable = await checkUsernameAvailability(username)
    guard isAvailable else {
      self.errorMessage = "Username is no longer available"
      return
    }

    do {
      let user = try await UserAPIService.shared.createUser(
        appleUserID: pending.appleUserID,
        username: username,
        displayName: displayName
      )
      completeSignIn(with: user)
      self.pendingUserData = nil
      self.needsUsernameSelection = false
    } catch {
      self.errorMessage = error.localizedDescription
    }
  }

  func completeSignIn(with user: User) {
    self.storedUserID = user.userID
    self.signedInUser = user
    self.errorMessage = nil
  }

  func checkUsernameAvailability(_ username: String) async -> Bool {
    do {
      return try await UserAPIService.shared.isUsernameAvailable(username)
    } catch {
      return false
    }
  }

  func cancelUsernameSelection() {
    self.pendingUserData = nil
    self.needsUsernameSelection = false
    self.errorMessage = nil
  }

  private func restoreSession() {
    guard let userID = storedUserID else { return }
    Task {
      guard self.signedInUser == nil else { return }
      do {
        let user = try await UserAPIService.shared.lookupByUserID(userID)
        self.signedInUser = user
      } catch {
        // Session expired or user not found — silently clear stored ID
        self.storedUserID = nil
      }
    }
  }

  func signOut() {
    storedAppleUserID = nil
    storedUserID = nil
    self.signedInUser = nil
    self.errorMessage = nil
    self.needsUsernameSelection = false
    self.pendingUserData = nil
  }

  func refreshUserData() async {
    guard let userID = storedUserID else { return }
    do {
      let user = try await UserAPIService.shared.lookupByUserID(userID)
      self.signedInUser = user
      self.errorMessage = nil
    } catch {
      self.errorMessage = "Failed to refresh user data: \(error.localizedDescription)"
    }
  }
}
