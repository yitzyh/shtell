/**
 * VERCEL API WITH SEARCH SUPPORT
 *
 * Fixed to include search functionality across:
 * - title
 * - description
 * - tags
 * - bfCategory
 */

import AWS from 'aws-sdk';

const dynamodb = new AWS.DynamoDB({
    region: 'us-east-1',
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'AKIAUON2G4CIEFYOZEJX',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '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'
});

const TABLE_NAME = 'webpages';

// Cache with 1-hour TTL
const cache = {
    categories: null,
    timestamp: null,
    TTL: 1000 * 60 * 60 // 1 hour
};

/**
 * Get all categories with active content (with pagination)
 */
async function getAllCategoriesWithActiveContent() {
    try {
        console.log('🔍 Scanning DynamoDB for ALL categories with active content...');

        const categories = new Set();
        let lastEvaluatedKey = null;
        let totalScanned = 0;
        let pageCount = 0;

        do {
            pageCount++;

            const params = {
                TableName: TABLE_NAME,
                FilterExpression: 'attribute_exists(bfCategory) AND #status = :status',
                ExpressionAttributeNames: {
                    '#status': 'status'
                },
                ExpressionAttributeValues: {
                    ':status': { S: 'active' }
                },
                ProjectionExpression: 'bfCategory',
                Limit: 1000
            };

            if (lastEvaluatedKey) {
                params.ExclusiveStartKey = lastEvaluatedKey;
            }

            console.log(`📄 Scanning page ${pageCount}...`);
            const result = await dynamodb.scan(params).promise();

            totalScanned += result.Count || 0;

            if (result.Items) {
                result.Items.forEach(item => {
                    if (item.bfCategory && item.bfCategory.S) {
                        categories.add(item.bfCategory.S);
                    }
                });
            }

            lastEvaluatedKey = result.LastEvaluatedKey;
            console.log(`  Page ${pageCount}: Found ${result.Count} items, ${categories.size} categories so far`);

        } while (lastEvaluatedKey);

        const categoryArray = Array.from(categories).sort();
        console.log(`✅ Scan complete: ${totalScanned} items, ${categoryArray.length} categories`);

        return categoryArray;

    } catch (error) {
        console.error('❌ Error scanning DynamoDB:', error);
        return ['art', 'books', 'culture', 'food', 'history', 'movies', 'science', 'technology', 'webgames', 'wikipedia', 'youtube'];
    }
}

/**
 * Get categories with caching
 */
async function getCategoriesWithCache() {
    const now = Date.now();

    if (cache.categories && cache.timestamp && (now - cache.timestamp) < cache.TTL) {
        console.log('💾 Returning cached categories');
        return cache.categories;
    }

    console.log('🔄 Fetching fresh categories...');
    const categories = await getAllCategoriesWithActiveContent();

    cache.categories = categories;
    cache.timestamp = now;

    return categories;
}

/**
 * NEW: Search content across multiple fields
 */
async function searchContent(searchQuery, limit = 20) {
    try {
        console.log(`🔍 Searching for: "${searchQuery}" (limit: ${limit})`);

        const searchLower = searchQuery.toLowerCase();
        const items = [];
        let lastEvaluatedKey = null;
        let scannedCount = 0;

        // Scan with pagination until we have enough results
        do {
            const params = {
                TableName: TABLE_NAME,
                FilterExpression: '#status = :status',
                ExpressionAttributeNames: {
                    '#status': 'status'
                },
                ExpressionAttributeValues: {
                    ':status': { S: 'active' }
                },
                Limit: 100 // Scan in batches
            };

            if (lastEvaluatedKey) {
                params.ExclusiveStartKey = lastEvaluatedKey;
            }

            const result = await dynamodb.scan(params).promise();
            scannedCount += result.Count || 0;

            // Filter results client-side (DynamoDB doesn't support case-insensitive contains)
            if (result.Items) {
                const filteredItems = result.Items
                    .map(item => AWS.DynamoDB.Converter.unmarshall(item))
                    .filter(item => {
                        // Search in title
                        if (item.title && item.title.toLowerCase().includes(searchLower)) {
                            return true;
                        }
                        // Search in description
                        if (item.description && item.description.toLowerCase().includes(searchLower)) {
                            return true;
                        }
                        // Search in tags
                        if (item.bfTags && Array.isArray(item.bfTags)) {
                            if (item.bfTags.some(tag => tag.toLowerCase().includes(searchLower))) {
                                return true;
                            }
                        }
                        // Search in category
                        if (item.bfCategory && item.bfCategory.toLowerCase().includes(searchLower)) {
                            return true;
                        }
                        return false;
                    });

                items.push(...filteredItems);
            }

            lastEvaluatedKey = result.LastEvaluatedKey;

            // Stop if we have enough results
            if (items.length >= limit) {
                break;
            }

            // Stop after scanning reasonable amount to avoid timeout
            if (scannedCount >= 1000) {
                break;
            }

        } while (lastEvaluatedKey);

        const results = items.slice(0, limit);
        console.log(`✅ Found ${results.length} results (scanned ${scannedCount} items)`);

        return results;

    } catch (error) {
        console.error('❌ Search error:', error);
        return [];
    }
}

/**
 * Get content by category (existing functionality)
 */
async function getContentByCategory(category, subcategory, itemLimit) {
    console.log(`📱 Browse content: category=${category}, subcategory=${subcategory || 'none'}, limit=${itemLimit}`);

    let items = [];
    let lastEvaluatedKey = null;

    do {
        const params = {
            TableName: TABLE_NAME,
            FilterExpression: 'bfCategory = :category AND #status = :status',
            ExpressionAttributeNames: {
                '#status': 'status'
            },
            ExpressionAttributeValues: {
                ':category': { S: category },
                ':status': { S: 'active' }
            },
            Limit: Math.min(itemLimit - items.length, 100)
        };

        // Add subcategory filter if provided
        if (subcategory) {
            params.FilterExpression += ' AND bfSubcategory = :subcategory';
            params.ExpressionAttributeValues[':subcategory'] = { S: subcategory };
        }

        if (lastEvaluatedKey) {
            params.ExclusiveStartKey = lastEvaluatedKey;
        }

        const result = await dynamodb.scan(params).promise();
        const pageItems = result.Items.map(item => AWS.DynamoDB.Converter.unmarshall(item));
        items = items.concat(pageItems);

        lastEvaluatedKey = result.LastEvaluatedKey;

        if (items.length >= itemLimit) {
            break;
        }

    } while (lastEvaluatedKey);

    console.log(`📤 Returning ${items.length} items for category ${category}`);

    return items.slice(0, itemLimit);
}

/**
 * Main handler for Vercel API
 */
export default async function handler(req, res) {
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    try {
        const { endpoint, category, subcategory, isActiveOnly, limit, search } = req.query;

        // Categories endpoint
        if (endpoint === 'categories') {
            console.log('📱 iOS app requested categories list');
            const categories = await getCategoriesWithCache();
            res.setHeader('Cache-Control', 'public, max-age=3600');
            return res.status(200).json({ categories });
        }

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

        // Browse content endpoint (category filter)
        if (category && isActiveOnly !== undefined) {
            const itemLimit = parseInt(limit) || 500;
            const items = await getContentByCategory(category, subcategory, itemLimit);

            return res.status(200).json({
                items: items,
                category: category,
                subcategory: subcategory || null,
                count: items.length
            });
        }

        // Unknown request
        return res.status(400).json({
            error: 'Invalid endpoint or missing parameters',
            endpoints: {
                categories: '/api/browse-content?endpoint=categories',
                search: '/api/browse-content?search=your-query&limit=20',
                content: '/api/browse-content?category=webgames&isActiveOnly=true&limit=500'
            }
        });

    } catch (error) {
        console.error('❌ API Error:', error);
        return res.status(500).json({
            error: 'Internal server error',
            message: error.message
        });
    }
}

/**
 * 🎯 KEY FEATURES:
 *
 * 1. ✅ SEARCH: Searches across title, description, tags, and category
 * 2. ✅ CASE-INSENSITIVE: Converts to lowercase for matching
 * 3. ✅ PAGINATION: Handles DynamoDB pagination properly
 * 4. ✅ PERFORMANCE: Stops after 1000 scanned items to avoid timeout
 * 5. ✅ BACKWARD COMPATIBLE: Existing category filtering still works
 *
 * USAGE:
 * GET /api/browse-content?search=youtube&limit=20
 * GET /api/browse-content?search=science&limit=50
 */
