import SwiftUI

struct TrendPageView: View {

  @Environment(\.colorScheme) var colorScheme
  @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
  @Environment(\.dismiss) var dismiss

  @EnvironmentObject private var webBrowser: WebBrowser
  @EnvironmentObject var webPageViewModel: WebPageViewModel
  @EnvironmentObject var authViewModel: AuthViewModel

  @State var commentsUrlString: String?
  @State private var trendingPages: [PageMetadata] = []
  @State private var isLoading = false
  @State private var searchText = ""

  private var filteredPages: [PageMetadata] {
    guard !searchText.isEmpty else { return trendingPages }
    return trendingPages.filter { page in
      let titleMatch = page.title?.localizedCaseInsensitiveContains(searchText) == true
      let domainMatch = page.domain?.localizedCaseInsensitiveContains(searchText) == true
      let urlMatch = page.urlString.localizedCaseInsensitiveContains(searchText)
      return titleMatch || domainMatch || urlMatch
    }
  }

  var body: some View {
    NavigationStack {
      VStack {
        if isLoading {
          VStack {
            ProgressView("Loading trending pages...")
              .padding()
            Spacer()
          }
        } else if trendingPages.isEmpty {
          VStack {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("No trending pages yet")
              .font(.headline)
              .foregroundColor(.secondary)
              .padding(.top, 8)
            Text("Pages appear here after comments are posted")
              .font(.caption)
              .foregroundColor(.secondary)
            Spacer()
          }
        } else {
          List(filteredPages) { page in
            PageMetadataRowView(
              page: page,
              commentsUrlString: $commentsUrlString,
              onBrowse: {
                webBrowser.urlString = page.urlString
                webBrowser.isUserInitiatedNavigation = true
                webBrowser.load(page.urlString)
                dismiss()
              }
            )
          }
          .listStyle(.plain)
          .searchable(text: $searchText, prompt: "Search pages")
          .refreshable {
            await loadTrending()
          }
        }
      }
    }
    .onAppear {
      Task { await loadTrending() }
    }
    .navigationBarBackButtonHidden(true)
    .toolbarBackground(colorScheme == .dark ? Color(white: 0.07) : .white, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.primary)
        }
      }
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          Task { await loadTrending() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .disabled(isLoading)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetToRoot"))) { _ in
      presentationMode.wrappedValue.dismiss()
    }
    .sheet(isPresented: .constant(commentsUrlString != nil), onDismiss: {
      webPageViewModel.contentState.webPage = nil
      webPageViewModel.contentState.comments = []
      commentsUrlString = nil
    }) {
      if let urlString = commentsUrlString {
        NavigationStack {
          CommentView(urlString: urlString)
            .environmentObject(webPageViewModel)
            .environmentObject(webBrowser)
            .environmentObject(authViewModel)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75), .large])
            .presentationContentInteraction(.scrolls)
            .presentationCornerRadius(20)
        }
      }
    }
  }

  @MainActor
  private func loadTrending() async {
    isLoading = true
    do {
      let pages = try await PagesAPIService.shared.fetchTrending()
      trendingPages = pages
      for page in pages {
        let normalized = page.urlString.normalizedURL ?? page.urlString
        webPageViewModel.contentState.commentCountLookup[normalized] = page.commentCount
      }
    } catch {
      print("loadTrending error: \(error)")
    }
    isLoading = false
  }
}

// MARK: - Row View

private struct PageMetadataRowView: View {
  let page: PageMetadata
  @Binding var commentsUrlString: String?
  let onBrowse: () -> Void
  @Environment(\.colorScheme) var colorScheme

  private var displayDomain: String {
    var d = page.domain ?? (URL(string: page.urlString)?.host ?? page.urlString)
    if d.hasPrefix("www.") { d = String(d.dropFirst(4)) }
    return d
  }

  private var faviconURL: URL? {
    if let stored = page.faviconURL, !stored.isEmpty { return URL(string: stored) }
    return URL(string: "https://www.google.com/s2/favicons?domain=\(displayDomain)&sz=64")
  }

  private var thumbnailURL: URL? {
    guard let stored = page.thumbnailURL, !stored.isEmpty else { return nil }
    return URL(string: stored)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {

      // ── HEADER: favicon as profile + domain + time ───────────────
      HStack(spacing: 10) {
        AsyncImage(url: faviconURL) { image in
          image.resizable().scaledToFit()
        } placeholder: {
          Circle()
            .fill(Color.secondary.opacity(0.15))
            .overlay(Image(systemName: "globe").foregroundColor(.secondary).font(.caption))
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())

        VStack(alignment: .leading, spacing: 1) {
          Text(displayDomain)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .lineLimit(1)
          if let lastComment = page.lastCommentAt,
             let date = ISO8601DateFormatter().date(from: lastComment) {
            Text(date.timeAgoShort())
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }

        Spacer()
      }
      .contentShape(Rectangle())
      .onTapGesture { onBrowse() }
      .padding(.vertical, 10)

      // ── CONTENT: title + thumbnail (tap → browse) ────────────────
      VStack(alignment: .leading, spacing: 8) {
        if let title = page.title, !title.isEmpty {
          Text(title)
            .font(.subheadline.weight(.medium))
            .lineLimit(3)
            .foregroundColor(.primary)
        }

        if let thumbURL = thumbnailURL {
          AsyncImage(url: thumbURL) { image in
            image.resizable().scaledToFill()
          } placeholder: {
            RoundedRectangle(cornerRadius: 10)
              .fill(Color.secondary.opacity(0.08))
              .frame(height: 180)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 180)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
      }
      .contentShape(Rectangle())
      .onTapGesture { onBrowse() }

      // ── FOOTER: comment count (tap → sheet) ──────────────────────
      HStack(spacing: 4) {
        Image(systemName: "bubble.right").font(.caption)
        Text("\(page.commentCount) comment\(page.commentCount == 1 ? "" : "s")")
          .font(.caption)
      }
      .foregroundColor(.secondary)
      .padding(.top, 10)
      .padding(.bottom, 6)
      .contentShape(Rectangle())
      .onTapGesture { commentsUrlString = page.urlString }
    }
  }
}
