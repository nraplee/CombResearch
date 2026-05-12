# Current Agent Task

## Goal

Set up shared agent instructions so Codex and Claude Code can work interchangeably in this repo.

## Current status

Complete.

## Decisions made

- `AGENTS.md` is the canonical shared instruction file.
- `CLAUDE.md` imports `AGENTS.md`.
- This file tracks live task state between agents.

## Files likely involved

- `AGENTS.md`
- `CLAUDE.md`
- `docs/agent-task.md`

## Commands/checks to run

```bash
git status --short
git diff
```

## Handoff notes

Before continuing, the next agent must:

1. Read `AGENTS.md`.
2. Read `CLAUDE.md` if using Claude Code.
3. Read this file.
4. Run `git status --short`.
5. Inspect `git diff`.
6. Continue from the current repo state, not hidden chat history.

## Last updated by

Codex on 2026-05-12

## Then when switching tools

When you switch from Claude to Codex:

```text
Read AGENTS.md and docs/agent-task.md. Run git status --short and git diff. Continue from the current repo state. Do not restart the task from scratch.
```

When you switch from Codex to Claude Code:

```text
Read CLAUDE.md, AGENTS.md, and docs/agent-task.md. Run git status --short and inspect the diff. Continue from the current repo state. Do not restart the task from scratch.
```
