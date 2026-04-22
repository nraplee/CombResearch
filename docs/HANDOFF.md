# HANDOFF

> **Historical context — superseded by `CLAUDE.md` (project root) and `PIPELINE.md` (this directory).** Kept for the prior-sessions narrative below; the methodological warnings still apply but the "current task" / "suggested pipeline" sections describe planning, not the current production code.

Context carryover from prior Claude.ai sessions. Read this before starting work.

## Project

Research paper on **random pure simplicial complexes**, coauthored with Dr. Betre (faculty advisor). The paper studies probability distributions over unlabeled isomorphism classes of pure simplicial complexes under three sampling regimes.

## Three sampling regimes

1. **Vertex-labeled** — uniform over vertex-labeled complexes.
2. **Facet-labeled** — uniform over facet-labeled complexes.
3. **Unlabeled** — uniform over isomorphism classes.

Each regime has a corresponding theoretical distribution derived in the manuscript. The three regimes induce different distributions over the same underlying set of isomorphism classes, and the paper's figures compare them side by side.

## ⚠️ Critical methodological point

**Do NOT use `RandomFacetLabeledPureSimplicialComplex` from the ECGrav paclet to produce the facet-labeled distribution.** It is not a verified uniform sampler — we were unable to confirm its output is uniform over facet-labeled complexes, and preliminary checks suggested it is not.

The correct approach (per the manuscript's own methodology) is:

1. Generate samples uniformly from the **vertex-labeled** distribution.
2. Reweight each sample X by:

   **w(X) = |Aut(X)| · q! / (|Aut_F(X)| · |V(X)|!)**

   where:
   - q = number of facets
   - |V(X)| = number of vertices
   - |Aut(X)| = order of the full automorphism group of X
   - |Aut_F(X)| = order of the facet-stabilizing automorphism subgroup

This reweighting has been **validated against exact enumeration** for small cases. Agreement between the reweighted empirical distribution and exact enumeration is the reliability benchmark. Theory and exact enumeration serve as mutual validation checks throughout the project.

## Prior figure work (completed)

**Figure 2** — 2×2 histogram comparing unweighted, vertex-labeled, facet-labeled, and unlabeled distributions. Already produced and exported. Validates the pipeline on a single case.

## Current task — Figures 3-15 at q=10, p ∈ {2,3,4}  *(updated)*

13 figures, each a 3×1 column (one panel per p). 10 different x-axis statistics: numV, |Γ(X)|, |Γ_F(X)|, |Γ(X)| connected, |Γ_F(X)| connected, num1V/num2V components, largest-component ratio, 2- and 3-path components, Betti₁/₂/₃. Three distributions per panel as translucent overlaid histograms.

**Important distinction:** the new figures are for **pure simplicial complexes**, NOT clique complexes.

**Method:** facet-labeled and unlabeled columns produced via reweighting per the formula above — not via the paclet's facet-labeled sampler.

**Production scripts** (now under `src/`, not next to this file):

- `src/pure_simplicial_compute.wl` — sampling + per-sample stats + atomic checkpointing. Outputs `data/p{p}q10_n{N}_samples.csv`.
- `src/render_all_figures.wl` — translucent overlaid histograms, per-panel PDFs (`figures/manuscript_panels/`), stacked previews (`figures/stacked_previews/`), combined multi-page PDF.
- `src/run_p{2,3,4}.wl` + `src/run_parallel.ps1` — three-way parallel compute driver.

See `PIPELINE.md` (sibling of this file) for the full technical writeup, including the q=10 ESS collapse.

## Reference files

- `src/reference/histograms_handoff_v2.nb` — corrected computational pipeline (Figure 2 baseline at q=3). Source of truth for the reweighting code.
- `src/reference/histograms_paper_figures.nb` — paper-ready figure panels with export (Figure 2). Source of truth for styling.
- `Pure Clique Complexes.tex` (this directory) — manuscript LaTeX draft.

## Environment

- **OS:** Windows.
- **Wolfram:** `wolframscript` is on PATH. Confirmed working with `wolframscript -file script.wl`.
- **ECGrav paclet:** installed, loads via `Needs["ECGrav`"]`. 112 symbols exposed.
- **Shell quoting gotcha:** backticks in `-code '...'` break in cmd/PowerShell. Use `-file` for anything non-trivial.

## Pipeline structure  *(implemented)*

Split adopted:

- **`src/pure_simplicial_compute.wl`** — sampling + per-sample stats + reweighting weights. Parameterized over p (`pListOverride`), N (`sampleSizeOverride`), parallelism (`useParallelOverride`). Writes one consolidated CSV per p to `data/`. Atomic per-chunk checkpointing for crash resumption.
- **`src/render_all_figures.wl`** — loads CSVs, assembles per-figure 3×1 columns and ~30 individual panel PDFs, exports.

## Open questions / decisions  *(updated)*

- **Sample size N per panel** — RESOLVED at N=500000 for the overnight pass. ESS still single-digit at p=4; see `PIPELINE.md` for variance-vs-N analysis. Pending professor input on whether to scale N up further or change samplers.
- **Bin widths** — discrete stats use width 1 (one bar per integer); log-discrete uses one bin per decade with 10^k tick labels; continuous uses Mathematica `Automatic`.
- **Grid structure** — 3×1 column per figure (one panel per p), not 3×2 (no clique-complex column).

## Working style notes

- Prefer direct technical diagnosis over speculative workarounds. When something fails, trace it to the specific cause rather than trying alternative approaches blindly.
- Manuscript writing is behind schedule relative to the submission timeline. Incomplete LaTeX sections are flagged ahead of internal review with Dr. Betre. Expect figure work and manuscript writing to proceed in parallel.