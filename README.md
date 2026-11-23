# CombResearch

Wolfram Mathematica research code for probability distributions of pure simplicial complexes with fixed facet count.

## Status

- Figure 2 at `q = 3` is complete.
- Exact truth data exists for 9 cells: `(2,4)`, `(2,5)`, `(2,6)`, `(2,7)`, `(3,4)`, `(3,5)`, `(3,6)`, `(4,4)`, `(4,5)`.
- MH chains validate against truth for all 27 cell-target combinations at L1 `< 0.05`.
- `(4,5)` has 5,532 isomorphism classes by McKay enumeration.
- Current open work is manuscript integration, Betre WXF cross-checks, and deciding whether to attempt `(4,6)`.

## Quick Start

`run.wl` is the single entry point. It launches the `pipeline/` stages and
skips any job whose outputs already exist.

```powershell
wolframscript -file run.wl check                 # update the ECGrav clone, regression, smoke tests
wolframscript -file run.wl all profile quick     # small end-to-end run (about 10-20 min)
wolframscript -file run.wl all dryrun            # every planned job and why it runs or skips
wolframscript -file run.wl status                # store report
```

Stages can also be run directly, for example:

```powershell
wolframscript -file pipeline\10_truth.wl          # exact truth enumeration
wolframscript -file pipeline\30_mh.wl             # MH chains
wolframscript -file pipeline\50_validate.wl samples
wolframscript -file pipeline\60_figures.wl truth_overlay
```

## Layout

```text
src/        Wolfram scripts for compute, rendering, enumeration, MH, probes, checks
data/       Generated CSV/WXF outputs, gitignored
figures/    Generated manuscript panels, previews, and combined PDFs
docs/       Current technical docs and live handoff
logs/       Generated run logs
archive/    Old renders, superseded data, and scratch tests
ECGrav/     Vendored ECGrav snapshots; scripts load one pinned snapshot via src/load_ecgrav.wl
```

## Docs

- `CLAUDE.md` - project instructions for Claude Code.
- `docs/agent-task.md` - live handoff and current project state.
- `docs/enumeration.md` - truth enumeration, BLISS, McKay, validation.
- `docs/sampling.md` - importance sampling, MH sampler, q=10 ESS caveat.
