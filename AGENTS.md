# AGENTS.md

Canonical shared instructions for Codex and Claude Code in this repository. Keep this file concise, practical, and synchronized with the live handoff in `docs/agent-task.md`.

## Project Overview

TODO: Keep this paragraph current as the paper evolves.

Current summary: Wolfram Mathematica research project for probability distributions of pure simplicial complexes. Figure 2 at q=3 is complete. Truth grid is now 9 cells `{(2,4), (2,5), (2,6), (2,7), (3,4), (3,5), (3,6), (4,4), (4,5)}`. MH chains validate against truth for all 27 cell×target combinations at L1 < 0.05. McKay canonical-augmentation enumeration (`src/streaming_enumerator_mckay.wl`) is the production path at p=4; the cheap pipeline OOMs at (4,5) even sequentially. Current work centers on manuscript integration, cross-checking the (4,5) iso count = 5,532 against Dr. Betre's independent samples, and deciding whether to attempt (4,6).

## Repo Layout

- `src/` - Wolfram `.wl` scripts for compute, rendering, enumeration, MH sampling, probes, and checks.
- `src/reference/` - Figure 2 reference notebooks; do not edit unless explicitly asked.
- `ECGrav/` - vendored ECGrav paclet sources/snapshots, not a separate app.
- `data/` - generated CSV/WXF compute outputs; generally do not edit by hand.
- `figures/` - generated manuscript panels, previews, and review PDFs.
- `docs/` - consolidated technical docs, manuscript draft, and live handoff.
- `logs/` - generated run logs.
- `archive/` - old renders, superseded data, scratch tests, and archived probes.

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

q=10 IS-vs-MH comparison (no truth at q=10):

```powershell
# Aggregate the merged 12M-row IS data into 9 small numV histograms
# (one per p in {2,3,4} x target in {vertex, unlabeled, facet}).
wolframscript -file src\precompute_is_histograms_q10.wl

# Sequential 10k-iter MH pilot, all 9 (p, target) at q=10.
powershell -ExecutionPolicy Bypass -File src\run_q10_mh_pilot.ps1

# 200k-iter production chains for the 4 IS-vs-MH disagreement cells
# (p in {3,4} x target in {unlabeled, facet}), launched in parallel.
powershell -ExecutionPolicy Bypass -File src\run_q10_mh_parallel.ps1

# Per-cell ASCII overlay + L1 summary, IS vs MH at q=10.
wolframscript -file src\compare_is_mh_q10.wl

# 3-way comparison at q=5 truth cells (3,5) and (4,5): IS, MH, truth.
wolframscript -file src\run_is_at_truth_cells.wl    # 100k IS samples each
wolframscript -file src\compare_3way.wl             # per-cell L1 table
wolframscript -file src\render_3way.wl              # 2x3 overlay grid PNG

# Warm-start + second-seed disambiguation at q=10 disagreement cells.
# 4 chains x 1M iters in parallel, ~5 hr wall.
powershell -ExecutionPolicy Bypass -File src\run_q10_mh_overnight.ps1
wolframscript -file src\compare_q10_warm_vs_prod.wl  # per-cell L1 table
wolframscript -file src\render_q10_warm_vs_prod.wl   # 2x2 grouped-bar PNG
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
- Treat q=10 facet/unlabeled IS histograms with caution; ESS collapse is documented in `docs/sampling.md`.

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
- **Every commit that ships meaningful work MUST include corresponding updates to `docs/agent-task.md`** (status, decisions, files touched, next steps) and to `AGENTS.md` (commands list, coding rules, project overview) when applicable. Stage and commit the handoff updates in the same commit as the work they describe — never as a follow-up. A commit that updates code without refreshing the handoff is treated as incomplete by either agent.
- At the end of substantial work, also re-confirm `docs/agent-task.md` reflects exactly what changed, what was checked, and what remains.

