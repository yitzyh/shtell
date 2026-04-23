import { dynamodb, TABLES, unmarshall } from './_helpers/dynamo.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { trending, urlString } = req.query;

    if (urlString) {
      const result = await dynamodb.getItem({
        TableName: TABLES.PAGES,
        Key: { urlString: { S: urlString } }
      }).promise();

      if (!result.Item) {
        return res.status(404).json({ error: 'Page not found' });
      }

      return res.status(200).json({ page: unmarshall(result.Item) });
    }

    if (trending === 'true') {
      const result = await dynamodb.scan({
        TableName: TABLES.PAGES
      }).promise();

      // Return all pages with comments, sorted by most recent — client handles display sorting.
      const pages = (result.Items || [])
        .map(unmarshall)
        .filter(p => p.commentCount > 0)
        .sort((a, b) => (b.lastCommentAt || '').localeCompare(a.lastCommentAt || ''));

      return res.status(200).json({ pages });
    }

    return res.status(400).json({ error: 'Provide either trending=true or urlString query param' });

  } catch (error) {
    console.error('Pages API error:', error);
    return res.status(500).json({ error: 'Internal server error', message: error.message });
  }
}
