# Current Agent Task

## Goal

**Phase 4b complete (2026-05-15).** Truth+MH on 9 cells × 3 targets, all 27 combinations PASS at L1 < 0.05.

**Phase 4c started (2026-05-17): IS-vs-MH q=10 comparison (numV marginal).**
With no truth available at q=10, we cross-check the two estimators against each other.
First pass (pilot 10k + production 200k) shows:

- **p=2 (all targets), vertex target everywhere**: L1(IS, MH) ≤ 0.10 — agreement
  within sampling noise.
- **p∈{3,4} × {unlabeled, facet}**: structural disagreement. 200k-iter chains give
  L1 ∈ [0.53, 1.38]; 20× the pilot budget barely moved the L1 (Δ ≤ 0.16). MH chains
  are stationary in a region of numV materially different from IS.
- Most likely reading: IS is broken at low ESS (as predicted; ESS=25/29 at p=4
  unlabeled/facet, ESS=123/118 at p=3). MH is sampling the high-|Aut| / low-numV
  corners that IS cannot reach. The p=2 agreement confirms MH is calibrated.
- Caveat: MH accept rate is 9% at p=4 q=10. Cannot fully rule out metastable
  trapping until a second seed and a warm-start from a high-numV state are
  tried.

**Phase 4c part 2: 3-way IS vs MH vs truth at (3,5) and (4,5).**
Ran 100k IS samples at the truth cells and compared all three estimators on
the same numV marginal. L1 vs truth:

| cell  | target    | L1(IS,T) | L1(MH,T) | ratio |
|-------|-----------|---------:|---------:|------:|
| (3,5) | vertex    |   0.003  |   0.014  |  0.2x |
| (3,5) | unlabeled |   0.097  |   0.022  |  4.5x |
| (3,5) | facet     |   0.071  |   0.005  | 15x   |
| (4,5) | vertex    |   0.005  |   0.009  |  0.6x |
| (4,5) | unlabeled |   0.132  |   0.025  |  5.3x |
| (4,5) | facet     |   0.093  |   0.029  |  3.2x |

- On **vertex** target, IS and MH both reach truth within ~0.01 L1. IS is
  marginally better (no chain mixing concerns).
- On **unlabeled** and **facet** targets at p∈{3,4}, **MH agrees with truth
  3-15x more tightly than IS does**. At (3,5) facet IS has L1=0.071 vs MH
  L1=0.005 — the same pattern as the q=10 case at smaller scale.
- IS systematically under-samples the high-|Aut|/low-numV corners. At (4,5)
  unlabeled, truth has ~2.5% of mass at numV ∈ {5,6,7}, and IS has zero
  there — exactly the bias predicted by ESS=134.
- Conclusion: the q=10 IS-vs-MH disagreement is the same phenomenon
  observed at q=5 where we have truth to break the tie. MH is right.

**Phase 4c part 3 (overnight 2026-05-17 → 2026-05-18): warm-start + second-seed disambiguation at q=10.**
Belt-and-suspenders test: run 1M-iter chains with seed 67890 and warm-start
at numV near the IS mode (14 for p=3, 18 for p=4) at the 4 disagreement
cells. If the chain stays at the warm-init region, MH-trapped is in play;
if it descends to the same region the production seed-12345 chains found,
both chains are stationary in the same basin and the MH answer is locked.

Result: **production and warm chains agree to L1 ≤ 0.06 at every cell.**

| cell  | target    | prod acc | warm acc | L1(IS, prod) | L1(IS, warm) | **L1(prod, warm)** |
|-------|-----------|---------:|---------:|-------------:|-------------:|-------------------:|
| (3,10) | unlabeled | 0.18 | 0.19 | 0.559 | 0.532 | **0.034** |
| (3,10) | facet     | 0.19 | 0.19 | 0.525 | 0.562 | **0.038** |
| (4,10) | unlabeled | 0.10 | 0.10 | 1.332 | 1.335 | **0.050** |
| (4,10) | facet     | 0.09 | 0.09 | 1.379 | 1.344 | **0.059** |

Different seed × different init × 5× chain length all settle on the same
distribution. MH-trapped ruled out. **IS is biased at low ESS; MH is right.**
Phase 4c is closed.

Remaining open items:

1. ~~Disambiguate MH-stationary vs MH-trapped at p=4 q=10 unlabeled/facet~~
   — closed by Phase 4c part 3 (warm-start + second seed). See below.
2. **Betre cross-check**: Dr. Betre has independent (4,4) and (4,5) facet-labeled
   and unlabeled samples in `.mx` files. Platform-locked to MacOSX-ARM64.
   Betre asked to re-export as WXF. When `.wxf` files land in
   `C:\CombResearch\data\`, cross-check our (4,5) iso count = 5,532.
3. **Next-phase decision** (user input needed): manuscript text integration
   (Phase 5), attempt (4,6) via McKay, broaden q=10 comparison to remaining
   Figure 3+ statistics, or other priorities.

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
- (4,5) MH chains ran in 3 parallel processes via `src\run_p4q5_mh_parallel.ps1`, monitored via `src\monitor_mh.ps1`.
- Betre's `.mx` re-export request was sent (user-mediated via email/Slack).

## Files modified this session

- `src/sampler_mh.wl` — vertex target fix
- `src/streaming_enumerator_bliss.wl` — integer-labeled `bipartiteIncidenceGraph`
- `src/streaming_enumerator_mckay.wl` — `canonicalRemovalVSide` for integer labels
- `src/enumerate_truth.wl` — pipeline + parallelism env vars, tagged filenames, payload `pipeline` field
- `src/render_truth_overlay.wl` — `reachableCells` 5 → 9, p=4 enabled in fig defaults
- 2026-05-16 Codex comment audit: refreshed stale headers/comments in sampler,
  truth/MH drivers, overlay renderer, streaming enumerators, and p=4 probe;
  `validate_mh_vs_truth.wl` now defaults to the current 9-cell grid.
- 2026-05-16 Codex doc consolidation: replaced historical planning docs with
  `docs/enumeration.md` and `docs/sampling.md`; README and source references
  now point at the consolidated docs.
- 2026-05-16 Codex archive cleanup: moved historical benchmark/probe/scaling
  scripts from `src/` to `archive/old_test_scripts/`; production renderers and
  smoke tests remain in `src/`.

## Files added this session (Phase 4c part 3)

- `src/run_q10_mh_overnight.ps1` — orchestrator for the overnight job.
  Step 1 restores `p4q10_mh_unlabeled.wxf` at the production 200k budget
  (a smoke test had overwritten it). Step 2 launches 4 parallel
  wolframscript processes at 1M iter, seed 67890, warm-start at
  numV=14 (p=3) or numV=18 (p=4). Outputs tagged
  `_seed67890_warm{N}` so production is never clobbered.
- `src/compare_q10_warm_vs_prod.wl` — per-cell L1 table comparing IS,
  production-seed, and warm-seed chains. Reports L1(prod, warm) as the
  key disambiguator.
- `src/render_q10_warm_vs_prod.wl` — 2x2 grouped-bar overlay
  (IS / prod / warm) at the 4 disagreement cells. Output:
  `figures/q10_warm_vs_prod.{png,pdf}`.

Sampler patches enabling the overnight job:
- `src/sampler_mh.wl`: added `warmInitialState[p,q,nMax,mTarget,seed]`
  that constructs q distinct random p-subsets of `{1..mTarget}` embedded
  in `[nMax]`. `runMHChain` gained option `initNumV` (default
  Automatic = existing random-vertex-labeled init).
- `src/run_mh_chains.wl`: added env vars `COMB_MH_TAG` (output-filename
  suffix), `COMB_MH_INITNUMV` (forwards to runMHChain), and
  `COMB_MH_OUTDIR` (override the output dir — needed when running the
  worktree script with outputs going to the main checkout). Tag and
  initNumV are persisted to the payload. The (3,5) inline gate is
  skipped for non-default tag or initNumV.

## Files added this session (Phase 4c part 2)

- `src/run_is_at_truth_cells.wl` — chunked IS sampler at (3,5) and (4,5),
  100k samples each, ParallelMap on the {numV, |Aut|, |Aut_F|} stats step.
  Writes the same `data/p{p}q{q}_is_{target}_numv_hist.wxf` schema as the
  q=10 aggregator so the comparison/render code is shared.
- `src/compare_3way.wl` — per (p, q, target) prints L1 against truth for
  both IS and MH plus the IS-vs-MH L1, with an ASCII overlay. Writes
  `data/is_mh_truth_3way_summary.wxf`.
- `src/render_3way.wl` — 2x3 grid of grouped bar overlays (truth, IS, MH).
  Output: `figures/q5_is_mh_truth_3way.{png,pdf}`.

## Files added this session (Phase 4c part 1)

- `src/precompute_is_histograms_q10.wl` — aggregates the merged 12M-row q=10 IS
  stats into 9 small numV-fraction WXFs (one per p × target). Uses GroupBy for
  the bin aggregation; the older Merge[Thread[..., Total]] was unusably slow on
  2M+ rows. Outputs: `data/p{2,3,4}q10_is_{vertex,unlabeled,facet}_numv_hist.wxf`.
- `src/run_q10_mh_pilot.ps1` — sequential 10k-iter MH pilot at q=10 for all 9
  (p, target) combos. Environment-overridable iter count.
- `src/run_q10_mh_parallel.ps1` — production launcher: 4 parallel
  wolframscript processes, one per cell × target at (3,10) and (4,10) ×
  {unlabeled, facet}. 200k iter, 20k burn-in, thin 5; ~45 min wall when run
  in parallel.
- `src/compare_is_mh_q10.wl` — bins MH numV column 1, compares against
  precomputed IS frac-hist, prints per-bin ASCII overlay + per-cell L1 and
  summary table. Writes `data/q10_is_vs_mh_summary.wxf`.
- Pilot archive: `data/q10_pilot_archive/p{3,4}q10_mh_{unlabeled,facet}_pilot10k.wxf`
  preserved before production rerun overwrote the WXFs.

## Files added this session (previous: Phase 4b)

- `src/validate_mh_vs_truth.wl` — MH-vs-truth validation harness
- `src/test_streaming_mckay.wl` — McKay correctness gate + profiler
- `archive/old_test_scripts/probe_mckay_primitives.wl` — archived per-primitive time attribution probe
- `archive/old_test_scripts/probe_clique_vs_bipartite.wl` — archived clique-graph vs bipartite speedup measurement
- `archive/old_test_scripts/probe_p4_cheap.wl` — archived (4,4) cheap pipeline scaling probe
- `src/probe_betre_mx.wl` — inspector for Betre's `.mx` files
- `src/run_p4q5_mh_parallel.ps1` — 3-process parallel launcher for (4,5) MH
- `src/monitor_mh.ps1` — dashboard for running MH chains

## Likely files for the next agent

- `src/sampler_mh.wl` — if MH semantics need further work
- `src/run_p4q5_mh_parallel.ps1` — if (4,5) MH chains need to be rerun
- `src/validate_mh_vs_truth.wl` — MH-vs-truth validation harness
- `data/p4q5_mh_*.wxf` — output of validated (4,5) MH chains
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

Claude Code on 2026-05-18 (Phase 4c part 3: warm-start + second-seed disambiguation, Phase 4c CLOSED)

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
