import { dynamodb, TABLES, unmarshall, marshall } from './_helpers/dynamo.js';

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
        ScanIndexForward: false // newest first (by SK, so this is alphabetical — acceptable for beta)
      }).promise();

      const savedPages = (result.Items || []).map(unmarshall);
      return res.status(200).json({ savedPages });
    }

    if (req.method === 'POST') {
      const { userID, urlString, title, domain } = req.body;

      if (!userID || !urlString || !title || !domain) {
        return res.status(400).json({ error: 'Missing required fields: userID, urlString, title, domain' });
      }

      const dateSaved = new Date().toISOString();

      await dynamodb.putItem({
        TableName: TABLES.SAVED_PAGES,
        Item: marshall({ userID, urlString, title, domain, dateSaved })
      }).promise();

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
