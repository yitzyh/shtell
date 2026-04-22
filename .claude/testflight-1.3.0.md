# TestFlight 1.3.0: CloudKit → AWS DynamoDB

**Status:** ✅ Complete — shipped to TestFlight as 1.3.0
**TestFlight baseline:** 1.2.0 (build 5)
**Goal:** Zero CloudKit dependency. DynamoDB via Vercel proxy for users, comments, saved pages. History goes local-only.
**Two beta users, no data worth preserving — fresh start on all tables.**

---

## Tab Assignments

| Tab | Owns | Scope |
|-----|------|-------|
| **Tab 1** | Tracking | This file. Updates checkboxes, coordinates between tabs. |
| **Tab 2** | AWS + Vercel | Pre-flight: create DynamoDB tables, install uuid, deploy Vercel routes, curl-test all endpoints. |
| **Tab 3** | iOS Phases 1–3 | New Codable models, ShtellAPIClient, all 5 service files. |
| **Tab 4** | iOS Phases 4–5 | Rewrite AuthViewModel + WebPageViewModel. |
| **Tab 5** | iOS Phases 6–9 | Delete CloudKit files, clean comment views, strip entitlements. |

**Each tab should read this file on open, tick checkboxes as work completes, and stop at its scope boundary.**

---

## Pre-Flight (do before any iOS code)

- [x] Create `users` table in AWS (us-east-1) — PK: userID, GSIs: appleUserID-index, username-index
- [x] Create `comments` table — PK: urlString, SK: commentID, GSI: userID-index
- [x] Create `saved-webpages` table — PK: userID, SK: urlString
- [x] Create `webpages-meta` table — PK: urlString (added post-sprint, see below)
- [x] Verify Vercel AWS credentials can access new tables
- [x] Deploy + curl-test all new Vercel routes

---

## Phase 1: New Models — no CloudKit dependency
- [x] `DumFlow/Models/User.swift` — Codable, replaces CK_User.swift; fields: userID, appleUserID, username, displayName, dateCreated
- [x] `DumFlow/Features/Comments/Models/Comment.swift` — Codable, replaces CK_Comment.swift; likeCount/saveCount stubbed for 1.4
- [x] `DumFlow/Features/WebPages/Models/SavedWebPage.swift` — Codable; userID, urlString, title, domain, dateSaved, optional thumbnailURL/faviconURL
- [x] `DumFlow/Features/Browser/Models/BrowserHistoryEntry.swift` — local-only, make() factory

## Phase 2: Vercel API Routes
- [x] `vercel-backend/api/_helpers/dynamo.js` — shared DynamoDB client; TABLES includes PAGES: 'webpages-meta'
- [x] `vercel-backend/api/users.js` — POST create, GET by appleUserID/userID/username
- [x] `vercel-backend/api/comments.js` — GET by urlString, POST; POST also upserts webpages-meta (atomic ADD commentCount, SET lastCommentAt/title/domain/faviconURL/thumbnailURL)
- [x] `vercel-backend/api/saved-webpages.js` — GET, POST, DELETE
- [x] `vercel-backend/api/pages.js` — GET ?trending=true (scan, sort by commentCount desc, top 20), GET ?urlString=X (single lookup)

## Phase 3: iOS API Client + Services
- [x] `DumFlow/Services/ShtellAPIClient.swift` — async URLSession singleton, get/post/delete helpers, ShtellAPIError enum, base URL https://vercel-backend-azure-three.vercel.app
- [x] `DumFlow/Services/UserAPIService.swift` — lookupByAppleUserID, lookupByUserID, isUsernameAvailable, createUser
- [x] `DumFlow/Services/CommentAPIService.swift` — fetchComments, postComment (accepts optional pageTitle/domain/faviconURL/thumbnailURL), deleteComment
- [x] `DumFlow/Services/SavedWebPagesAPIService.swift` — fetchSavedPages, isSaved, savePage, unsavePage
- [x] `DumFlow/Services/LocalHistoryService.swift` — UserDefaults, move-to-front dedup, 500 entry cap, no network

## Phase 3b: webpages-meta iOS Layer (added post-sprint)
- [x] `DumFlow/Features/WebPages/Models/PageMetadata.swift` — Codable: urlString, title, domain, faviconURL?, thumbnailURL?, commentCount, lastCommentAt
- [x] `DumFlow/Services/PagesAPIService.swift` — fetchTrending() → GET /api/pages?trending=true, fetchPageMetadata(for:) → GET /api/pages?urlString=X

## Phase 4: Rewrite AuthViewModel
- [x] `DumFlow/Features/Authentication/ViewModels/AuthViewModel.swift`
  - Remove all `import CloudKit`
  - SIWA → lookupByAppleID → create if not found → username prompt
  - Session via `@AppStorage` userID (not cloudKitRecordName)

## Phase 5: Rewrite WebPageViewModel
- [x] `DumFlow/Features/WebPages/ViewModels/WebPageViewModel.swift`
- [x] `DumFlow/Features/WebPages/ViewModels/WebPageViewModel+Comments.swift`
  - Remove CloudKit queries, like/save state, CloudKit service deps
  - Inject CommentAPIService, SavedWebPagesAPIService
  - BrowserHistoryManager wraps LocalHistoryService
  - addComment() extracts og:image via JS + Google favicon URL, passes to postComment()
  - fetchComments() updates commentCountLookup[urlString], then fetches authoritative count from PageMetadata in background
  - urlString setter pre-fetches PageMetadata on navigation to populate toolbar count before comments load
  - View fixes: HistoryView/HistoryRowView, SavedItemsView, SavedWebPagesView, CommentRowView, CommentView, CommentThreadView, WebPageCardView previews

## Phase 5b: TrendPageView rewrite (added post-sprint)
- [x] `DumFlow/Views/TrendPageView.swift` — rewritten to use @State var trendingPages: [PageMetadata], calls PagesAPIService.shared.fetchTrending() on appear, renders favicon (AsyncImage) + title + domain + comment count per row, tapping navigates to URL and dismisses

## Phase 6: Clean Up Comment Views
- [x] Remove like/save buttons from `CommentView.swift`, `CommentRowView.swift`
- [x] Delete `ExpandableCommentRowView.swift`
- [x] Delete `CenterCommentRowView.swift`
- [x] Delete `CommpressedParentCommentRowView.swift`
- [x] Delete `InfiniteReplyView.swift`
- [x] Delete `ParentCommentRowView.swift`

## Phase 7: Delete CloudKit Infrastructure
- [x] Delete `DumFlow/CloudKit/` directory (CloudKitManager, CloudKitError, UserService)
- [x] Delete `DumFlow/Features/Comments/Services/CommentService.swift`
- [x] Delete `DumFlow/Services/WebPageService.swift`
- [x] Delete `DumFlow/Features/Browser/Services/BrowserHistoryService.swift`
- [x] Delete `DumFlow/Models/CK_User.swift`
- [x] Delete `DumFlow/Features/Comments/Models/CK_Comment.swift`
- [x] Delete `DumFlow/Features/WebPages/Models/CK_WebPage.swift`
- [x] Delete `DumFlow/Features/Comments/Models/CommentLike.swift`
- [x] Delete `DumFlow/Features/Comments/Models/CommentSave.swift`
- [x] Delete `DumFlow/Features/WebPages/Models/WebPageLike.swift`
- [x] Delete `DumFlow/Features/WebPages/Models/WebPageSave.swift`
- [x] Delete `DumFlow/Features/Browser/Models/CK_BrowserHistory.swift`
- [x] Delete `DumFlow/Models/UserFollow.swift`

## Phase 8: Remove `import CloudKit` from surviving files (~17)
- [x] Run grep for `import CloudKit` — fix all remaining hits

## Phase 9: Entitlements
- [x] Remove iCloud/CloudKit keys from `DumFlow.entitlements`
- [x] Remove iCloud/CloudKit keys from `DumFlowRelease.entitlements`
- [x] Keep App Groups + SIWA entitlements

---

## ⚠️ Before Public Launch (not required for TestFlight)

- [ ] Server-side Apple identity token verification — Vercel must verify the signed JWT Apple issues at sign-in before creating/looking up users. Currently the server trusts the client-supplied `appleUserID` with no validation. Fine for 2 beta users; must be fixed before strangers can create accounts. (Planned: Cognito in 1.4, or manual verification in Vercel)

---

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| No Cognito for 1.3 | Trust client-side SIWA appleUserID; lock down with JWT in 1.4 |
| No data migration | Two beta users, fresh start is cleaner |
| History local-only | No value in syncing; avoids extra table |
| No likes in 1.3 | Simplifies model; deferred to 1.4 |
| Xcode rename deferred | Source folder rename (DumFlow/ → Shtell/) is cosmetic; 1.4 |
| saved-webpages is user-only | Never written to by algorithm — exclusively user saved items |
| webpages-meta via comments POST | Page metadata auto-registered when first comment is posted; no separate create step needed |
| No GSI on webpages-meta | Trending uses a full Scan (fine at current scale); add GSI at scale |

---

## Done When

- `grep -r "import CloudKit" DumFlow/` returns nothing
- `grep -r "CKRecord\|CKContainer\|CKDatabase\|CKQuery" DumFlow/` returns nothing
- Entitlements have no iCloud/CloudKit keys
- All e2e scenarios pass: signup, login, session restore, comment, reply, quote, save, unsave, history
- App works with iCloud signed out on device
