import { v4 as uuidv4 } from 'uuid';
import { dynamodb, TABLES, unmarshall, marshall } from './_helpers/dynamo.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    if (req.method === 'GET') {
      const { urlString } = req.query;

      if (!urlString) {
        return res.status(400).json({ error: 'Missing required query param: urlString' });
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
        parentCommentID, quotedText, quotedTextSelector, quotedTextOffset
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

      await dynamodb.putItem({
        TableName: TABLES.COMMENTS,
        Item: marshall(item)
      }).promise();

      return res.status(201).json({ comment: item });
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Comments API error:', error);
    return res.status(500).json({ error: 'Internal server error', message: error.message });
  }
}
