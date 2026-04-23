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

// ---- User color enrichment ----

async function enrichWithUserColors(comments) {
  if (!comments || comments.length === 0) return comments;

  const uniqueUserIDs = [...new Set(comments.map(c => c.userID).filter(Boolean))];
  if (uniqueUserIDs.length === 0) return comments;

  // BatchGetItem allows max 100 keys per call
  const chunks = [];
  for (let i = 0; i < uniqueUserIDs.length; i += 100) {
    chunks.push(uniqueUserIDs.slice(i, i + 100));
  }

  const colorMap = {};
  for (const chunk of chunks) {
    const keys = chunk.map(id => ({ userID: { S: id } }));
    const result = await dynamodb.batchGetItem({
      RequestItems: {
        [TABLES.USERS]: {
          Keys: keys,
          ProjectionExpression: 'userID, avatarColor1, avatarColor2'
        }
      }
    }).promise();

    const items = (result.Responses && result.Responses[TABLES.USERS]) || [];
    for (const item of items) {
      const u = unmarshall(item);
      colorMap[u.userID] = { avatarColor1: u.avatarColor1 || null, avatarColor2: u.avatarColor2 || null };
    }
  }

  return comments.map(c => ({
    ...c,
    avatarColor1: colorMap[c.userID]?.avatarColor1 ?? null,
    avatarColor2: colorMap[c.userID]?.avatarColor2 ?? null,
  }));
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
        const raw = (result.Items || [])
          .map(unmarshall)
          .sort((a, b) => new Date(b.dateCreated) - new Date(a.dateCreated))
          .slice(0, parseInt(limit) || 50);
        const comments = await enrichWithUserColors(raw);
        return res.status(200).json({ comments });
      }

      if (userID) {
        const result = await dynamodb.query({
          TableName: TABLES.COMMENTS,
          IndexName: 'userID-index',
          KeyConditionExpression: 'userID = :userID',
          ExpressionAttributeValues: { ':userID': { S: userID } }
        }).promise();
        const enriched = await enrichWithUserColors((result.Items || []).map(unmarshall));
        return res.status(200).json({ comments: enriched });
      }

      if (req.query.domain) {
        const domain = req.query.domain;
        // Find all URLs for this domain from webpages-meta
        const pagesResult = await dynamodb.scan({
          TableName: TABLES.PAGES,
          FilterExpression: '#dm = :domain',
          ExpressionAttributeNames: { '#dm': 'domain' },
          ExpressionAttributeValues: { ':domain': { S: domain } }
        }).promise();

        const urlStrings = (pagesResult.Items || [])
          .map(unmarshall)
          .map(p => p.urlString)
          .filter(Boolean)
          .slice(0, 20);

        if (urlStrings.length === 0) return res.status(200).json({ comments: [] });

        const commentArrays = await Promise.all(
          urlStrings.map(url =>
            dynamodb.query({
              TableName: TABLES.COMMENTS,
              KeyConditionExpression: 'urlString = :url',
              ExpressionAttributeValues: { ':url': { S: url } },
              ScanIndexForward: false,
              Limit: 10
            }).promise().then(r => (r.Items || []).map(unmarshall))
          )
        );

        const flatComments = commentArrays.flat()
          .sort((a, b) => b.dateCreated.localeCompare(a.dateCreated))
          .slice(0, 50);
        const comments = await enrichWithUserColors(flatComments);

        return res.status(200).json({ comments });
      }

      if (!urlString) {
        return res.status(400).json({ error: 'Provide urlString, userID, or domain query param' });
      }

      const result = await dynamodb.query({
        TableName: TABLES.COMMENTS,
        KeyConditionExpression: 'urlString = :urlString',
        ExpressionAttributeValues: { ':urlString': { S: urlString } }
      }).promise();

      const enriched = await enrichWithUserColors((result.Items || []).map(unmarshall));
      return res.status(200).json({ comments: enriched });
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

      // Decrement commentCount in webpages-meta. If it reaches 0, delete the row
      // so the page no longer appears in TrendPageView.
      try {
        const updated = await dynamodb.updateItem({
          TableName: TABLES.PAGES,
          Key: { urlString: { S: urlString } },
          UpdateExpression: 'ADD commentCount :neg',
          ExpressionAttributeValues: { ':neg': { N: '-1' } },
          ReturnValues: 'UPDATED_NEW',
        }).promise();
        const newCount = Number(updated.Attributes?.commentCount?.N ?? 0);
        if (newCount <= 0) {
          await dynamodb.deleteItem({
            TableName: TABLES.PAGES,
            Key: { urlString: { S: urlString } },
          }).promise();
        }
      } catch (pagesErr) {
        console.error('Pages decrement failed (non-fatal):', pagesErr.message);
      }

      return res.status(200).json({ deleted: true });
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Comments API error:', error);
    return res.status(500).json({ error: 'Internal server error', message: error.message });
  }
}
