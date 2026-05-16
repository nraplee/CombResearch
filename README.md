# CombResearch

Wolfram Mathematica research code for probability distributions of pure simplicial complexes with fixed facet count.

## Status

- Figure 2 at `q = 3` is complete.
- Exact truth data exists for 9 cells: `(2,4)`, `(2,5)`, `(2,6)`, `(2,7)`, `(3,4)`, `(3,5)`, `(3,6)`, `(4,4)`, `(4,5)`.
- MH chains validate against truth for all 27 cell-target combinations at L1 `< 0.05`.
- `(4,5)` has 5,532 isomorphism classes by McKay enumeration.
- Current open work is manuscript integration, Betre WXF cross-checks, and deciding whether to attempt `(4,6)`.

## Quick Start

```powershell
# Exact truth enumeration.
wolframscript -file src\enumerate_truth.wl

# MH chains.
wolframscript -file src\run_mh_chains.wl

# Validate MH against truth.
wolframscript -file src\validate_mh_vs_truth.wl

# Render truth/MH overlay panels.
wolframscript -file src\render_truth_overlay.wl
```

Older q=10 importance-sampling commands are still available:

```powershell
wolframscript -file src\pure_simplicial_compute.wl
wolframscript -file src\render_all_figures.wl
powershell -ExecutionPolicy Bypass -File src\run_parallel.ps1
```

## Layout

```text
src/        Wolfram scripts for compute, rendering, enumeration, MH, probes, checks
data/       Generated CSV/WXF outputs, gitignored
figures/    Generated manuscript panels, previews, and combined PDFs
docs/       Current technical docs and live handoff
logs/       Generated run logs
archive/    Old renders, superseded data, and scratch tests
ECGrav/     Vendored ECGrav paclet sources/snapshots
```

## Docs

- `AGENTS.md` - canonical working instructions for coding agents.
- `docs/agent-task.md` - live handoff and current project state.
- `docs/enumeration.md` - truth enumeration, BLISS, McKay, validation.
- `docs/sampling.md` - importance sampling, MH sampler, q=10 ESS caveat.
