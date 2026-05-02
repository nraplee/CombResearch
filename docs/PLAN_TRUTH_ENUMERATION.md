# Plan — Truth-enumeration pipeline (q-sweep, target q=10, expected cap q=5)

> Written 2026-05-01. Supersedes `docs/NEXT.md` for the active workstream. Paper is delayed pending sampler decision; the right panel of `figures/sampler_mh_progress.png` (IS reweighting collapsed to a near-delta at numV=18 against an MH chain that disagrees by ~3 mean units) is the smoking gun that motivates this plan.

## Goal

Produce **exact, deterministic** truth distributions over isomorphism classes — the blue bars in `figures/sampler_mh_progress.png` — across as much of the (p, q) grid as fits in memory and time. Three exact measures per case (vertex-labeled, facet-labeled, unlabeled), all 13 statistics, every (p, q) we can enumerate. These bars are the ground truth that MH (and the abandoned IS pipeline) get compared against.

Target: (p, q) up to (4, 10). Realistic cap: q≈5 in the worst-purity case. Plan embraces partial coverage — the truth grid is whatever fits, and we publish only what we can verify.

## Why now

1. The MH sampler is verified at (2,4) and (3,4). It needs verification at *more* points before we trust it at (4,10) where no truth is reachable. Each additional truth case we can compute is one more independent confirmation that MH math + mixing both work.
2. Wherever truth is reachable, **truth replaces empirical bars in the manuscript** — no chain noise, no ESS caveat, just the exact distribution. We expect this to apply across most p=2 figures and at small q for p=3.
3. Betre confirmed a Hamiltonian is essential for the MC pipeline to scale; the new ECGrav `main` source has `H1d/H2dCombManifold`, `H2dPseudoCombManifold`, `LowEnergyStates`, etc. to support that. **This plan is upstream of that work** — truth bars don't depend on the Hamiltonian; they're needed regardless of which sampler ends up in production.

## What "truth enumeration" means here

For a given (p, q):

1. **Enumerate.** `allLab = GenerateAllFacetLabeledPureSimplicialComplexes[{p, q}]` produces every facet-labeled complex on a relabeled vertex set.
2. **Reduce to iso classes.** `iso = ChooseNonIsomorphicSimplicialComplexes[allLab]` — one representative per iso class.
3. **Compute weights** per iso class X:
   - `aut(X)  = PureComplexAutomorphismGroupOrder[X]`
   - `autF(X) = PureComplexFacetAutomorphismGroupOrder[X]`
   - `nV(X)   = number of vertices`
4. **Three exact distributions** over the iso classes:
   - Vertex-labeled: `π_V(X) ∝ nV(X)! / aut(X)`   (count of distinct vertex labelings of [X] on nV labels)
   - Facet-labeled: `π_F(X) ∝ q! / autF(X)`        (count of distinct facet labelings of [X])
   - Unlabeled:     `π_U(X) ∝ 1`                   (uniform on iso classes)
5. **Statistics.** Reuse `statsFor` from `src/pure_simplicial_compute.wl` to compute the 13-vector per iso-class rep. Push each (statistic, distribution) through to a histogram.

These are **exact**: no sampling, no ESS, no chain. The only error is rounding.

## Existing infrastructure we build on

- `GenerateAllFacetLabeledPureSimplicialComplexes`, `ChooseNonIsomorphicSimplicialComplexes`, `PureComplexAutomorphismGroupOrder`, `PureComplexFacetAutomorphismGroupOrder` — all in ECGrav 1.0.0 (no new install needed for this work).
- `src/render_uniformity_check.wl` — already does exactly this at (p=2, q=4). Generalize.
- `src/render_sampler_progress.wl` — produces the smoking-gun figure. The truth-bar logic at (2,4) and (3,4) is the template.
- `src/pure_simplicial_compute.wl::statsFor` — the statistics function we want to apply per iso-class rep.

## Phases

### Phase 1 — Scaling probe (1–2 hrs)

Before writing the production enumerator, find the actual cap. Quick `wolframscript` benchmarks of `GenerateAllFacetLabeledPureSimplicialComplexes[{p, q}]` for:

| p | q values to try |
|---|---|
| 2 | 5, 6, 7, 8, 9, 10 |
| 3 | 5, 6 (then stop on memory/time) |
| 4 | 5, 6 (then stop) |

For each, record:
- |allLab| (count of facet-labeled complexes)
- |iso| (count of iso classes after `ChooseNonIsomorphic...`)
- wall-clock for `GenerateAll...` and for `ChooseNonIsomorphic...`
- peak memory (`MaxMemoryUsed`)

Write results to `docs/enumeration_scaling.md`. The two cost drivers are different:
- `GenerateAll...` is a generator — memory bounded by what we hold.
- `ChooseNonIsomorphic...` does pairwise iso testing in O(|allLab|²) worst case. **This is likely the wall.**

If `ChooseNonIsomorphic...` is the bottleneck, swap in a `CanonicalGraph`-bucket-then-deduplicate strategy as part of Phase 2. The existing helper does pairwise comparisons; canonical-form bucketing is O(|allLab| · cost(canonical-form)).

**Exit criteria:** a concrete (p, q) cap declared, with a number for memory and wall-clock at the boundary. Updates the goal grid for Phase 2.

### Phase 2 — Enumeration cache (`src/enumerate_truth.wl`)

Single script, parameterized over `(p, q)`. For each case:

1. Enumerate → reduce to iso classes (with canonical-form bucketing if Phase 1 says we need it).
2. For each iso-class rep: compute `aut`, `autF`, `nV`, plus the 13 stats from `statsFor`.
3. Persist to `data/p{p}q{q}_truth.wxf`. Schema:
   ```
   <|
     "p" -> p, "q" -> q,
     "numIsoClasses" -> Length[iso],
     "complexes" -> {<|"facets"->..., "aut"->..., "autF"->..., "nV"->..., "stats"-><|...|>|>, ...},
     "wallClockSec" -> ..., "peakMemMB" -> ..., "ecGravVersion" -> ...
   |>
   ```
4. Idempotent: skip cases whose WXF already exists and is non-empty. Force-recompute via env var `COMB_FORCE=1`.
5. Driver: enumerate the (p, q) cap grid sequentially (or `ParallelMap` over the grid; cases are independent).

**Validation gates** before declaring Phase 2 done:
- (p=2, q=4): match `render_uniformity_check.wl`'s 11 iso classes exactly.
- (p=3, q=4): match `render_sampler_progress.wl`'s 66 iso classes exactly.
- One spot-check of `numV` distribution against an N=200k MH chain at the same (p, q): L1 < 0.05.

### Phase 3 — Truth-overlay renderer (`src/render_truth_overlay.wl`)

Reads `data/p{p}q{q}_truth.wxf` plus optional sampler outputs. Produces the same per-figure 3×1 column structure the manuscript uses (one panel per p), with these layers per panel:

- **truth (blue, solid):** present whenever the (p, q) WXF is on disk.
- **MH chain (red, translucent):** present whenever an MH sample exists. Validates MH against truth.
- **IS reweighted (yellow, translucent):** present whenever the IS WXF exists. Demonstrates the q=10 collapse on the same axes.

Where truth is absent (i.e. q=10 for p=3,4), only MH + IS layers render — that's the smoking gun panel and stays in the deck as evidence.

Style matches existing `render_all_figures.wl`: Times 11pt, ImageSize {360, 270}, three colors (vertex=yellow, facet=blue, unlabeled=red — though for *this* renderer the three colors map to truth/MH/IS, not the three measure types — the *measure type* is encoded by which figure it is, not which bar within a panel).

Outputs:
- `figures/manuscript_panels/truth_*_p{p}.pdf` — per-panel for the manuscript.
- `figures/stacked_previews/truth_*.png` — 3-panel review previews.
- `figures/combined_truth_overlay.pdf` — multi-page review.

### Phase 4 — Manuscript integration

For figures where truth is reachable on the full (p, q) grid we publish (i.e. all p at q=5 if Phase 1 confirms feasibility):
- Replace IS bars with truth bars in the manuscript figures.
- Drop the ESS caveat from the figure captions for those cases.

For figures where truth is reachable only partially (e.g. truth at q=4 for p∈{2,3,4} but only sampler bars at q=10):
- Add a "truth where reachable, sampler elsewhere" caveat, with the per-(p,q) reachability stated explicitly in a table in the methods section.

Manuscript edits live in `docs/Pure Clique Complexes.tex`. **Defer until Phases 1–3 land** — the actual content depends on which cases turn out to be reachable.

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

Other papers to follow up on as their citation graph dictates: Linial-Meshulam, Kahle, Costa-Farber. Track in the same notes file.

## Risks and known unknowns

- **Iso testing is the cost wall.** `ChooseNonIsomorphicSimplicialComplexes` likely uses pairwise `IsomorphicSimplicialComplexQ`. At (3,5) and (4,5) the input list could be 10⁴–10⁶ complexes; pairwise is infeasible. **Mitigation:** canonical-form bucketing (`CanonicalGraph[GraphFromCliques[c]]` as a hash key) in Phase 2; dedupe within buckets only.
- **Memory at p=4.** The vertex set ranges up to N = p·q = 40 for (4,10), and even at q=5 (N=20) the count of facet-labeled (4,5)-complexes is `Binomial[20, 4]^5` upper bound — most of which fail purity, but the generator may still materialize too much. **Mitigation:** stream the generator and bucket on the fly; never hold the full list.
- **Statistic compute cost** per iso class is bounded but nontrivial — Betti₂ and Betti₃ involve homology over ℤ₂. `ParallelMap` over iso-class reps is the obvious win.
- **Truth at (4,10) is almost certainly impossible.** The plan does not promise it. The smoking-gun panel stays in the manuscript with sampler-only bars regardless.

## Deliverables

- `docs/enumeration_scaling.md` — Phase 1 scaling table.
- `src/enumerate_truth.wl` — Phase 2 enumerator.
- `data/p{p}q{q}_truth.wxf` — one per reachable (p, q).
- `src/render_truth_overlay.wl` — Phase 3 renderer.
- `figures/combined_truth_overlay.pdf` and per-panel PDFs.
- `docs/literature_notes.md` — running paper notes (Phase 5; lives independently).

## Out of scope

- Hamiltonian definition / MC tempering schedule. Betre's email confirms this is the next major workstream after truth enumeration; it depends on the manifold-detection Hamiltonians in ECGrav `main` (`H1dCombManifold`, `H2dCombManifold`, `H2dPseudoCombManifold`, `LowEnergyStates`). **Defer to a separate plan.**
- Replacing the IS pipeline. The IS data on disk stays as-is for diagnostic comparison; nothing depending on it gets deleted until truth + MH cover its role.
- Production runs of MH at (4,10). The smoking-gun panel's MH bars come from existing 25k+5k chains; longer runs are a separate decision tied to whether the figure goes in the paper.

## Sequencing

1. **Phase 1 first** — without scaling data, Phase 2 is shooting in the dark. Half a day.
2. **Phase 5 (reading) starts in parallel.** Doesn't block anything; informs the manuscript intro.
3. **Phase 2 once Phase 1 returns a cap.** Two to three days including validation gates.
4. **Phase 3 after Phase 2.** Two days.
5. **Phase 4 last** — manuscript edits on top of confirmed reachability.

End state: the manuscript figures show truth bars wherever computable, MH bars where truth is out of reach, and the (4,10) smoking-gun panel as honest evidence of why IS has to go.
