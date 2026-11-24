# CombResearch

Wolfram Mathematica research code for probability distributions of pure simplicial complexes with fixed facet count.

## Status

- Figure 2 at `q = 3` is complete.
- Exact truth data exists for 9 cells: `(2,4)`, `(2,5)`, `(2,6)`, `(2,7)`, `(3,4)`, `(3,5)`, `(3,6)`, `(4,4)`, `(4,5)`.
- MH chains validate against truth for all 27 cell-target combinations at L1 `< 0.05`.
- `(4,5)` has 5,532 isomorphism classes by McKay enumeration.
- Current open work is manuscript integration, Betre WXF cross-checks, and deciding whether to attempt `(4,6)`.

## Quick Start

You need:

- Wolfram 15.0 or later, with `wolframscript` on `PATH` (Mathematica or
  the free Wolfram Engine);
- git, to clone this repository and the ECGrav package. Without git, see
  the notes below.

```powershell
git clone https://github.com/nraplee/CombResearch.git
cd CombResearch
wolframscript -file run.wl check                 # clones ECGrav, runs the smoke tests
wolframscript -file run.wl all profile quick     # small end-to-end run
wolframscript -file run.wl status                # what was made, and with which ECGrav
```

- `run.wl check` clones [ECGrav](https://github.com/kassabetre/ECGrav)
  (Dr. Kassahun Betre's package) into `ECGrav-upstream/`. Later runs of
  `check` update it to the latest `main`.
- `run.wl all profile quick` computes small versions of everything into
  `data/`, `figures/`, `results/` and `logs/` inside the clone: exact truth
  for the small cells, IS, MH and ECGrav samples, validation tables and
  figures. Every stage resumes: rerunning skips finished jobs.
- `profile paper` is the full set behind the paper. It takes days.
- `wolframscript -file run.wl all dryrun` lists every planned job and why
  it would run or skip.

Notes:

- **No git:** download ECGrav as a zip from GitHub and unpack it as
  `ECGrav-upstream/` next to `run.wl` (or point `COMB_ECGRAV_DIR` at any
  ECGrav checkout). `run.wl check` says so when it cannot clone. Outputs go
  into the folder that holds `run.wl`.
- **Repository zip:** a GitHub zip works the same way, even when unpacked
  inside another git repository. Outputs stay in the unpacked folder.
- `COMB_ROOT=<dir>` sends all outputs somewhere else.

Stages can also be run directly, for example:

```powershell
wolframscript -file pipeline/10_truth.wl          # exact truth enumeration
wolframscript -file pipeline/30_mh.wl             # MH chains
wolframscript -file pipeline/50_validate.wl samples
wolframscript -file pipeline/60_figures.wl truth_overlay
```

## Layout

```text
run.wl                 single entry point (stages, profiles, skip rule, store report)
config/cells.wl        run profiles: quick, paper
CombResearch/          the algorithms as a package (Enumeration, Statistics, MHSampler, ISSampler, Compare) + .wlt tests
pipeline/              the stages run.wl launches (10_truth ... 60_figures)
pipeline/common/       shared helpers: paths, names, io, config, ecgrav, combresearch
tests/                 pipeline checks, ECGrav truth-grid regression, golden references
tools/dev/             .ps1 launchers and monitors, worktree sync, ECGrav update helpers
reference/             .tex, Figure 2 notebooks, related papers (reference only)
docs/                  technical docs and live handoff
data/ figures/ logs/ results/   generated outputs (large data files gitignored)
ECGrav-upstream/       shared clone of upstream ECGrav (gitignored), updated by run.wl check
```

## Docs

- `CLAUDE.md` - project instructions for Claude Code.
- `docs/agent-task.md` - live handoff and current project state.
- `docs/enumeration.md` - truth enumeration, BLISS, McKay, validation.
- `docs/sampling.md` - importance sampling, MH sampler, q=10 ESS caveat.
