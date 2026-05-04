# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Wolfram Mathematica research project studying the probability distributions of **pure simplicial complexes**. The work validates theoretical formulas against empirical sampling, with results destined for an academic paper. Figure 2 (q=3) is complete; Figures 3-15 (q=10, p ∈ {2,3,4}) are the current focus.

## Environment

- **OS**: Windows
- **Runtime**: `wolframscript` (on PATH) — run scripts as `wolframscript -file script.wl` from PowerShell/cmd
- **Package**: ECGrav paclet is installed; load with `Needs["ECGrav`"]`

## Directory layout

```
C:\CombResearch\
├── CLAUDE.md                      (this file — must stay at root)
├── src\                           (working scripts)
│   ├── pure_simplicial_compute.wl    (sampling + per-sample stats; checkpointing)
│   ├── pure_simplicial_compute_overnight.wl   (N=500000 wrapper)
│   ├── render_all_figures.wl         (Figs 3-15 renderer)
│   ├── run_p{2,3,4}.wl               (per-p wrappers, parallel-aware)
│   ├── run_parallel.ps1              (3-way parallel driver)
│   ├── sampler_mh.wl                 (MH iso-class sampler — verified at (2,4), (3,4))
│   ├── streaming_enumerator.wl       (truth-enum: streaming gen + bucketed dedupe)
│   ├── scaling_probe.wl              (truth-enum: eager-pipeline timing probe)
│   ├── scaling_probe_streaming.wl    (truth-enum: streaming-pipeline timing probe)
│   ├── test_streaming.wl             (truth-enum: correctness check vs ECGrav)
│   └── reference\                    (Figure 2 source notebooks; do not edit)
├── ECGrav\                        (vendored paclet sources — 1.0.0 prod, main snapshot)
├── data\                          (CSVs/WXFs from compute runs)
├── figures\
│   ├── stacked_previews\            (3-panel column previews per figure)
│   ├── manuscript_panels\           (~30 individual per-panel PDFs for \includegraphics)
│   └── combined_all_figures_n500k.pdf (multi-page review PDF)
├── docs\                          (PLAN_TRUTH_ENUMERATION.md, enumeration_scaling.md,
│                                   HANDOFF.md, PIPELINE.md, NEXT.md, manuscript .tex)
├── logs\                          (overnight.log, compute_p{2,3,4}.log,
│                                   scaling_probe.log, scaling_probe_streaming.log)
└── archive\                       (superseded data, tests, old renders)
```

See `docs/PIPELINE.md` for full technical documentation of the compute and render pipelines (incl. the importance-sampling reweighting math and ESS diagnostics).

## Execution

Production pipeline (Figures 3-15):

1. **Compute** — `wolframscript -file src/pure_simplicial_compute.wl` (default N=10000) or `src/pure_simplicial_compute_overnight.wl` (N=500000). Writes `data/p{2,3,4}q10_n{N}_samples.csv`. Resumable via per-chunk atomic checkpointing — restarting after a crash skips finished chunks.
2. **Render** — `wolframscript -file src/render_all_figures.wl`. Reads the N=500k CSVs from `data/`, writes per-panel PDFs to `figures/manuscript_panels/`, stacked previews to `figures/stacked_previews/`, and a combined PDF to `figures/`.
3. **Parallel compute** — `powershell -ExecutionPolicy Bypass -File src/run_parallel.ps1` launches three `wolframscript` processes (one per p) with each using ParallelMap on the stats step. Override N via `$env:N` before invocation (e.g. `$env:N = 100000; powershell ...`); the PS script forwards it to the wrappers through the `COMB_N` environment variable. Smoke-tested at N=2000 (3 processes × 8 subkernels, wall-clock ≈ max(p=4) ≈ 120s including kernel-launch overhead).

Reference notebooks (Figure 2 baseline, do not edit):

1. `src/reference/histograms_handoff_v2.nb` — original computation pipeline at q=3
2. `src/reference/histograms_paper_figures.nb` — figure styling reference

## Key Parameters (src/pure_simplicial_compute.wl)

| Variable | Default | Override | Purpose |
|---|---|---|---|
| `qVal` | `10` | (hardcoded) | Number of facets |
| `pList` | `{2, 3, 4}` | `pListOverride` | Purity values to sweep |
| `sampleSize` | `10000` | `sampleSizeOverride` | Vertex-labeled samples per p |
| `chunkSize` | `25000` | `chunkSizeOverride` | Per-chunk size (atomic checkpoint unit) |
| `randomSeed` | `123456` | (hardcoded) | Reproducibility seed (per chunk: seed + p*1000 + k) |
| `useParallel` | `False` | `useParallelOverride` | Use ParallelMap on stats step |

Outputs: `data/p{p}q10_n{N}_samples.csv`, 15 columns: stats + reweighting weights (wVertex, wUnlabeled, wFacet).

## Architecture & Data Flow (Figures 3-15)

The computation pipeline in `src/pure_simplicial_compute.wl`:

1. **Sampling** — `RandomVertexLabeledPureSimplicialComplex[{p, qVal}, chunkSize]` per chunk.

2. **Per-sample statistics** — For each sample compute: numV, |Aut|, |Aut_F|, connected, num1V/num2V components, largest-component ratio, num2P/num3P path components, Betti₁/₂/₃ (over ℤ₂). See `src/pure_simplicial_compute.wl::statsFor`.

3. **Reweighting weights** stored alongside stats in the CSV:
   - `wVertex = 1` (samples already vertex-labeled-uniform)
   - `wUnlabeled = |Aut| / numV!` (Eq. 24)
   - `wFacet = |Aut| · q! / (|Aut_F| · numV!)` (Eq. 25)

4. **Atomic checkpointing** — each chunk written as `..._chunk_k.csv.tmp` then renamed; on crash, restart skips finished chunks. After all chunks land, consolidated into a single `..._samples.csv`.

5. **ESS diagnostic** — `Total[w]² / Total[w²]` printed per p per weighting at end. **At q=10 the reweighting is heavy-tailed and ESS collapses** (e.g. ESS=4 / 500000 for p=4 unlabeled). See `docs/PIPELINE.md` for diagnosis and the practical implication for figure quality.

The render pipeline in `src/render_all_figures.wl`:

1. Loads each `data/p{p}q10_n{N}_samples.csv`.
2. For each (statistic, p) builds a translucent-overlaid histogram of the three weightings (vertex / facet / unlabeled).
3. Three panel modes: `discrete` (integer bins width 1), `logdiscrete` (per-decade Log10 bins, 10^k tick labels), `continuous` (Automatic bins).
4. Exports to `figures/manuscript_panels/` (per-panel for the manuscript), `figures/stacked_previews/` (3-panel column for review), and `figures/combined_all_figures_n500k.pdf` (multi-page combined).

Styling matches paper Figure 2: Times 11pt, ImageSize {360, 270}, translucent fill (Opacity 0.55), three colors (vertex=yellow `RGBColor[0.984, 0.757, 0.369]`, facet=blue `[0.122, 0.471, 0.706]`, unlabeled=red `[0.890, 0.290, 0.200]`).

## ECGrav Package API

Key functions provided by the package:

- `GenerateAllFacetLabeledPureSimplicialComplexes[pq]`
- `ChooseNonIsomorphicSimplicialComplexes[complexes]`
- `PureComplexAutomorphismGroupOrder[complex]`
- `PureComplexFacetAutomorphismGroupOrder[complex]`
- `RandomVertexLabeledPureSimplicialComplex[pq, n]`
- `IsomorphicSimplicialComplexQ[c1, c2]`

## Paper Equation References

- **Eq. 22**: Facet-labeled theoretical probability formula
- **Eq. 24**: Reweighting formula — unlabeled from vertex-labeled sample (weight = |Aut|/n!)
- **Eq. 25**: Reweighting formula — facet-labeled from vertex-labeled sample (w_f ∝ |Aut| · q! / (|Aut_F| · n!))
- **Figure 2**: Four-panel histogram produced by `histograms_paper_figures.nb`

> **`RandomFacetLabeledPureSimplicialComplex` must never be used** for the facet-labeled distribution — it is not a verified uniform sampler. Always derive the facet-labeled empirical distribution by sampling vertex-labeled complexes and reweighting each sample by:
> ```
> w(X) = |Aut(X)| * q! / (|Aut_F(X)| * |V(X)|!)
> ```
> This reweighting has been validated against exact enumeration.

## Current Task: Figures 3-15 at q=10

Producing 13 figures, each a 3×1 column (one panel per p ∈ {2,3,4}) — pure simplicial complexes only, **not** clique complexes. Statistics: numV, |Γ(X)|, |Γ_F(X)|, those two filtered to connected complexes, num1V/num2V components, largest-component ratio, 2- and 3-path components, Betti₁/₂/₃.

**Status (2026-05-02):** the IS pipeline is shelved at q=10 p=4 (ESS=25, biased mean — see `docs/sampler_writeup.md`). The MH sampler is verified at (2,4), (3,4), (3,5). The active workstream is **truth enumeration** — computing exact distributions for the small (p, q) cells where they're feasible, so manuscript figures can replace IS bars with exact bars wherever possible.

### Truth-enumeration plan

See **`docs/PLAN_TRUTH_ENUMERATION.md`** for the active plan. Highlights:
- ✅ Phase 1 (scaling probe) complete. Reachable grid: `{(2,4), (2,5), (2,6), (3,4), (3,5)}`. Results in `docs/enumeration_scaling.md`.
- ✅ Streaming enumerator prototype (`src/streaming_enumerator.wl`) — DFS gen + bucketed dedupe, parallel, validated against ECGrav. Drop-in `chooseNonIsoBucketed` available too.
- ⏳ Phase 2 next: `src/enumerate_truth.wl` writes `data/p{p}q{q}_truth.wxf` for the five reachable cells.
- ⏳ Phase 3: `src/render_truth_overlay.wl` produces the manuscript panels.

`docs/NEXT.md` is the older (pre-truth-enumeration) handoff note; the plan supersedes it for this workstream.
