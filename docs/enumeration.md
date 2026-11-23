# Enumeration And Truth Data

This document is the durable reference for exact truth enumeration of pure simplicial complexes in this project. For current task state, use `docs/agent-task.md`.

## Current Truth Grid

Exact truth data exists for 9 cells:

```text
(2,4), (2,5), (2,6), (2,7),
(3,4), (3,5), (3,6),
(4,4), (4,5)
```

The `(4,5)` truth count is **5,532** isomorphism classes. It was produced by `streamingEnumeratePureMcKay` in sequential mode in about 17.1 hours, with about 7.9 GB peak memory. The cheap streaming pipeline OOMs at `(4,5)` even sequentially, so McKay is the production path for `p = 4, q >= 5`.

## What Truth Enumeration Produces

For each `(p, q)`, `pipeline/10_truth.wl` writes:

```text
data/p{p}q{q}_truth.wxf
```

The WXF payload contains:

```wolfram
<|
  "p" -> p,
  "q" -> q,
  "numIsoClasses" -> n,
  "totalFacetLabeled" -> emitted,
  "numBuckets" -> bucketCount,
  "complexes" -> {<|"facets" -> ..., "aut" -> ..., "autF" -> ...,
                    "nV" -> ..., "stats" -> <|...|>|>, ...},
  "piVertex" -> {...},
  "piFacet" -> {...},
  "piUnlabeled" -> {...},
  "pipeline" -> "cheap" | "bliss" | "mckay",
  "wallClockSec" -> ...,
  "peakMemMB" -> ...,
  "createdAt" -> ...
|>
```

The three exact distributions are over isomorphism classes:

- Vertex-labeled: `piVertex(X) ∝ numV(X)! / |Aut(X)|`
- Facet-labeled: `piFacet(X) ∝ q! / |Aut_F(X)|`
- Unlabeled: `piUnlabeled(X) ∝ 1`

## Commands

```powershell
# Default truth run.
wolframscript -file pipeline\10_truth.wl

# Restrict cells.
$env:COMB_TRUTH_CELLS = "4,5"
wolframscript -file pipeline\10_truth.wl

# Select enumerator.
$env:COMB_TRUTH_PIPELINE = "mckay"   # auto (McKay for p>=4) | cheap | bliss | mckay
$env:COMB_TRUTH_PARALLEL = "false"   # use false for memory-heavy p=4 cells
wolframscript -file pipeline\10_truth.wl

# Force overwrite.
$env:COMB_FORCE = "1"
wolframscript -file pipeline\10_truth.wl
```

Every pipeline writes `data/p{p}q{q}_truth.wxf`. To cross-validate one pipeline against another, run it in a scratch `COMB_ROOT` (the tagged `_truth_<pipeline>.wxf` files of the old `src/enumerate_truth.wl` went with that script in Phase 5).

## Enumerators

### Cheap Streaming

`EnumerateUnlabeledPureComplexes[p, q, Method -> "Cheap"]` (`CombResearch/Kernel/Subpackages/Enumeration.wl`; was `src/streaming_enumerator.wl`) reimplements ECGrav's facet-labeled generator as a DFS that emits one finished complex at a time. Each emitted complex is bucketed by a cheap relabeling-invariant key:

- number of active vertices,
- sorted vertex-degree multiset,
- sorted facet-pair-overlap multiset.

Within each bucket, `IsomorphicSimplicialComplexQ` confirms uniqueness. This is reliable for small cells and avoids holding the full facet-labeled list in memory, but it does not scale to `(4,5)`.

### BLISS Canonical Keys

`Method -> "BLISS"` (was `src/streaming_enumerator_bliss.wl`) replaces the cheap key with a true canonical form using Mathematica `CanonicalGraph` on a bipartite face-incidence graph with a facet-side distinguishing gadget. It is correct, but not a standalone speedup because DFS traversal dominates runtime.

BLISS remains important because McKay uses its canonical key and canonical-removal primitive.

### McKay Canonical Augmentation

`Method -> "McKay"` (was `src/streaming_enumerator_mckay.wl`) prunes DFS branches with a McKay-style canonical-augmentation predicate. It defines a canonical removal vertex from the BLISS-canonicalized bipartite incidence graph, accepts only canonical augmentations within each DFS subtree, and deduplicates cross-start duplicates at leaves using BLISS keys.

This is the only viable path currently known for `p = 4, q >= 5`.

## Validation

Small correctness checks (iso counts of all three enumerators, keys, parallel path; the old test_streaming*.wl checks live here now):

```powershell
wolframscript -file CombResearch/Tests/run_tests.wl
```

MH-vs-truth validation:

```powershell
wolframscript -file pipeline\50_validate.wl samples

$env:COMB_VAL_CELLS = "3,5"
$env:COMB_VAL_TARGETS = "vertex"
wolframscript -file pipeline\50_validate.wl samples
```

As of the Phase 4b closeout, all 27 combinations in the 9-cell truth grid crossed against `{unlabeled, facet, vertex}` pass the numV-marginal L1 threshold `< 0.05`.

## Historical Scaling Notes

The original 30-minute scaling probe found this five-cell grid feasible with the cheap streaming pipeline:

```text
(2,4), (2,5), (2,6), (3,4), (3,5)
```

Later extended runs and McKay work added `(2,7)`, `(3,6)`, `(4,4)`, and `(4,5)`. The important lesson from the scaling probes is still current: the wall is generation, not final isomorphism deduplication. Faster canonical keys help, but canonical augmentation is the real structural improvement.

## Open Enumeration Work

- Cross-check `(4,5)` iso count `5,532` against Dr. Betre's independent WXF exports when they land.
- Decide whether attempting `(4,6)` via McKay is worth the compute and memory risk.
