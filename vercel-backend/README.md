# Shtell BrowseForward Backend API

Secure backend proxy for Shtell's BrowseForward feature, eliminating the need for AWS credentials in the iOS app.

## Quick Setup

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Deploy to Vercel:**
   ```bash
   cd vercel-backend
   npm install
   vercel
   ```

3. **Set Environment Variables in Vercel Dashboard:**
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
   - `AWS_REGION`: us-east-1

## API Endpoints

### Base URL
After deployment: `https://your-project.vercel.app`

### Get Browse Content
```
GET /api/browse-content?category=Science&limit=20&isActiveOnly=true
```

**Parameters:**
- `category` (optional): Filter by bfCategory (Science, Culture, News, etc.)
- `subcategory` (optional): Filter by bfSubcategory
- `isActiveOnly` (optional): true/false, default true
- `source` (optional): Filter by source
- `limit` (optional): Number of items to return, default 50
- `endpoint` (optional): browse-queue (default), categories, subcategories

**Response:**
```json
{
  "items": [
    {
      "url": "https://example.com/article",
      "title": "Article Title",
      "thumbnailUrl": "https://example.com/thumb.jpg",
      "domain": "example.com",
      "category": "Science",
      "bfCategory": "Science",
      "isActive": true,
      "wordCount": 1500
    }
  ],
  "count": 1,
  "scannedCount": 100
}
```

### Get Available Categories
```
GET /api/browse-content?endpoint=categories
```

**Response:**
```json
{
  "categories": ["Science", "Culture", "News", "Classics"]
}
```

### Get Subcategories
```
GET /api/browse-content?endpoint=subcategories&category=Science
```

**Response:**
```json
{
  "subcategories": ["Physics", "Biology", "Chemistry"]
}
```

## Security Features

- AWS credentials stored securely in Vercel environment variables
- CORS enabled for your iOS app
- No credentials exposed in client code
- Request timeout protection (10 seconds)

## iOS Integration

Replace DynamoDB calls with HTTP requests:

```swift
// Before (insecure):
let items = try await DynamoDBWebPageService.shared.fetchBFQueueItems(category: "Science")

// After (secure):
let url = URL(string: "https://your-app.vercel.app/api/browse-content?category=Science")!
let data = try await URLSession.shared.data(from: url).0
let response = try JSONDecoder().decode(BrowseContentResponse.self, from: data)
let items = response.items
```

## Deployment Commands

```bash
# Development
vercel dev

# Production deployment
vercel --prod

# Set environment variable
vercel env add AWS_ACCESS_KEY_ID
```

## Next Steps

1. Deploy this backend to Vercel
2. Update iOS app to use HTTP endpoints instead of direct AWS calls
3. Remove AWS credentials from Info.plist
4. Test the integration
5. Submit to TestFlight! 🚀