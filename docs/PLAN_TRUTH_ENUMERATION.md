# Plan — Truth-enumeration pipeline (q-sweep, target q=10, expected cap q=5)

> Written 2026-05-01. Phase 1 complete 2026-05-02. Phase 2 complete 2026-05-04 — five truth WXFs in `data/`, all iso-class gates pass. Phase 3 (`render_truth_overlay.wl`) is next.

## Status (2026-05-04)

- ✅ **Phase 1 — Scaling probe.** `src/scaling_probe.wl` (eager pipeline) and `src/scaling_probe_streaming.wl` (streaming + bucketed pipeline) both run; results in `docs/enumeration_scaling.md`. Empirically reachable grid: `{(2,4), (2,5), (2,6), (3,4), (3,5)}`. (2,7), (3,6), (4,5), (4,6), and the rest of the (p, q) grid are unreachable within a 30 min budget per cell on the current host with either pipeline.
- ✅ **Streaming pipeline prototype.** `src/streaming_enumerator.wl` — DFS streaming generator + online bucketed dedupe, parallelized over starting states. Validated against ECGrav on (2,4), (2,5), (3,4); reproduces canonical iso class counts. 1.1×–3.4× faster than eager+naive on cells where eager succeeds; ~10× lower memory peak. **Does not unlock new cells.**
- ✅ **Phase 2 — enumerate_truth.wl.** Done. `src/enumerate_truth.wl` produced `data/p{p}q{q}_truth.wxf` for all five reachable cells. All iso-class count gates pass: 11 / 26 / 68 / 66 / 445. Total wall-clock ≈ 14 min (dominated by (3,5) at 526s and (2,6) at 265s). See "Phase 2 results" below.
- ⏳ **Phase 3 — render_truth_overlay.wl.**
- ⏳ **Phase 4 — manuscript integration.**
- ⏳ **Phase 5 — literature reading.**

## Phase 2 results (2026-05-04)

`src/enumerate_truth.wl`, sequential driver, streaming enumerator parallelized over starting states (~14 subkernels). Run logged at `logs/enumerate_truth_smoke.log` (the (2,4) + (3,4) gate check) and `logs/enumerate_truth_full.log` (the remaining three cells).

| (p, q) | \|isoReps\| (gate) | totalEmitted | numBuckets | streaming time (s) | peak mem (MB) | WXF size |
|:------:|------------------:|-------------:|-----------:|-------------------:|--------------:|---------:|
| (2, 4) | 11 ✓              | 70           | 9          | 7.6                | 137.9         | 3.4 KB   |
| (2, 5) | 26 ✓              | 794          | 17         | 14.0               | 121.0         | 7.7 KB   |
| (2, 6) | 68 ✓              | 12 055       | 31         | 265.1              | 123.9         | 20.1 KB  |
| (3, 4) | 66 ✓              | 666          | 46         | 5.2                | 137.9         | 19.0 KB  |
| (3, 5) | 445 ✓             | 28 344       | 159        | 526.0              | 169.3         | 129.4 KB |

Stats step (computing the 12-stat row per iso-class rep) was negligible: (2,4) 0.05s, (2,5) 0.12s, (2,6) 0.45s, (3,4) 0.35s, (3,5) 2.97s. The bottleneck is the streaming enumerator, exactly as Phase 1 anticipated. Sanity: all three exact distributions (`piVertex`, `piFacet`, `piUnlabeled`) sum to 1 within `1e-9` per cell.

WXF schema (one per cell):

```
<|"p" -> p, "q" -> q,
  "numIsoClasses" -> nIso,
  "totalFacetLabeled" -> sr["totalEmitted"],
  "numBuckets" -> sr["numBuckets"],
  "complexes" -> {<|"facets"->..., "aut"->..., "autF"->..., "nV"->...,
                    "stats"-><|numV->..., aut->..., autF->...,
                              connected->..., num1VConnComps->...,
                              num2VConnComps->..., largestCompRatio->...,
                              num2PathConnComps->..., num3PathConnComps->...,
                              Betti1->..., Betti2->..., Betti3->...|>|>, ...},
  "piVertex" -> {N, ...}, "piFacet" -> {N, ...}, "piUnlabeled" -> {N, ...},
  "wallClockSec" -> ..., "peakMemMB" -> ...,
  "ecGravVersion" -> "1.0.0",
  "enumeratorVersion" -> "streaming_enumerator.wl@<sha>",
  "createdAt" -> ...|>
```

Run convention:

```
wolframscript -file src/enumerate_truth.wl              # full reachable grid
COMB_TRUTH_CELLS="2,4;3,4" wolframscript -file ...      # restrict cells
COMB_FORCE=1 wolframscript -file ...                    # ignore existing WXFs
```

Idempotent: existing non-empty WXFs are skipped unless `COMB_FORCE=1`. Atomic write (`tmp + RenameFile`) so a crash mid-cell doesn't leave a partial file.

**Validation gate not run yet:** the optional cross-check of the (3,5) numV distribution against an N=200k MH chain (the plan's `L1 < 0.05` gate). Listed under deliverables; defer to Phase 3 since it shares the same load-WXF + extract-marginal scaffolding.

## Goal

Produce **exact, deterministic** truth distributions over isomorphism classes — the blue bars in `figures/sampler_mh_progress.png` — across as much of the (p, q) grid as fits in memory and time. Three exact measures per case (vertex-labeled, facet-labeled, unlabeled), all 13 statistics, every (p, q) we can enumerate. These bars are the ground truth that MH (and the abandoned IS pipeline) get compared against.

Original target: (p, q) up to (4, 10). **Empirically achievable target (per Phase 1):** five cells `{(2,4), (2,5), (2,6), (3,4), (3,5)}`.

## Why now

1. The MH sampler is verified at (2,4) and (3,4). It needs verification at *more* points before we trust it at (4,10) where no truth is reachable. Each additional truth case we can compute is one more independent confirmation that MH math + mixing both work. Phase 1 added (3,5) and probably (2,5), (2,6) to the reachable list.
2. Wherever truth is reachable, **truth replaces empirical bars in the manuscript** — no chain noise, no ESS caveat, just the exact distribution. Most p=2 figures and p=3 q=4,5 figures are now in scope.
3. Betre confirmed a Hamiltonian is essential for the MC pipeline to scale; the new ECGrav `main` source has `H1d/H2dCombManifold`, `H2dPseudoCombManifold`, `LowEnergyStates`, etc. to support that. **This plan is upstream of that work** — truth bars don't depend on the Hamiltonian; they're needed regardless of which sampler ends up in production.

## What "truth enumeration" means here

For a given (p, q):

1. **Enumerate iso classes.** Use `streamingEnumeratePure[p, q]` from `src/streaming_enumerator.wl`. Returns an Association `<|"isoReps"->{...}, "totalEmitted"->n, "numBuckets"->k|>`. The `isoReps` field is one canonical representative per iso class.
2. **Compute weights** per iso class X:
   - `aut(X)  = PureComplexAutomorphismGroupOrder[X]`
   - `autF(X) = PureComplexFacetAutomorphismGroupOrder[X]`
   - `nV(X)   = number of vertices`
3. **Three exact distributions** over the iso classes:
   - Vertex-labeled: `π_V(X) ∝ nV(X)! / aut(X)`   (count of distinct vertex labelings of [X] on nV labels)
   - Facet-labeled: `π_F(X) ∝ q! / autF(X)`        (count of distinct facet labelings of [X])
   - Unlabeled:     `π_U(X) ∝ 1`                   (uniform on iso classes)
4. **Statistics.** Reuse `statsFor` from `src/pure_simplicial_compute.wl` to compute the 13-vector per iso-class rep.

These are **exact**: no sampling, no ESS, no chain. The only error is rounding.

## Existing infrastructure

- **ECGrav 1.0.0 (vendored at `ECGrav/ECGrav-1.0.0/`).** Provides `IsomorphicSimplicialComplexQ`, `PureComplexAutomorphismGroupOrder`, `PureComplexFacetAutomorphismGroupOrder`, the eager `GenerateAllFacetLabeledPureSimplicialComplexes` (for cross-validation), and `ChooseNonIsomorphicSimplicialComplexes` (for cross-validation).
- **`src/streaming_enumerator.wl`** (new in Phase 1):
  - `chooseNonIsoBucketed[allLab]` — drop-in replacement for `ChooseNonIsomorphicSimplicialComplexes` using canonical-key bucketing. 1.8×–3.6× faster than naive on small cells.
  - `streamingEnumeratePure[p, q, Parallel -> True]` — the streaming generator. Returns iso class reps directly. Parallel over starting states (~14 subkernels).
  - `canonicalKey[c]` — relabeling-invariant tuple `(numV, sortedVertexDegrees, sortedFacetPairOverlaps)`. Cheap; not a true canonical form but strong enough that within-bucket iso testing is fast.
- **`src/scaling_probe.wl`** — eager pipeline timing probe.
- **`src/scaling_probe_streaming.wl`** — streaming pipeline timing probe.
- **`src/test_streaming.wl`** — correctness check against ECGrav on small cells.
- **`src/render_uniformity_check.wl`, `src/render_sampler_progress.wl`** — existing per-iso-class enumeration logic at (2,4) and (3,4); reference templates for Phase 3.
- **`src/pure_simplicial_compute.wl::statsFor`** — the statistics function we want to apply per iso-class rep.

## Phases

### ✅ Phase 1 — Scaling probe (DONE)

Results in `docs/enumeration_scaling.md`. The plan's original prediction was wrong in an interesting way: it identified `ChooseNonIsomorphic...` (iso testing, O(n²)) as the wall, and proposed canonical-form bucketing as the mitigation. The actual wall is the *generator* — every timeout cell ((2,7), (3,6), (4,5)) died inside `GenerateAll` (eager) or DFS traversal (streaming) without producing a single emission. Bucketing helped (it's now in the streaming pipeline) but didn't change reachability. See "Risks" below for the corrected understanding.

### ✅ Phase 2 — Enumeration cache (`src/enumerate_truth.wl`) — DONE 2026-05-04

Single script, sequential driver over the reachable grid `{(2,4), (2,5), (2,6), (3,4), (3,5)}`. For each cell:

1. `sr = streamingEnumeratePure[p, q, Parallel -> True]` — iso class reps.
2. For each rep: 12-stat row from `statsFor` (reused from `pure_simplicial_compute.wl` — the script `Get`s that file with `pListOverride={}` to suppress its main loop and only pick up the function definitions).
3. Per-cell exact distributions over iso classes:
   - `π_V(X) ∝ nV(X)! / aut(X)`
   - `π_F(X) ∝ q!     / autF(X)`
   - `π_U(X) ∝ 1`
   computed with exact rationals then converted to machine reals at the very end. All three sum to 1 within `1e-9` per cell.
4. Atomic persist (`tmp + RenameFile`) to `data/p{p}q{q}_truth.wxf` — schema in the "Phase 2 results" section above.
5. Idempotent: skip cells with existing non-empty WXF unless `COMB_FORCE=1`. Restrict cells via `COMB_TRUTH_CELLS="p,q;p,q;..."`.

**Validation gates** — all met:
- (p=2, q=4): 11 iso classes ✓ (matches `render_uniformity_check.wl`).
- (p=3, q=4): 66 iso classes ✓ (matches `render_sampler_progress.wl`).
- (p=2, q=5): 26 iso classes ✓ (matches Phase 1).
- (p=2, q=6): 68 iso classes ✓ (matches Phase 1).
- (p=3, q=5): 445 iso classes ✓ (matches Phase 1).
- ⏳ Spot-check of `numV` distribution against an N=200k MH chain at (3, 5): L1 < 0.05. **Not run yet — defer to Phase 3** since it shares the load-WXF + extract-marginal scaffolding.

**Actual wall-clock** (logs/enumerate_truth_full.log + logs/enumerate_truth_smoke.log): ~14 min total. (3,5) dominates at 526s (matches Phase 1's 455s estimate within ~16%); (2,6) at 265s is ~25% slower than Phase 1's 210s, likely host-load variance. The full timing table is in the "Phase 2 results" section above.

### Phase 3 — Truth-overlay renderer (`src/render_truth_overlay.wl`)

Reads `data/p{p}q{q}_truth.wxf` plus optional sampler outputs. Produces the same per-figure 3×1 column structure the manuscript uses (one panel per p), with these layers per panel:

- **truth (blue, solid):** present whenever the (p, q) WXF is on disk.
- **MH chain (red, translucent):** present whenever an MH sample exists. Validates MH against truth.
- **IS reweighted (yellow, translucent):** present whenever the IS WXF exists. Demonstrates the q=10 collapse on the same axes.

Where truth is absent (i.e. q ≥ 6 for p=3, all of p=4), only MH + IS layers render — that's the smoking gun panel and stays in the deck as evidence.

Style matches existing `render_all_figures.wl`: Times 11pt, ImageSize {360, 270}, three colors (vertex=yellow, facet=blue, unlabeled=red — though for *this* renderer the three colors map to truth/MH/IS, not the three measure types).

Outputs:
- `figures/manuscript_panels/truth_*_p{p}.pdf` — per-panel for the manuscript.
- `figures/stacked_previews/truth_*.png` — 3-panel review previews.
- `figures/combined_truth_overlay.pdf` — multi-page review.

### Phase 4 — Manuscript integration

Per-figure decision based on Phase 1's reachable grid:

| Figure | (2, 4) | (2, 5) | (2, 6) | (3, 4) | (3, 5) | (3, 10) | (4, 10) |
|--------|:------:|:------:|:------:|:------:|:------:|:-------:|:-------:|
| Status | truth  | truth  | truth  | truth  | truth  | sampler | sampler |

For figures that involve a (p, q=10) panel, truth is unreachable and we keep MH (or whatever the production sampler ends up being) for those panels. The manuscript methods section gets an explicit reachability table.

Manuscript edits live in `docs/Pure Clique Complexes.tex`. **Defer until Phases 2–3 land.**

### Phase 5 — Literature reading (parallel track)

Bobrowski & Krioukov 2021, "Random Simplicial Complexes: Models and Phenomena" (arXiv:2105.12914). Review article surveying:
- Random simplicial complex models (Linial-Meshulam, random clique, random flag, etc.).
- Phase transitions / threshold phenomena (when does Hₖ vanish; when does the complex become connected; etc.).
- Distributional limits of topological invariants (Betti numbers, Euler characteristics).
- Statistical / entropy framing — which is the angle our paper shares.

Output: `docs/literature_notes.md` — running notes, organized by:
1. Models and how each maps (or fails to map) to "pure simplicial complex with q facets at fixed p."
2. Threshold results applicable to our regime (probably few — most threshold work is at fixed dimension / growing n, while our model is fixed p, q with growing complexity).
3. Distributional-limit results we can cite for context in the manuscript intro.
4. **Whether anyone has a known formula for the count of pure-simplicial iso classes at fixed (p, q).** If yes, that's a check on our enumeration; if there's also a generator for them, it might unlock more cells than our DFS+bucket approach can reach.

Other papers to follow up on as their citation graph dictates: Linial-Meshulam, Kahle, Costa-Farber. Track in the same notes file.

## Alternative enumeration approaches (for pushing the cap)

Phase 1 settled the reachable grid for the *current* approach. Below are the options for unlocking (2,7), (3,6), (4,5), and beyond, sorted from cheapest to most ambitious. None are committed — listed so the next sprint can pick.

### A. Longer compute budget (no code change)

Just rerun the streaming probe with `COMB_PROBE_TIMEOUT=21600` (6 hr/cell) on the unreachable cells. (2,7) and (3,6) plausibly finish; (4,5) probably still doesn't. Cheap to try; no new code. Worth doing once to confirm whether the wall is "30 min / cell" or genuinely "24+ hr / cell."

### B. Stronger canonical hash (BLISS canonical form)

Replace `canonicalKey` (the cheap `(numV, vDegrees, pairOverlaps)` tuple) with `CanonicalGraph` of the bipartite face-incidence graph. Encoding:
- V-side: one vertex per complex-vertex, no special tag.
- F-side: one vertex per facet, plus 2 leaf-tag vertices attached to each F-side node so that V-side and F-side aren't permuted into each other during canonicalization.
- Edges: incidence (v, f) iff v ∈ f; plus the leaf attachments.

Because the bipartite graph captures the full structure (no information loss), `CanonicalGraph` produces a true canonical form and equal canonical forms imply iso. Buckets shrink to 1 rep each, and the within-bucket `IsomorphicSimplicialComplexQ` call disappears entirely.

Risk: `CanonicalGraph` itself runs BLISS, which has its own cost. For our complexes (≤ p·q ≤ 40 vertices) it's likely faster than `IsomorphicSimplicialComplexQ` per call, but needs benchmarking. Estimated speedup: 1.3× to 2× over the current streaming pipeline. Probably doesn't change reachability — DFS traversal cost dominates, not iso testing.

Half a day of work.

### C. Drop the iso confirmation entirely (trust the hash)

If the cheap canonical key (or the BLISS one) has zero collisions across non-iso classes for the cells we care about, we can skip the within-bucket iso check entirely. `numBuckets` would equal `|isoReps|` exactly. Cheaper per emission.

How to verify: at each completable cell, compute `numBuckets` and `|isoReps|` separately; if they match across (2,4), (2,5), (2,6), (3,4), (3,5), trust it forward. Phase 1 data already gives `numBuckets = 9, 17, 31, 46, 159` versus `|isoReps| = 11, 26, 68, 66, 445`. **Buckets ≠ iso classes** with the current cheap hash, so this approach doesn't work for the cheap hash. With BLISS canonical form (option B), buckets should equal iso classes by construction — option C falls out for free if we adopt B.

### D. DFS pruning by canonical augmentation (McKay-style)

The expensive thing isn't testing iso at the leaves — it's that we *generate the same iso class many times* (28k facet-labeled complexes for 445 iso classes at (3,5)). McKay's canonical-augmentation method generates each iso class exactly once by:
1. At each DFS node, define a canonical ordering of children.
2. Only descend into a child if it's the canonical augmentation of the current state — i.e., adding it doesn't break canonicity.

For our setting: at each partial state (list of vertex membership-subsets), only extend with a vertex `v` if the resulting state is the lex-canonical labeling of the underlying complex with `numV+1` vertices. The lex-canonical check is itself a small canonicalization problem on the partial state.

Expected gain: at (3,5) we'd generate ~445 emissions instead of 28,344 — a 60× reduction. Most of the savings translate directly to wall-clock since DFS traversal cost is the dominant term. (3,6) and (4,5) become plausibly reachable; (2,7) likely too.

Cost: a real research-engineering project. The canonical-augmentation predicate has to be correct or we'll lose iso classes silently. Validation against the streaming pipeline on the reachable grid is the gate. Estimated: 1–2 weeks of work, possibly a new paper if we get the formulation clean.

### E. External nauty / bliss

Call out to compiled `bliss` or `nauty` binaries for canonicalization and iso testing. Potentially 10–100× faster than Mathematica's iso check per call. Combine with options B and D for compound speedup.

Cost: shell-out infrastructure (process, stdin/stdout encoding), Windows-side build/install of nauty. Probably 2–3 days. Doesn't change asymptotics, but a constant-factor 50× would put (2,7) and (3,6) in reach.

### F. Bottom-up: enumerate (p, q+1) from (p, q)

Given a complete iso-class enumeration at (p, q-1), enumerate (p, q) by adding one new facet to each (p, q-1) iso class in every inequivalent way. Each iso class at (p, q) is reached by extending some iso class at (p, q-1) — but possibly through multiple (p, q-1) parents, so we still need a dedupe step.

Advantage: re-uses the (p, q-1) work; never regenerates the shared substructure.

Disadvantage: still has the dedupe cost of comparing (p, q) iso classes to each other. Probably amounts to roughly the same total cost as DFS-from-scratch, just front-loaded.

Probably not worth it unless we already have many (p, q-1) caches sitting on disk.

### G. Topological filtering at gen time

Most paper figures focus on connected complexes, pseudo-manifolds, manifolds — not the full set of pure complexes. If we restrict generation to a structural subclass during DFS, emission count drops dramatically.

ECGrav `main` (the in-progress branch we vendored alongside 1.0.0) has `CombinatorialManifoldQ`, `OrientableCombinatorialManifoldQ`, `RandomUnlabeledPseudoManifold`, and Hamiltonians for these subclasses. Adapting these as DFS pruning predicates is feasible — but probably premature until the manuscript's scope is locked.

### Recommendation

For Phase 2: ship with the current pipeline on the five reachable cells. That's enough truth for most of the manuscript.

For pushing the cap, in priority order:
1. **A** (longer budget) — try once before doing real work, costs nothing.
2. **D** (canonical augmentation) — biggest expected payoff, but real research-engineering.
3. **B + E** (BLISS canonical form, possibly via external nauty) — nice constant-factor speedups; combines well with D.

## Risks and known unknowns (corrected post-Phase-1)

- **The wall is the generator, not iso testing.** Phase 1's plan had this backwards. At (3,5) — the largest reachable cell — gen took 476s and iso took 1074s under the eager pipeline; iso is heavier in absolute terms. But every timeout case died in `GenerateAll`, never producing a finished complex. The streaming pipeline confirms this — even with online dedupe (no separate iso phase), the same cells time out. **Mitigation:** see the alternative-approaches section above.
- **(4,10) is almost certainly impossible.** At p·q = 40 vertices, even canonical-augmentation enumeration is unlikely to handle the iso class count. The plan does not promise it. The smoking-gun panel stays in the manuscript with sampler-only bars regardless.
- **`canonicalKey` collisions.** The cheap invariant in `streaming_enumerator.wl` is not a true canonical form; within-bucket iso checks catch any non-iso classes that share a key. Phase 1 data shows `numBuckets < |isoReps|` at every cell, so collisions are common and the iso check is doing real work. Switching to BLISS canonical form (option B) eliminates this concern.
- **Statistic compute cost** per iso class is bounded but nontrivial — Betti₂ and Betti₃ involve homology over ℤ₂. `ParallelMap` over iso-class reps in Phase 2's stats step is the obvious win. Likely irrelevant for our reachable grid (≤ 600 iso classes total) but worth keeping in mind for option D / E expansions.

## Deliverables

| File | Status | Notes |
|------|--------|-------|
| `docs/enumeration_scaling.md`        | ✅ done | Phase 1 results |
| `src/streaming_enumerator.wl`        | ✅ done | Streaming gen + bucketed dedupe |
| `src/scaling_probe.wl`               | ✅ done | Eager pipeline probe |
| `src/scaling_probe_streaming.wl`     | ✅ done | Streaming pipeline probe |
| `src/test_streaming.wl`              | ✅ done | Correctness check |
| `src/enumerate_truth.wl`             | ✅ done | Phase 2 driver |
| `data/p{p}q{q}_truth.wxf`            | ✅ done | Phase 2 — five files (3.4–129.4 KB) |
| `src/render_truth_overlay.wl`        | pending | Phase 3 |
| `figures/combined_truth_overlay.pdf` | pending | Phase 3 |
| `docs/literature_notes.md`           | pending | Phase 5 |

## Out of scope

- Hamiltonian definition / MC tempering schedule. Betre's email confirms this is the next major workstream after truth enumeration; it depends on the manifold-detection Hamiltonians in ECGrav `main` (`H1dCombManifold`, `H2dCombManifold`, `H2dPseudoCombManifold`, `LowEnergyStates`). **Defer to a separate plan.**
- Replacing the IS pipeline. The IS data on disk stays as-is for diagnostic comparison; nothing depending on it gets deleted until truth + MH cover its role.
- Production runs of MH at (4,10). The smoking-gun panel's MH bars come from existing 25k+5k chains; longer runs are a separate decision tied to whether the figure goes in the paper.

## Sequencing

1. ✅ **Phase 1 — done 2026-05-02.** Half a day budgeted; took ~1.5 days including the streaming-pipeline development.
2. ✅ **Phase 2 — done 2026-05-04.** Compute was fast as predicted (~14 min wall-clock for the full grid); the work was in the persistence schema, validation gates, and the `statsFor` integration via override-suppressed `Get` of `pure_simplicial_compute.wl`.
3. **Phase 5 (reading) can start in parallel.** Doesn't block anything; informs the manuscript intro.
4. **Phase 3 next.** Two days. Templates: `render_uniformity_check.wl` (per-iso-class bar style), `render_all_figures.wl` (3-color translucent overlay style + manuscript-panel naming).
5. **Phase 4 last** — manuscript edits on top of confirmed reachability.

End state: the manuscript figures show truth bars for (2, q≤6) and (3, q≤5), MH bars where truth is out of reach, and the (4,10) smoking-gun panel as honest evidence of why IS has to go.
