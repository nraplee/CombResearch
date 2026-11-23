# Sampling And MH

This document consolidates the importance-sampling and Metropolis-Hastings notes for the pure simplicial complex figures. Exact enumeration and McKay details live in `docs/enumeration.md`.

## Measures

The paper compares probability distributions over isomorphism classes of pure simplicial complexes with fixed purity `p` and facet count `q`.

- **Vertex-labeled:** uniform over vertex-labeled complexes.
- **Facet-labeled:** uniform over facet labelings.
- **Unlabeled:** uniform over isomorphism classes.

These measures are different. Symmetric complexes have fewer vertex labelings and are underrepresented by direct vertex-labeled sampling relative to the unlabeled measure.

## Importance Sampling

ECGrav's verified random sampler is:

```wolfram
RandomVertexLabeledPureSimplicialComplex[{p, q}, n]
```

Facet-labeled and unlabeled empirical estimates were originally obtained by reweighting vertex-labeled samples:

```wolfram
wVertex    = 1
wUnlabeled = |Aut(X)| / numV(X)!
wFacet     = |Aut(X)| * q! / (|Aut_F(X)| * numV(X)!)
```

For a statistic `f`:

```text
E_unlabeled[f] ≈ Sum[f(X_i) wUnlabeled(X_i)] / Sum[wUnlabeled(X_i)]
E_facet[f]     ≈ Sum[f(X_i) wFacet(X_i)]     / Sum[wFacet(X_i)]
```

Effective sample size is:

```text
ESS = (Sum[w_i])^2 / Sum[w_i^2]
```

At `q = 10`, especially for `p = 4`, `numV!` varies so much that a few low-vertex samples dominate the reweighted estimates. The largest merged IS run produced approximately:

| p | merged N | ESS unlabeled | ESS facet |
|---:|---:|---:|---:|
| 2 | 2,000,000 | 667 | 527 |
| 3 | 12,000,000 | 123 | 118 |
| 4 | 12,000,000 | 25 | 29 |

Conclusion: vertex-labeled q=10 histograms are direct samples and usable; q=10 facet/unlabeled IS histograms, especially at `p = 3, 4`, should be treated as diagnostic only unless replaced by truth or MH.

## ECGrav Facet Sampler Warning

Do **not** use `RandomFacetLabeledPureSimplicialComplex` for the facet-labeled distribution.

Direct measurement at `(p, q) = (2, 4)` showed:

| sampler | L1 to facet truth |
|---|---:|
| MH facet | 0.028 |
| ECGrav `RandomFacetLabeledPureSimplicialComplex` | 0.427 |

The ECGrav sampler is not uniform on facet labelings for this project.

## MH Sampler

`PureComplexMHChain` implements a Metropolis-Hastings chain over fixed-ambient vertex-labeled states.

State:

```text
X = sorted list of q distinct p-subsets of [N], where N = p q
```

Unused labels in `[N]` are allowed. The chain does not canonicalize states; an earlier canonicalized-state attempt broke detailed balance by collapsing different labelings of the same isomorphism class unevenly.

Default proposal:

1. Pick one facet uniformly.
2. Replace it with a uniform `p`-subset of `[N]` not equal to the other facets.
3. Sort the state.

The proposal is symmetric, so the acceptance probability is:

```text
alpha(X -> Y) = min(1, pi(Y) / pi(X))
```

Targets used in code:

```text
unlabeled: pi(X) ∝ |Aut(X)| * (N - numV(X))!
facet:     pi(X) ∝ |Aut(X)| * (N - numV(X))! / |Aut_F(X)|
vertex:    pi(X) ∝ 1 / Binomial(N, numV(X))
```

The vertex target form is important. Before 2026-05-14 the code used `pi(X) ∝ 1`, which gives the wrong isomorphism-class marginal by an extra `Binomial(N, k)` factor. The fixed acceptance ratio is:

```wolfram
Binomial[nMax, m] / Binomial[nMax, mY]
```

## MH Validation

The current 9-cell truth grid is validated against MH for all three targets:

```text
9 cells x 3 targets = 27 cell-target combinations
all pass numV-marginal L1 < 0.05
```

The `(4,5)` MH chains landed and validated:

| target | L1 |
|---|---:|
| unlabeled | 0.0253 |
| facet | 0.0294 |
| vertex | 0.0086 |

Run validation with:

```powershell
wolframscript -file pipeline\50_validate.wl samples
```

## Proposal Kernels

`PureComplexMHChain` (`CombResearch/Kernel/Subpackages/MHSampler.wl`; was `src/sampler_mh.wl`) supports, as `"kernel" -> ...`:

- `global`: replace one whole facet. Default.
- `local`: change one vertex in one facet.
- `swap`: exchange one vertex between two facets. Poor alone.
- `mixed`: 50% local, 30% swap, 20% global.

Benchmarks at q=10 found higher acceptance rate did not imply better mixing. The global kernel remains the default because it moves `numV` more effectively.

## Main Commands

```powershell
# Run MH chains.
wolframscript -file pipeline\30_mh.wl

# Restrict to one cell and target.
$env:COMB_MH_CELLS = "4,5"
$env:COMB_MH_TARGETS = "unlabeled"
wolframscript -file pipeline\30_mh.wl

# Launch all three (4,5) targets in parallel.
powershell -ExecutionPolicy Bypass -File tools\dev\run_p4q5_mh_parallel.ps1

# Monitor the parallel run.
powershell -ExecutionPolicy Bypass -File tools\dev\monitor_mh.ps1
```

## Figure Rendering

- `pipeline/60_figures.wl q10_stats` renders the q=10 IS figures (Figures 3-15).
- `pipeline/60_figures.wl truth_overlay` renders truth plus MH overlay panels for the enumerated grid.
- the `sampler_progress`, `uniformity` and `ecgrav_compare` jobs of `pipeline/60_figures.wl` are diagnostic renderers.
