# Vercel API Deployment Guide - Fix Categories Bug

## Problem Summary
Your Vercel API is hardcoded to return only 5 categories, missing "webgames" and 6 other categories that exist in your database.

**Current API Response:**
```json
{
  "categories": ["books", "food", "movies", "technology", "wikipedia"]
}
```

**Expected API Response (After Fix):**
```json
{
  "categories": [
    "art", "books", "culture", "food", "history",
    "movies", "science", "technology", "webgames",
    "wikipedia", "youtube"
  ]
}
```

## Deployment Steps

### 1. Update Your Vercel Project Files

Replace your existing `api/browse-content.js` (or similar) with the fixed code from `vercel_api_fixed_categories.js`.

### 2. Update package.json

Add the AWS SDK dependency:
```json
{
  "dependencies": {
    "aws-sdk": "^2.1000.0"
  }
}
```

### 3. Set Environment Variables in Vercel

Go to your Vercel dashboard → Project → Settings → Environment Variables:

- `AWS_ACCESS_KEY_ID`: `AKIAUON2G4CIEFYOZEJX`
- `AWS_SECRET_ACCESS_KEY`: `SVMqfKzPRgtLbL9JijZqQegrpWRkvLsR2caXYcy9`

### 4. Deploy to Vercel

```bash
# If using Vercel CLI
vercel --prod

# Or push to your connected Git repository
git add .
git commit -m "Fix categories endpoint to dynamically discover all categories"
git push origin main
```

## Testing the Fix

### 1. Test Categories Endpoint
```bash
curl "https://vercel-backend-k6iizy48w-yitzyhs-projects.vercel.app/api/browse-content?endpoint=categories"
```

Expected response should include "webgames" and all 11 categories.

### 2. Test iOS App
- Open your iOS app
- Use the pull-forward gesture in BrowseForward
- You should now see "webgames" appear as an available category
- Each category should load 500 items instead of 10

## What This Fix Does

1. **Dynamic Discovery**: Scans DynamoDB for all `bfCategory` values where `status = 'active'`
2. **Performance**: Adds 1-hour caching to reduce database load
3. **Reliability**: Includes fallback categories if database is unavailable
4. **Logging**: Comprehensive console logs for debugging

## Expected Database Results

Based on your database analysis, this should return:
- **webgames**: 23 active items ✅
- **Total categories**: 11 categories with active content
- **Performance**: Cached for 1 hour, refreshed automatically

## Troubleshooting

If webgames still doesn't appear:

1. Check Vercel function logs for errors
2. Verify AWS credentials are set correctly
3. Confirm DynamoDB has active webgames with `bfCategory = 'webgames'`
4. Test the API directly with curl before testing iOS app

## Next Steps

After deployment:
1. Test the categories API endpoint
2. Test the iOS app pull-forward feature
3. Verify webgames category appears and loads content
4. Monitor performance and adjust cache TTL if needed