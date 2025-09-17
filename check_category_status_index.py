#!/usr/bin/env python3
import boto3

# AWS credentials
AWS_ACCESS_KEY = "AKIAUON2G4CIEFYOZEJX"
AWS_SECRET_KEY = "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"
REGION = "us-east-1"
TABLE_NAME = "webpages"

def main():
    dynamodb = boto3.client(
        'dynamodb',
        region_name=REGION,
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY
    )
    
    print("📊 CATEGORY-STATUS-INDEX QUERY")
    print("=" * 50)
    
    # Query active webgames using the GSI
    print("🟢 Querying ACTIVE webgames...")
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='category-status-index',
        KeyConditionExpression='bfCategory = :category AND #status = :status',
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues={
            ':category': {'S': 'webgames'},
            ':status': {'S': 'active'}
        }
    )
    
    active_count = response.get('Count', 0)
    
    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = dynamodb.query(
            TableName=TABLE_NAME,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category AND #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':category': {'S': 'webgames'},
                ':status': {'S': 'active'}
            },
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        active_count += response.get('Count', 0)
    
    print(f"Active webgames: {active_count}")
    
    # Query inactive webgames using the GSI
    print("\n🔴 Querying INACTIVE webgames...")
    response = dynamodb.query(
        TableName=TABLE_NAME,
        IndexName='category-status-index',
        KeyConditionExpression='bfCategory = :category AND #status = :status',
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues={
            ':category': {'S': 'webgames'},
            ':status': {'S': 'inactive'}
        }
    )
    
    inactive_count = response.get('Count', 0)
    
    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = dynamodb.query(
            TableName=TABLE_NAME,
            IndexName='category-status-index',
            KeyConditionExpression='bfCategory = :category AND #status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':category': {'S': 'webgames'},
                ':status': {'S': 'inactive'}
            },
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        inactive_count += response.get('Count', 0)
    
    print(f"Inactive webgames: {inactive_count}")
    
    # Summary
    total = active_count + inactive_count
    
    print(f"\n📊 SUMMARY:")
    print(f"  🟢 Active:   {active_count}")
    print(f"  🔴 Inactive: {inactive_count}")
    print(f"  📊 Total:    {total}")
    print(f"  📉 Removed:  {inactive_count/total*100:.1f}%")
    
    print(f"\n✨ GSI query complete!")

if __name__ == "__main__":
    main()