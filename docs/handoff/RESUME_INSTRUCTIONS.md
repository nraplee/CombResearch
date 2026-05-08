# Resume This Session on Another Machine

This file lets you pick up the Claude Code session that produced this PR on a different machine. You will get back the full conversation transcript so the model has context for the work.

## What's in here

- `3c923d56-de2e-4a1f-a72d-a3ca7adccbff.jsonl` — the Claude Code conversation transcript at the time of this PR. Plaintext JSONL.
- This file.

## How to resume

1. **On the target machine, install Claude Code** (`claude --version` to verify; instructions at https://claude.com/claude-code if missing).

2. **Clone or pull the repo and check out this branch** so the working tree matches what the conversation references:
   ```
   git clone https://github.com/nraplee/CombResearch.git
   cd CombResearch
   git checkout claude/adoring-hoover-18d09b
   ```

3. **Find the local Claude Code project folder name** on the target machine. Claude Code derives the folder name from the absolute path of the working directory by replacing `\` and `/` and `:` with `-`. List existing project folders:
   ```
   ls ~/.claude/projects/
   ```
   You'll see one named after where you cloned (e.g. `-Users-name-CombResearch` or `C--CombResearch`). If no folder exists yet, just run `claude` once in the worktree to create it; then exit.

4. **Drop the JSONL into that folder** with its original filename:
   ```
   cp docs/handoff/3c923d56-de2e-4a1f-a72d-a3ca7adccbff.jsonl \
      ~/.claude/projects/<your-project-folder-name>/
   ```
   On Windows PowerShell:
   ```powershell
   Copy-Item docs\handoff\3c923d56-de2e-4a1f-a72d-a3ca7adccbff.jsonl `
     "$HOME\.claude\projects\<your-project-folder-name>\"
   ```

5. **Resume the session.** From the worktree:
   ```
   claude --resume 3c923d56-de2e-4a1f-a72d-a3ca7adccbff
   ```
   Or if your CLI version doesn't accept the session ID directly, use `claude --list-sessions` to confirm it's visible, then `--resume` per its documented syntax.

## Caveats

- **Plaintext.** The JSONL contains the full conversation including file paths and code excerpts. Don't push to a public repo without reviewing.
- **Snapshot, not live.** This file is the transcript at the moment of this PR — anything that happened after the PR was opened is not in here. If you keep working on the original machine and want to re-sync, copy a fresh JSONL from `~/.claude/projects/<original-project-folder-name>/<session-id>.jsonl`.
- **No background processes.** Resume restores conversation context; running compute jobs, subkernels, etc. do not carry over.
- **Working tree.** The conversation references file states at various points; the git branch (this PR) carries the corresponding code. Make sure the branch is checked out before resuming.

## Session metadata

- Session ID: `3c923d56-de2e-4a1f-a72d-a3ca7adccbff`
- Originating worktree: `C:\CombResearch\.claude\worktrees\adoring-hoover-18d09b`
- Originating branch: `claude/adoring-hoover-18d09b`
