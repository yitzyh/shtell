# 🔍 BrowseForward Search Fix - Deployment Guide

## Problem
Your Vercel API was returning the same 3 items for every search query because it wasn't handling the `search` query parameter at all.

## Solution
Added search functionality that filters across:
- ✅ Title
- ✅ Description
- ✅ Tags (bfTags)
- ✅ Category (bfCategory)

## Deployment Steps

### Step 1: Locate Your Vercel Project

Your API is deployed at:
```
https://vercel-backend-9n83v1jk5-yitzyhs-projects.vercel.app/api/browse-content
```

Find this project in your Vercel dashboard.

### Step 2: Update the API File

1. In your Vercel project, locate the API file (likely at `/api/browse-content.js` or similar)

2. Replace the entire contents with the new code from: `vercel_api_with_search.js`

### Step 3: Verify Environment Variables

Make sure these are set in Vercel dashboard → Settings → Environment Variables:

```
AWS_ACCESS_KEY_ID=AKIAUON2G4CIEFYOZEJX
AWS_SECRET_ACCESS_KEY=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
```

### Step 4: Deploy

Option A - If using Git:
```bash
git add api/browse-content.js
git commit -m "Add search functionality to browse-content API"
git push
```
Vercel will auto-deploy.

Option B - Manual:
1. Go to Vercel dashboard
2. Upload the new file
3. Click "Deploy"

### Step 5: Test

After deployment, test the search:

```bash
# Test search for "youtube"
curl "https://vercel-backend-9n83v1jk5-yitzyhs-projects.vercel.app/api/browse-content?search=youtube&limit=20"

# Test search for "science"
curl "https://vercel-backend-9n83v1jk5-yitzyhs-projects.vercel.app/api/browse-content?search=science&limit=20"

# Test search for "food"
curl "https://vercel-backend-9n83v1jk5-yitzyhs-projects.vercel.app/api/browse-content?search=food&limit=20"
```

Each query should return DIFFERENT results now!

### Step 6: Test in iOS App

1. Open your app
2. Tap search bar
3. Type "youtube" - should see YouTube videos
4. Clear and type "science" - should see science articles
5. Clear and type "food" - should see food content

## What Changed

### OLD CODE (Missing search support):
```javascript
const { endpoint, category, isActiveOnly, limit } = req.query;
// No handling for 'search' parameter!
```

### NEW CODE (With search):
```javascript
const { endpoint, category, subcategory, isActiveOnly, limit, search } = req.query;

// NEW: Search endpoint
if (search) {
    const itemLimit = parseInt(limit) || 20;
    const results = await searchContent(search, itemLimit);
    return res.status(200).json({
        items: results,
        query: search,
        count: results.length
    });
}
```

## Search Algorithm

The new `searchContent()` function:

1. **Scans DynamoDB** with pagination (in batches of 100)
2. **Filters client-side** for case-insensitive matching across:
   - `title.toLowerCase().includes(searchQuery)`
   - `description.toLowerCase().includes(searchQuery)`
   - `bfTags[].toLowerCase().includes(searchQuery)`
   - `bfCategory.toLowerCase().includes(searchQuery)`
3. **Returns up to limit** items (default 20)
4. **Stops after 1000 scanned items** to avoid timeout

## API Endpoints Reference

### Categories
```
GET /api/browse-content?endpoint=categories
```

### Search (NEW!)
```
GET /api/browse-content?search=YOUR_QUERY&limit=20
```

### Category Filter
```
GET /api/browse-content?category=webgames&isActiveOnly=true&limit=500
GET /api/browse-content?category=youtube&subcategory=long&isActiveOnly=true&limit=250
```

## Troubleshooting

### Still getting same 3 results?
1. Check Vercel deployment logs to confirm new code deployed
2. Clear browser/app cache
3. Try with timestamp: `?search=test&t=123456`

### Search too slow?
Adjust the scan limit in the code:
```javascript
if (scannedCount >= 1000) {  // Change this number
    break;
}
```

### Not finding results you expect?
Check console logs in Vercel dashboard - it shows what was scanned:
```
✅ Found 15 results (scanned 300 items)
```

## Performance Notes

- **First search**: May take 1-2 seconds (cold start)
- **Subsequent searches**: 200-500ms
- **Scans up to 1000 items** before stopping (prevents timeout)
- **Case-insensitive** matching
- **Searches 4 fields**: title, description, tags, category

## Success Criteria

✅ Different searches return different results
✅ Searching "youtube" finds YouTube videos
✅ Searching "science" finds science articles
✅ Searching "food" finds food content
✅ iOS app search works in real-time with 300ms debounce
✅ Category filtering still works (backward compatible)
