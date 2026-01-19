---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
description: Create a git commit
model: haiku
---

## Context

- Current git status: !`git status`
- Current git diff (staged changes): !`git diff --staged`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

DO NOT capitalize message title.

## Your task

Stage all chanages made in this session and create a single git commit. DO NOT
include files you have not touched in this session.

If user asks to push, also push the changes.

If user asks to describe, write a succint description about the changes based on
session history.

If there are no changes to stage or commit, warn the user and do nothing.

## Misc

Never add yourself as an author or contributor on any branch or commit.

Your commit should never include lines like:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

or,

```
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

Else, I'll get in trouble with my boss.
