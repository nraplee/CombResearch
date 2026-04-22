# Pipeline: how the code works

This document explains the compute and render pipeline that produces the new figures (Figure 3 onward) for the pure simplicial complexes paper. Figure 2 has its own separate notebook (`histograms_handoff_v2.nb`, `histograms_paper_figures.nb`) and is not covered here.

---

## What we are computing

For each purity `p ∈ {2, 3, 4}` and fixed facet count `q = 10`, we want empirical distributions of various complex-level statistics under three probability measures:

1. **Vertex-labeled** `𝒴_v(p, q)` — uniform over vertex-labeled pure complexes with `q` facets.
2. **Facet-labeled** `𝒴_f(p, q)` — uniform over facet-labelings, paper Eq. 22.
3. **Unlabeled** `𝒴_u(p, q)` — uniform over isomorphism classes.

The statistics tracked per sample (one CSV row each):

| column | meaning |
|---|---|
| `numV` | number of vertices |
| `aut` | `|Aut(X)|`, vertex-permutation automorphism group order |
| `autF` | `|Aut_F(X)|`, facet-permutation automorphism group order |
| `connected` | 1 if the complex is connected, else 0 |
| `num1VConnComps` | number of (1-vertex) connected components |
| `num2VConnComps` | number of 2-vertex-connected components |
| `largestCompRatio` | vertices in largest component / total vertices |
| `num2PathConnComps` | number of 2-path connected components (`""` for `p=2`) |
| `num3PathConnComps` | number of 3-path connected components (`""` for `p<4`) |
| `Betti1` | `β₁` over `ℤ₂` |
| `Betti2` | `β₂` over `ℤ₂` (`""` for `p=2`) |
| `Betti3` | `β₃` over `ℤ₂` (`""` for `p<4`) |
| `wVertex` | `= 1`, weight for vertex-labeled estimator |
| `wUnlabeled` | `= |Aut(X)| / numV!`, paper Eq. 24 |
| `wFacet` | `= |Aut(X)| · q! / (|Aut_F(X)| · numV!)`, paper Eq. 25 |

---

## The reweighting hack and when it breaks

### The math

The ECGrav package only provides one verified uniform sampler: `RandomVertexLabeledPureSimplicialComplex[{p, q}, n]`. To get empirical estimates under the other two measures, we don't sample them directly — instead we **importance-sample** from the vertex-labeled measure and reweight.

For any statistic `f`,

```
E_𝒴_u[f] ≈ Σᵢ f(Xᵢ) · wU(Xᵢ) / Σᵢ wU(Xᵢ)
E_𝒴_f[f] ≈ Σᵢ f(Xᵢ) · wF(Xᵢ) / Σᵢ wF(Xᵢ)
```

where `Xᵢ` is the i-th vertex-labeled sample and `wU`, `wF` are the per-sample weights given above. Histograms work the same way — the height of each bin is the sum of weights of samples landing in that bin, normalized by total weight.

### The ESS diagnostic

The Effective Sample Size is

```
ESS = (Σᵢ wᵢ)² / Σᵢ wᵢ²
```

Range: `1 ≤ ESS ≤ N`. If all weights are equal, `ESS = N`. If one sample carries all the weight, `ESS = 1`. **ESS measures how many equally-weighted samples from the target distribution would give the same estimator variance.** Low ESS → high variance → noisy histograms.

### Why it works at q=3 and not at q=10

At `q = 3`, the number of vertices `n` is bounded small (≤ `q · p`), so `n!` and `|Aut(X)|` are also bounded — the ratio `|Aut|/n!` varies modestly across samples and weights are reasonably comparable. The 12 isomorphism classes at `(p=3, q=3)` are well-covered by vertex-labeled sampling. ESS is healthy.

At `q = 10`, especially for `p = 4`:
- `n` ranges roughly 18–40, so `n!` varies by **17 orders of magnitude** sample-to-sample.
- The minimum-`n` complexes (highly symmetric, dense) carry weight `|Aut|/18! ≈ 10⁻¹⁵` while typical `n=30` samples carry `≈ 10⁻³³`.
- Drawing even one of these rare small-`n` complexes makes its weight dominate the entire reweighted measure.
- Empirically at `N = 500,000` for `p = 4`: one sample (`numV=18`, `|Aut|=4`) carries 44% of total unlabeled weight; second sample carries 22%. ESS = 4.

This is a structural failure of importance sampling under heavy-tailed weights. Increasing `N` does not fix it — in fact for `p=4` the ESS got *worse* going from `N=10k` (ESS=12) to `N=500k` (ESS=4) because we drew an extreme-weight sample we hadn't seen before.

**Practical implications:**
- Vertex-labeled histograms (using `wVertex = 1`) are direct samples — fully reliable.
- Unlabeled and facet-labeled histograms at `q=10` are reweighting estimates with single-digit ESS for `p ∈ {3, 4}` — qualitative shape may be informative, bar heights are not. Need a different sampler if quantitative facet/unlabeled distributions are required.

---

## File layout

Currently flat at `C:\CombResearch\` (the cleanup plan moves these into `src/`, `data/`, `figures/`, etc., once we re-render).

### Source code

| file | role |
|---|---|
| `pure_simplicial_compute.wl` | The main compute script. Samples vertex-labeled complexes in chunks, computes all stats and weights per sample, writes one CSV per `p`. Handles checkpoint resume. |
| `pure_simplicial_compute_overnight.wl` | Three-line wrapper that sets `sampleSizeOverride = 500000` then `Get`s the main script. |
| `render_all_figures.wl` | Loads the CSVs, renders 13 figures (Fig 3–15) as PDF + PNG previews. Three panel modes: `discrete`, `logdiscrete`, `continuous`. |
| `pure_simplicial_figures.nb` | Notebook mirror of the renderer (work-in-progress alternate path; the `.wl` is the production renderer). |
| `histograms_handoff_v2.nb` | Figure 2 reference — DO NOT EDIT. |
| `histograms_paper_figures.nb` | Figure 2 styling reference — DO NOT EDIT. |
| `diagnose_weights.wl` | Diagnostic: prints top-5 weight samples and ESS per `p`. Useful when ESS looks wrong. |

### Data

| pattern | meaning |
|---|---|
| `p{2,3,4}q10_n500000_samples.csv` | The current "good" data (from the overnight run). 15 columns, 500,001 rows (header + 500k samples). |
| `p{2,3,4}q10_n10000_samples.csv` | Earlier `N=10k` exploratory data. Superseded but kept for cross-check. |
| `p{p}q10_n{N}_chunk_{k}.csv` | Per-chunk intermediate files written during a checkpointed run; deleted after consolidation. Only present if a run was interrupted. |

### Documentation

| file | role |
|---|---|
| `CLAUDE.md` | Project instructions for Claude Code (loaded automatically when invoked at this directory). Must stay at root. |
| `HANDOFF.md` | Pipeline summary and warnings for human reviewers. |
| `Pure Clique Complexes.tex` | The manuscript source. |
| `PIPELINE.md` | This file. |

### Logs and outputs

`overnight.log` (last compute run), `fig{03..15}_*.pdf` and `.png` (current renders from `N=10k` data).

---

## Compute pipeline (`pure_simplicial_compute.wl`)

### Top-level flow

```
For each p in pList:
  If final CSV exists, skip p.
  Else, find first missing chunk k* and resume:
    For k in k*..numChunks:
      SeedRandom[randomSeed + p*1000 + k]
      sample = RandomVertexLabeledPureSimplicialComplex[{p, qVal}, chunkSize]
      statsRows = (statsFor[#, p] for each X in sample)
      compute weights wV, wU, wF
      atomic-write chunk file (tmp, then rename)
  consolidate all chunks into one final CSV
  delete chunk files
  print ESS for unlabeled and facet weights
```

### Checkpointing details

Each chunk's `chunkSize = 25000` samples are written to a separate file via `tmp + RenameFile`. Either the chunk file is fully present or absent — no partial writes. On restart:

- If `final` CSV for a given `p` exists, that `p` is skipped.
- Otherwise the script scans for the first missing `chunk_{k}.csv` and resumes there.
- Worst case: one in-progress chunk (≤ ~17 minutes for `p=4`) is redone.

The atomic-write uses `Export[tmp, rows, "CSV"]` (explicit format — without it, Mathematica fails to infer format from `.tmp` and silently writes nothing) followed by `RenameFile[tmp, final]`. Both are checked for failure with `Abort[]`.

### Per-sample stats (`statsFor`)

For each complex `X` (a list of facets, each facet a list of vertex labels):

1. Build the 1-skeleton graph from the facet edges.
2. Compute `|Aut(X)|`, `|Aut_F(X)|` via ECGrav.
3. Connected components of the 1-skeleton → `num1VConnComps` and `largestCompRatio`.
4. `KVertexConnectedComponents[g, 2]` → `num2VConnComps`.
5. For `p ≥ 3`: build the 2-graph (1-simplices as vertices, edge if both faces share a facet) → `num2PathConnComps`. Same for 3-graph if `p ≥ 4`.
6. Betti numbers over `ℤ₂` via boundary matrix ranks: `β_k = dim C_k - rank ∂_k - rank ∂_{k+1}`. Sparse matrices, modular rank.

Stats unavailable at a given `p` (e.g. `Betti3` for `p=2`) emit `""` — preserved as `Missing[]` when the renderer reads them back.

### Weights

```wolfram
wV = ConstantArray[1, n]
wU = MapThread[#1 / #2! &, {auts, numVs}]                       (* |Aut|/n! *)
wF = MapThread[#1 * qVal! / (#2 * #3!) &, {auts, autFs, numVs}] (* |Aut|·q!/(|Aut_F|·n!) *)
```

These are written as the last three columns of every CSV row. The renderer just reads them; no recomputation.

### CSV format

15 columns, comma-delimited, with a header row. Empty cells (`""`) for stats unavailable at the given `p`. All numeric values are written as Mathematica's default CSV serialization (integers as integers, floats as decimals, large integers as plain digits — no exponential notation).

### Parameter overrides

The script reads several optional override variables at startup. Set them before `Get`-ing the script:

| variable | default | effect |
|---|---|---|
| `sampleSizeOverride` | `10000` | Total samples per `p`. |
| `chunkSizeOverride` | `25000` | Samples per chunk. |
| `pListOverride` | (planned) `{2, 3, 4}` | Restrict which `p` values to compute. |
| `useParallelOverride` | (planned) `False` | If `True`, parallelize `statsFor` via `ParallelMap` after launching subkernels. |

The two `(planned)` rows are not yet implemented but are part of the approved Phase B work in the `lexical-leaping-book.md` plan file.

---

## Render pipeline (`render_all_figures.wl`)

### Top-level flow

```
For each p, load p{p}q10_n{N}_samples.csv into an Association {colName -> column}.
For each (statistic, panelType, pSubset, filterSpec) in figs:
  For each p in pSubset (default {2,3,4}):
    panel = panelDispatch[panelType, p, col, label, filterSpec]
  figure = stack panels into a 1-column GraphicsGrid
  Export figure as PDF + PNG
```

### Panel types

| mode | when to use | implementation |
|---|---|---|
| `discrete` | small-integer x values (numV, num1V, num2V, Betti, path-comp counts) | aggregate `(value, weight)` pairs per series, render via grouped `BarChart` |
| `logdiscrete` | `aut`, `autF` — values span many orders of magnitude | bin samples per power of 10, label each bin `10^k`, grouped `BarChart` |
| `continuous` | `largestCompRatio` (in `[0, 1]`) | `Histogram[{WeightedData}*3, Automatic, "PDF"]` |

The plan in `lexical-leaping-book.md` calls for replacing all three modes with **translucent overlaid histograms** instead of grouped bars — to match the paper's existing style for Figures 3+. That work is queued, not yet implemented.

### Filters

`filterSpec` is `None` (use all samples) or `"connected"` (only `connected == 1`). Used to render the connected-only variants of the `aut` and `autF` figures.

### Output naming

Currently outputs are stacked-panel PDFs named `fig{NN}_{statName}.pdf`. The approved plan changes this to:

- `combined_all_figures_n500k.pdf` — one multi-page PDF with all stacked figures (preview / review).
- `p{p}q10SX{Stat}_n500k.pdf` (and `..connSX..` variants) — ~30 individual per-panel PDFs with names mirroring the manuscript's `\includegraphics` paths, ready to drop into the LaTeX.

---

## How to run

### Compute (one-shot at default `N = 10000`)

```
wolframscript -file C:\CombResearch\pure_simplicial_compute.wl
```

Writes three CSVs into the same directory. ~13 minutes wall-clock total.

### Compute (overnight at `N = 500000`)

```
wolframscript -file C:\CombResearch\pure_simplicial_compute_overnight.wl > C:\CombResearch\overnight.log 2>&1
```

~11 hours single-threaded. If interrupted, just re-run the same command — the script resumes at the first missing chunk for each `p`.

### Render

```
wolframscript -file C:\CombResearch\render_all_figures.wl
```

Reads CSVs, writes 13 PDFs and 13 PNGs. ~30 seconds.

### Diagnose ESS

```
wolframscript -file C:\CombResearch\diagnose_weights.wl
```

Prints top-5 weight samples and ESS for each `p`. Use when ESS looks suspicious or before trusting facet/unlabeled bar heights.

---

## Critical rules (do not violate)

- **Never use `RandomFacetLabeledPureSimplicialComplex`.** It is not a verified uniform sampler. Always derive facet-labeled empirics by reweighting vertex-labeled samples per Eq. 25.
- **Do not edit `histograms_handoff_v2.nb` or `histograms_paper_figures.nb`.** These are the Figure 2 reference; their behavior is locked in.
- **Don't trust facet/unlabeled histograms at `q=10`, `p ∈ {3, 4}`** until either ESS improves or a different sampler is implemented. Vertex-labeled histograms at `q=10` are fine.
