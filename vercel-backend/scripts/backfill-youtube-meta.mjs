/**
 * Backfill title + thumbnailURL for YouTube entries in webpages-meta
 * that are missing one or both fields.
 *
 * Uses YouTube oEmbed (free, no API key) + constructs maxresdefault thumbnail.
 *
 * Usage: node scripts/backfill-youtube-meta.mjs
 * Reads AWS credentials from ~/.aws/credentials (default profile) or env vars.
 */

import AWS from 'aws-sdk';

const dynamodb = new AWS.DynamoDB({ region: 'us-east-1' });
const { unmarshall, marshall } = AWS.DynamoDB.Converter;
const PAGES_TABLE = 'webpages-meta';

function youtubeVideoId(url) {
  try {
    const u = new URL(url);
    if (u.hostname === 'youtu.be') return u.pathname.slice(1).split('?')[0];
    if (u.hostname.endsWith('youtube.com')) return u.searchParams.get('v');
  } catch {}
  return null;
}

async function fetchOEmbed(url) {
  const resp = await fetch(
    `https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`,
    { signal: AbortSignal.timeout(5000) }
  );
  if (!resp.ok) return null;
  return resp.json();
}

async function scanAll() {
  const items = [];
  let lastKey;
  do {
    const params = { TableName: PAGES_TABLE };
    if (lastKey) params.ExclusiveStartKey = lastKey;
    const result = await dynamodb.scan(params).promise();
    items.push(...(result.Items || []).map(unmarshall));
    lastKey = result.LastEvaluatedKey;
  } while (lastKey);
  return items;
}

async function main() {
  console.log('Scanning webpages-meta for YouTube entries missing title/thumbnail...');
  const pages = await scanAll();

  const ytPages = pages.filter(p => {
    const id = youtubeVideoId(p.urlString);
    return id && (!p.title || !p.thumbnailURL);
  });

  console.log(`Found ${ytPages.length} YouTube entries to backfill (out of ${pages.length} total).`);
  if (ytPages.length === 0) return;

  let updated = 0;
  let failed = 0;

  for (const page of ytPages) {
    const ytId = youtubeVideoId(page.urlString);
    const thumbnailURL = `https://img.youtube.com/vi/${ytId}/maxresdefault.jpg`;
    const faviconURL = 'https://www.youtube.com/s/desktop/56323de4/img/favicon_144x144.png';

    let title = page.title || null;
    try {
      const oembed = await fetchOEmbed(page.urlString);
      if (oembed?.title) title = oembed.title;
    } catch {
      console.warn(`  oEmbed failed for ${page.urlString}, using existing title`);
    }

    const setParts = ['thumbnailURL = :thumbnailURL', 'faviconURL = :faviconURL'];
    const exprAttrValues = {
      ':thumbnailURL': { S: thumbnailURL },
      ':faviconURL': { S: faviconURL },
    };
    const exprAttrNames = {};

    if (title) {
      setParts.push('#pt = :title');
      exprAttrNames['#pt'] = 'title';
      exprAttrValues[':title'] = { S: title };
    }

    try {
      const params = {
        TableName: PAGES_TABLE,
        Key: { urlString: { S: page.urlString } },
        UpdateExpression: `SET ${setParts.join(', ')}`,
        ExpressionAttributeValues: exprAttrValues,
      };
      if (Object.keys(exprAttrNames).length) params.ExpressionAttributeNames = exprAttrNames;
      await dynamodb.updateItem(params).promise();
      console.log(`  ✓ ${title || '(no title)'} — ${page.urlString}`);
      updated++;
    } catch (err) {
      console.error(`  ✗ Failed ${page.urlString}: ${err.message}`);
      failed++;
    }
  }

  console.log(`\nDone: ${updated} updated, ${failed} failed.`);
}

main().catch(err => { console.error(err); process.exit(1); });
