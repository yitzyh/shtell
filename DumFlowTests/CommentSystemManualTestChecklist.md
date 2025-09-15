# Comment System Manual Testing Checklist

## Pre-Testing Setup
- [ ] Ensure you're signed into iCloud on the device/simulator
- [ ] Have multiple test URLs ready (different websites)
- [ ] Create test user accounts if needed for multi-user testing
- [ ] Clear app data if testing fresh state

## Basic Comment Functionality

### Comment Creation
- [ ] Navigate to a webpage in DumFlow
- [ ] Tap the comment button/icon
- [ ] Type a comment in the text field
- [ ] Tap "Post" or submit button
- [ ] **Expected**: Comment appears immediately with your username and timestamp
- [ ] **Expected**: Comment persists after closing and reopening the app
- [ ] **Expected**: Comment syncs across devices if using same iCloud account

### Comment Display
- [ ] Verify comments show proper formatting (text, username, date)
- [ ] Check sorting options (newest/oldest first)
- [ ] Scroll through multiple comments to test performance
- [ ] **Expected**: Smooth scrolling with no lag
- [ ] **Expected**: Proper date formatting and relative time display

### Empty States
- [ ] Visit a page with no comments
- [ ] **Expected**: Shows "No comments" or similar empty state message
- [ ] Post the first comment on a page
- [ ] **Expected**: Empty state disappears and comment appears

## Reply Functionality

### Basic Replies
- [ ] Tap "Reply" on an existing comment
- [ ] Type a reply message
- [ ] Submit the reply
- [ ] **Expected**: Reply appears nested under the parent comment
- [ ] **Expected**: Reply shows "Reply to @username" or similar indication

### Reply Threading
- [ ] Create multiple levels of replies (reply to a reply)
- [ ] **Expected**: Proper visual indentation for nested replies
- [ ] **Expected**: Can expand/collapse reply threads
- [ ] Test "View all replies" functionality if there are many replies
- [ ] **Expected**: Smooth animations when expanding/collapsing

### Reply Navigation
- [ ] Tap on a reply to highlight it
- [ ] Use any "Go to parent" functionality
- [ ] **Expected**: Proper navigation between parent and child comments

## Like Functionality

### Basic Liking
- [ ] Tap the heart/like button on a comment
- [ ] **Expected**: Button changes state (filled heart, color change)
- [ ] **Expected**: Like count increases by 1
- [ ] **Expected**: Change is immediate (no loading delay)

### Unlike Functionality
- [ ] Tap the like button on a comment you've already liked
- [ ] **Expected**: Button returns to unliked state
- [ ] **Expected**: Like count decreases by 1

### Like Persistence
- [ ] Like a comment, close the app, reopen
- [ ] **Expected**: Like state is preserved
- [ ] Check on different device with same account
- [ ] **Expected**: Likes sync across devices

### Multiple User Likes
- [ ] Have another user like the same comment
- [ ] **Expected**: Like count reflects all likes
- [ ] **Expected**: Your like state is independent of others

## Save Functionality

### Basic Saving
- [ ] Tap the bookmark/save button on a comment
- [ ] **Expected**: Button changes to "saved" state
- [ ] **Expected**: Save count increases if displayed

### Unsaving
- [ ] Tap save button on a previously saved comment
- [ ] **Expected**: Button returns to unsaved state
- [ ] **Expected**: Save count decreases if displayed

### Save Persistence
- [ ] Save a comment, close app, reopen
- [ ] **Expected**: Save state is preserved
- [ ] Check if there's a "Saved Comments" section in user profile
- [ ] **Expected**: Saved comments appear in saved list

### Save Accessibility
- [ ] Navigate to saved comments from user profile or settings
- [ ] **Expected**: Easy access to all saved comments
- [ ] **Expected**: Can unsave from saved comments list

## Quote Functionality (Advanced)

### Text Selection Quoting
- [ ] Select text on a webpage
- [ ] Start creating a comment with selected text
- [ ] **Expected**: Selected text appears as a quote in comment
- [ ] **Expected**: Quote is visually distinct from regular comment text

### Quote Display
- [ ] View comments with quotes
- [ ] **Expected**: Quoted text is clearly formatted (different color, indentation, etc.)
- [ ] **Expected**: Can tap quote to navigate back to original text location

## User Interface Testing

### Keyboard Handling
- [ ] Start typing a comment
- [ ] **Expected**: Keyboard appears smoothly
- [ ] **Expected**: Comment box resizes appropriately
- [ ] **Expected**: Can scroll to see your comment while typing

### Gesture Navigation
- [ ] Test swipe gestures while in comment view
- [ ] **Expected**: Gestures don't conflict with comment interactions
- [ ] **Expected**: Can swipe back to webpage view

### Accessibility
- [ ] Test with VoiceOver enabled
- [ ] **Expected**: All buttons and text are properly labeled
- [ ] **Expected**: Can navigate comment threads with accessibility tools

## Error Handling & Edge Cases

### Network Issues
- [ ] Turn off internet, try to post a comment
- [ ] **Expected**: Appropriate error message
- [ ] **Expected**: Comment is queued and posts when connection returns

### Long Comments
- [ ] Type a very long comment (500+ characters)
- [ ] **Expected**: Text field expands appropriately
- [ ] **Expected**: Comment displays properly when posted

### Special Characters
- [ ] Include emojis, special characters, and different languages in comments
- [ ] **Expected**: All characters display correctly
- [ ] **Expected**: No encoding issues

### Rapid Actions
- [ ] Quickly tap like/unlike multiple times
- [ ] **Expected**: Actions are processed correctly without duplication
- [ ] **Expected**: UI state remains consistent

## Performance Testing

### Load Testing
- [ ] Visit a page with many comments (20+)
- [ ] **Expected**: Comments load reasonably quickly
- [ ] **Expected**: Smooth scrolling through long comment lists

### Memory Testing
- [ ] Navigate between multiple pages with comments
- [ ] **Expected**: App doesn't crash or slow down significantly
- [ ] **Expected**: Memory usage remains stable

## Multi-User Testing

### Real-time Updates
- [ ] Have another user comment on the same page
- [ ] **Expected**: New comments appear without manual refresh (if real-time is implemented)
- [ ] **Expected**: Like/save counts update when others interact

### User Identification
- [ ] Comment as different users
- [ ] **Expected**: Comments clearly show which user posted them
- [ ] **Expected**: Can't edit/delete other users' comments

## Data Persistence

### App Backgrounding
- [ ] Start typing a comment, background the app, return
- [ ] **Expected**: Draft comment is preserved
- [ ] **Expected**: Posted comments are still visible

### App Restart
- [ ] Post comments, force quit app, reopen
- [ ] **Expected**: All comments are preserved
- [ ] **Expected**: Like/save states are maintained

### Device Restart
- [ ] Post comments, restart device, open app
- [ ] **Expected**: Comments persist through device restart

## Integration Testing

### WebView Integration
- [ ] Ensure comment button is accessible while browsing
- [ ] **Expected**: Seamless transition between browsing and commenting
- [ ] **Expected**: Can return to webpage without losing comment view state

### User Profile Integration
- [ ] Check if comments appear in user profile/activity
- [ ] **Expected**: User can view their comment history
- [ ] **Expected**: Proper attribution of comments to user account

## Reporting & Moderation

### Comment Reporting
- [ ] Find or create inappropriate content
- [ ] Use report functionality
- [ ] **Expected**: Report is submitted successfully
- [ ] **Expected**: Appropriate confirmation message

### Moderated Content
- [ ] Check if reported content is handled appropriately
- [ ] **Expected**: Moderated comments are hidden or marked

## Testing Checklist Summary

**Total Tests**: 70+ individual test cases
**Critical Areas**: 
- ✅ Comment Creation & Display
- ✅ Reply Threading
- ✅ Like/Unlike Operations
- ✅ Save/Unsave Operations
- ✅ UI/UX Responsiveness
- ✅ Data Persistence
- ✅ Error Handling

## Quick Test Scenarios (5-minute tests)

### Scenario 1: Basic Flow
1. Open DumFlow, navigate to any webpage
2. Post a comment
3. Like your own comment
4. Save your own comment
5. Close and reopen app
6. Verify comment, like, and save state persisted

### Scenario 2: Reply Flow
1. Find an existing comment or post one
2. Reply to the comment
3. Reply to your reply (nested)
4. Like the original comment and both replies
5. Test expand/collapse thread functionality

### Scenario 3: Multi-Page Flow
1. Comment on Page A
2. Navigate to Page B, comment there
3. Return to Page A
4. Verify original comment is still there
5. Check that Page B comment doesn't appear on Page A

### Scenario 4: Quote Flow (if implemented)
1. Select text on a webpage
2. Start comment with selected text
3. Add your own commentary
4. Post comment with quote
5. Verify quote formatting in posted comment

**Pass Criteria**: All scenarios complete without crashes, data loss, or UI issues.