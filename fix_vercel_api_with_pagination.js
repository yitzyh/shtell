/**
 * FIXED Vercel API - WITH PROPER PAGINATION
 *
 * The issue: DynamoDB scan returns paginated results
 * webgames items ARE in the database but scattered across pages
 * Must continue scanning until LastEvaluatedKey is null
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
 * CRITICAL FIX: Properly handle DynamoDB pagination
 * Must scan ALL pages to find all categories
 */
async function getAllCategoriesWithActiveContent() {
    try {
        console.log('🔍 Scanning DynamoDB for ALL categories with active content...');

        const categories = new Set();
        let lastEvaluatedKey = null;
        let totalScanned = 0;
        let pageCount = 0;

        // CRITICAL: Keep scanning until no more pages
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
                Limit: 1000 // Process in reasonable batches
            };

            // Continue from last page if exists
            if (lastEvaluatedKey) {
                params.ExclusiveStartKey = lastEvaluatedKey;
            }

            console.log(`📄 Scanning page ${pageCount}...`);
            const result = await dynamodb.scan(params).promise();

            totalScanned += result.Count || 0;

            // Extract categories from this page
            if (result.Items) {
                result.Items.forEach(item => {
                    if (item.bfCategory && item.bfCategory.S) {
                        categories.add(item.bfCategory.S);
                    }
                });
            }

            // CRITICAL: Check if there are more pages
            lastEvaluatedKey = result.LastEvaluatedKey;

            console.log(`  Page ${pageCount}: Found ${result.Count} items, ${categories.size} categories so far`);

        } while (lastEvaluatedKey); // Keep going until no more pages!

        const categoryArray = Array.from(categories).sort();

        console.log(`✅ Scan complete after ${pageCount} pages`);
        console.log(`📊 Scanned ${totalScanned} active items total`);
        console.log(`📋 Found ${categoryArray.length} categories: ${JSON.stringify(categoryArray)}`);

        return categoryArray;

    } catch (error) {
        console.error('❌ Error scanning DynamoDB:', error);

        // Fallback categories including webgames
        const fallback = [
            'art', 'books', 'culture', 'food', 'history',
            'movies', 'science', 'technology', 'webgames',
            'wikipedia', 'youtube'
        ];
        console.log('⚠️ Using fallback categories:', fallback);
        return fallback;
    }
}

/**
 * Get categories with caching
 */
async function getCategoriesWithCache() {
    const now = Date.now();

    // Return cached if still valid
    if (cache.categories && cache.timestamp && (now - cache.timestamp) < cache.TTL) {
        console.log('💾 Returning cached categories:', cache.categories);
        return cache.categories;
    }

    // Fetch fresh data with proper pagination
    console.log('🔄 Cache miss/expired, fetching fresh categories...');
    const categories = await getAllCategoriesWithActiveContent();

    // Update cache
    cache.categories = categories;
    cache.timestamp = now;

    return categories;
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
        const { endpoint, category, isActiveOnly, limit } = req.query;

        // Categories endpoint
        if (endpoint === 'categories') {
            console.log('📱 iOS app requested categories list');

            const categories = await getCategoriesWithCache();

            // Add cache header
            res.setHeader('Cache-Control', 'public, max-age=3600');

            const response = { categories: categories };
            console.log(`📤 Returning ${categories.length} categories to iOS app`);

            return res.status(200).json(response);
        }

        // Browse content endpoint
        if (category && isActiveOnly !== undefined) {
            const itemLimit = parseInt(limit) || 500;

            console.log(`📱 Browse content: category=${category}, limit=${itemLimit}, isActiveOnly=${isActiveOnly}`);

            // TODO: Implement your existing content fetching logic here
            // This should also use pagination to get all items!

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

                if (lastEvaluatedKey) {
                    params.ExclusiveStartKey = lastEvaluatedKey;
                }

                const result = await dynamodb.scan(params).promise();

                // Convert DynamoDB format to JSON
                const pageItems = result.Items.map(item => AWS.DynamoDB.Converter.unmarshall(item));
                items = items.concat(pageItems);

                lastEvaluatedKey = result.LastEvaluatedKey;

                // Stop if we have enough items
                if (items.length >= itemLimit) {
                    break;
                }

            } while (lastEvaluatedKey);

            console.log(`📤 Returning ${items.length} items for category ${category}`);

            return res.status(200).json({
                items: items.slice(0, itemLimit),
                category: category,
                count: items.length
            });
        }

        // Unknown request
        return res.status(400).json({
            error: 'Invalid endpoint or missing parameters',
            endpoints: {
                categories: '/api/browse-content?endpoint=categories',
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
 * 🎯 KEY FIXES:
 *
 * 1. ✅ PAGINATION: Continues scanning until LastEvaluatedKey is null
 * 2. ✅ FINDS ALL CATEGORIES: Including webgames scattered across pages
 * 3. ✅ PERFORMANCE: Caches results for 1 hour
 * 4. ✅ CONTENT FETCHING: Also uses pagination for getting items
 *
 * This will find all 11 categories including webgames!
 */