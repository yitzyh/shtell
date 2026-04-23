import { v4 as uuidv4 } from 'uuid';
import { dynamodb, TABLES, unmarshall, marshall } from './_helpers/dynamo.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    if (req.method === 'GET') {
      const { appleUserID, userID, username, checkAvailability } = req.query;

      // Username availability check
      if (username && checkAvailability === 'true') {
        const result = await dynamodb.query({
          TableName: TABLES.USERS,
          IndexName: 'username-index',
          KeyConditionExpression: 'username = :username',
          ExpressionAttributeValues: { ':username': { S: username } },
          Limit: 1
        }).promise();
        return res.status(200).json({ available: result.Count === 0 });
      }

      // Lookup by Apple ID
      if (appleUserID) {
        const result = await dynamodb.query({
          TableName: TABLES.USERS,
          IndexName: 'appleUserID-index',
          KeyConditionExpression: 'appleUserID = :appleUserID',
          ExpressionAttributeValues: { ':appleUserID': { S: appleUserID } },
          Limit: 1
        }).promise();

        if (result.Count === 0) return res.status(404).json({ error: 'User not found' });
        return res.status(200).json({ user: unmarshall(result.Items[0]) });
      }

      // Lookup by userID
      if (userID) {
        const result = await dynamodb.getItem({
          TableName: TABLES.USERS,
          Key: { userID: { S: userID } }
        }).promise();

        if (!result.Item) return res.status(404).json({ error: 'User not found' });
        return res.status(200).json({ user: unmarshall(result.Item) });
      }

      return res.status(400).json({ error: 'Missing required query param: appleUserID, userID, or username+checkAvailability' });
    }

    if (req.method === 'POST') {
      const { appleUserID, username, displayName } = req.body;

      if (!appleUserID || !username || !displayName) {
        return res.status(400).json({ error: 'Missing required fields: appleUserID, username, displayName' });
      }

      // Check username is available
      const usernameCheck = await dynamodb.query({
        TableName: TABLES.USERS,
        IndexName: 'username-index',
        KeyConditionExpression: 'username = :username',
        ExpressionAttributeValues: { ':username': { S: username } },
        Limit: 1
      }).promise();

      if (usernameCheck.Count > 0) {
        return res.status(409).json({ error: 'Username already taken' });
      }

      const userID = uuidv4();
      const dateCreated = new Date().toISOString();

      await dynamodb.putItem({
        TableName: TABLES.USERS,
        Item: marshall({ userID, appleUserID, username, displayName, dateCreated })
      }).promise();

      return res.status(201).json({ user: { userID, appleUserID, username, displayName, dateCreated } });
    }

    if (req.method === 'PATCH') {
      const { userID, displayName, username, bio, avatarColor1, avatarColor2 } = req.body;

      if (!userID) {
        return res.status(400).json({ error: 'Missing required field: userID' });
      }

      // Check username availability if changing it
      if (username !== undefined) {
        const usernameCheck = await dynamodb.query({
          TableName: TABLES.USERS,
          IndexName: 'username-index',
          KeyConditionExpression: 'username = :username',
          ExpressionAttributeValues: { ':username': { S: username } },
          Limit: 1
        }).promise();

        if (usernameCheck.Count > 0 && usernameCheck.Items[0] && unmarshall(usernameCheck.Items[0]).userID !== userID) {
          return res.status(409).json({ error: 'Username already taken' });
        }
      }

      const setParts = [];
      const exprAttrValues = {};
      const exprAttrNames = {};

      if (displayName !== undefined) {
        setParts.push('#dn = :displayName');
        exprAttrNames['#dn'] = 'displayName';
        exprAttrValues[':displayName'] = { S: displayName };
      }
      if (username !== undefined) {
        setParts.push('username = :username');
        exprAttrValues[':username'] = { S: username };
      }
      if (bio !== undefined) {
        setParts.push('bio = :bio');
        exprAttrValues[':bio'] = { S: bio };
      }
      if (avatarColor1 !== undefined) {
        setParts.push('avatarColor1 = :avatarColor1');
        exprAttrValues[':avatarColor1'] = { S: avatarColor1 };
      }
      if (avatarColor2 !== undefined) {
        setParts.push('avatarColor2 = :avatarColor2');
        exprAttrValues[':avatarColor2'] = { S: avatarColor2 };
      }

      if (setParts.length === 0) {
        return res.status(400).json({ error: 'No fields to update' });
      }

      const params = {
        TableName: TABLES.USERS,
        Key: { userID: { S: userID } },
        UpdateExpression: `SET ${setParts.join(', ')}`,
        ExpressionAttributeValues: exprAttrValues,
        ReturnValues: 'ALL_NEW'
      };
      if (Object.keys(exprAttrNames).length) params.ExpressionAttributeNames = exprAttrNames;

      const result = await dynamodb.updateItem(params).promise();
      return res.status(200).json({ user: unmarshall(result.Attributes) });
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Users API error:', error);
    return res.status(500).json({ error: 'Internal server error', message: error.message });
  }
}
