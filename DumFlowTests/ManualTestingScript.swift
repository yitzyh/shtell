import SwiftUI
import CloudKit
@testable import DumFlow

// This is a demonstration file showing how to manually test comment features
// Not meant to be run as automated tests, but as a guide for manual testing

struct ManualTestingScript {
    
    // MARK: - Test Data Setup
    
    static func createTestComments() -> [Comment] {
        var comments: [Comment] = []
        
        // Create some test comments with CloudKit records
        for i in 1...5 {
            let record = CKRecord(recordType: "Comment")
            record["commentID"] = "test-comment-\(i)"
            record["text"] = "This is test comment number \(i). It contains some sample text to test display and functionality."
            record["dateCreated"] = Date().addingTimeInterval(-Double(i * 300)) // Each 5 minutes apart
            record["userID"] = "test-user-\(i % 3 + 1)" // Rotate between 3 users
            record["username"] = "TestUser\(i % 3 + 1)"
            record["urlString"] = "https://example.com/test-article"
            record["likeCount"] = Int.random(in: 0...10)
            record["saveCount"] = Int.random(in: 0...5)
            record["isReported"] = 0
            record["reportCount"] = 0
            
            if let comment = try? Comment(record: record) {
                comments.append(comment)
            }
        }
        
        return comments
    }
    
    static func createTestReplies(to parentCommentID: String) -> [Comment] {
        var replies: [Comment] = []
        
        for i in 1...3 {
            let record = CKRecord(recordType: "Comment")
            record["commentID"] = "reply-\(parentCommentID)-\(i)"
            record["text"] = "This is reply \(i) to the parent comment. Testing nested threading."
            record["dateCreated"] = Date().addingTimeInterval(-Double(i * 60)) // Each 1 minute apart
            record["userID"] = "reply-user-\(i)"
            record["username"] = "ReplyUser\(i)"
            record["urlString"] = "https://example.com/test-article"
            record["parentCommentID"] = parentCommentID
            record["likeCount"] = Int.random(in: 0...5)
            record["saveCount"] = Int.random(in: 0...3)
            record["isReported"] = 0
            record["reportCount"] = 0
            
            if let reply = try? Comment(record: record) {
                replies.append(reply)
            }
        }
        
        return replies
    }
    
    static func createTestCommentWithQuote() -> Comment? {
        let record = CKRecord(recordType: "Comment")
        record["commentID"] = "quote-test-comment"
        record["text"] = "This part of the article really resonated with me. Great insight!"
        record["dateCreated"] = Date()
        record["userID"] = "quote-user"
        record["username"] = "QuoteUser"
        record["urlString"] = "https://example.com/article-with-quotes"
        record["quotedText"] = "The future of technology lies not in replacing human creativity, but in augmenting it."
        record["quotedTextSelector"] = "article-paragraph-3"
        record["quotedTextOffset"] = 150
        record["likeCount"] = 8
        record["saveCount"] = 4
        record["isReported"] = 0
        record["reportCount"] = 0
        
        return try? Comment(record: record)
    }
    
    // MARK: - Manual Test Scenarios
    
    static func testBasicCommentFlow() {
        print("=== Testing Basic Comment Flow ===")
        
        // 1. Create a comment
        let comments = createTestComments()
        print("✅ Created \(comments.count) test comments")
        
        // 2. Verify comment properties
        for comment in comments {
            assert(!comment.commentID.isEmpty, "Comment ID should not be empty")
            assert(!comment.text.isEmpty, "Comment text should not be empty")
            assert(!comment.userID.isEmpty, "User ID should not be empty")
            assert(comment.likeCount >= 0, "Like count should be non-negative")
            assert(comment.saveCount >= 0, "Save count should be non-negative")
        }
        print("✅ All comment properties validated")
        
        // 3. Test CloudKit conversion
        for comment in comments {
            let record = comment.toRecord()
            assert(record.recordType == "Comment", "Record type should be Comment")
            assert(record["commentID"] as? String == comment.commentID, "Comment ID should match")
        }
        print("✅ CloudKit conversion working")
        
        print("=== Basic Comment Flow Test Complete ===\n")
    }
    
    static func testReplyFlow() {
        print("=== Testing Reply Flow ===")
        
        // 1. Create parent comment
        let parentComments = createTestComments()
        guard let parentComment = parentComments.first else {
            print("❌ Failed to create parent comment")
            return
        }
        
        // 2. Create replies
        let replies = createTestReplies(to: parentComment.commentID)
        print("✅ Created \(replies.count) replies to parent comment")
        
        // 3. Verify reply structure
        for reply in replies {
            assert(reply.parentCommentID == parentComment.commentID, "Reply should reference parent")
            assert(reply.parentCommentID != nil, "Reply should have parent ID")
        }
        print("✅ Reply structure validated")
        
        // 4. Test nested replies
        if let firstReply = replies.first {
            let nestedReplies = createTestReplies(to: firstReply.commentID)
            print("✅ Created \(nestedReplies.count) nested replies")
            
            for nestedReply in nestedReplies {
                assert(nestedReply.parentCommentID == firstReply.commentID, "Nested reply should reference first reply")
            }
            print("✅ Nested reply structure validated")
        }
        
        print("=== Reply Flow Test Complete ===\n")
    }
    
    static func testLikeAndSaveFlow() {
        print("=== Testing Like and Save Flow ===")
        
        let comments = createTestComments()
        guard var testComment = comments.first else {
            print("❌ Failed to create test comment")
            return
        }
        
        let originalLikes = testComment.likeCount
        let originalSaves = testComment.saveCount
        
        // Simulate like toggle
        testComment.likeCount += 1
        assert(testComment.likeCount == originalLikes + 1, "Like count should increase")
        print("✅ Like increment working")
        
        testComment.likeCount -= 1
        assert(testComment.likeCount == originalLikes, "Like count should return to original")
        print("✅ Like decrement working")
        
        // Simulate save toggle
        testComment.saveCount += 1
        assert(testComment.saveCount == originalSaves + 1, "Save count should increase")
        print("✅ Save increment working")
        
        testComment.saveCount -= 1
        assert(testComment.saveCount == originalSaves, "Save count should return to original")
        print("✅ Save decrement working")
        
        print("=== Like and Save Flow Test Complete ===\n")
    }
    
    static func testQuoteFlow() {
        print("=== Testing Quote Flow ===")
        
        guard let quoteComment = createTestCommentWithQuote() else {
            print("❌ Failed to create comment with quote")
            return
        }
        
        // Verify quote properties
        assert(quoteComment.quotedText != nil, "Comment should have quoted text")
        assert(quoteComment.quotedTextSelector != nil, "Comment should have quote selector")
        assert(quoteComment.quotedTextOffset != nil, "Comment should have quote offset")
        
        print("✅ Quote comment created with all properties")
        print("   Quoted text: \(quoteComment.quotedText ?? "nil")")
        print("   Selector: \(quoteComment.quotedTextSelector ?? "nil")")
        print("   Offset: \(quoteComment.quotedTextOffset ?? -1)")
        
        // Test CloudKit conversion with quotes
        let record = quoteComment.toRecord()
        assert(record["quotedText"] as? String == quoteComment.quotedText, "Quoted text should convert correctly")
        assert(record["quotedTextSelector"] as? String == quoteComment.quotedTextSelector, "Quote selector should convert correctly")
        assert(record["quotedTextOffset"] as? Int == quoteComment.quotedTextOffset, "Quote offset should convert correctly")
        
        print("✅ Quote CloudKit conversion working")
        print("=== Quote Flow Test Complete ===\n")
    }
    
    static func testReportingFlow() {
        print("=== Testing Reporting Flow ===")
        
        let comments = createTestComments()
        guard var testComment = comments.first else {
            print("❌ Failed to create test comment")
            return
        }
        
        let originalReportCount = testComment.reportCount
        let originalReportedStatus = testComment.isReported
        
        // Simulate reporting
        testComment.isReported = 1
        testComment.reportCount += 1
        
        assert(testComment.isReported == 1, "Comment should be marked as reported")
        assert(testComment.reportCount == originalReportCount + 1, "Report count should increase")
        
        print("✅ Comment reporting working")
        print("   Reported status: \(testComment.isReported)")
        print("   Report count: \(testComment.reportCount)")
        
        // Test CloudKit conversion with reporting
        let record = testComment.toRecord()
        assert(record["isReported"] as? Int == testComment.isReported, "Reported status should convert correctly")
        assert(record["reportCount"] as? Int == testComment.reportCount, "Report count should convert correctly")
        
        print("✅ Reporting CloudKit conversion working")
        print("=== Reporting Flow Test Complete ===\n")
    }
    
    // MARK: - Main Test Runner
    
    static func runAllTests() {
        print("🧪 Starting Manual Comment System Tests\n")
        
        testBasicCommentFlow()
        testReplyFlow()
        testLikeAndSaveFlow()
        testQuoteFlow()
        testReportingFlow()
        
        print("🎉 All Manual Tests Complete!")
        print("\n📝 Next Steps:")
        print("1. Run these tests in the iOS Simulator")
        print("2. Test the UI components in the app")
        print("3. Verify CloudKit integration")
        print("4. Test on real device with multiple users")
    }
    
    // MARK: - UI Testing Helpers
    
    static func generateUITestData() -> (comments: [Comment], replies: [Comment]) {
        let comments = createTestComments()
        let replies = comments.isEmpty ? [] : createTestReplies(to: comments[0].commentID)
        return (comments, replies)
    }
    
    static func printCommentHierarchy(comments: [Comment], replies: [Comment]) {
        print("=== Comment Hierarchy ===")
        for comment in comments {
            print("💬 \(comment.username): \(comment.text.prefix(50))...")
            print("   👍 \(comment.likeCount) likes, 📌 \(comment.saveCount) saves")
            
            let commentReplies = replies.filter { $0.parentCommentID == comment.commentID }
            for reply in commentReplies {
                print("  └─ 💬 \(reply.username): \(reply.text.prefix(40))...")
                print("     👍 \(reply.likeCount) likes, 📌 \(reply.saveCount) saves")
            }
            print("")
        }
        print("========================")
    }
}

// MARK: - Performance Testing

struct CommentPerformanceTester {
    
    static func measureCommentCreation(count: Int = 1000) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<count {
            let record = CKRecord(recordType: "Comment")
            record["commentID"] = "perf-\(i)"
            record["text"] = "Performance test comment \(i)"
            record["dateCreated"] = Date()
            record["userID"] = "user-\(i % 10)"
            record["username"] = "User\(i % 10)"
            record["urlString"] = "https://example.com/perf-test"
            record["likeCount"] = 0
            record["saveCount"] = 0
            record["isReported"] = 0
            record["reportCount"] = 0
            
            _ = try? Comment(record: record)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let timeElapsed = endTime - startTime
        
        print("⚡ Created \(count) comments in \(String(format: "%.3f", timeElapsed)) seconds")
        print("⚡ Average: \(String(format: "%.6f", timeElapsed / Double(count))) seconds per comment")
    }
    
    static func measureCloudKitConversion(count: Int = 1000) {
        let record = CKRecord(recordType: "Comment")
        record["commentID"] = "conversion-test"
        record["text"] = "Test conversion performance"
        record["dateCreated"] = Date()
        record["userID"] = "test-user"
        record["username"] = "TestUser"
        record["urlString"] = "https://example.com/test"
        record["likeCount"] = 5
        record["saveCount"] = 2
        record["isReported"] = 0
        record["reportCount"] = 0
        
        guard let comment = try? Comment(record: record) else {
            print("❌ Failed to create test comment for performance testing")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<count {
            _ = comment.toRecord()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let timeElapsed = endTime - startTime
        
        print("⚡ Converted \(count) comments to CloudKit in \(String(format: "%.3f", timeElapsed)) seconds")
        print("⚡ Average: \(String(format: "%.6f", timeElapsed / Double(count))) seconds per conversion")
    }
    
    static func runPerformanceTests() {
        print("🚀 Running Comment Performance Tests\n")
        
        measureCommentCreation(count: 1000)
        measureCloudKitConversion(count: 1000)
        
        print("\n🏁 Performance Tests Complete")
    }
}

// MARK: - Usage Example

/*
 To use these manual testing utilities:
 
 1. Add this file to your test target (for reference only)
 2. In your test file or app, call:
    - ManualTestingScript.runAllTests()
    - CommentPerformanceTester.runPerformanceTests()
 
 3. For UI testing:
    - Use ManualTestingScript.generateUITestData() to get test data
    - Use ManualTestingScript.printCommentHierarchy() to visualize structure
 
 4. These functions will help you verify:
    - Comment creation and properties
    - Reply threading
    - Like/save functionality
    - Quote features
    - Reporting system
    - Performance characteristics
 */