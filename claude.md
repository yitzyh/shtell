# Claude Context for Shtell

## Recent Progress

⏺ Created: /docs/MVP_ROADMAP.md

Contains:
- Current state (1.1.0 stable)
- MVP roadmap (1.1.x → 2.0.0)
- Next step: 1.1.1 vertical swipe
- Technical context
- Key files

## Tab Structure

**THIS TAB**: Progress tracking and coordination
**NEW TAB**: Development work for 1.1.1

## Next Session Tasks (For New Development Tab)

### START HERE: Test Current Stable Version (1.1.0)

**Priority 1: Investigate iPhone Screen Extension Issue**

Before starting 1.1.1 feature work, you must:

1. **Test on physical iPhone device**
   - Launch current stable version (1.1.0)
   - Document the screen extension issue (content extending past screen boundaries)
   - Take screenshots/notes of the problem
   - Report findings back to tracking tab

2. **Compare with Simulator behavior**
   - Test same version on iOS Simulator
   - Verify that issue does NOT occur in simulator
   - Document differences in behavior

3. **Root Cause Analysis**
   - Investigate why physical device behaves differently than simulator
   - Common causes to check:
     - Safe area insets not being respected
     - Frame calculations using wrong bounds
     - Constraint issues with device-specific layouts
     - Status bar/notch handling
   - Check layout constraints in relevant view files

4. **Fix and Verify**
   - Implement fix for screen extension issue
   - Test on both physical device and simulator
   - Ensure fix doesn't break existing functionality
   - Report completion to tracking tab

### After Fixing Current Issue: Proceed to 1.1.1 Vertical Swipe

See `/docs/MVP_ROADMAP.md` for:
- Feature requirements
- Technical implementation approach
- Files to modify
- Success criteria

## Progress Tracking

Updates will be recorded here by the tracking tab based on reports from the development tab.

**Status**: Ready to start 1.1.1 investigation and development

## Key Files
- `/docs/MVP_ROADMAP.md` - Project roadmap and technical context
- Relevant view files will be identified during testing
