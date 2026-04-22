import { v4 as uuidv4 } from 'uuid';
import { dynamodb, TABLES, unmarshall, marshall } from './_helpers/dynamo.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    if (req.method === 'GET') {
      const { urlString, userID } = req.query;

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

      await dynamodb.putItem({
        TableName: TABLES.COMMENTS,
        Item: marshall(item)
      }).promise();

      // Upsert page metadata: increment commentCount, update lastCommentAt
      // 'title', 'domain', 'name' are DynamoDB reserved words — alias with ExpressionAttributeNames
      const setParts = ['lastCommentAt = :lastCommentAt'];
      const exprAttrValues = { ':one': { N: '1' }, ':lastCommentAt': { S: dateCreated } };
      const exprAttrNames = {};
      if (pageTitle) {
        setParts.push('#pt = :title');
        exprAttrNames['#pt'] = 'title';
        exprAttrValues[':title'] = { S: pageTitle };
      }
      if (domain) {
        setParts.push('#dm = :domain');
        exprAttrNames['#dm'] = 'domain';
        exprAttrValues[':domain'] = { S: domain };
      }
      if (faviconURL) {
        setParts.push('faviconURL = :faviconURL');
        exprAttrValues[':faviconURL'] = { S: faviconURL };
      }
      if (thumbnailURL) {
        setParts.push('thumbnailURL = :thumbnailURL');
        exprAttrValues[':thumbnailURL'] = { S: thumbnailURL };
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
