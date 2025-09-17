# TestFlight 1.1.7 Monitoring Commands
*Reference guide for monitoring agent operations*

## 🔍 Status Check Commands

### GitHub Integration
```bash
# Check 1.1.7 issues
gh issue list --label "1.1.7" --state all --json number,title,state,labels

# Monitor critical issues
gh issue view 1 --json title,state,labels,body
gh issue view 3 --json title,state,labels,body
gh issue view 4 --json title,state,labels,body

# Check PR status
gh pr list --state all --json number,title,state,labels,baseRefName

# Recent commits on all branches
git log --oneline --since="1 week ago" --all --graph --decorate

# Branch comparison
git log main..browse-forward-ux --oneline
```

### Implementation Verification
```bash
# Verify preload manager implementation
find /Users/isaacherskowitz/Swift/_DumFlow/DumFlow -name "*PreloadManager*" -type f

# Check pull-forward integration points
grep -r "useInstantDisplay\|browseForward.*true" DumFlow --include="*.swift"

# Verify WebView handoff system
grep -r "preloadManager\|hasPreloadedContent" DumFlow --include="*.swift"

# Check gesture integration
grep -r "handleRefresh\|refreshControl" DumFlow --include="*.swift"

# Memory management verification
grep -r "deinit\|cleanup\|removeFromSuperview" DumFlow/Features/BrowseForward/ --include="*.swift"
```

### Agent Coordination
```bash
# List all agents
ls -la /Users/isaacherskowitz/Swift/_DumFlow/DumFlow/.claude/agents/

# Check monitoring dashboard status
ls -la /Users/isaacherskowitz/Swift/_DumFlow/DumFlow/.claude/monitoring/

# Git status for uncommitted monitoring changes
git status | grep -E "(monitoring|agents)"
```

### Timeline & Progress Tracking
```bash
# Count Swift files in BrowseForward feature
find DumFlow/Features/BrowseForward -name "*.swift" | wc -l

# Check recent file modifications
find DumFlow/Features/BrowseForward -name "*.swift" -mtime -7 -exec ls -la {} \;

# Count implementation completeness markers
grep -r "COMPLETE\|TODO\|FIXME" DumFlow/Features/BrowseForward/ --include="*.swift" | wc -l
```

## 📊 Performance Monitoring

### Memory Usage Analysis
```bash
# Check for memory leaks in preload system
grep -r "weak\|strong\|retain" DumFlow/Features/BrowseForward/ --include="*.swift"

# Verify cleanup implementations
grep -r "cleanup\|deinit" DumFlow/Features/BrowseForward/ --include="*.swift"

# Check WebView pool management
grep -r "backgroundWebView\|webView.*nil" DumFlow/Features/BrowseForward/ --include="*.swift"
```

### Debug Logging Verification
```bash
# Check debug logging implementation
grep -r "DEBUG\|preloadLog\|BROWSE_FORWARD_LOGS" DumFlow --include="*.swift"

# Verify environment variable usage
grep -r "ProcessInfo\|environment" DumFlow --include="*.swift"
```

## 🚨 Critical Issue Monitoring

### Security Assessment
```bash
# Search for hardcoded credentials (Issue #1)
grep -r -i "aws.*key\|secret" --exclude-dir=.git --exclude="*.md" .

# Check Info.plist for sensitive data
grep -r -A5 -B5 "AWS\|key\|secret" *.plist 2>/dev/null || echo "No plist files found"

# Verify credential management
grep -r "credential\|auth\|token" DumFlow --include="*.swift" | grep -v "comment"
```

### iOS Compatibility Check (Issue #3)
```bash
# Find deprecated API usage
grep -r "@available\|deprecated\|iOS.*version" DumFlow --include="*.swift"

# Check deployment target consistency
grep -r "iOS.*Deployment\|IPHONEOS_DEPLOYMENT_TARGET" . --include="*.pbxproj"
```

### Navigation Issues (Issue #4)
```bash
# Check comment system integration
find DumFlow -name "*Comment*" -type f | grep -v ".git"

# Scroll position management
grep -r "scrollTo\|contentOffset\|scrollView" DumFlow --include="*.swift"
```

## 🎯 Testing Verification

### Integration Testing
```bash
# Check test files exist
find . -name "*Test*" -type f | grep -v ".git"

# Manual test checklist
ls -la DumFlowTests/ 2>/dev/null || echo "Test directory not found"

# Simulator/device testing preparation
xcrun simctl list devices | grep "iPhone.*Booted"
```

### Build System Check
```bash
# Verify build configuration
xcodebuild -project DumFlow.xcodeproj -list

# Check scheme configuration
cat DumFlow.xcodeproj/xcshareddata/xcschemes/DumFlow.xcscheme | grep -A5 -B5 "buildConfiguration"

# Build and test capability
xcodebuild -project DumFlow.xcodeproj -scheme DumFlow -configuration Debug -dry-run
```

## 📅 Daily Monitoring Routine

### Morning Status Check
```bash
# Full status pipeline
echo "=== GITHUB STATUS ==="
gh issue list --label "1.1.7" --state open --json number,title
echo "=== BRANCH STATUS ==="
git status --porcelain
echo "=== IMPLEMENTATION STATUS ==="
find DumFlow/Features/BrowseForward -name "*.swift" -mtime -1 | wc -l
echo "=== CRITICAL ISSUES ==="
grep -r "FIXME\|TODO\|CRITICAL" DumFlow/Features/BrowseForward/ --include="*.swift" | wc -l
```

### Weekly Progress Report
```bash
# Generate comprehensive report
echo "=== WEEKLY PROGRESS REPORT ===" > weekly-report.txt
echo "Generated: $(date)" >> weekly-report.txt
echo "" >> weekly-report.txt
echo "GITHUB ISSUES:" >> weekly-report.txt
gh issue list --label "1.1.7" --state all --json number,title,state >> weekly-report.txt
echo "" >> weekly-report.txt
echo "COMMITS THIS WEEK:" >> weekly-report.txt
git log --since="1 week ago" --oneline >> weekly-report.txt
echo "" >> weekly-report.txt
echo "IMPLEMENTATION FILES:" >> weekly-report.txt
find DumFlow/Features/BrowseForward -name "*.swift" -exec wc -l {} + >> weekly-report.txt
```

## 🎬 Automated Monitoring Setup

### Git Hooks (Optional)
```bash
# Pre-commit monitoring
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "🔍 TestFlight 1.1.7 Pre-commit Check"
# Check for hardcoded credentials
if grep -r "AKIAUON2G4CIEFYOZEJX\|SVMqfKzPRgtLbL9JijZqQegrp" . --exclude-dir=.git; then
    echo "🚨 CRITICAL: Hardcoded AWS credentials detected!"
    exit 1
fi
echo "✅ Security check passed"
EOF
chmod +x .git/hooks/pre-commit
```

### Environment Setup for Debugging
```bash
# Set debug flags for comprehensive logging
export DYNAMO_LOGS=1
export NETWORK_LOGS=1
export AWS_LOGS=1
export BROWSE_FORWARD_LOGS=1
export MEMORY_LOGS=1
```

---
*Command reference for testflight-1-1-7 monitoring agent*
*Last updated: 2025-09-16*