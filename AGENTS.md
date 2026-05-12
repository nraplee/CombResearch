# AGENTS.md

Canonical shared instructions for Codex and Claude Code in this repository. Keep this file concise, practical, and synchronized with the live handoff in `docs/agent-task.md`.

## Project Overview

TODO: Keep this paragraph current as the paper evolves.

Current summary: Wolfram Mathematica research project for probability distributions of pure simplicial complexes. Figure 2 at q=3 is complete. Current work centers on Figures 3-15, q=10 sampling/diagnostics, truth enumeration for reachable small `(p, q)` cells, MH validation, and manuscript integration.

## Repo Layout

- `src/` - Wolfram `.wl` scripts for compute, rendering, enumeration, MH sampling, probes, and checks.
- `src/reference/` - Figure 2 reference notebooks; do not edit unless explicitly asked.
- `ECGrav/` - vendored ECGrav paclet sources/snapshots, not a separate app.
- `data/` - generated CSV/WXF compute outputs; generally do not edit by hand.
- `figures/` - generated manuscript panels, previews, and review PDFs.
- `docs/` - pipeline docs, manuscript draft, plans, and handoff files.
- `logs/` - generated run logs.
- `archive/` - old renders, superseded data, and scratch tests.

This is a single-project repo rooted at `C:\CombResearch`; there are no major independent subprojects that need nested `AGENTS.md` files right now.

## Commands

Discovered package metadata: tracked `PacletInfo.wl` files under `ECGrav/`; no tracked `package.json`, `pyproject.toml`, `Cargo.toml`, Makefile, or similar build metadata was found.

Install/setup:

- No dependency installation step is defined for this repo.
- `wolframscript` must be on `PATH`.
- ECGrav is expected to be installed and loadable with `Needs["ECGrav`"]`.
- Do not add or install dependencies without asking first.

Main compute/render commands:

```powershell
wolframscript -file src\pure_simplicial_compute.wl
wolframscript -file src\pure_simplicial_compute_overnight.wl
powershell -ExecutionPolicy Bypass -File src\run_parallel.ps1
wolframscript -file src\render_all_figures.wl
```

Truth-enumeration and MH commands:

```powershell
wolframscript -file src\enumerate_truth.wl
wolframscript -file src\run_mh_chains.wl
wolframscript -file src\render_truth_overlay.wl
```

Checks/smoke tests:

```powershell
wolframscript -file src\test_streaming.wl
wolframscript -file src\test_streaming_bliss.wl
```

No lint or typecheck command is configured. Use targeted Wolfram scripts as checks. Avoid full overnight or large production runs unless the user asks.

## Coding Rules

- Prefer existing Wolfram patterns and helpers already in `src/`.
- Use `wolframscript -file` for non-trivial Wolfram execution; shell quoting around Wolfram backticks is fragile.
- Do not edit generated files in `data/`, `figures/`, or `logs/` unless explicitly asked.
- Do not edit Figure 2 reference notebooks in `src/reference/` unless explicitly asked.
- Never use `RandomFacetLabeledPureSimplicialComplex` for the facet-labeled distribution. Use verified reweighting or exact truth data where available.
- Keep changes narrowly scoped. Do not reformat unrelated files.
- Do not add dependencies without asking first.

## Testing and Checking Rules

- Before continuing prior work, inspect `git status --short` and relevant `git diff`.
- For documentation-only changes, `git diff -- AGENTS.md CLAUDE.md docs/agent-task.md` is usually enough.
- For code changes, run the smallest relevant Wolfram check or smoke script and record what ran in the handoff.
- Treat q=10 facet/unlabeled IS histograms with caution; ESS collapse is documented in `docs/PIPELINE.md`.

## Git and Worktree Rules

- The worktree may already contain user or agent changes. Do not revert changes you did not make.
- Inspect `git status --short` and relevant diffs before modifying files, especially when resuming prior work.
- Do not commit, push, branch, or clean generated files unless the user asks.
- If asked to create a branch, use the `codex/` prefix by default unless the user requests another name.

## Handoff Protocol

- `AGENTS.md` is canonical shared guidance.
- `CLAUDE.md` should import this file with `@AGENTS.md` and contain only Claude Code-specific notes.
- `docs/agent-task.md` is the live handoff. Update it when the goal, status, decisions, likely files, or validation commands change.
- At the start of a resumed session, read `docs/agent-task.md`, inspect git status/diff, then continue from the recorded state.
- At the end of substantial work, update `docs/agent-task.md` with what changed, what was checked, and what remains.

