import Foundation
import Combine
import SwiftUI
import UIKit
import WebKit

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

  let authViewModel: AuthViewModel
  let browserHistoryService = BrowserHistoryManager.shared

  // MARK: - Published State

  @Published var contentState = ContentState()
  @Published var uiState = UIState()
  @Published var loadingState = LoadingState()

  // MARK: - Internal

  var currentWebPageURLString: String?
  var cancellables = Set<AnyCancellable>()
  weak var webBrowser: WebBrowser?

  init(authViewModel: AuthViewModel) {
    self.authViewModel = authViewModel
    authViewModel.$signedInUser
      .compactMap { $0 }
      .sink { [weak self] user in self?.loadAllUserData(for: user) }
      .store(in: &cancellables)
  }

  // MARK: - URL setter

  var urlString: String? {
    get { loadingState.urlString }
    set {
      loadingState.urlString = newValue
      if let url = newValue?.normalizedURL {
        fetchComments(for: url)
        // Pre-populate comment count from pages metadata (before comments load)
        Task {
          if let metadata = try? await PagesAPIService.shared.fetchPageMetadata(for: url) {
            self.contentState.commentCountLookup[url] = metadata.commentCount
          }
        }
      }
    }
  }

  // MARK: - User Data Loading

  func loadAllUserData(for user: User) {
    Task {
      await fetchSavedWebPagesAsync(for: user)
    }
  }

  // MARK: - Comments

  func fetchComments(for urlString: String) {
    loadingState.isLoadingComments = true
    Task {
      do {
        let comments = try await CommentAPIService.shared.fetchComments(for: urlString)
        self.contentState.comments = comments
        self.contentState.commentCountLookup[urlString] = comments.count
        self.loadingState.isLoadingComments = false
        if let coordinator = self.webBrowser?.wkWebView?.navigationDelegate as? WebView.Coordinator {
          coordinator.triggerHighlighting()
        }
        // Also fetch authoritative count from pages metadata in background
        Task {
          if let metadata = try? await PagesAPIService.shared.fetchPageMetadata(for: urlString) {
            self.contentState.commentCountLookup[urlString] = metadata.commentCount
          }
        }
      } catch {
        print("Error fetching comments: \(error)")
        self.loadingState.isLoadingComments = false
      }
    }
  }

  func extractPageMetadata(from webView: WKWebView?) async -> (faviconURL: String?, thumbnailURL: String?) {
    guard let webView else { return (nil, nil) }
    let domain = webView.url?.host ?? ""
    let faviconURL = domain.isEmpty ? nil : "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"
    let thumbnailURL: String? = await withCheckedContinuation { continuation in
      webView.evaluateJavaScript(
        "(function(){var og=document.querySelector('meta[property=\"og:image\"]');return og?og.getAttribute('content'):null;})()"
      ) { result, _ in
        continuation.resume(returning: result as? String)
      }
    }
    return (faviconURL, thumbnailURL)
  }

  func addComment(text: String, parentCommentID: String? = nil) {
    guard let user = authViewModel.signedInUser else {
      loadingState.error = .authenticationRequired
      loadingState.showErrorAlert = true
      return
    }
    guard let currentURL = self.urlString?.normalizedURL, !currentURL.isEmpty else {
      loadingState.error = .invalidURL
      loadingState.showErrorAlert = true
      return
    }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      loadingState.error = .commentPostFailed
      loadingState.showErrorAlert = true
      return
    }

    Task {
      do {
        let wkWebView = webBrowser?.wkWebView
        let (faviconURL, thumbnailURL) = await extractPageMetadata(from: wkWebView)
        let pageTitle = wkWebView?.title?.isEmpty == false ? wkWebView?.title : currentURL
        let domain = URL(string: currentURL)?.host

        let comment = try await CommentAPIService.shared.postComment(
          urlString: currentURL,
          text: text,
          userID: user.userID,
          username: user.username,
          parentCommentID: parentCommentID,
          quotedText: uiState.pendingQuote?.text,
          quotedTextSelector: uiState.pendingQuote?.selector,
          quotedTextOffset: uiState.pendingQuote?.offset,
          pageTitle: pageTitle,
          domain: domain,
          faviconURL: faviconURL,
          thumbnailURL: thumbnailURL
        )
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
          self.contentState.comments.insert(comment, at: 0)
          self.contentState.userComments.insert(comment, at: 0)
        }
        self.loadingState.isLoadingComments = false
        self.uiState.pendingQuote = nil
      } catch {
        self.loadingState.error = .commentPostFailed
        self.loadingState.showErrorAlert = true
      }
    }
  }

  func removeComment(_ comment: Comment) {
    guard let user = authViewModel.signedInUser, comment.userID == user.userID else { return }
    contentState.comments.removeAll { $0.commentID == comment.commentID }
    contentState.userComments.removeAll { $0.commentID == comment.commentID }
    Task {
      try? await CommentAPIService.shared.deleteComment(
        urlString: comment.urlString,
        commentID: comment.commentID
      )
    }
  }

  func refreshCommentCounts() {
    contentState.commentCountLookup = contentState.webPages.reduce(into: [:]) { result, webPage in
      result[webPage.urlString] = webPage.commentCount
    }
  }

  // MARK: - Saved Pages

  func fetchSavedWebPages(for user: User, completion: (() -> Void)? = nil) {
    Task {
      await fetchSavedWebPagesAsync(for: user)
      completion?()
    }
  }

  private func fetchSavedWebPagesAsync(for user: User) async {
    do {
      let pages = try await SavedWebPagesAPIService.shared.fetchSavedPages(for: user.userID)
      self.contentState.savedWebPages = pages.map { WebPage(savedPage: $0) }
      self.uiState.savedWebPageStates = Set(pages.map { $0.urlString })
      // Populate save dates from ISO 8601 strings
      for page in pages {
        if let date = ISO8601DateFormatter().date(from: page.dateSaved) {
          self.contentState.webPageSaveDates[page.urlString] = date
        }
      }
    } catch {
      print("Error fetching saved pages: \(error)")
    }
  }

  func toggleSave(on webPage: WebPage, completion: (() -> Void)? = nil) {
    guard let user = authViewModel.signedInUser else { completion?(); return }
    let wasSaved = hasSaved(webPage)

    if wasSaved {
      uiState.savedWebPageStates.remove(webPage.urlString)
      contentState.savedWebPages.removeAll { $0.urlString == webPage.urlString }
      contentState.webPageSaveDates.removeValue(forKey: webPage.urlString)
      Task { try? await SavedWebPagesAPIService.shared.unsavePage(userID: user.userID, urlString: webPage.urlString) }
    } else {
      uiState.savedWebPageStates.insert(webPage.urlString)
      Task {
        do {
          let saved = try await SavedWebPagesAPIService.shared.savePage(
            userID: user.userID,
            urlString: webPage.urlString,
            title: webPage.title,
            domain: webPage.domain
          )
          if !self.contentState.savedWebPages.contains(where: { $0.urlString == saved.urlString }) {
            let newWebPage = WebPage(savedPage: saved)
            self.contentState.savedWebPages.append(newWebPage)
            if let date = ISO8601DateFormatter().date(from: saved.dateSaved) {
              self.contentState.webPageSaveDates[saved.urlString] = date
            }
          }
        } catch {
          self.uiState.savedWebPageStates.remove(webPage.urlString)
        }
      }
    }
    completion?()
  }

  func hasSaved(_ webPage: WebPage) -> Bool {
    uiState.savedWebPageStates.contains(webPage.urlString)
  }

  // MARK: - Create/Save helpers (called from ContentView save flow)

  func createWebPageForSave(for urlString: String, title providedTitle: String? = nil, completion: @escaping (WebPage?) -> Void) {
    let title = providedTitle ?? urlString
    let domain = URL(string: urlString)?.host ?? urlString
    let webPage = WebPage(urlString: urlString, title: title, domain: domain)
    completion(webPage)
  }

  func performDirectSave(on webPage: WebPage) {
    guard let user = authViewModel.signedInUser else { return }
    uiState.savedWebPageStates.insert(webPage.urlString)
    Task {
      do {
        let saved = try await SavedWebPagesAPIService.shared.savePage(
          userID: user.userID,
          urlString: webPage.urlString,
          title: webPage.title,
          domain: webPage.domain
        )
        if !self.contentState.savedWebPages.contains(where: { $0.urlString == saved.urlString }) {
          self.contentState.savedWebPages.append(WebPage(savedPage: saved))
          if let date = ISO8601DateFormatter().date(from: saved.dateSaved) {
            self.contentState.webPageSaveDates[saved.urlString] = date
          }
        }
      } catch {
        self.uiState.savedWebPageStates.remove(webPage.urlString)
      }
    }
  }

  // MARK: - Like stubs (1.4)

  func toggleLike(on webPage: WebPage, isCurrentlyLiked: Bool, completion: (() -> Void)? = nil) {
    if isCurrentlyLiked {
      uiState.likedWebPages.remove(webPage.urlString)
    } else {
      uiState.likedWebPages.insert(webPage.urlString)
    }
    completion?()
  }

  func toggleLike(on comment: Comment, isCurrentlyLiked: Bool, completion: (() -> Void)? = nil) {
    if isCurrentlyLiked {
      uiState.likedComments.remove(comment.commentID)
    } else {
      uiState.likedComments.insert(comment.commentID)
    }
    completion?()
  }

  func toggleSave(on comment: Comment, completion: (() -> Void)? = nil) {
    if uiState.savedCommentStates.contains(comment.commentID) {
      uiState.savedCommentStates.remove(comment.commentID)
    } else {
      uiState.savedCommentStates.insert(comment.commentID)
    }
    completion?()
  }

  func hasLiked(_ webPage: WebPage) -> Bool {
    uiState.likedWebPages.contains(webPage.urlString)
  }

  func hasLiked(_ comment: Comment) -> Bool {
    uiState.likedComments.contains(comment.commentID)
  }

  func hasSaved(_ comment: Comment) -> Bool {
    uiState.savedCommentStates.contains(comment.commentID)
  }

  func getLikeCount(for webPage: WebPage) -> Int {
    uiState.webPageLikeCounts[webPage.urlString] ?? 0
  }

  func getLikeCount(for comment: Comment) -> Int {
    uiState.commentLikeCounts[comment.commentID] ?? 0
  }

  func getSaveCount(for webPage: WebPage) -> Int {
    uiState.webPageSaveCounts[webPage.urlString] ?? 0
  }

  func getSaveCount(for comment: Comment) -> Int {
    uiState.commentSaveCounts[comment.commentID] ?? 0
  }

  func getReplyCount(for comment: Comment) -> Int {
    contentState.comments.filter { $0.parentCommentID == comment.commentID }.count
  }

  func checkLikeStatus(for comment: Comment, completion: @escaping (Bool) -> Void) {
    completion(uiState.likedComments.contains(comment.commentID))
  }

  // MARK: - Stub methods (deferred to 1.4)

  func fetchSavedComments(for user: User, completion: (() -> Void)? = nil) {
    contentState.savedComments = []
    completion?()
  }

  func fetchUserComments(for user: User, completion: (() -> Void)? = nil) {
    Task {
      do {
        let comments = try await CommentAPIService.shared.fetchComments(byUserID: user.userID)
        self.contentState.userComments = comments.sorted { $0.dateCreated > $1.dateCreated }
      } catch {
        print("fetchUserComments error: \(error)")
        self.contentState.userComments = []
      }
      completion?()
    }
  }

  func fetchFollowedUsersComments(for user: User, completion: @escaping ([Comment]) -> Void) {
    contentState.followedUserComments = []
    completion([])
  }

  func fetchViewedUserComments(userID: String, completion: (() -> Void)? = nil) {
    Task {
      do {
        let comments = try await CommentAPIService.shared.fetchComments(byUserID: userID)
        self.contentState.viewedUserComments = comments.sorted { $0.dateCreated > $1.dateCreated }
      } catch {
        print("fetchViewedUserComments error: \(error)")
        self.contentState.viewedUserComments = []
      }
      completion?()
    }
  }

  func fetchAllWebPages() {
    // Deferred to 1.4 — no trending endpoint yet
    loadingState.isLoadingWebPage = false
  }

  func loadAndCacheImages(for webPage: WebPage) {
    // No CloudKit image storage — images are loaded inline by views via URL
  }

  func getCachedImages(for webPage: WebPage) -> (favicon: Data?, thumbnail: Data?) {
    contentState.imageCache[webPage.urlString] ?? (nil, nil)
  }

  // MARK: - Title extraction (kept for views)

  func extractQuickTitle(from urlString: String) -> String {
    URL(string: urlString)?.host ?? urlString
  }

  /// Stub — no longer fetches from CloudKit. Returns nil via completion.
  func fetchExistingWebPage(for urlString: String, completion: @escaping (WebPage?) -> Void) {
    let existing = contentState.savedWebPages.first(where: { $0.urlString == urlString })
    completion(existing)
  }
}
