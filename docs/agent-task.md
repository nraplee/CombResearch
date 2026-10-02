# Current Agent Task

## Goal

**Phase 5a (started 2026-09-25): validate the ECGrav 1.17.0 samplers** against
our truth grid and repeat the Phase 4 metrics (numV L1, per-class fit, ESS,
ESS/s). Requested by Dr. Betre. Plan: Claude plan file
`big-things-happening-it-s-eager-sprout.md` (steps 0-6 summarized below).

New in ECGrav (v1.0.0 -> v1.17.0, github.com/kassabetre/ECGrav @ d15739c):
exact rejection-free `RandomUniformFacetLabeledPureSimplicialComplex` and
`RandomUniformUnlabeledPureSimplicialComplex` (n free, drawn from the counts),
ECGrav's own `RandomPureSimplicialComplexMCMC` (labeling 0/1/2), faster
`RandomVertexLabeledPureSimplicialComplex`, and exact counters
`Num{Vertex,Facet,Un}LabeledPureComplexes`.

### Phase 5a status

- Step 0 DONE: 1.17.0 source vendored at `ECGrav/ECGrav-1.17.0/`. Its
  PacletInfo says WolframVersion 15.0+, which the paclet system filters out
  on 14.3, so `src/load_ecgrav.wl` `Get`s the kernel file directly (works on
  14.3). User is installing Wolfram 15.0.1 (2026-09-25); after that a global
  PacletInstall also works, but the loader stays the pinned path.
  (4,4) truth regenerated via McKay (278 classes, 262 s) ->
  `data/p4q4_truth.wxf`. Other truth/MH WXFs copied from the
  `adoring-hoover-18d09b` worktree and `C:\CombResearch\data`.
- Step 1 DONE: `src/validate_counts_vs_truth.wl` - ECGrav U/F/V counts match
  our truth EXACTLY per n on all 9 cells. **(4,5) iso count 5,532
  independently confirmed** (NumUnlabeledPureComplexes[4,5]). This closes
  the Betre .mx cross-check item.
- Step 2 IN PROGRESS: `src/run_ecgrav_samplers.wl` written; smoke run at
  (2,4),(3,4), N=20k, all 3 targets: 0 unmatched samples, all classes hit
  (vertex misses 2 rare classes at (3,4)). Validation harness extended but
  its first run was interrupted by the Wolfram upgrade.
- Step 2 DONE (2026-09-26): full exact campaign, 9 cells x 3 targets,
  N=100k each (`src
un_ecgrav_campaign.ps1`, ~1 h). **27/27 PASS**, numV L1
  0.002-0.011 (mean ~0.006 vs 0.018 for our MH), per-class chi-square p
  0.058-0.977, iid p-values look uniform (min 0.018 of 27), 0 unmatched
  samples. Negative control `ecglegacyfacet` at (2,4),(3,4): FAILS as
  required (L1 0.22, chi-square p = 0; was 0.43 under 1.0.0).
- Step 4 partial: `src/compare_samplers_efficiency.wl` ran on the 9 cells.
  Exact samplers: tau ~0.5 (draws independent), ESS/s 150-15000. Our MH:
  ESS/s 1-13 for unlabeled/facet. IS from vertex draws: ESS/N falls to
  ~0.001 by (3,6)/(4,5) - same collapse as Phase 3.
- Step 3 DONE (2026-09-26, 03:00-05:10): ECGrav MCMC, 9 cells x 3 targets,
  N=20k. All converged, 0 unmatched. **27/27 PASS** the Phase 4 criterion
  (numV L1 < 0.05; range 0.006-0.030). Wall: vertex/facet ~15 min each,
  unlabeled ~2 h 10 min.
  - Caveat: ECGrav's returned samples are NOT independent for unlabeled.
    corrT (2-5 sweeps) is shorter than the numV τ_int per sweep (1.5-4.6),
    so ESS/N on the sample stream is only 0.31-0.73 for unlabeled
    (0.53-0.96 facet/vertex). The usage message promises independent samples.
  - (4,5) unlabeled fails the strict iid/per-class checks (iid p = 0.000,
    class p = 0.001, L1 0.0296 vs ~0.018 expected at its ESS ~13k). This is
    probably autocorrelation plus possibly slow mixing; not yet separated.
    Follow-up: rerun (4,5) unlabeled with longer spacing, or report the
    corrT issue to Betre.
  - ESS/s: ECGrav MCMC beats our MH (unlabeled 7-44 vs 3-9; facet 65-624 vs
    1-12) but is 10-100x behind the exact samplers.
- q=10 exact runs deferred by user (plan: 100k facet, ~10k unlabeled per p).
- q=10 timing pilot: unlabeled exact is slow (88 ms / 494 ms / 3.9 s per
  sample at p=2/3/4); facet 1.7 / 4.5 / 25 ms; vertex 0.4 ms.
- STALE DATA: the vertex MH WXFs copied from `adoring-hoover-18d09b`
  ((2,4),(2,5),(2,6),(3,4),(3,5)) fail with L1 ~0.7-0.85 - they predate the
  2026-05-14 vertex fix. Rerun before using them. (4,5) vertex MH (from
  `C:\CombResearch\data`) is post-fix and passes (L1 0.0086).
- ECGrav 1.17.0 also installed globally (Wolfram 15.0.1, 2026-09-25).

### Findings so far

- ECGrav MCMC (`RandomPureSimplicialComplexMCMCSweep`) is the same global
  remove-one/add-one kernel on N = p q labels as our `proposeGlobal`, with
  weights 1/C(N,k) (vertex), FacetStabilizer*q!/(C(N,k) k!) (facet),
  Aut/(C(N,k) k!) (unlabeled). These equal our π_V/π_F/π_U on labeled
  states (FacetStabilizer = aut/autF). Vertex weight dated 05/14/2026 - same
  fix as ours.
- Exact samplers run serially unless kernels are already launched
  ($KernelCount > 0); we parallelize per target process instead.

### Phase 5a next steps

1. Once Wolfram 15 is up: `COMB_VAL_SOURCE=ecgexact COMB_VAL_CELLS="2,4;3,4"`
   validate smoke data; debug harness if needed.
2. Negative control: `COMB_ECG_SAMPLER=legacyfacet COMB_ECG_CELLS="2,4"` then
   validate with `COMB_VAL_SOURCE=ecglegacyfacet` (must FAIL, L1 ~0.43).
3. Full exact campaign: `src
un_ecgrav_campaign.ps1` (9 cells, N=100k).
4. MCMC campaign: `COMB_ECG_SAMPLER=mcmc` (N=20k), long - ask user first.
5. q=10 exact: `COMB_ECG_CELLS="2,10;3,10;4,10"` after a timing pilot.
6. `src/compare_samplers_efficiency.wl` for the ESS table.
7. Missing MH WXFs for (2,7),(3,6),(4,4) - rerun `run_mh_chains.wl` if the
   efficiency table needs our MH at those cells.

## Previous goal (Phase 4b, complete 2026-05-15)

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

## Files added this session

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

Claude Code on 2026-09-25 (Phase 5a ECGrav 1.17 sampler validation, in progress)

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
