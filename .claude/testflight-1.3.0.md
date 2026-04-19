# TestFlight 1.3.0: CloudKit → AWS DynamoDB

**Status:** In progress
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
- [x] Verify Vercel AWS credentials can access new tables
- [x] Deploy + curl-test all new Vercel routes

---

## Phase 1: New Models — no CloudKit dependency
- [ ] `DumFlow/Models/User.swift` — Codable, replaces CK_User.swift
- [ ] `DumFlow/Features/Comments/Models/Comment.swift` — Codable, replaces CK_Comment.swift, no likes/saves
- [ ] `DumFlow/Features/WebPages/Models/SavedPage.swift` — new Codable struct
- [ ] `DumFlow/Features/Browser/Models/BrowserHistoryEntry.swift` — new, local-only

## Phase 2: Vercel API Routes
- [x] `vercel-backend/api/_helpers/dynamo.js` — shared DynamoDB client
- [x] `vercel-backend/api/users.js` — POST create, GET by appleUserID/userID/username
- [x] `vercel-backend/api/comments.js` — GET by urlString, POST
- [x] `vercel-backend/api/saved-webpages.js` — GET, POST, DELETE

## Phase 3: iOS API Client + Services
- [ ] `DumFlow/Services/ShtellAPIClient.swift` — async URLSession singleton
- [ ] `DumFlow/Services/UserAPIService.swift`
- [ ] `DumFlow/Services/CommentAPIService.swift`
- [ ] `DumFlow/Services/SavedPagesAPIService.swift`
- [ ] `DumFlow/Services/LocalHistoryService.swift` — UserDefaults/JSON, no network

## Phase 4: Rewrite AuthViewModel
- [ ] `DumFlow/Features/Authentication/ViewModels/AuthViewModel.swift`
  - Remove all `import CloudKit`
  - SIWA → lookupByAppleID → create if not found → username prompt
  - Session via `@AppStorage` userID (not cloudKitRecordName)

## Phase 5: Rewrite WebPageViewModel
- [ ] `DumFlow/Features/WebPages/ViewModels/WebPageViewModel.swift`
- [ ] `DumFlow/Features/WebPages/ViewModels/WebPageViewModel+Comments.swift`
  - Remove CloudKit queries, like/save state, CloudKit service deps
  - Inject CommentAPIService, SavedPagesAPIService

## Phase 6: Clean Up Comment Views
- [ ] Remove like/save buttons from `CommentView.swift`, `CommentRowView.swift`
- [ ] Delete `ExpandableCommentRowView.swift`
- [ ] Delete `CenterCommentRowView.swift`
- [ ] Delete `CommpressedParentCommentRowView.swift`
- [ ] Delete `InfiniteReplyView.swift`
- [ ] Delete `ParentCommentRowView.swift`

## Phase 7: Delete CloudKit Infrastructure
- [ ] Delete `DumFlow/CloudKit/` directory (CloudKitManager, CloudKitError, UserService)
- [ ] Delete `DumFlow/Features/Comments/Services/CommentService.swift`
- [ ] Delete `DumFlow/Services/WebPageService.swift`
- [ ] Delete `DumFlow/Features/Browser/Services/BrowserHistoryService.swift`
- [ ] Delete `DumFlow/Models/CK_User.swift`
- [ ] Delete `DumFlow/Features/Comments/Models/CK_Comment.swift`
- [ ] Delete `DumFlow/Features/WebPages/Models/CK_WebPage.swift`
- [ ] Delete `DumFlow/Features/Comments/Models/CommentLike.swift`
- [ ] Delete `DumFlow/Features/Comments/Models/CommentSave.swift`
- [ ] Delete `DumFlow/Features/WebPages/Models/WebPageLike.swift`
- [ ] Delete `DumFlow/Features/WebPages/Models/WebPageSave.swift`
- [ ] Delete `DumFlow/Features/Browser/Models/CK_BrowserHistory.swift`
- [ ] Delete `DumFlow/Models/UserFollow.swift`

## Phase 8: Remove `import CloudKit` from surviving files (~17)
- [ ] Run grep for `import CloudKit` — fix all remaining hits

## Phase 9: Entitlements
- [ ] Remove iCloud/CloudKit keys from `DumFlow.entitlements`
- [ ] Remove iCloud/CloudKit keys from `DumFlowRelease.entitlements`
- [ ] Keep App Groups + SIWA entitlements

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

---

## Done When

- `grep -r "import CloudKit" DumFlow/` returns nothing
- `grep -r "CKRecord\|CKContainer\|CKDatabase\|CKQuery" DumFlow/` returns nothing
- Entitlements have no iCloud/CloudKit keys
- All e2e scenarios pass: signup, login, session restore, comment, reply, quote, save, unsave, history
- App works with iCloud signed out on device
