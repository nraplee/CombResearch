# Current Agent Task

## Goal

**Phase 4b complete (2026-05-15).** Truth+MH on 9 cells × 3 targets, all 27 combinations PASS at L1 < 0.05. (4,5) MH chains landed and validated:
- unlabeled L1 = 0.0253
- facet L1 = 0.0294
- vertex L1 = 0.0086

Renderer produces 273 manuscript panels, all with full overlays (no truth-only rows remaining).

Remaining open items:

1. **Betre cross-check**: Dr. Betre has independent (4,4) and (4,5) facet-labeled and unlabeled samples in `.mx` files. These are platform-locked to MacOSX-ARM64 and don't load on Windows. Betre is being asked to re-export as WXF (one-liner: `Export["p4q5SXUnlabeled.wxf", p4q5SXUnlabeled, "WXF"]`). When `.wxf` files land in `C:\CombResearch\data\`, cross-check our (4,5) iso count = 5,532.
2. **Next-phase decision** (user input needed): manuscript text integration (Phase 5), attempt (4,6) via McKay, IS-vs-MH q=10 comparison, or other priorities.

## Current status (2026-05-15)

- **Truth grid expanded to 9 cells**: `(2,4), (2,5), (2,6), (2,7), (3,4), (3,5), (3,6), (4,4), (4,5)`. (4,4) and (4,5) are first-ever p=4 enumerations in this project. (4,5) iso count = 5,532, via `streamingEnumeratePureMcKay` sequential, 17.1 hr wall-clock, 7.9 GB peak. Cheap pipeline OOM'd at (4,5) even sequential — McKay is the only viable path at p=4 q≥5.
- **MH chains validated at all 9 cells × 3 targets = 27 cell×target combinations PASS** (mean L1 = 0.018, all below 0.05 threshold vs truth on numV marginal). See `src/validate_mh_vs_truth.wl` for the harness.
- **(4,5) MH chains** ran in parallel (3 processes, one per target) via `src/run_p4q5_mh_parallel.ps1` overnight on 2026-05-15. Total wall-clock ~6 hr.
- **Vertex target bug found + fixed.** Before 2026-05-14, `mhStep`'s vertex branch used `piRatio = 1`, which gave a marginal-on-iso of `C(N, k) · k!/|Aut(Y)|` — wrong by a factor of `C(N, k)` against the manuscript's intrinsic `π_V ∝ k!/|Aut(Y)|`. Manifested as L1 = 0.85 at (3,5) vertex. Fixed by setting `piRatio = Binomial[nMax, m] / Binomial[nMax, mY]`. All vertex MH WXFs re-run with the fix.
- **Renderer extended** to 9 cells × including p=4 panels. 273 manuscript panels + 33 stacked previews + `figures/combined_truth_overlay.pdf`.
- **McKay enumerator integer-labeled** (was string-labeled). `bipartiteIncidenceGraph` build dropped ~120 µs → ~55 µs per call. McKay-on-cliques angle (Betre's suggestion) was investigated and rejected — speedup at p≤3 only (1.2-1.4×), slower at p=4.
- **`enumerate_truth.wl` extended**: env vars `COMB_TRUTH_PIPELINE` (cheap|bliss|mckay) and `COMB_TRUTH_PARALLEL` (true|false). Tagged filenames `p{p}q{q}_truth_{pipeline}.wxf` for cross-validation.

## Decisions made

- McKay-style canonical-augmentation enumerator is the production path at p=4.
- `data/p4q5_truth.wxf` is the cheap-style filename but is copied from `p4q5_truth_mckay.wxf` (cheap pipeline failed at this cell).
- Vertex target's `π_V(X)` is `∝ 1/C(N, numV(X))` (not `∝ 1`). See `mhStep` in `src/sampler_mh.wl`.
- (4,5) MH chains will run in 3 parallel processes via `src\run_p4q5_mh_parallel.ps1`, monitored via `src\monitor_mh.ps1`.
- Betre's `.mx` re-export request was sent (user-mediated via email/Slack).

## Files modified this session

- `src/sampler_mh.wl` — vertex target fix
- `src/streaming_enumerator_bliss.wl` — integer-labeled `bipartiteIncidenceGraph`
- `src/streaming_enumerator_mckay.wl` — `canonicalRemovalVSide` for integer labels
- `src/enumerate_truth.wl` — pipeline + parallelism env vars, tagged filenames, payload `pipeline` field
- `src/render_truth_overlay.wl` — `reachableCells` 5 → 9, p=4 enabled in fig defaults

## Files added this session

- `src/validate_mh_vs_truth.wl` — MH-vs-truth validation harness
- `src/test_streaming_mckay.wl` — McKay correctness gate + profiler
- `src/probe_mckay_primitives.wl` — per-primitive time attribution probe
- `src/probe_clique_vs_bipartite.wl` — clique-graph vs bipartite speedup measurement
- `src/probe_p4_cheap.wl` — (4,4) cheap pipeline scaling probe
- `src/probe_betre_mx.wl` — inspector for Betre's `.mx` files
- `src/run_p4q5_mh_parallel.ps1` — 3-process parallel launcher for (4,5) MH
- `src/monitor_mh.ps1` — dashboard for running MH chains

## Likely files for the next agent

- `src/sampler_mh.wl` — if MH semantics need further work
- `src/run_p4q5_mh_parallel.ps1` — to launch (4,5) MH chains
- `src/validate_mh_vs_truth.wl` — to validate when chains land
- `data/p4q5_mh_*.wxf` — output of (4,5) MH chains (will appear when launcher runs)
- `data/p4q*SXFacetLabeled.wxf`, `data/p4q*SXUnlabeled.wxf` — Betre's data (when he re-exports)

## Commands/checks to run

```powershell
# Smoke check: McKay still correct at small cells
wolframscript -file src\test_streaming_mckay.wl

# Validate any (cell × target) combination
COMB_VAL_CELLS="3,5" COMB_VAL_TARGETS="vertex" wolframscript -file src\validate_mh_vs_truth.wl

# Launch (4,5) MH chains (manual)
powershell -ExecutionPolicy Bypass -File src\run_p4q5_mh_parallel.ps1

# Monitor (4,5) MH progress
powershell -ExecutionPolicy Bypass -File src\monitor_mh.ps1
```

## Handoff notes

Before continuing, the next agent must:

1. Read `AGENTS.md`.
2. Read `CLAUDE.md` if using Claude Code.
3. Read this file.
4. Run `git status --short`.
5. Inspect `git diff` (especially the live MH-vs-truth fix and the renderer change).
6. Check whether `data/p4q5_mh_*.wxf` exist (user may have launched manually).
7. Continue from the current repo state, not hidden chat history.

## Last updated by

Claude Code on 2026-05-15 (Phase 4b closeout)

## Tool switch prompts

When switching from Claude to Codex:

```text
Read AGENTS.md and docs/agent-task.md. Run git status --short and git diff.
Continue from the current repo state. Do not restart the task from scratch.
```

When switching from Codex to Claude Code:

```text
Read CLAUDE.md, AGENTS.md, and docs/agent-task.md. Run git status --short and
inspect the diff. Continue from the current repo state. Do not restart the task
from scratch.
```
