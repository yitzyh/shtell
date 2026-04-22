/**
 * Backfill webpages-meta table from existing comments.
 * Groups comments by urlString, computes commentCount + lastCommentAt,
 * extracts domain, and upserts into webpages-meta.
 *
 * Usage: node scripts/backfill-pages.mjs
 * Reads AWS credentials from ~/.aws/credentials (default profile) or env vars.
 */

import AWS from 'aws-sdk';

const dynamodb = new AWS.DynamoDB({ region: 'us-east-1' });
const { unmarshall, marshall } = AWS.DynamoDB.Converter;

const COMMENTS_TABLE = 'comments';
const PAGES_TABLE = 'webpages-meta';

async function scanAll(tableName) {
  const items = [];
  let lastKey;
  do {
    const params = { TableName: tableName };
    if (lastKey) params.ExclusiveStartKey = lastKey;
    const result = await dynamodb.scan(params).promise();
    items.push(...(result.Items || []).map(unmarshall));
    lastKey = result.LastEvaluatedKey;
  } while (lastKey);
  return items;
}

function extractDomain(urlString) {
  try {
    let host = new URL(urlString).hostname;
    if (host.startsWith('www.')) host = host.slice(4);
    return host;
  } catch {
    return urlString;
  }
}

async function main() {
  console.log('Scanning comments table...');
  const comments = await scanAll(COMMENTS_TABLE);
  console.log(`Found ${comments.length} comments`);

  // Group by urlString
  const byURL = {};
  for (const c of comments) {
    const url = c.urlString;
    if (!url) continue;
    if (!byURL[url]) byURL[url] = [];
    byURL[url].push(c);
  }

  const urls = Object.keys(byURL);
  console.log(`Found ${urls.length} unique URLs — upserting into ${PAGES_TABLE}...`);

  let updated = 0;
  for (const urlString of urls) {
    const group = byURL[urlString];
    const commentCount = group.length;
    const lastCommentAt = group
      .map(c => c.dateCreated)
      .filter(Boolean)
      .sort()
      .at(-1);
    const domain = extractDomain(urlString);

    // Build upsert — domain is a reserved word, alias it
    try {
      await dynamodb.updateItem({
        TableName: PAGES_TABLE,
        Key: marshall({ urlString }),
        UpdateExpression: 'SET #dm = :domain, lastCommentAt = :lastCommentAt, commentCount = :commentCount',
        ExpressionAttributeNames: { '#dm': 'domain' },
        ExpressionAttributeValues: marshall({
          ':domain': domain,
          ':lastCommentAt': lastCommentAt ?? new Date().toISOString(),
          ':commentCount': commentCount,
        }),
      }).promise();
      updated++;
      console.log(`  ✓ ${urlString} (${commentCount} comments)`);
    } catch (err) {
      console.error(`  ✗ ${urlString}: ${err.message}`);
    }
  }

  console.log(`\nDone. Updated ${updated}/${urls.length} entries.`);
}

main().catch(err => { console.error(err); process.exit(1); });
