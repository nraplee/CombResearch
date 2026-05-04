# Next session — handoff

> Written 2026-04-27, updated 2026-04-29 with MH-prototype state. Email to Dr. Betre was sent 2026-04-29 (per Elijah).
>
> **Superseded 2026-05-01 → 2026-05-02 by `docs/PLAN_TRUTH_ENUMERATION.md`** for the active workstream. Phase 1 of that plan is now complete (reachable grid `{(2,4), (2,5), (2,6), (3,4), (3,5)}`, see `docs/enumeration_scaling.md`); Phase 2 is next. The MH-sampler verification details below are still valid history — keep them as the durable evidence base for "MH math is correct," referenced in the plan and (eventually) the manuscript. Sections discussing IS pipeline next steps are stale.

## Where we are

Batch3 is done. We now have the largest IS-reweighting dataset the q=10 pipeline can ever meaningfully produce, and it confirms the heavy-tail diagnosis from `docs/PIPELINE.md`.

**Final merged ESS** (unlabeled / facet, from `logs/concat_post_batch3.log`):

| p | merged N | ESS_unlabeled | ESS_facet |
|---|----------|---------------|-----------|
| 2 | 2,000,000 | 667 | 527 |
| 3 | 12,000,000 | 123 | 118 |
| 4 | 12,000,000 | 25 | 29 |

Read: p=2 fine; p=3 at the borderline; **p=4 confirmed broken-IS-regime** — 24× more samples (500k → 12M) only nudged ESS from 4 to ~27, and the trajectory was non-monotone (12 → 4 → 24 → 25).

## What's on disk now

- `data/p{2,3,4}q10_merged_stats.wxf` — full merged stats with weights. **Load these with the renderer.**
- `data/p{3,4}q10_n10000000_batch3_complexes.wxf` — raw complexes from batch3 only (Dr. Betre asked for these). Legacy batches don't have them.
- `figures/manuscript_panels/*_merged.pdf` — ~30 individual per-panel PDFs (batch1+2+3 combined).
- `figures/combined_all_figures_merged.pdf` — multi-page review PDF.
- `figures/stacked_previews/*.{pdf,png}` — 3-panel column previews.
- `logs/concat_post_batch3.log`, `logs/render_post_batch3.log` — run output.

## Pipeline changes landed in this session

- **`src/concat_samples.wl`** — patched to log a warning and skip the complexes merge when input siblings are missing (legacy migrated WXFs have no complexes), instead of aborting. Stats merge always runs.
- **`src/render_all_figures.wl`** — switched to merged WXFs (`stem` returns `p{p}q10_merged`, `sampleTag = "merged"`); existing `_n500k` outputs untouched on disk.

## When you return

1. **If Dr. Betre has replied:** write a fresh plan reflecting his direction. The drafted email is at `docs/email_betre_post_batch3.md` — confirm the actual sent text matches before throwing it out, then delete the draft.
2. **If no reply yet:** nothing to do. The figures, ESS, and email draft are the deliverable until he weighs in.
3. **Sanity-check the figures** (`figures/combined_all_figures_merged.pdf`) yourself if you haven't already — vertex-labeled bars should be smooth and stable; facet/unlabeled at p=4 will be visibly spiky / outlier-dominated. That's expected and matches the ESS=25/29.

## Pending / blocked

- **Email to Dr. Betre.** SENT 2026-04-29. Draft at `docs/email_betre_post_batch3.md` may now be stale — confirm sent text matches, then delete the draft.
- **Sampler swap.** Sketched in the email; awaiting Dr. Betre's reply. Elijah's stance: doubts we'll actually rewrite the samplers; an old accept/reject sampler exists but is too inefficient to use.
- **Manuscript text** updates to caveat the p=4 figures — defer until sampler decision lands.
- **Add Dr. Betre as GitHub collaborator** once he sends his username (carryover from prior handoff).

## MH sampler prototype (2026-04-29, exploratory only)

User asked for a "for shits and giggles" Metropolis-Hastings prototype targeting iso-class measures directly. Lives at `src/sampler_mh.wl`. Plain-language writeup of IS-vs-MH at `docs/sampler_writeup.md` (shareable with Dr. Betre if useful). **Status: runs end-to-end, math hand-verified AND empirically verified against enumeration at p=2 q=4. NOT in the production pipeline. Do not use for figures yet.**

### Design (current revision, after one rewrite)

- **State space:** sorted q-tuples of distinct sorted p-subsets of fixed ambient `[N]` with `N = q·p`. Active vertex set = ⋃ F_i. **No canonicalization** (this was a bug in the first draft — see below).
- **Targets:**
  - `unlabeled`: π(X) ∝ |Aut(X)| · (N − numV)!  → uniform marginal on iso classes
  - `facet`: π(X) ∝ |Aut(X)| · (N − numV)! / |Aut_F(X)|  → uniform on facet-labelings
  - `vertex`: π(X) ∝ 1  → sanity check, should match IS vertex-labeled
- **Proposal:** pick i ∈ {1..q}, replace F_i with uniform p-subset of [N] not equal to other facets. Symmetric, so α = min(1, π(Y)/π(X)).
- **Hand-verified at p=2 q=2 N=4:** path iso (12 states · weight 2·1!) = matching iso (3 states · weight 8·0!) = 24 each. ✓

### What was wrong with the first draft

First draft canonicalized state to "labels in first-appearance order, no unused labels." That breaks detailed balance: canonicalization collapses different vertex-labelings of the same iso class to a *variable* number of canonical forms (e.g. for the (p=2,q=2) path, 3 labelings → 2 canonical forms; for matching, 3 labelings → 1). The chain's iso-class marginal becomes ∝ 1/c([Y]) for an irregular collapse factor c. Empirically: gave E[numV]≈10 at p=4 q=10 vs IS-empirical ≈18.6.

### Current empirical results (q=10, target=unlabeled, smoke test 5k+1k burn-in)

| p | nMax | accept | E[numV] (MH) | E[numV] (IS @12M, ESS=25 for p=4) |
|---|------|--------|--------------|-----------------------------------|
| 2 | 20   | 0.38   | 10.24        | (didn't measure) |
| 3 | 30   | 0.18   | 12.68        | (didn't measure) |
| 4 | 40   | 0.09   | 16.23        | 18.57 |

Longer p=4 run (30k+5k burn-in): mean = 15.74, first-10k=16.07, last-10k=15.05 — drifting *down*, not converging to 18.57. **Open question: is the chain still mis-mixed, or is the IS estimate biased high by outlier weights at ESS=25?** Cannot tell without ground truth.

### Ground truth verification (DONE 2026-04-29)

Two independent enumerable cases:

**p=2 q=4** (11 iso classes, MH 30k+3k burn): all numV bins within ~2pp, E[numV] = 5.495 vs truth 5.545.

**p=3 q=4** (66 iso classes from 666 facet-labeled enumeration, MH 50k+5k burn): all numV bins within ~2pp, E[numV] = 7.402 vs truth 7.348.

**MH math is correct** — verified at two independent cases of varying complexity.

### Implication for q=10 p=4

The chain at p=4 q=10 (35k+5k burn) gives stable E[numV] ≈ 15.7 across first/last 10k. Given the math is correct, the chain is likely sampling π_U correctly, which means **the IS estimate of E[numV]=18.57 is biased high**. Mechanism: random VL sampling almost never produces numV<17 at p=4 q=10 (vertex-labeled mode is at 30), so the IS dataset's 12M samples include only a handful with very-low numV. Those few have huge `|Aut|/numV!` weights (because numV! is small), so they dominate the reweighted estimate — but they're a biased sample of the low-numV region of state space. ESS=25 quantifies "only 25 effective samples contribute," and they all happen to live at numV∈{17,18,19} because that's the lowest-numV the IS sample reached.

If this analysis is right:
- MH gives meaningfully better estimates of unlabeled/facet measures at q=10 p=4 than IS does, even at moderate sample sizes.
- The IS bars in the merged figures at p=4 are not just noisy but systematically wrong — pulled up toward the higher numV the IS sample happens to reach.
- The email to Dr. Betre still has the right top-line conclusion (sampler swap warranted) but understates the case: it's not just "ESS too low" — IS at q=10 p=4 may be producing wrong central tendencies, not just noisy ones.

**Multi-seed verification (4 chains × 25k+5k burn at p=4 q=10):**

| seed | E[numV] | first 10k | last 10k |
|------|---------|-----------|----------|
| 12345 | 16.01 | 16.07 | 15.77 |
| 67890 | 16.34 | 16.30 | 16.25 |
| 11111 | 15.68 | 16.21 | 15.66 |
| 99999 | 15.63 | 15.87 | 15.64 |

Range 15.62–16.34, mean ≈ 15.9. Within-chain first/last halves consistent. IS estimate 18.57 is ~9 inter-seed std-deviations away — a real disagreement, not noise. Treat MH ≈ 15.9 as the better estimate.

### Smarter proposal kernels (DONE 2026-04-29)

Added three new proposal kernels to `src/sampler_mh.wl` (selected via `kernel -> "..."` option to `runMHChain`):
- `local`: change one vertex in one facet
- `swap`: exchange one vertex between two facets
- `mixed`: 50% local + 30% swap + 20% global

Two benchmarks (scripts: `src/benchmark_kernels.wl`, `src/benchmark_kernels_uniformity.wl`):

**ESS/sec at p=4 q=10, target=unlabeled (numV mixing):**

| kernel | accept | τ_int | ESS/sec |
|--------|--------|-------|---------|
| global | 0.094 | 96 | **0.998** |
| local  | 0.473 | 206 | 0.569 |
| mixed  | 0.352 | 148 | 0.731 |

Higher accept rate ≠ better mixing. Local moves change numV by ≤1 per step; global moves can shift numV by up to p, so each accepted global move buys more decorrelation.

**Per-iso-class L1 to uniform at p=2 q=4 (30k+3k burn):**

| kernel | L1 to uniform | iso-11 deviation |
|--------|---------------|------------------|
| global | 0.052 | -19% |
| local  | 0.082 | +18% |
| swap   | **1.818** | -100% (stuck) |
| mixed  | 0.055 | +10% |

Swap alone is broken — chain stuck because most swap proposals at p=2 yield labelings within the same iso class. Mixed kernel is comparable on L1 and slightly better on iso-11. Modest improvement, not dramatic.

**Verdict:** mixed kernel is reasonable as a new alternative — comparable accuracy, ~26% faster wall-clock, slightly better symmetric-class coverage. Not a 10× improvement. Real gains would come from parallel tempering or smarter swap moves (3-cycle vertex rotations across 3 facets, edge contractions). Both deferred. Default kernel remains `"global"` for backward compatibility.

### ECGrav `RandomFacetLabeledPureSimplicialComplex` direct measurement (DONE 2026-04-29)

The CLAUDE.md prohibition on this sampler was inherited; we now have direct measurement. At p=2 q=4 (11 iso classes), 30k samples from each sampler, compared to q!/|Aut_F| truth:

- L1(MH facet, truth) = 0.028 (sample noise, ~7% per-bin max)
- L1(ECGrav RandomFacetLabeled, truth) = **0.427** (15× worse, single iso classes off by 6.4× over and 88% under)

ECGrav sampler is conclusively NOT uniform on facet-labelings. Warning fully justified. Figure: `figures/sampler_ecgrav_compare.{pdf,png}`. Script: `src/render_ecgrav_compare.wl`.

### Per-iso-class uniformity check (DONE 2026-04-29)

Stronger correctness test than numV-marginal: at p=2 q=4 with 11 enumerable iso classes, run MH with each target, identify the iso class of every sampled state (via `IsomorphicSimplicialComplexQ` filtered by numV), and compare visit fractions to truth. Output: `figures/sampler_mh_uniformity.{pdf,png}` (script: `src/render_uniformity_check.wl`).

**target=facet:** all 11 iso classes match truth (q!/|Aut_F| normalized) within ~5%. Clean.

**target=unlabeled:** 10 of 11 iso classes within ~7% of truth (1/11). **Iso class 11** (numV=8, |Aut|=384 — 4 disjoint edges, the most symmetric class) is undersampled at empirical 0.069 vs truth 0.091 (~25% deficit, ~13σ at 30k samples).

This is NOT a math bug — the same target produces correct counts for the other 10 classes, and the facet target produces correct counts for class 11 too. It's a **mixing artifact**: highly symmetric configurations sit in narrow basins that a local single-facet-replacement proposal struggles to enter from non-symmetric states. With more burn-in, more thinning, or a smarter proposal (e.g., a "swap two facets" or "rewire" move), the gap would close.

Practical implication: at q=10, the most-symmetric iso classes will be undersampled in target=unlabeled relative to their true π_U mass. For paper figures this likely shows up as bar heights at the symmetric end of the distribution being slightly low. Bounded magnitude — far smaller than the IS-vs-truth gap we documented above. If MH ever moves toward production, a better proposal kernel is the obvious engineering improvement.

### Next verification step (when resuming)

If pursuing further:
- Run a much longer MH chain at p=4 q=10 (e.g. 500k–1M steps, parallel tempering or smarter proposals to fight the 9% accept rate). If the running mean stabilizes < 18, evidence that IS biases high.
- Or: enumerate at one more small case (e.g. p=3 q=4) and verify match holds at slightly larger scale before trusting q=10 results.
- Or: compare MH-facet to MH-vertex output and check the vertex target reproduces the IS vertex-labeled distribution (which is direct, not reweighted, and should match at all p, q). That rules out any remaining proposal-kernel bug.

If shelving: nothing to do. Prototype lives in `src/sampler_mh.wl`, math notes in its header, this section is the running log.

### Files touched
- `src/sampler_mh.wl` — the prototype (current revision is the fixed-ambient-N version, NOT the canonicalization version)
- No data files written
- No figures written
- `data/p4q10_merged_stats.wxf` was read for IS empirical baseline (E[numV]_unlabeled=18.57, top-10 weight numVs all 17–19)

## If something goes wrong

- **Need to re-render:** `wolframscript -file src/render_all_figures.wl` — reads `_merged_stats.wxf` directly, ~1 min once samples are loaded.
- **Need to re-merge:** `wolframscript -file src/concat_samples.wl`. Idempotent; overwrites `*_merged_*.wxf` from current `data/` contents. Will warn on missing complexes (expected).
- **Want to switch back to N=500k figures:** edit `src/render_all_figures.wl:34` (`sampleTag = "n500k"`) and `:60` (`stem[p_] := "p" <> ToString[p] <> "q" <> ToString[qVal] <> "_n500000"`). The old `_n500k.pdf` outputs are still on disk untouched.
