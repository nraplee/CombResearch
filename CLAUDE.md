# CLAUDE.md

Project instructions for Claude Code in this repository. Keep this file concise and practical.

## Project Overview

TODO: Keep this paragraph current as the paper evolves.

Current summary: Wolfram Mathematica research project for probability distributions of pure simplicial complexes. Figure 2 at q=3 is complete. Truth grid is now 9 cells `{(2,4), (2,5), (2,6), (2,7), (3,4), (3,5), (3,6), (4,4), (4,5)}`. MH chains validated against truth for all 27 cell×target combinations at L1 < 0.05 in May 2026, but the stored chains no longer back this: five vertex chains predate the vertex fix and (2,7), (3,6), (4,4) have none (`docs/architecture/provenance.md`). McKay canonical-augmentation enumeration (`src/streaming_enumerator_mckay.wl`) is the production path at p=4; the cheap pipeline OOMs at (4,5) even sequentially. Phase 5a (2026-09-26): ECGrav 1.17.0 validated against the truth grid. Its exact counters match our truth at every n on all 9 cells (confirming the (4,5) iso count 5,532), and its exact samplers (`RandomUniformUnlabeled…`, `RandomUniformFacetLabeled…`, `RandomVertexLabeled…`) pass all 27 cell×target combinations. `RandomPureSimplicialComplexMCMC` passes L1 but returns correlated samples for unlabeled. 2026-11-20 (Phase 1): every script loads the latest upstream ECGrav from one shared clone (`C:\CombResearch\ECGrav-upstream`, currently main @ 474b5c2); `tests/ecgrav_regression.wl` re-validates it against the truth grid. 2026-11-20: all generated outputs now live once in the main checkout (`src/comb_paths.wl`); worktrees no longer keep their own data. 2026-11-20 (Phase 2a): shared `src/lib_stats.wl` and `src/lib_io.wl`. Next: the rest of Phase 2 of `docs/architecture/implementation-plan.md` (names, config, manifests), the MH data fixes from `provenance.md`, then q=10 with the exact samplers as reference, then manuscript integration.

## Repo Layout

- `src/` - Wolfram `.wl` scripts for compute, rendering, enumeration, MH sampling, probes, and checks.
- `src/reference/` - Figure 2 reference notebooks; do not edit unless explicitly asked.
- `ECGrav-upstream/` (main checkout only, gitignored) - shared clone of upstream ECGrav that every script loads. No ECGrav sources are vendored in git.
- `data/` - generated CSV/WXF compute outputs; generally do not edit by hand. One shared copy lives in the main checkout (`C:\CombResearch\data` on the Ryzen PC), never in a worktree; see "Generated outputs" below.
- `figures/` - generated manuscript panels, previews, and review PDFs.
- `docs/` - consolidated technical docs, manuscript draft, and live handoff.
- `logs/` - generated run logs.
- `archive/` - old renders, superseded data, scratch tests, and archived probes.

This is a single-project repo rooted at `C:\CombResearch`; there are no major independent subprojects that need nested `CLAUDE.md` files right now.

## Commands

No tracked package or build metadata (`PacletInfo.wl`, `package.json`, `pyproject.toml`, Makefile, or similar); ECGrav comes from the shared upstream clone.

Install/setup:

- No dependency installation step is defined for this repo.
- `wolframscript` must be on `PATH`.
- Wolfram 15.0+ is required (ECGrav declares `WolframVersion -> "15.0+"`). Wolfram 15.0.1 is installed on both machines (i5 laptop and Ryzen 7 5800X PC; heavy runs go on the Ryzen).
- ECGrav: `wolframscript -file tools\dev\update_ecgrav.wl` clones github.com/kassabetre/ECGrav into `$CombRoot\ECGrav-upstream` on first use, then fast-forwards it to upstream main. Run it only between runs (running kernels keep the code they loaded), then run `wolframscript -file tests\ecgrav_regression.wl`: counters, aut/autF and exact samplers vs the truth grid, plus an MH smoke test (~10 min). A pass is recorded in `results\ecgrav_regression_passed.wl`; `load_ecgrav.wl` warns while the loaded commit has not passed.
- Every script loads ECGrav through `src/load_ecgrav.wl`, which `Get`s `Kernel/ECGrav.wl` from the shared clone; the globally installed paclet is never used. `COMB_ECGRAV_DIR=<checkout>` loads another ECGrav checkout instead (e.g. a fork branch being prepared for upstream). The loader sets `$CombECGravVersion` (e.g. `1.18.0-474b5c2`) and `$CombECGravCommit`, and aborts if a function this repo calls (`$CombECGravSymbols`) is missing. Old vendored snapshots (1.0.0, 1.17.0, 1.18.0-474b5c2) are in git history before Phase 1 (tag `pre-restructure`).
- Global paclet (notebooks, `src/reference/`, the Wolfram MCP server only): `wolframscript -file src\install_ecgrav_global.wl` installs the shared clone. Rerun it after `update_ecgrav.wl` moves the clone.
- Do not add or install dependencies without asking first.

Generated outputs (added 2026-11-20):

- Every script takes `data/`, `figures/` and `logs/` from `src/comb_paths.wl` (`$CombDataDir`, `$CombFiguresDir`, `$CombLogsDir`) or, in PowerShell launchers, `src/comb_paths.ps1`. These resolve to the main checkout (the parent of `git rev-parse --git-common-dir`) even when the script runs from a worktree. Code still runs from the checkout the script lives in. `COMB_ROOT` overrides the output root.
- Safety net: `src/sync_worktree_data.ps1` copies untracked/ignored files from every worktree's `data/`, `figures/`, `logs/` into the main checkout. It never overwrites or deletes; a file that differs from main's goes to `<dir>\_from_worktrees\<worktree>\` and is reported as a conflict. `-DryRun` previews. The committed `.claude/settings.json` runs it on Claude Code SessionStart and SessionEnd.

```powershell
powershell -ExecutionPolicy Bypass -File src\sync_worktree_data.ps1 -DryRun
```

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

# ECGrav 1.17 sampler campaign (Phase 5a).
#   COMB_ECG_SAMPLER=exact|mcmc|legacyfacet, COMB_ECG_CELLS, COMB_ECG_TARGETS,
#   COMB_ECG_N, COMB_ECG_SEED, COMB_ECG_TRACE_STEPS, COMB_FORCE
#   -> data/p{p}q{q}_ecg{sampler}_{target}.wxf
wolframscript -file src\validate_counts_vs_truth.wl   # ECGrav counters vs truth
wolframscript -file src\run_ecgrav_samplers.wl
powershell -ExecutionPolicy Bypass -File src\run_ecgrav_campaign.ps1   # 3 parallel targets
powershell -ExecutionPolicy Bypass -File src\monitor_ecgrav.ps1        # COMB_MON_SAMPLER
# Validate any sample source: COMB_VAL_SOURCE=mh|ecgexact|ecgmcmc|ecglegacyfacet
wolframscript -file src\validate_mh_vs_truth.wl
# ESS / ESS-per-second table across all sources (COMB_EFF_CELLS, COMB_EFF_TARGETS).
wolframscript -file src\compare_samplers_efficiency.wl
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
wolframscript -file tests\ecgrav_regression.wl     # ECGrav vs truth grid; after any ECGrav change
wolframscript -file tests\golden\golden_derived.wl check   # refactors must reproduce golden/derived
```

No lint or typecheck command is configured. Use targeted Wolfram scripts as checks. Avoid full overnight or large production runs unless the user asks.

## Coding Rules

- Prefer existing Wolfram patterns and helpers already in `src/`, and targeted edits that keep the repo's Wolfram style.
- Use `wolframscript -file` for non-trivial Wolfram execution; shell quoting around Wolfram backticks is fragile.
- Do not edit generated files in `data/`, `figures/`, or `logs/` unless explicitly asked.
- Do not edit Figure 2 reference notebooks in `src/reference/` unless explicitly asked.
- Never use `RandomFacetLabeledPureSimplicialComplex` for the facet-labeled distribution (still non-uniform in 1.17.0; it is the harness negative control). Use `RandomUniformFacetLabeledPureSimplicialComplex` (validated 2026-09-26) or exact truth data.
- Load ECGrav only through `src/load_ecgrav.wl` (`Get[FileNameJoin[{DirectoryName[$InputFileName], "load_ecgrav.wl"}]]`); never a bare `Needs["ECGrav`"]`. After `LaunchKernels[]` use `combLoadECGravOnKernels[]`, not `ParallelEvaluate[Needs["ECGrav`"]]`, so subkernels run the same checkout.
- Vertex MH WXFs copied from the `adoring-hoover-18d09b` worktree predate the vertex fix (L1 ~0.75). Rerun before use.
- MH sampler vertex target uses `π_V(X) ∝ 1/C(N, numV(X))` (2026-05-14 fix). The earlier `π_V ∝ 1` was wrong by a `C(N, k)` factor and produced L1 = 0.85 vs truth at (3,5). Do NOT revert without re-deriving — see in-code comment at the vertex Switch branch of `mhStep` in `src/sampler_mh.wl`.
- At p=4 the cheap pipeline (`streamingEnumeratePure`) OOMs at (4,5) even sequential. Use `streamingEnumeratePureMcKay` for p=4 q≥5. Cheap is still fine at (4,4) and below.
- Read and write generated files only through `comb_paths.wl` / `comb_paths.ps1`. Never hardcode `C:/CombResearch/...`, never build output paths from the script's own checkout (`projectRoot`/`$PSScriptRoot`), and never use cwd-relative `"data/..."`. Large outputs must not be committed through git; they live only in the main checkout.
- `statsFor` and the 12-column stats schema (`$CombStatsHeaders`) live in `src/lib_stats.wl`; `exportWxfAtomic` in `src/lib_io.wl`. `Get` those; never `Block`-`Get` `pure_simplicial_compute.wl` for its helpers.
- Keep changes narrowly scoped. Do not reformat unrelated files.
- Do not add dependencies without asking first.

## Testing and Checking Rules

- Before continuing prior work, inspect `git status --short` and relevant `git diff`.
- For documentation-only changes, `git diff -- CLAUDE.md docs/agent-task.md` is usually enough.
- For code changes, run the smallest relevant Wolfram check or smoke script and record what ran in the handoff.
- Treat q=10 facet/unlabeled IS histograms with caution; ESS collapse is documented in `docs/sampling.md`.

## Git and Worktree Rules

- The worktree may already contain user or agent changes. Do not revert changes you did not make.
- Inspect `git status --short` and relevant diffs before modifying files, especially when resuming prior work.
- Do not commit, push, branch, or clean generated files unless the user asks.
- Any commit or PR whose work wrote outputs must say so: list the files (or globs) written under the main checkout's `data/`, `figures/`, `logs/`, and say they are not in the commit. Figures and logs that should be tracked are committed from the main checkout.

## Handoff Protocol

- `CLAUDE.md` (this file) holds the project instructions. There is no `AGENTS.md`.
- Use plan mode before large rewrites or broad research-code changes.
- `docs/agent-task.md` is the live handoff. Update it when the goal, status, decisions, likely files, or validation commands change.
- At the start of a resumed session, read `docs/agent-task.md`, inspect git status/diff, then continue from the recorded state.

