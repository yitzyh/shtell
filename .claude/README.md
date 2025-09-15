# Claude Code Slash Commands for Git/Worktree Management

This directory contains 4 custom Claude Code slash commands for managing your git worktree workflow.

## Available Commands

### `/git-status`
**Purpose:** Show current branch, worktree path, and recent commits
**Output:**
- Current location and branch
- Current worktree information
- Last 5 commits
- Working tree status
- Sync status with origin

### `/git-branches`
**Purpose:** List all branches and worktrees with their locations
**Output:**
- All worktrees with current branch highlighted
- All local branches with worktree indicators
- Remote branches (first 10)

### `/git-worktrees`
**Purpose:** Show detailed overview of all worktrees and their status
**Output:**
- All worktrees with their branches
- Status of each worktree (clean, uncommitted changes, etc.)
- Sync status for each branch

### `/git-feature-sync`
**Purpose:** Complete workflow for finishing feature development and syncing with main
**Workflow:**
1. Commits current work (prompts for commit message)
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

## Usage

Use these commands directly in Claude Code chat:

```
/git-status
/git-branches
/git-worktrees
/git-feature-sync
```

These commands are now properly registered as Claude Code slash commands through Markdown files in `.claude/commands/` that execute the corresponding bash scripts.

## Your Worktree Structure

Based on your current setup:
- `/Users/isaacherskowitz/Swift/_DumFlow/DumFlow` (main)
- `/Users/isaacherskowitz/Swift/_DumFlow/DumFlow-bottom-toolbar` (feature/bottom-toolbar)
- `/Users/isaacherskowitz/Swift/_DumFlow/DumFlow-pull-forward` (feature/pull-forward-aws)
- `/Users/isaacherskowitz/Swift/_DumFlow/DumFlow-pull-forward-main` (feature/pull-forward)
- `/Users/isaacherskowitz/Swift/_DumFlow/DumFlow-pull-forward-ui` (feature/pull-forward-ui)
- `/Users/isaacherskowitz/Swift/_DumFlow/DumFlow-top-toolbar` (top-toolbar)

## Safety Features

- `/git-feature-sync` validates you're not on main branch before starting
- All scripts handle errors gracefully
- Clear status messages throughout execution
- No destructive operations without confirmation