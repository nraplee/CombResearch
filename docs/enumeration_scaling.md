# Enumeration scaling — Phase 1 results

**Sources:**
- Eager probe — `src/scaling_probe.wl`, log `logs/scaling_probe.log`.
- Streaming + bucketed probe — `src/scaling_probe_streaming.wl`, log `logs/scaling_probe_streaming.log`.
- Streaming enumerator — `src/streaming_enumerator.wl` (validated against ECGrav on (2,4), (2,5), (3,4) via `src/test_streaming.wl`).

Per-phase timeout 1800 s. Host: 16 GB RAM, 14 subkernels.

## Two pipelines under test

1. **Eager + naive** (vendored ECGrav 1.0.0): `GenerateAllFacetLabeledPureSimplicialComplexes` produces the full facet-labeled list eagerly with internal `ParallelMap`; `ChooseNonIsomorphicSimplicialComplexes` dedupes via O(n²) pairwise iso testing.
2. **Streaming + bucketed** (`src/streaming_enumerator.wl`): DFS reimplementation that emits one finished facet-labeled complex at a time and immediately routes it into a bucket map keyed by a relabeling-invariant tuple `(numV, sortedVertexDegrees, sortedFacetPairOverlaps)`. Within-bucket dedupe uses the same `IsomorphicSimplicialComplexQ`. Parallelized over starting states (each subkernel runs an independent DFS+local bucket map; merged at end).

The streaming pipeline never holds the full facet-labeled list in memory; memory is bounded by the number of iso classes seen.

## Results

Both pipelines on the same grid, 1800 s/cell timeout:

| (p, q) | \|allLab\| | \|iso\| | eager gen+iso (s) | streaming total (s) | speedup | streaming peak (MB) |
|:------:|----------:|--------:|------------------:|--------------------:|--------:|--------------------:|
| (2, 4) | 70        | 11      | (smoke ~4)        | 4.5                 | —       | ~1                  |
| (2, 5) | 794       | 26      | 10.3              | 4.9                 | 2.0×    | 0.6                 |
| (2, 6) | 12 055    | 68      | 233.9             | 209.7               | 1.1×    | 3.7                 |
| (2, 7) | —         | —       | timeout (gen)     | timeout (>1800)     | —       | —                   |
| (3, 4) | 666       | 66      | 13.5              | 4.9                 | 2.9×    | 2.1                 |
| (3, 5) | 28 344    | 445     | 1549.6            | 455.0               | 3.4×    | 49                  |
| (3, 6) | —         | —       | timeout (gen)     | timeout (>1800)     | —       | —                   |
| (4, 5) | —         | —       | timeout (gen)     | timeout (>1800)     | —       | —                   |

`chooseNonIsoBucketed` (the dedupe component alone) was also benchmarked against `ChooseNonIsomorphicSimplicialComplexes` on the eager output — see `src/test_streaming.wl` output: 1.8× speedup at (2,4), 2.0× at (2,5), 3.6× at (3,4). The streaming pipeline includes this speedup as part of its total.

Iso-class counts validated against canonical answers on every cell that completes:
- (2,4) → 11 (matches `render_uniformity_check.wl`)
- (3,4) → 66 (matches `render_sampler_progress.wl`)
- (2,5), (2,6), (3,5) — both pipelines agree, and the bucketed dedupe also agrees with naive iso on the eager output.

## Cap declaration

The reachable grid is the **same under both pipelines**:

| p | reachable q | first unreachable q |
|--:|:-----------:|:-------------------:|
| 2 | up to 6     | 7                   |
| 3 | up to 5     | 6                   |
| 4 | none        | 5                   |

Phase 2's reachable grid is therefore `{(2,4), (2,5), (2,6), (3,4), (3,5)}` — five cells.

(The plan's tentative target was up to q=5 in worst purity; the empirical cap comes in slightly tighter — p=4 is *not* reachable at q=5 within a 30 min budget on this host.)

## What changed between the two pipelines, and what didn't

**Changed:**
- Total wall-clock for completable cells: streaming is 1.1×–3.4× faster.
- Memory ceiling for completable cells: streaming peaks at 0.6–49 MB vs eager's 38–173 MB on the gen step alone.
- Bucketed dedupe replaces O(n²) pairwise iso with O(n) hash + within-bucket O(b²) — for (3,5) this is the bulk of the speedup (eager iso phase was 1074 s, streaming's online dedupe over the same emissions is sub-minute).

**Didn't change:**
- The reachable grid. (2,7), (3,6), (4,5) time out under both pipelines.

The plan predicted that ChooseNonIsomorphic was the wall and bucketing would unlock cells. The actual wall is the *generator* — every timeout died inside `GenerateAll...` (eager) or inside the DFS traversal (streaming) without producing a single emission past the 1800 s mark. That's combinatorial size, not algorithm choice. (3,5) emitted 28k complexes in 7.6 min parallel; (3,6) and (4,5) plausibly emit 10⁵–10⁶+ complexes and the per-emission cost (canonical-key + iso-check) grows with q.

## What it would take to push the cap further

Listed in increasing scope:

1. **Longer budgets.** A 6 hr budget per cell would probably reach (2,7) and possibly (3,6). Wouldn't reach (4,5). Cheap to try; just rerun with `COMB_PROBE_TIMEOUT=21600`.
2. **Stronger canonical hash (BLISS canonical form).** Replace the cheap-invariant `canonicalKey` with `CanonicalGraph` of the bipartite face-incidence graph (with side-distinguishing tags so V-side and F-side don't get permuted). Shrinks every bucket to ≤1 rep so the within-bucket iso check disappears. Likely saves ~30–50 % on (3,5) and similar fractions on harder cells; doesn't change asymptotics.
3. **Direct iso-class enumeration.** Instead of generating facet-labeled then deduping, generate one complex per iso class directly. Known approaches exist in the graph-canonicalization literature (orbit pruning, McKay-style backtracking). Big rewrite.
4. **Accept the cap.** Truth at the reachable five cells is enough for most of the manuscript's validation; (4,10) is the smoking-gun panel and was always going to be sampler-only. Phase 2 builds the truth grid on `{(2,4), (2,5), (2,6), (3,4), (3,5)}` and hands the rest to MH.

Recommendation: Phase 2 starts with option 4 — build `enumerate_truth.wl` on top of `src/streaming_enumerator.wl::streamingEnumeratePure`, target the five reachable cells, ship the truth WXFs. If a stretch goal is desired, try option 1 on (2,7) and (3,6) only (each ~6 hr of background compute). Option 2 is a defensible Phase-2.5 if iso class counts suggest the bucketed hash is collision-heavy.

## Reproducibility

- **Eager probe.** `wolframscript -file src/scaling_probe.wl`. Override grid with `COMB_PROBE_GRID="p1,q1;p2,q2;..."`. Per-phase timeout via `COMB_PROBE_TIMEOUT`.
- **Streaming probe.** `wolframscript -file src/scaling_probe_streaming.wl`. Same env-var conventions; per-cell timeout (single phase, not split gen/iso).
- **Validation.** `wolframscript -file src/test_streaming.wl` runs the small (p,q) correctness check; set `COMB_TEST_SLOW=1` to also include (2,6) and (3,5).
- **Single-cell streaming run** (e.g. to compute and persist iso reps for (3,5)):
  ```
  wolframscript -e 'Get["src/streaming_enumerator.wl"]; sr = streamingEnumeratePure[3, 5]; Length[sr["isoReps"]]'
  ```
- Logs:
  - Eager: `logs/scaling_probe.log` (multiple session-boundary headers).
  - Streaming: `logs/scaling_probe_streaming.log`.
