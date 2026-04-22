import AWS from 'aws-sdk';

export const dynamodb = new AWS.DynamoDB({
  region: 'us-east-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
});

export const TABLES = {
  USERS: 'users',
  COMMENTS: 'comments',
  SAVED_PAGES: 'saved-webpages',
  PAGES: 'webpages-meta'
};

export const { unmarshall, marshall } = AWS.DynamoDB.Converter;
