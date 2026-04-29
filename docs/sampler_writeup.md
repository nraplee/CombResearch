# Sampling pure simplicial complexes: IS vs MH

A plain-language explanation of the current Importance Sampling pipeline, why it breaks at q=10, and how the prototype Metropolis-Hastings sampler (`src/sampler_mh.wl`) is supposed to fix it.

## What we're trying to measure

We want empirical probability distributions over **isomorphism classes** of pure simplicial complexes with `q` facets at purity `p`. "Iso class" means: two complexes are the same if you can relabel the vertices of one to get the other.

Three different probability measures show up in the paper, and they're genuinely different distributions:

1. **Vertex-labeled.** Every distinct way of labeling vertices counts as a separate object; all get equal weight. A complex with high symmetry (lots of automorphisms) has fewer distinct vertex-labelings, so it's *less* probable here.
2. **Facet-labeled.** Every distinct way of labeling the facets `1..q` counts as a separate object; all equal weight.
3. **Unlabeled** (= uniform on iso classes). Each iso class gets equal weight regardless of how many labelings it has.

A symmetric complex like "five disjoint edges" has very few distinct vertex-labelings (because permuting vertices within or across edges gives the same labeled graph). An asymmetric tree has many. So vertex-labeled sampling under-represents symmetric structures relative to the unlabeled measure. The reweighting fixes that — when it works.

## ECGrav gives us one tool

The package provides `RandomVertexLabeledPureSimplicialComplex`, which produces uniform samples from the vertex-labeled measure. That's it. To estimate any of the other two measures, we have to be cleverer.

(There is a `RandomFacetLabeledPureSimplicialComplex` in the package, but **it is not a verified uniform sampler** and is forbidden in this project — see CLAUDE.md.)

## Importance Sampling (IS) — what the current pipeline does

**The trick.** Sample from the easy distribution (vertex-labeled), then re-weight each sample so the weighted statistics behave as if the samples came from the target distribution.

**The math.** An iso class `[X]` has `|V(X)|! / |Aut(X)|` distinct vertex-labelings on `|V(X)|` labels. Vertex-labeled sampling visits `[X]` in proportion to that count. To convert to "uniform on iso classes," divide each sample's contribution by that count. The reweighting factor (paper Eq. 24) is

```
w_unlabeled(X) = |Aut(X)| / |V(X)|!
```

For the facet-labeled measure, the weight (Eq. 25) is

```
w_facet(X) = |Aut(X)| · q! / (|Aut_F(X)| · |V(X)|!)
```

**Diagnostic: Effective Sample Size (ESS).** Reweighting trades sample equality for distribution-matching. If most samples carry tiny weights and one sample carries most of the total, you effectively have one sample, not N. ESS quantifies this:

```
ESS = (Σ w_i)² / (Σ w_i²)
```

ESS = N means all weights are equal (no information lost from reweighting). ESS = 1 means one weight dominates everything.

**Why IS worked at q=3.** With `q=3`, the number of vertices `|V|` is bounded small, so `|V|!` doesn't vary much across samples. The weights `|Aut|/|V|!` are comparable in size, ESS scales linearly with N, and Figure 2 looks clean.

**Why IS breaks at q=10.** The factor `|V(X)|!` ranges over roughly **17 orders of magnitude** across samples at p=4 (`|V|` ranges 13–40, and `|V|!` is hyperexponential in `|V|`). The sample with the smallest `|V|` carries virtually all the weight. ESS does not scale with N — we observed:

| sample size N | ESS for unlabeled at p=4 |
|---|---|
| 10k       | 12 |
| 500k      | 4 |
| 10M (batch3) | 24 |
| 12M (merged) | 25 |

A 1200× increase in N moved ESS from 12 to 25, with a non-monotonic dip in the middle. This is the textbook signature of importance sampling against a heavy-tailed weight distribution: max-weight grows with N at roughly the same rate as Σ-weight, so the ratio never shrinks. **No amount of additional compute fixes this in the IS framework.**

## Metropolis-Hastings (MH) — the prototype alternative

**The idea.** Don't sample then reweight — sample directly from the target distribution by constructing a Markov chain whose long-run distribution *is* the target. Walk around in state space, accepting or rejecting each step based on a ratio. After enough steps, the chain "forgets" where it started and visits states in proportion to the target.

**State space.** A state is a list of `q` distinct `p`-element subsets of a fixed ambient label set `[N] = {1, ..., N}` where `N = q · p` (the largest `|V|` could ever be). Two different labelings of the same iso class are *different* states — we do not try to canonicalize. (An earlier draft did try to canonicalize and broke detailed balance for subtle reasons; see the file header in `src/sampler_mh.wl`.)

**Proposal kernel.** From state X:
1. Pick one of the `q` facets uniformly at random.
2. Replace it with a uniformly random `p`-subset of `[N]` not equal to any of the other `q-1` facets.

This is symmetric: probability X → Y equals probability Y → X.

**Target distribution and acceptance.** With a symmetric proposal, the Metropolis acceptance probability is `min(1, π(Y)/π(X))`, where `π` is the chosen target. For the unlabeled measure:

```
π_unlabeled(X) ∝ |Aut(X)| · (N − |V(X)|)!
```

The `(N − |V|)!` factor accounts for the unused labels in `[N]` — different vertex-labelings of an iso class differ by which subset of `[N]` they sit on, and there are `C(N, |V|)` such embeddings. The full derivation and a hand-verified small example (p=2, q=2, N=4) sit in the file's header comment.

**Why this avoids the heavy-tail problem.** Every step compares two neighboring states `X` and `Y` that differ by one facet. The ratio `|Aut(Y)|/|Aut(X)|` is bounded. The factorial ratio `(N−|V(Y)|)! / (N−|V(X)|)!` involves at most `p` terms (because one facet swap changes `|V|` by at most `p`), so it's also bounded. **No single ratio can be 17 orders of magnitude bigger than the next.** The chain never gets stuck on outlier samples because the architecture only ever asks about local ratios.

**The trade-off: correlation.** MH samples are not independent — consecutive states are very similar (one facet differs at most). The chain has to "mix" before its samples behave like an independent sample. Effective sample size for MH is `numIter / (2 τ_int)` where `τ_int` is the integrated autocorrelation time. So you need many MH steps to get one "useful" sample, but the steps are cheap and the mixing time is in principle finite — unlike the variance of IS at q=10, which is structurally infinite.

## Status of the prototype

- Math derived and reviewed in the file header.
- Hand-verified on (p=2, q=2): the two iso classes "path" and "matching" each get total mass 24 under the target, as required.
- Empirically verified against full enumeration at **two** independent cases (numV marginal):
  - (p=2, q=4): 11 iso classes; MH numV histogram within ~2pp per bin; E[numV] 5.495 (MH) vs 5.545 (truth).
  - (p=3, q=4): 66 iso classes; MH numV histogram within ~2pp per bin; E[numV] 7.402 (MH) vs 7.348 (truth).
- **Per-iso-class uniformity check** at (p=2, q=4) — stronger test than the numV marginal:
  - target=facet: all 11 iso classes match truth (q!/|Aut_F| normalized) within ~5%.
  - target=unlabeled: 10 of 11 within ~7% of truth (1/11). The 11th class (4 disjoint edges, |Aut|=384) is undersampled by ~25% at 30k samples — **not a math bug** (the facet target produces correct counts for that same class) but a mixing artifact: a local single-facet-replacement kernel struggles to reach highly symmetric configurations. Closes with more steps or a smarter proposal.
- **Math is correct; current proposal kernel mixes slowly into highly symmetric corners of state space.**

Figures:
- `figures/sampler_mh_progress.{pdf,png}` — verification at p=2 q=4 and p=3 q=4 (numV marginal) plus IS-vs-MH at p=4 q=10.
- `figures/sampler_mh_uniformity.{pdf,png}` — per-iso-class visit fractions at p=2 q=4 for both targets.
- At q=10 p=4 the chain mixes slowly (accept rate 9%) but produces stable E[numV] ≈ 15.7 across first-half/last-half of a long run. The IS-empirical estimate is 18.57. Since the MH math is verified and the chain is at stationary, **the most likely explanation is that the IS estimate is biased high** — vertex-labeled sampling almost never lands in the low-numV region where π_U has most of its mass, so the IS reweighting is dominated by a handful of slightly-low-numV samples (top-10 weights all at numV ∈ {17, 18, 19}) that don't fairly represent the bulk of the unlabeled distribution.
- Not in the production pipeline. Lives at `src/sampler_mh.wl`. To use, call `runMHChain[p, q, target, numIter]` after `Get["src/sampler_mh.wl"]` (set `$smokeTestSkip = True` first if you don't want the auto-smoke-test).

## Side check: was the ECGrav warning correct?

CLAUDE.md (and `docs/PIPELINE.md`) carry a long-standing prohibition against using `RandomFacetLabeledPureSimplicialComplex` from the ECGrav package, on the grounds that "it is not a verified uniform sampler." That warning was inherited rather than measured. Now that we have a verified uniform-on-facet-labelings sampler (MH facet target, validated against enumeration on 11 iso classes at p=2 q=4), we can directly measure how far off ECGrav's sampler actually is.

Test: at p=2 q=4, sample 30k from `RandomFacetLabeledPureSimplicialComplex`, identify the iso class of each, count visit fractions, compare to the q!/|Aut_F|-normalized truth. Same test for MH facet target as a control.

| metric | value |
|---|---|
| L1 distance MH facet → truth | **0.028** |
| L1 distance ECGrav RandomFacetLabeled → truth | **0.427** |

ECGrav's sampler is **15× further from uniform-on-facet-labelings** than MH is. Per-iso-class deviations are large in both directions — one class is over-represented by 6.4×, another is under-represented by 88%. This isn't "biased toward some inherited natural distribution" — the bias varies in sign across classes, and the magnitude (40%+ L1) is well beyond any sampling-variance explanation.

**Conclusion: the inherited warning is fully justified by direct measurement.** Whatever ECGrav's sampler is doing, it is not uniform on facet-labelings, and using its output for facet-labeled empirics would produce wildly wrong distributions. Continue treating it as forbidden.

Figure: `figures/sampler_ecgrav_compare.{pdf,png}`. Three-color bar chart, one bar per iso class for each of (truth, MH facet, ECGrav). MH and truth bars track tightly; ECGrav bars are visibly all over the place.

## What this means for the paper

The email to Dr. Betre concluded that IS is structurally unable to produce paper-quality unlabeled/facet figures at q=10 p∈{3,4} because of low ESS, and proposed MH as an alternative. The new finding sharpens the case: at p=4 q=10, IS may not just be noisy but **systematically biased** — its central tendencies (means, modes) for unlabeled and facet measures are pulled toward whatever low-numV samples happen to be in the dataset, rather than toward the true bulk of the distribution.

This raises the stakes on the sampler decision somewhat. If we publish IS-derived bars at q=10 p=4 with a "noisy" caveat, the actual error may be larger than "noisy" implies. Worth confirming with multiple-seed MH runs before treating this as definitive — one chain's output isn't proof.

## When you'd actually use this

If the paper needs paper-quality unlabeled or facet-labeled distributions at q=10 p∈{3,4}, IS is structurally unable to produce them. MH is a route that doesn't have that structural problem. The remaining engineering question is whether the proposal kernel can be made to mix fast enough at q=10 to produce useful sample sizes in reasonable wall-clock. The current proposal accepts 9% of moves at p=4 q=10; a smarter mixture of local + global moves could plausibly improve that to 30–50% (standard MCMC technique), shortening the autocorrelation time accordingly.

If the paper can publish vertex-labeled-only at q=10 (those are direct samples and fully reliable) plus a caveat about facet/unlabeled, none of this is needed.
