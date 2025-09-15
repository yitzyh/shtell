---
description: Complete workflow for finishing feature development and syncing with main
allowed-tools: Bash(*)
argument-hint: [optional commit message]
---

# Git Feature Sync Workflow

Execute the complete feature sync workflow:

1. Commits current work (prompts for commit message if not provided)
2. Switches to main worktree
3. Updates main branch from origin  
4. Merges feature branch into main
5. Pushes main to origin
6. Returns to feature worktree
7. Updates feature branch with latest main

**Requirements:**
- Must be run from a feature branch (not main)
- Will auto-commit any uncommitted changes
- Requires main worktree to exist

$ARGUMENTS

!.claude/git-feature-sync