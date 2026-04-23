import { v4 as uuidv4 } from 'uuid';
import { dynamodb, TABLES, unmarshall, marshall } from './_helpers/dynamo.js';

// ---- Metadata fetch via Microlink ----

// Extract YouTube video ID from a URL (handles youtu.be and youtube.com/watch)
function youtubeVideoId(url) {
  try {
    const u = new URL(url);
    if (u.hostname === 'youtu.be') return u.pathname.slice(1).split('?')[0];
    if (u.hostname.endsWith('youtube.com')) return u.searchParams.get('v');
  } catch {}
  return null;
}

async function fetchMetadata(url) {
  // YouTube: derive thumbnail and title directly — faster and more reliable than Microlink
  const ytId = youtubeVideoId(url);
  if (ytId) {
    try {
      const oembedResp = await fetch(
        `https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`,
        { signal: AbortSignal.timeout(5000) }
      );
      if (oembedResp.ok) {
        const oembed = await oembedResp.json();
        return {
          title: oembed.title || null,
          thumbnailURL: `https://img.youtube.com/vi/${ytId}/maxresdefault.jpg`,
          faviconURL: 'https://www.youtube.com/s/desktop/56323de4/img/favicon_144x144.png',
        };
      }
    } catch {}
    // oEmbed failed — still return the thumbnail we can construct deterministically
    return {
      title: null,
      thumbnailURL: `https://img.youtube.com/vi/${ytId}/maxresdefault.jpg`,
      faviconURL: 'https://www.youtube.com/s/desktop/56323de4/img/favicon_144x144.png',
    };
  }

  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    const resp = await fetch(
      `https://api.microlink.io/?url=${encodeURIComponent(url)}&prerender=auto`,
      { signal: controller.signal }
    );
    clearTimeout(timer);
    if (!resp.ok) return {};
    const { status, data } = await resp.json();
    if (status !== 'success' || !data) return {};
    return {
      title: data.title || null,
      thumbnailURL: data.image?.url || null,
      faviconURL: data.logo?.url || null,
    };
  } catch {
    return {};
  }
}

// ---- Handler ----

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    if (req.method === 'GET') {
      const { urlString, userID, recent, limit } = req.query;

      if (recent === 'true') {
        const result = await dynamodb.scan({
          TableName: TABLES.COMMENTS,
          Limit: 200
        }).promise();
        const comments = (result.Items || [])
          .map(unmarshall)
          .sort((a, b) => new Date(b.dateCreated) - new Date(a.dateCreated))
          .slice(0, parseInt(limit) || 50);
        return res.status(200).json({ comments });
      }

      if (userID) {
        const result = await dynamodb.query({
          TableName: TABLES.COMMENTS,
          IndexName: 'userID-index',
          KeyConditionExpression: 'userID = :userID',
          ExpressionAttributeValues: { ':userID': { S: userID } }
        }).promise();
        const comments = (result.Items || []).map(unmarshall);
        return res.status(200).json({ comments });
      }

      if (!urlString) {
        return res.status(400).json({ error: 'Provide urlString or userID query param' });
      }

      const result = await dynamodb.query({
        TableName: TABLES.COMMENTS,
        KeyConditionExpression: 'urlString = :urlString',
        ExpressionAttributeValues: { ':urlString': { S: urlString } }
      }).promise();

      const comments = (result.Items || []).map(unmarshall);
      return res.status(200).json({ comments });
    }

    if (req.method === 'POST') {
      const {
        urlString, text, userID, username,
        parentCommentID, quotedText, quotedTextSelector, quotedTextOffset,
        pageTitle, domain, faviconURL, thumbnailURL
      } = req.body;

      if (!urlString || !text || !userID || !username) {
        return res.status(400).json({ error: 'Missing required fields: urlString, text, userID, username' });
      }

      const commentID = uuidv4();
      const dateCreated = new Date().toISOString();

      const item = { urlString, commentID, text, userID, username, dateCreated };
      if (parentCommentID) item.parentCommentID = parentCommentID;
      if (quotedText) item.quotedText = quotedText;
      if (quotedTextSelector) item.quotedTextSelector = quotedTextSelector;
      if (quotedTextOffset != null) item.quotedTextOffset = quotedTextOffset;

      // Save comment and upsert metadata concurrently
      const [, fetched] = await Promise.all([
        dynamodb.putItem({ TableName: TABLES.COMMENTS, Item: marshall(item) }).promise(),
        // Server-side metadata fetch — fills gaps the app couldn't capture
        fetchMetadata(urlString),
      ]);

      // Merge: app-supplied values win; server-fetched fills anything missing.
      // Prefer Microlink title if app title looks generic (just the site name, no separator).
      const appTitleIsGeneric = !pageTitle || pageTitle.startsWith('http') || !/[\-–—|·•:]/.test(pageTitle);
      const resolvedTitle = appTitleIsGeneric ? (fetched.title || pageTitle || null) : pageTitle;
      const resolvedThumbnail = thumbnailURL || fetched.thumbnailURL || null;
      const resolvedFavicon = faviconURL || fetched.faviconURL || null;

      // Derive domain from URL if not supplied
      let resolvedDomain = domain;
      if (!resolvedDomain) {
        try { resolvedDomain = new URL(urlString).hostname; } catch { resolvedDomain = null; }
      }

      // Build webpages-meta upsert
      // 'title', 'domain', 'name' are DynamoDB reserved words — alias with ExpressionAttributeNames
      const setParts = ['lastCommentAt = :lastCommentAt'];
      const exprAttrValues = { ':one': { N: '1' }, ':lastCommentAt': { S: dateCreated } };
      const exprAttrNames = {};

      if (resolvedTitle) {
        setParts.push('#pt = :title');
        exprAttrNames['#pt'] = 'title';
        exprAttrValues[':title'] = { S: resolvedTitle };
      }
      if (resolvedDomain) {
        setParts.push('#dm = :domain');
        exprAttrNames['#dm'] = 'domain';
        exprAttrValues[':domain'] = { S: resolvedDomain };
      }
      if (resolvedFavicon) {
        setParts.push('faviconURL = :faviconURL');
        exprAttrValues[':faviconURL'] = { S: resolvedFavicon };
      }
      if (resolvedThumbnail) {
        setParts.push('thumbnailURL = :thumbnailURL');
        exprAttrValues[':thumbnailURL'] = { S: resolvedThumbnail };
      }

      try {
        const pageParams = {
          TableName: TABLES.PAGES,
          Key: { urlString: { S: urlString } },
          UpdateExpression: `SET ${setParts.join(', ')} ADD commentCount :one`,
          ExpressionAttributeValues: exprAttrValues,
        };
        if (Object.keys(exprAttrNames).length) pageParams.ExpressionAttributeNames = exprAttrNames;
        await dynamodb.updateItem(pageParams).promise();
      } catch (pagesErr) {
        console.error('Pages upsert failed (non-fatal):', pagesErr.message);
      }

      return res.status(201).json({ comment: item });
    }

    if (req.method === 'DELETE') {
      const { urlString, commentID } = req.body;
      if (!urlString || !commentID) {
        return res.status(400).json({ error: 'Missing required fields: urlString, commentID' });
      }
      await dynamodb.deleteItem({
        TableName: TABLES.COMMENTS,
        Key: marshall({ urlString, commentID })
      }).promise();
      return res.status(200).json({ deleted: true });
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Comments API error:', error);
    return res.status(500).json({ error: 'Internal server error', message: error.message });
  }
}
