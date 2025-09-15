import XCTest
import CloudKit
@testable import DumFlow

class CommentSystemSimpleTests: XCTestCase {
    
    func testCommentModelCreation() {
        // Create a CloudKit record for testing
        let record = CKRecord(recordType: "Comment")
        record["commentID"] = "test-comment-1"
        record["text"] = "This is a test comment"
        record["dateCreated"] = Date()
        record["userID"] = "test-user-123"
        record["username"] = "TestUser"
        record["urlString"] = "https://example.com/article"
        record["likeCount"] = 5
        record["saveCount"] = 2
        record["isReported"] = 0
        record["reportCount"] = 0
        
        do {
            let comment = try Comment(record: record)
            
            XCTAssertEqual(comment.commentID, "test-comment-1")
            XCTAssertEqual(comment.text, "This is a test comment")
            XCTAssertEqual(comment.userID, "test-user-123")
            XCTAssertEqual(comment.username, "TestUser")
            XCTAssertEqual(comment.urlString, "https://example.com/article")
            XCTAssertEqual(comment.likeCount, 5)
            XCTAssertEqual(comment.saveCount, 2)
            XCTAssertEqual(comment.isReported, 0)
            XCTAssertEqual(comment.reportCount, 0)
            XCTAssertNil(comment.parentCommentID)
            
        } catch {
            XCTFail("Failed to create comment from record: \(error)")
        }
    }
    
    func testCommentWithReply() {
        // Test parent comment
        let parentRecord = CKRecord(recordType: "Comment")
        parentRecord["commentID"] = "parent-comment"
        parentRecord["text"] = "Parent comment"
        parentRecord["dateCreated"] = Date()
        parentRecord["userID"] = "user-1"
        parentRecord["username"] = "User1"
        parentRecord["urlString"] = "https://example.com/article"
        parentRecord["likeCount"] = 0
        parentRecord["saveCount"] = 0
        parentRecord["isReported"] = 0
        parentRecord["reportCount"] = 0
        
        // Test reply comment
        let replyRecord = CKRecord(recordType: "Comment")
        replyRecord["commentID"] = "reply-comment"
        replyRecord["text"] = "Reply to parent"
        replyRecord["dateCreated"] = Date()
        replyRecord["userID"] = "user-2"
        replyRecord["username"] = "User2"
        replyRecord["urlString"] = "https://example.com/article"
        replyRecord["parentCommentID"] = "parent-comment"
        replyRecord["likeCount"] = 0
        replyRecord["saveCount"] = 0
        replyRecord["isReported"] = 0
        replyRecord["reportCount"] = 0
        
        do {
            let parentComment = try Comment(record: parentRecord)
            let replyComment = try Comment(record: replyRecord)
            
            XCTAssertNil(parentComment.parentCommentID)
            XCTAssertEqual(replyComment.parentCommentID, "parent-comment")
            
        } catch {
            XCTFail("Failed to create comments: \(error)")
        }
    }
    
    func testCommentWithQuote() {
        let record = CKRecord(recordType: "Comment")
        record["commentID"] = "quote-comment"
        record["text"] = "Great article about this topic"
        record["dateCreated"] = Date()
        record["userID"] = "user-1"
        record["username"] = "User1"
        record["urlString"] = "https://example.com/article"
        record["quotedText"] = "This is the important part of the article"
        record["quotedTextSelector"] = "article-p-1"
        record["quotedTextOffset"] = 100
        record["likeCount"] = 0
        record["saveCount"] = 0
        record["isReported"] = 0
        record["reportCount"] = 0
        
        do {
            let comment = try Comment(record: record)
            
            XCTAssertEqual(comment.quotedText, "This is the important part of the article")
            XCTAssertEqual(comment.quotedTextSelector, "article-p-1")
            XCTAssertEqual(comment.quotedTextOffset, 100)
            
        } catch {
            XCTFail("Failed to create comment with quote: \(error)")
        }
    }
    
    func testCommentToRecordConversion() {
        // Create a comment using convenience initializer
        let record = CKRecord(recordType: "Comment")
        let originalComment = Comment(
            id: record.recordID,
            commentID: "conversion-test",
            text: "Test conversion",
            dateCreated: Date(),
            userID: "test-user",
            username: "TestUser",
            urlString: "https://example.com/test",
            parentCommentID: nil,
            quotedText: nil,
            quotedTextSelector: nil,
            quotedTextOffset: nil,
            likeCount: 3,
            saveCount: 1,
            isReported: 0,
            reportCount: 0
        )
        
        // Convert to record
        let convertedRecord = originalComment.toRecord()
        
        // Verify record fields
        XCTAssertEqual(convertedRecord.recordType, "Comment")
        XCTAssertEqual(convertedRecord["commentID"] as? String, "conversion-test")
        XCTAssertEqual(convertedRecord["text"] as? String, "Test conversion")
        XCTAssertEqual(convertedRecord["userID"] as? String, "test-user")
        XCTAssertEqual(convertedRecord["username"] as? String, "TestUser")
        XCTAssertEqual(convertedRecord["urlString"] as? String, "https://example.com/test")
        XCTAssertEqual(convertedRecord["likeCount"] as? Int, 3)
        XCTAssertEqual(convertedRecord["saveCount"] as? Int, 1)
        XCTAssertEqual(convertedRecord["isReported"] as? Int, 0)
        XCTAssertEqual(convertedRecord["reportCount"] as? Int, 0)
    }
    
    func testCommentEquality() {
        let record1 = CKRecord(recordType: "Comment")
        let record2 = CKRecord(recordType: "Comment")
        
        let comment1 = Comment(
            id: record1.recordID,
            commentID: "same-id",
            text: "Comment 1",
            dateCreated: Date(),
            userID: "user-1",
            username: "User1",
            urlString: "https://example.com/test",
            likeCount: 0,
            saveCount: 0,
            isReported: 0,
            reportCount: 0
        )
        
        let comment2 = Comment(
            id: record2.recordID,
            commentID: "same-id",
            text: "Comment 2",
            dateCreated: Date(),
            userID: "user-2",
            username: "User2",
            urlString: "https://example.com/test",
            likeCount: 0,
            saveCount: 0,
            isReported: 0,
            reportCount: 0
        )
        
        // Comments with same commentID should be equal
        XCTAssertEqual(comment1, comment2)
        
        let comment3 = Comment(
            id: record1.recordID,
            commentID: "different-id",
            text: "Comment 3",
            dateCreated: Date(),
            userID: "user-1",
            username: "User1",
            urlString: "https://example.com/test",
            likeCount: 0,
            saveCount: 0,
            isReported: 0,
            reportCount: 0
        )
        
        // Comments with different commentID should not be equal
        XCTAssertNotEqual(comment1, comment3)
    }
    
    func testCommentTimeAgo() {
        let record = CKRecord(recordType: "Comment")
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        let comment = Comment(
            id: record.recordID,
            commentID: "time-test",
            text: "Time test comment",
            dateCreated: pastDate,
            userID: "test-user",
            username: "TestUser",
            urlString: "https://example.com/test",
            likeCount: 0,
            saveCount: 0,
            isReported: 0,
            reportCount: 0
        )
        
        // Test that timeAgoShort returns some string
        let timeAgo = comment.timeAgoShort
        XCTAssertFalse(timeAgo.isEmpty)
    }
    
    func testPerformanceCommentCreation() {
        measure {
            for i in 0..<100 {
                let record = CKRecord(recordType: "Comment")
                record["commentID"] = "perf-test-\(i)"
                record["text"] = "Performance test comment \(i)"
                record["dateCreated"] = Date()
                record["userID"] = "test-user"
                record["username"] = "TestUser"
                record["urlString"] = "https://example.com/test"
                record["likeCount"] = 0
                record["saveCount"] = 0
                record["isReported"] = 0
                record["reportCount"] = 0
                
                do {
                    _ = try Comment(record: record)
                } catch {
                    XCTFail("Failed to create comment \(i): \(error)")
                }
            }
        }
    }
}