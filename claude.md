# Claude Context for Shtell

## Current Status

**Version on TestFlight:** 1.3.0 (build 6)
**Active sprint:** 1.4.0 — Likes, follows, user profiles

See `.claude/CLAUDE.md` for full technical documentation.
See `.claude/testflight-1.3.0.md` for completed 1.3.0 sprint tracking.

---

## What Shipped in 1.3.0

- **Zero CloudKit** — fully removed, no iCloud dependency
- **AWS DynamoDB** backend: `users`, `comments`, `saved-webpages`, `webpages-meta`
- **Vercel API routes**: `/api/users`, `/api/comments`, `/api/saved-webpages`, `/api/pages`
- **TrendPageView** — social post-style feed of pages with comments (favicon as profile pic, title, thumbnail)
- **ViewUserView** — user comment history with split tap (card → browse, comment → sheet)
- **Local browser history** — on-device only, no network
- **webpages-meta backfill** — `vercel-backend/scripts/backfill-pages.mjs`
- **URL bar fix** — `PreloadedWebViewManager.initializeWebViews()` now guards against re-init on sheet dismiss

## DynamoDB Tables (4 active)

| Table | PK | SK | Notes |
|-------|----|----|-------|
| `users` | userID | — | GSIs: appleUserID-index, username-index |
| `comments` | urlString | commentID | GSI: userID-index |
| `saved-webpages` | userID | urlString | User bookmarks only |
| `webpages-meta` | urlString | — | Auto-upserted on comment POST; powers TrendPageView |

## Vercel API

Base URL: `https://vercel-backend-azure-three.vercel.app`

- `POST/GET /api/users`
- `GET/POST/DELETE /api/comments`
- `GET/POST/DELETE /api/saved-webpages`
- `GET /api/pages` — `?trending=true` or `?urlString=X`

## What's Next (1.4.0)

- Comment likes + webpage likes (new DynamoDB tables)
- User profiles (photo, bio)
- Follows, blocks, mutes
- JWT token verification in Vercel (security hardening)
- Xcode project rename: DumFlow → Shtell
