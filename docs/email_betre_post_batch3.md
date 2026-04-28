# Draft email to Dr. Betre — post batch3

> Draft for Elijah's review before sending. Attach `figures/combined_all_figures_merged.pdf`.

---

**To:** [Dr. Betre's email]
**From:** elijah.raplee@sjsu.edu
**Subject:** q=10 reweighting ESS at 12M samples — sampler-swap data

Dr. Betre,

Batch 3 of the q=10 sampling run finished today. We now have **12 million vertex-labeled samples per p ∈ {3, 4}** and **2 million for p=2** (consolidated across batches 1–3). The full merged dataset is checkpointed to WXF; raw complexes for p=3 and p=4 batch3 (10M each) are available on request.

The headline result is that the vertex-labeled → unlabeled / facet reweighting (Eq. 24, 25) confirms its predicted scaling regime:

| p | N=10k | N=500k | N=10M (batch3) | **merged**          |
|---|-------|--------|----------------|---------------------|
| 2 | 27 / 13   | 369 / 244 | —          | **667 / 527** (N=2M)  |
| 3 | 7 / 9     | 26 / 21   | 97 / 93    | **123 / 118** (N=12M) |
| 4 | 12 / 11   | 4 / 4     | 24 / 23    | **25 / 29** (N=12M)   |

(ESS shown as unlabeled / facet, integers. Full log: `logs/concat_post_batch3.log`.)

**What this says:**

- **p=2** scales cleanly (~N^0.45). ESS in the hundreds is plenty for stable bar heights.
- **p=3** also scales cleanly (~N^0.4 across 10k → 500k → 10M). Merged ESS = 123 is at the borderline of the ~100 threshold for trustworthy unlabeled/facet bars. With another 10× samples I'd expect ESS ~250–300, which would be comfortable.
- **p=4 stays broken.** Going from 500k to 12M (a 24× increase) only nudged ESS from 4 to ~27 — and the path was non-monotonic (12 → 4 → 24 across the three batch sizes). This is the textbook signature of importance sampling against a heavy-tailed weight distribution with tail index α < 2: max(w) grows with N at least as fast as Σw, so the variance estimator never settles. **For p=4, no feasible N gets us to paper-quality unlabeled or facet bars.**

The diagnosis from `docs/PIPELINE.md` (the `n!` ratio spans 17 orders of magnitude across samples at q=10 p=4) is now confirmed empirically across three batch scales.

**What I recommend:**

For p=4 — and likely also for p=3 once we want comfortable ESS — we should switch from importance sampling to a sampler that targets the unlabeled or facet measure directly. The cleanest candidate is a Metropolis-Hastings chain over isomorphism classes:

- **Proposal:** swap two facets between two purity-p complexes, or a local "rewire" move that preserves p.
- **Acceptance:** ratio of |Aut(X)| or q!/|Aut_F(X)| depending on which target measure we want, by detailed balance.
- **Mixing diagnostics:** autocorrelation on numV, |Aut|, β₁ — should beat 12M-IS-equivalent-ESS-of-25 with far fewer chain steps.

Vertex-labeled bars at all p are fully reliable (those are direct samples); p=2 unlabeled/facet are also fine. So the sampler change is specifically about rescuing the p=3 (borderline) and p=4 (broken) reweighted distributions.

**Attached:** `combined_all_figures_merged.pdf` — Figures 3–15 rendered from the merged 12M-per-p dataset. The vertex-labeled (yellow) bars are the trustworthy ones; the facet (blue) and unlabeled (red) bars at p=3 are smoother than before but still noisy, and at p=4 are still dominated by 1–2 outlier bins.

Three things I'd appreciate your guidance on:

1. Do you want me to proceed with the MH-over-isomorphism-classes sampler, or do you have a different proposal in mind?
2. Are you okay publishing the p=2 figures from the IS approach as-is, while we redo p=3 and p=4 with the new sampler?
3. Is there a target submission timeline I should be planning the sampler work against?

Happy to talk through any of this on a call.

Thanks,
Elijah

---

## Notes for Elijah before sending

- Confirm Dr. Betre's preferred email address (the prior thread should have it).
- Attach `figures/combined_all_figures_merged.pdf` (multi-page).
- Optional attach: `logs/concat_post_batch3.log` if he wants the raw script output.
- The `12 → 4 → 24 → 25` non-monotone progression for p=4 is the strongest single piece of evidence for the sampler swap — keep that prominent.
- We have not pre-discussed Markov-chain proposals with him — this is the first time we're naming a concrete alternative. Be open to him preferring something else (e.g. brute-force enumeration for low-numV cases, then IS for the rest).
