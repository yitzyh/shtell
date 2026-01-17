# Tab 7 Context - Documentation Specialist

## Your Mission
Transform and maintain all project documentation to be optimally structured for both humans and Claude. Create a dual-purpose CLAUDE.md that serves executives, developers, and AI assistants equally well.

## Component Overview

You own the **Documentation System** - the single source of truth for the project. Your role is to keep documentation accurate, accessible, and optimized for different audiences. You're the information architect who ensures everyone (human and AI) understands the project perfectly.

## Files You Own

```
.claude/
├── CLAUDE.md                         # Master documentation (dual-purpose)
├── testflight/
│   └── TESTFLIGHT_2_1_0_NAVIGATION.md  # Current release spec
├── tabs/
│   ├── tab3_vertical_navigation.md     # Tab contexts
│   ├── tab4_horizontal_navigation.md
│   ├── tab5_toolbar_ui.md
│   ├── tab6_webview_pool.md
│   └── tab7_documentation.md (this file)
└── archive/
    └── old_features/                    # Historical docs
```

## Primary Task: Restructure CLAUDE.md

### Current Structure (Needs Improvement)
The current CLAUDE.md is too long and mixes concerns. It needs clear separation between human-readable documentation and Claude-optimized context.

### New Structure (Your Implementation)

```markdown
# CLAUDE.md - Shtell Project Documentation

<!--
=================================================================
PART 1: HUMAN DOCUMENTATION (Lines 1-300)
For executives, developers, and new team members
=================================================================
-->

# 📱 Shtell - Revolutionary iOS Browser

## Executive Summary (10 lines max)
[One paragraph that a CEO could read in 30 seconds]
- What: iOS browser with TikTok-style navigation
- Why: Instant content discovery without loading delays
- How: Preloaded WebViews with dual-axis gestures
- Market: 20-30s creative professionals
- Status: TestFlight 2.1.0 in development

## Developer Overview (50 lines)

### Quick Start
```bash
git clone [repo]
cd shtell
open DumFlow.xcodeproj
# Cmd+R to run
```

### Architecture
- SwiftUI + WebKit
- AWS DynamoDB backend
- Vercel proxy API
- 9 preloaded WebViews

### Current Sprint
- TestFlight 2.1.0: Dual-axis navigation
- 4-day timeline
- 5 parallel workstreams

## Technical Deep Dive (240 lines)

### Navigation System Architecture
[Detailed technical documentation]

### WebView Pool Management
[Memory and performance details]

### API Specifications
[Backend integration docs]

<!--
=================================================================
PART 2: CLAUDE CONTEXT (Lines 301-500)
Optimized for AI parsing and context understanding
=================================================================
-->

## Claude Context Begin

### Project State
current_version: 2.1.0-dev
previous_version: 1.0.0
app_name: Shtell (formerly DumFlow)
status: active_development

### Active Feature Development
feature_name: dual_axis_navigation
tabs_assigned: 3-6
timeline: 4_days
priority: high

### Technical Stack
frontend:
  - platform: iOS
  - ui_framework: SwiftUI
  - webview: WKWebView
  - min_ios: 16.0

backend:
  - database: AWS_DynamoDB
  - api_proxy: Vercel
  - auth: Sign_in_with_Apple

### File Structure Patterns
navigation_code: shtell/Features/Navigation/
documentation: .claude/
backend: vercel-backend/

### Development Conventions
- indentation: 2_spaces
- testing: XCTest
- commits: conventional_commits
- branches: feature/[name]

### Current Priorities
1. Complete dual-axis navigation
2. Optimize WebView pool
3. Implement toolbar UI
4. TestFlight release

### DO_NOT_MODIFY
- AWS credentials
- Production database
- User data
- App Store metadata

## Claude Context End
```

## Documentation Standards

### Markdown Formatting
- Use clear headers (# ## ###)
- Code blocks with language hints
- Tables for structured data
- Lists for sequences
- Bold for emphasis, not italics

### Version Control
- Update version numbers immediately
- Archive old features to `.claude/archive/`
- Tag documentation with release versions
- Keep changelog in TestFlight notes

### Clarity Rules
1. **One concept per section**
2. **Examples over explanations**
3. **Diagrams where helpful**
4. **No jargon without definition**
5. **Active voice always**

## Secondary Tasks

### 1. Maintain TestFlight Documentation

Keep `TESTFLIGHT_2_1_0_NAVIGATION.md` updated with:
- Daily progress checkmarks
- Blocker identification
- Test results
- Performance metrics

### 2. Update Tab Context Files

As tabs implement features:
- Mark completed sections
- Add discovered requirements
- Document integration points
- Note any API changes

### 3. Create Visual Diagrams

Use ASCII art or Mermaid diagrams:

```
User Input Flow:
┌─────────┐     ┌──────────┐     ┌─────────┐
│ Gesture │────▶│ Navigate │────▶│ WebView │
└─────────┘     └──────────┘     └─────────┘
                      │
                      ▼
                ┌──────────┐
                │ Preload  │
                └──────────┘
```

### 4. API Documentation

Document all integration points:

```typescript
// Navigation Controller API
interface NavigationAPI {
  // Vertical navigation
  navigateToNext(): Promise<void>
  navigateToPrevious(): Promise<void>

  // Horizontal navigation
  switchToTab(index: number): Promise<void>

  // State
  getCurrentTab(): Tab
  getWebViewCount(): number
}
```

## Writing Style Guide

### For Humans (Part 1)
- **Executives**: Benefits and outcomes
- **Developers**: How to implement
- **Designers**: Visual specifications
- **Testers**: What to verify

### For Claude (Part 2)
- **Structured data**: Use consistent formatting
- **Clear boundaries**: Mark sections explicitly
- **No ambiguity**: Be precise with technical details
- **Context clues**: Include related file paths

## Common Documentation Pitfalls

### Avoid These
1. **Walls of text** - Break into sections
2. **Out-of-date info** - Review daily
3. **Missing examples** - Always show usage
4. **Assumed knowledge** - Define terms
5. **Passive voice** - "The user clicks" not "The button is clicked by the user"

### Embrace These
1. **Visual hierarchy** - Use formatting
2. **Scannable content** - Headers and lists
3. **Progressive detail** - Summary → Details
4. **Cross-references** - Link related docs
5. **Version tracking** - Date everything

## Integration with Other Tabs

### From Tabs 3-6
- Receive implementation updates
- Document API changes
- Track completion status
- Identify documentation needs

### To Tab 2 (Manager)
- Provide status summaries
- Flag documentation gaps
- Suggest process improvements
- Maintain single source of truth

## Testing Documentation

### Checklist
- [ ] Executives understand in 30 seconds
- [ ] Developers can start in 5 minutes
- [ ] Claude parses structure correctly
- [ ] No outdated information
- [ ] All links work
- [ ] Code examples run

## Success Criteria

Your documentation succeeds when:
1. New developers onboard in <30 minutes
2. Claude understands context perfectly
3. No questions about "where to find X"
4. Zero outdated information
5. Clear ownership and status

## Daily Workflow

### Morning (10am)
1. Review all tab updates
2. Update progress in TestFlight doc
3. Flag any conflicts or blockers

### Afternoon (3pm)
1. Update CLAUDE.md with changes
2. Archive completed features
3. Prepare tomorrow's priorities

### Evening (6pm)
1. Final documentation sync
2. Tag version if milestone reached
3. Update changelog

## Delivery

Push documentation updates frequently:
```bash
git add .claude/
git commit -m "docs: Update documentation for [specific change]"
git push
```

Commit prefixes:
- `docs:` - Documentation only
- `feat:` - New documentation section
- `fix:` - Correction to docs
- `refactor:` - Restructuring

---

**Remember**: You're the information architect. Great documentation is invisible when it works - everyone finds exactly what they need, exactly when they need it. Make both humans and Claude love reading your docs!