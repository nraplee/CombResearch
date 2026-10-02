# ECGrav 1.17.0 sampler validation: results

To: Dr. Betre
From: Elijah Raplee
Date: 2026-09-26
ECGrav version: 1.17.0 (commit d15739c), Wolfram 15.0.1

## Summary

I tested the new counters and samplers against our exact enumeration on the 9-cell truth grid: (p,q) = (2,4), (2,5), (2,6), (2,7), (3,4), (3,5), (3,6), (4,4), (4,5). Each cell was tested with all three ensembles: vertex-labeled, facet-labeled and unlabeled.

- **Counters are exact.** `NumUnlabeledPureComplexes`, `NumFacetLabeledPureComplexes` and `NumVertexLabeledPureComplexes` match our enumerated counts exactly, at every vertex count n, on all 9 cells. This includes the (4,5) iso-class total of 5,532, which settles the cross-check we were doing with the `.mx` files.
- **The exact samplers pass everything.** `RandomUniformUnlabeled…`, `RandomUniformFacetLabeled…` and `RandomVertexLabeled…` (n free) pass every test on all 27 cell × ensemble combinations, including a per-class goodness-of-fit test.
- **`RandomPureSimplicialComplexMCMC` passes, but its samples are not independent.** It passes our Phase 4 criterion on all 27 combinations. However, for the unlabeled ensemble the returned samples are correlated, contrary to the usage message. The `corrT` spacing is too short. Details are in the MCMC section below.
- **The old `RandomFacetLabeledPureSimplicialComplex` is still non-uniform.** It fails every test (L1 ≈ 0.22), as expected. We used it as a negative control to confirm the tests can detect a wrong sampler.

## How we tested

We have exact truth from brute-force enumeration: every isomorphism class, with |Aut|, |Aut_F| and the other statistics. From it, π_V ∝ n!/|Aut|, π_F ∝ q!/|Aut_F|, and π_U is uniform.

We canonicalize each sample and match it to its truth class. The canonical form is the vertex–facet incidence graph run through `CanonicalGraph`, with a gadget attached to each facet node so the vertex and facet sides stay distinct.

Tests per cell and ensemble:

1. **numV L1.** L1 distance between the sampled and exact vertex-count distributions. The pass threshold is 0.05, the same criterion we used for our own MH sampler.
2. **iid p-value.** How likely the observed L1 is under genuinely independent sampling at the same N, from 1,000 multinomial resamples.
3. **Per-class χ².** A chi-square test over the iso classes, with bins pooled so that each expected count is at least 5.
4. **Support check.** The number of samples that match no truth class. It must be 0.
5. **Other statistics.** L1 on the other 11 statistics (|Aut|, |Aut_F|, connectivity, component counts, Betti numbers).
6. **Effective sample size.** ESS = N/(2τ_int), with τ_int measured on the numV sequence.

## Exact samplers (N = 100,000 per cell and ensemble)

| | Result |
|---|---|
| numV L1 | 0.002 – 0.011, all 27 pass |
| iid p-value | 0.018 – 0.95, consistent with uniform across the 27 tests |
| per-class χ² p | 0.058 – 0.98 |
| samples outside the truth support | 0 |
| τ_int of the sample stream | 0.50 – 0.51, so the draws are independent |

Throughput, in independent samples per second (single kernel, serial):

| cell | unlabeled | facet | vertex |
|---|---|---|---|
| (2,4) | 1,571 | 3,462 | 7,663 |
| (3,5) | 532 | 3,059 | 9,108 |
| (3,6) | 259 | 3,982 | 10,945 |
| (4,5) | 149 | 2,686 | 14,640 |

At q=10, a timing pilot gave:

| sampler | p=2 | p=3 | p=4 |
|---|---|---|---|
| unlabeled | 88 ms | 0.49 s | 3.9 s |
| facet | 1.7 ms | 4.5 ms | 25 ms |
| vertex | 0.4 ms | 0.4 ms | 0.4 ms |

The unlabeled sampler is the only one whose per-sample cost limits q=10 work.

## `RandomPureSimplicialComplexMCMC` (N = 20,000 per cell and ensemble)

All chains reported `converged -> True`, and every sample lay inside the truth support. On the numV L1 criterion all 27 combinations pass, with L1 from 0.006 to 0.030. Total wall time was about 15 min each for vertex and facet, and 2 h 10 min for unlabeled.

We also checked the chain itself. The weights in `RandomPureSimplicialComplexMCMCSweep` reduce exactly to π_V, π_F and π_U on iso classes, since `PureComplexFacetStabilizerGroupOrder` = |Aut|/|Aut_F|. The proposal is symmetric.

**The problem: the returned samples are not independent, especially for unlabeled.** `corrT` came out at 2–5 sweeps. We ran a separate per-sweep trace and measured τ_int of numV at 1.5–4.6 sweeps for unlabeled. As a result, the sample stream returned by the driver has an effective sample size well below N:

| ensemble | ESS / N of the returned samples |
|---|---|
| unlabeled | 0.31 – 0.73 |
| facet | 0.53 – 0.96 |
| vertex | 0.65 – 0.86 |

**Where this shows up: (4,5) unlabeled.** This is the hardest cell, with 5,532 classes. The full 20k stream fails the strict tests:

- iid p = 0.002
- per-class χ² p = 0.0006
- numV L1 = 0.030 (still under 0.05)

Keeping only every 2nd, 3rd or 5th sample fixes the per-class test: p = 0.24–0.79 in 8 of 9 thinned subsets. So the chain is not putting mass on the wrong classes.

The numV marginal of the thinned subsets, however, still runs somewhat noisier than independent draws of the same size:

| sampler | subset size | numV L1 |
|---|---|---|
| MCMC, thinned | same sizes | 0.021 – 0.049 |
| exact sampler | same sizes | 0.018 – 0.029 |

Two of the nine thinned subsets still have a low iid p-value (0.001 and 0.015).

Our reading is that the vertex count drifts slowly over the long run, and the `corrT` estimate does not capture that. We see no evidence of bias, but these data can't exclude a small one. A longer (4,5) run with wider spacing would settle it, and we can do that if it's useful.

Two suggestions:

1. Space samples by a multiple of the measured τ_int, for example 2τ_int or more, rather than by `corrT` directly.
2. Consider estimating τ_int with a windowed or automatic cutoff, rather than truncating at the first negative autocorrelation. First-negative truncation tends to underestimate τ_int for slowly drifting observables such as numV.

## Comparison with our own samplers

Throughput on the numV observable, in independent samples per second:

| method | unlabeled | facet |
|---|---|---|
| ECGrav exact | 150 – 1,600 | 2,500 – 4,000 |
| ECGrav MCMC | 7 – 44 | 65 – 624 |
| our Metropolis–Hastings | 3 – 9 | 1 – 12 |
| importance reweighting of vertex-labeled draws | ESS/N falls to ~0.001 by (3,6) and (4,5) | same |

We plan to switch our figures to the exact samplers, including q=10, where our reweighting estimates had single-digit ESS.
