---
name: git-commit
description: Create commits from only the changes made during the current agent session, using messages that match the repository's recent history. Use when the user asks to commit the current work or invokes $git-commit; do not use for pushing, amending, or unrelated pre-existing changes.
---

# Git Commit

Create clean commits containing all and only the hunks attributable to the
current session. Treat the request or skill invocation as authorization to stage
and commit those hunks, but not to push, amend, or alter other worktree changes.
Default to one commit, while following any commit grouping, ordering, wording,
or other guidance the user gave during the conversation.

Aim to finish the ordinary path within 20 seconds. Safety, repository hooks, and
an explicitly required check take precedence over that target.

## Fast path

1. In one read-only pass, inspect `git status --short`, the relevant diff, and
   the subjects of the last 20 commits with `git log -20 --format=%s`.
2. Identify session-owned hunks from the current conversation and tool history.
   Preserve modifications and untracked files that existed before this session.
   Do not treat an entire file as session-owned merely because one hunk is.
   Do not use timestamps alone to infer ownership.
3. Partition the hunks according to the user's guidance. For example, when the
   user asks for two commits, create two logical hunk sets in the requested
   grouping and order. If the grouping is unstated but follows clearly from the
   work, infer it; ask only when different groupings would materially change the
   result.
4. For each commit, stage only its hunks with `git add -p -- <paths>` or by
   applying an exact patch to the index. Use `git add -N -- <path>` first when an
   untracked file needs hunk staging. Split or edit overlapping hunks when
   necessary. Do not stage later commit groups early, and do not use whole-file
   `git add -- <path>` for tracked modifications. Never use `git add .`,
   `git add -A`, or an equivalent broad command, even when the user asks to
   commit every session change.
5. Before each commit, review the full `git diff --cached` and run
   `git diff --cached --check`. Confirm the index contains the complete current
   hunk group and nothing from another group or unrelated work.
6. Derive each subject from its staged result and commit it. Do not rerun broad
   tests that already passed during the session merely for this skill.
7. Confirm that all requested session hunks were committed. Report each commit
   hash and subject, plus any changes deliberately left uncommitted.

## Commit message

Infer conventions from the last 20 subjects: capitalization, tense, optional
scope prefixes, punctuation, and typical length. Match the dominant style while
describing the staged change specifically. Prefer a short single-line subject
when that is the repository norm; add a body only when recent comparable commits
do so or essential context would otherwise be lost.

Base the message on the staged diff and the user's current guidance rather than
blindly reusing the initial task wording. If the user supplies exact commit
messages, use them. Do not copy spelling mistakes from history merely to imitate
it.

## Guardrails

- If no session-owned changes remain, do not create an empty commit.
- If ownership is ambiguous and cannot be resolved from session context, ask the
  user rather than sweeping in unrelated changes.
- Do not skip hooks, amend an existing commit, push, force, stash, discard, or
  rewrite changes unless the user separately requests it.
- If a hook fails, preserve the staged state, report the failure concisely, and
  fix it only when the fix is clearly within the current task.
