# AGENTS.md

Canonical shared instructions for Codex and Claude Code in this repository. Keep this file concise, practical, and synchronized with the live handoff in `docs/agent-task.md`.

## Project Overview

TODO: Keep this paragraph current as the paper evolves.

Current summary: Wolfram Mathematica research project for probability distributions of pure simplicial complexes. Figure 2 at q=3 is complete. Truth grid is now 9 cells `{(2,4), (2,5), (2,6), (2,7), (3,4), (3,5), (3,6), (4,4), (4,5)}`. MH chains validated against truth at 8 of those (27/27 cell×target combinations pass L1 < 0.04); (4,5) MH pending. McKay canonical-augmentation enumerator (`src/streaming_enumerator_mckay.wl`) is the production path at p=4 — the cheap pipeline OOMs at (4,5) even sequentially. Current work centers on Figures 3-15, the (4,5) MH chains, cross-checking the (4,5) iso count = 5,532 against Dr. Betre's independent samples, and manuscript integration.

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
# Truth enumeration. Env knobs (added 2026-05-13):
#   COMB_TRUTH_CELLS="p,q;p,q;..."   restrict cells
#   COMB_TRUTH_PIPELINE=cheap|bliss|mckay   default cheap
#   COMB_TRUTH_PARALLEL=true|false   default true; set false for p=4 OOM avoidance
#   COMB_FORCE=1                     overwrite existing WXFs
# Non-cheap pipelines write to data/p{p}q{q}_truth_<pipeline>.wxf for
# side-by-side cross-validation. Cheap writes to p{p}q{q}_truth.wxf.
wolframscript -file src\enumerate_truth.wl

# MH chains. Same env knobs (COMB_MH_CELLS, COMB_MH_TARGETS, COMB_MH_NUMITER,
# COMB_MH_BURNIN, COMB_MH_THIN, COMB_MH_SEED, COMB_MH_KERNEL, COMB_FORCE).
wolframscript -file src\run_mh_chains.wl

# Parallel (4,5) MH launch (one process per target) + dashboard:
powershell -ExecutionPolicy Bypass -File src\run_p4q5_mh_parallel.ps1
powershell -ExecutionPolicy Bypass -File src\monitor_mh.ps1

# Validation: per-cell × target numV-marginal L1 between MH and truth.
# Env: COMB_VAL_CELLS, COMB_VAL_TARGETS, COMB_VAL_THRESHOLD (default 0.05).
wolframscript -file src\validate_mh_vs_truth.wl

# Render manuscript overlay panels (truth + MH + IS layers).
wolframscript -file src\render_truth_overlay.wl
```

Checks/smoke tests:

```powershell
wolframscript -file src\test_streaming.wl
wolframscript -file src\test_streaming_bliss.wl
wolframscript -file src\test_streaming_mckay.wl    # validates McKay on (2,4)+(3,4)
```

No lint or typecheck command is configured. Use targeted Wolfram scripts as checks. Avoid full overnight or large production runs unless the user asks.

## Coding Rules

- Prefer existing Wolfram patterns and helpers already in `src/`.
- Use `wolframscript -file` for non-trivial Wolfram execution; shell quoting around Wolfram backticks is fragile.
- Do not edit generated files in `data/`, `figures/`, or `logs/` unless explicitly asked.
- Do not edit Figure 2 reference notebooks in `src/reference/` unless explicitly asked.
- Never use `RandomFacetLabeledPureSimplicialComplex` for the facet-labeled distribution. Use verified reweighting or exact truth data where available.
- MH sampler vertex target uses `π_V(X) ∝ 1/C(N, numV(X))` (2026-05-14 fix). The earlier `π_V ∝ 1` was wrong by a `C(N, k)` factor and produced L1 = 0.85 vs truth at (3,5). Do NOT revert without re-deriving — see in-code comment at the vertex Switch branch of `mhStep` in `src/sampler_mh.wl`.
- At p=4 the cheap pipeline (`streamingEnumeratePure`) OOMs at (4,5) even sequential. Use `streamingEnumeratePureMcKay` for p=4 q≥5. Cheap is still fine at (4,4) and below.
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

