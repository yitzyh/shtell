import SwiftUI

struct ViewUserView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var webBrowser: WebBrowser
    @EnvironmentObject var webPageViewModel: WebPageViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    let userID: String

    init(userID: String) { self.userID = userID }

    @State private var user: User?
    @State private var isLoading = true
    @State private var commentsUrlString: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // User Header
                HStack {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.blue)
                        .padding(.trailing, 10)

                    VStack(alignment: .leading) {
                        Text(user?.displayName ?? "Loading...")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(user.map { "@\($0.username)" } ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // TODO: 1.4 — follow button
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(colorScheme == .dark ? .black : .white)

                Divider()

                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading...")
                        Spacer()
                    }
                } else if webPageViewModel.contentState.viewedUserComments.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "bubble")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No comments yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(webPageViewModel.contentState.viewedUserComments, id: \.commentID) { comment in
                        UserCommentRow(
                            comment: comment,
                            onBrowse: {
                                webBrowser.urlString = comment.urlString
                                webBrowser.isUserInitiatedNavigation = true
                                webBrowser.load(comment.urlString)
                                dismiss()
                            },
                            onComment: { commentsUrlString = comment.urlString }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(colorScheme == .dark ? .black : .white)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
        }
        .onAppear {
            Task {
                user = try? await UserAPIService.shared.lookupByUserID(userID)
                webPageViewModel.fetchViewedUserComments(userID: userID) {}
                isLoading = false
            }
        }
        .sheet(isPresented: .constant(commentsUrlString != nil), onDismiss: {
            commentsUrlString = nil
        }) {
            if let urlString = commentsUrlString {
                NavigationStack {
                    CommentView(urlString: urlString)
                        .environmentObject(webPageViewModel)
                        .environmentObject(authViewModel)
                        .presentationDetents([.fraction(0.75), .large])
                        .presentationDragIndicator(.visible)
                        .presentationContentInteraction(.scrolls)
                        .presentationCornerRadius(20)
                }
            }
        }
    }
}

struct UserCommentRow: View {
    let comment: Comment
    let onBrowse: () -> Void
    let onComment: () -> Void
    @EnvironmentObject var webPageViewModel: WebPageViewModel

    private let faviconSize: CGFloat = 36
    private let lineOffset: CGFloat = 18

    private var rawDomain: String {
        var d = URL(string: comment.urlString)?.host ?? comment.urlString
        if d.hasPrefix("www.") { d = String(d.dropFirst(4)) }
        return d
    }
    private var faviconURL: URL? {
        URL(string: "https://www.google.com/s2/favicons?domain=\(rawDomain)&sz=64")
    }
    private var commentCount: Int {
        let key = comment.urlString.normalizedURL ?? comment.urlString
        return webPageViewModel.contentState.commentCountLookup[key] ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── WEBPAGE CARD (tap → open browser) ────────────────────
            HStack(spacing: 10) {
                AsyncImage(url: faviconURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))
                        .overlay(Image(systemName: "globe").foregroundColor(.secondary).font(.caption))
                }
                .frame(width: faviconSize, height: faviconSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(rawDomain)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right").font(.caption2)
                        Text("\(commentCount)").font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { onBrowse() }

            // ── CONNECTING LINE ───────────────────────────────────────
            HStack(spacing: 0) {
                Spacer().frame(width: lineOffset - 0.75)
                Rectangle()
                    .frame(width: 1.5)
                    .foregroundColor(Color.secondary.opacity(0.25))
                Spacer()
            }
            .frame(height: 18)

            // ── COMMENT (tap → open comments sheet) ──────────────────
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: faviconSize))
                    .foregroundColor(.secondary.opacity(0.4))
                    .frame(width: faviconSize, height: faviconSize)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(comment.username)
                            .font(.subheadline.weight(.semibold))
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(comment.timeAgoShort)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(comment.text)
                        .font(.subheadline)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onComment() }
        }
        .padding(.vertical, 6)
        .buttonStyle(.plain)
    }
}
