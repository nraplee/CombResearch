# Plan — Truth-enumeration pipeline (q-sweep, target q=10, expected cap q=5)

> Written 2026-05-01. Phase 1 complete 2026-05-02 — see `docs/enumeration_scaling.md` for results. Phase 2 is now ready to begin and uses the streaming pipeline from `src/streaming_enumerator.wl`.

## Status (2026-05-02)

- ✅ **Phase 1 — Scaling probe.** `src/scaling_probe.wl` (eager pipeline) and `src/scaling_probe_streaming.wl` (streaming + bucketed pipeline) both run; results in `docs/enumeration_scaling.md`. Empirically reachable grid: `{(2,4), (2,5), (2,6), (3,4), (3,5)}`. (2,7), (3,6), (4,5), (4,6), and the rest of the (p, q) grid are unreachable within a 30 min budget per cell on the current host with either pipeline.
- ✅ **Streaming pipeline prototype.** `src/streaming_enumerator.wl` — DFS streaming generator + online bucketed dedupe, parallelized over starting states. Validated against ECGrav on (2,4), (2,5), (3,4); reproduces canonical iso class counts. 1.1×–3.4× faster than eager+naive on cells where eager succeeds; ~10× lower memory peak. **Does not unlock new cells.**
- ⏳ **Phase 2 — enumerate_truth.wl.** Five reachable cells, ready to build.
- ⏳ **Phase 3 — render_truth_overlay.wl.**
- ⏳ **Phase 4 — manuscript integration.**
- ⏳ **Phase 5 — literature reading.**

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

### Phase 2 — Enumeration cache (`src/enumerate_truth.wl`)

Single script, parameterized over `(p, q)`. For each case in the reachable grid `{(2,4), (2,5), (2,6), (3,4), (3,5)}`:

1. `sr = streamingEnumeratePure[p, q]` — get iso class reps.
2. For each iso-class rep: compute `aut`, `autF`, `nV`, plus the 13 stats from `statsFor`.
3. Persist to `data/p{p}q{q}_truth.wxf`. Schema:
   ```
   <|
     "p" -> p, "q" -> q,
     "numIsoClasses" -> Length[sr["isoReps"]],
     "totalFacetLabeled" -> sr["totalEmitted"],
     "complexes" -> {<|"facets"->..., "aut"->..., "autF"->..., "nV"->..., "stats"-><|...|>|>, ...},
     "wallClockSec" -> ..., "peakMemMB" -> ..., "ecGravVersion" -> "1.0.0",
     "enumeratorVersion" -> "streaming_enumerator.wl@<commit>"
   |>
   ```
4. Idempotent: skip cases whose WXF already exists and is non-empty. Force-recompute via env var `COMB_FORCE=1`.
5. Driver: enumerate the reachable grid sequentially.

**Validation gates** before declaring Phase 2 done:
- (p=2, q=4): match the 11 iso classes from `render_uniformity_check.wl`.
- (p=3, q=4): match the 66 iso classes from `render_sampler_progress.wl`.
- (p=2, q=5): match 26 iso classes (validated in Phase 1).
- (p=2, q=6): match 68 iso classes (validated in Phase 1).
- (p=3, q=5): match 445 iso classes (validated in Phase 1).
- One spot-check of `numV` distribution against an N=200k MH chain at (3, 5): L1 < 0.05.

**Estimated wall-clock:** (3,5) is the dominant cost at ~7.6 min; the rest are ≤4 min each. Full Phase 2 run ≈ 15–20 min wall-clock.

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
| `src/enumerate_truth.wl`             | pending | Phase 2 |
| `data/p{p}q{q}_truth.wxf`            | pending | Phase 2 — five files |
| `src/render_truth_overlay.wl`        | pending | Phase 3 |
| `figures/combined_truth_overlay.pdf` | pending | Phase 3 |
| `docs/literature_notes.md`           | pending | Phase 5 |

## Out of scope

- Hamiltonian definition / MC tempering schedule. Betre's email confirms this is the next major workstream after truth enumeration; it depends on the manifold-detection Hamiltonians in ECGrav `main` (`H1dCombManifold`, `H2dCombManifold`, `H2dPseudoCombManifold`, `LowEnergyStates`). **Defer to a separate plan.**
- Replacing the IS pipeline. The IS data on disk stays as-is for diagnostic comparison; nothing depending on it gets deleted until truth + MH cover its role.
- Production runs of MH at (4,10). The smoking-gun panel's MH bars come from existing 25k+5k chains; longer runs are a separate decision tied to whether the figure goes in the paper.

## Sequencing

1. ✅ **Phase 1 — done 2026-05-02.** Half a day budgeted; took ~1.5 days including the streaming-pipeline development.
2. **Phase 5 (reading) starts in parallel.** Doesn't block anything; informs the manuscript intro.
3. **Phase 2 next.** Two days including validation gates. Compute is fast (~20 min wall-clock); the work is in the persistence schema, the validation script, and the stats integration.
4. **Phase 3 after Phase 2.** Two days.
5. **Phase 4 last** — manuscript edits on top of confirmed reachability.

End state: the manuscript figures show truth bars for (2, q≤6) and (3, q≤5), MH bars where truth is out of reach, and the (4,10) smoking-gun panel as honest evidence of why IS has to go.
