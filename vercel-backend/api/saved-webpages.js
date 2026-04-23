import { dynamodb, TABLES, unmarshall, marshall } from './_helpers/dynamo.js';

// ---- Metadata fetch via Microlink (or YouTube oEmbed) ----

function youtubeVideoId(url) {
  try {
    const u = new URL(url);
    if (u.hostname === 'youtu.be') return u.pathname.slice(1).split('?')[0];
    if (u.hostname.endsWith('youtube.com')) return u.searchParams.get('v');
  } catch {}
  return null;
}

async function fetchMetadata(url) {
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

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    if (req.method === 'GET') {
      const { userID, urlString } = req.query;

      if (!userID) {
        return res.status(400).json({ error: 'Missing required query param: userID' });
      }

      // Check if a specific page is saved
      if (urlString) {
        const result = await dynamodb.getItem({
          TableName: TABLES.SAVED_PAGES,
          Key: marshall({ userID, urlString })
        }).promise();

        return res.status(200).json({ saved: !!result.Item });
      }

      // Fetch all saved pages for a user
      const result = await dynamodb.query({
        TableName: TABLES.SAVED_PAGES,
        KeyConditionExpression: 'userID = :userID',
        ExpressionAttributeValues: { ':userID': { S: userID } },
        ScanIndexForward: false
      }).promise();

      const savedPages = (result.Items || []).map(unmarshall);
      return res.status(200).json({ savedPages });
    }

    if (req.method === 'POST') {
      const { userID, urlString, title, domain, thumbnailURL, faviconURL } = req.body;

      if (!userID || !urlString || !title || !domain) {
        return res.status(400).json({ error: 'Missing required fields: userID, urlString, title, domain' });
      }

      const dateSaved = new Date().toISOString();

      // Save page and fetch metadata concurrently
      const [, fetched] = await Promise.all([
        dynamodb.putItem({
          TableName: TABLES.SAVED_PAGES,
          Item: marshall({ userID, urlString, title, domain, dateSaved })
        }).promise(),
        fetchMetadata(urlString),
      ]);

      // Merge: app-supplied values win; server-fetched fills anything missing
      const appTitleIsGeneric = !title || title.startsWith('http') || !/[\-–—|·•:]/.test(title);
      const resolvedTitle = appTitleIsGeneric ? (fetched.title || title || null) : title;
      const resolvedThumbnail = thumbnailURL || fetched.thumbnailURL || null;
      const resolvedFavicon = faviconURL || fetched.faviconURL || null;
      let resolvedDomain = domain;
      if (!resolvedDomain) {
        try { resolvedDomain = new URL(urlString).hostname; } catch { resolvedDomain = null; }
      }

      try {
        const setParts = [];
        const exprAttrValues = {};
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
        if (resolvedThumbnail) {
          setParts.push('thumbnailURL = :thumbnailURL');
          exprAttrValues[':thumbnailURL'] = { S: resolvedThumbnail };
        }
        if (resolvedFavicon) {
          setParts.push('faviconURL = :faviconURL');
          exprAttrValues[':faviconURL'] = { S: resolvedFavicon };
        }

        if (setParts.length > 0) {
          const pageParams = {
            TableName: TABLES.PAGES,
            Key: { urlString: { S: urlString } },
            UpdateExpression: `SET ${setParts.join(', ')}`,
            ExpressionAttributeValues: exprAttrValues,
          };
          if (Object.keys(exprAttrNames).length) pageParams.ExpressionAttributeNames = exprAttrNames;
          await dynamodb.updateItem(pageParams).promise();
        }
      } catch (metaErr) {
        console.error('webpages-meta upsert failed (non-fatal):', metaErr.message);
      }

      return res.status(201).json({ savedPage: { userID, urlString, title, domain, dateSaved } });
    }

    if (req.method === 'DELETE') {
      const { userID, urlString } = req.body;

      if (!userID || !urlString) {
        return res.status(400).json({ error: 'Missing required fields: userID, urlString' });
      }

      await dynamodb.deleteItem({
        TableName: TABLES.SAVED_PAGES,
        Key: marshall({ userID, urlString })
      }).promise();

      return res.status(200).json({ success: true });
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Saved pages API error:', error);
    return res.status(500).json({ error: 'Internal server error', message: error.message });
  }
}
