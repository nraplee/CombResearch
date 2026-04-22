# CombResearch

Wolfram Mathematica pipeline for *Random Pure Simplicial Complexes with Fixed Number of Facets* (Raplee & Betre, in preparation). Manuscript draft in `docs/`.

## Quick start

```powershell
# Compute (default N=10000 per p; produces data/p{2,3,4}q10_n10000_samples.csv)
wolframscript -file src\pure_simplicial_compute.wl

# Render Figures 3-15 from existing CSV
wolframscript -file src\render_all_figures.wl

# Larger run — overnight, N=500000
wolframscript -file src\pure_simplicial_compute_overnight.wl

# Three-process parallel run (one per p)
powershell -ExecutionPolicy Bypass -File src\run_parallel.ps1
```

Sample CSVs are not checked in (~120 MB total) — regenerate via the compute commands above.

## Layout

```
src/        — working scripts (compute + render + parallel wrappers)
data/       — generated CSVs (gitignored)
figures/    — rendered PDFs/PNGs (manuscript_panels/, stacked_previews/, combined PDF)
docs/       — PIPELINE.md (technical writeup), HANDOFF.md, manuscript .tex
logs/       — overnight.log etc.
archive/    — superseded data, scratch tests, old renders
```

See [`CLAUDE.md`](CLAUDE.md) for the full project guide and [`docs/PIPELINE.md`](docs/PIPELINE.md) for the technical pipeline writeup.

## Status

- **Figure 2 (q=3):** done, in manuscript.
- **Figures 3-15 (q=10, p ∈ {2,3,4}):** N=500k samples generated; figures rendered. Importance-sampling reweighting collapses at q=10 for p=3,4 (ESS in single digits) — see `docs/PIPELINE.md` § "Why the hack breaks at q=10."
