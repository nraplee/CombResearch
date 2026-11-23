# CLAUDE.md

Project instructions for Claude Code in this repository. Keep this file concise and practical.

## Project Overview

TODO: Keep this paragraph current as the paper evolves.

Current summary: Wolfram Mathematica research project for probability distributions of pure simplicial complexes. Figure 2 at q=3 is complete. Truth grid is now 9 cells `{(2,4), (2,5), (2,6), (2,7), (3,4), (3,5), (3,6), (4,4), (4,5)}`. MH chains validate against truth for all 27 cell×target combinations at L1 < 0.05, backed by stored 200k chains since Phase 3a (2026-11-21; `docs/architecture/provenance.md`). McKay canonical-augmentation enumeration (`EnumerateUnlabeledPureComplexes`, `Method -> "McKay"`, the Automatic choice at p >= 4) is the production path at p=4; the cheap pipeline OOMs at (4,5) even sequentially. Phase 5a (2026-09-26): ECGrav 1.17.0 validated against the truth grid. Its exact counters match our truth at every n on all 9 cells (confirming the (4,5) iso count 5,532), and its exact samplers (`RandomUniformUnlabeled…`, `RandomUniformFacetLabeled…`, `RandomVertexLabeled…`) pass all 27 cell×target combinations. `RandomPureSimplicialComplexMCMC` passes L1 but returns correlated samples for unlabeled. 2026-11-20 (Phase 1): every script loads the latest upstream ECGrav from one shared clone (`C:\CombResearch\ECGrav-upstream`, currently main @ 474b5c2); `tests/ecgrav_regression.wl` re-validates it against the truth grid. 2026-11-20: all generated outputs now live once in the main checkout (`pipeline/common/paths.wl`); worktrees no longer keep their own data. 2026-11-20 (Phase 2a): shared `src/lib_stats.wl` and `pipeline/common/io.wl`. 2026-11-20 (Phase 2b): `pipeline/common/names.wl` builds every data and log file name. 2026-11-20 (Phase 2c): `pipeline/common/config.wl` resolves every `COMB_*` setting; profiles `quick` and `paper` in `config/cells.wl`. 2026-11-21 (Phase 2d): every data output gets a `<file>.manifest.wl` sidecar; `tools/dev/backfill_manifest.wl` backfills the store from `provenance.md`. 2026-11-21 (Phase 3): `run.wl` is the single entry point (stages, profiles, skip rule, per-job fan-out, store report); Figure 2 is a script, `src/render_fig2.wl`, checked against the reference notebooks by `tests/fig2_check.wl`; `tests/golden/golden_quick.wl` checks a quick-profile store. 2026-11-21 (Phase 3a): flagged MH/ECGrav data regenerated with `run.wl` on ECGrav 474b5c2; `mh`, `ecgexact`, `ecgmcmc` all pass 27/27. 2026-11-21 (Phase 4, row 1): the `CombResearch` package (`CombResearch/`, ECGrav layout) holds the enumerators (`Enumeration.wl`); 2026-11-22 (row 2): and the 12 statistics (`Statistics.wl`, `PureComplexStatistics`; `src/lib_stats.wl` is a shim); 2026-11-22 (row 3): and the MH sampler (`MHSampler.wl`, `PureComplexMHChain`); `pipeline/30_mh.wl` is the MH stage (`src/sampler_mh.wl`, `src/run_mh_chains.wl` are shims); row 4: `pipeline/40_ecgrav.wl` is the ECGrav stage (`src/run_ecgrav_samplers.wl` is a shim); row 5a: IS sampling and weights (`ISSampler.wl`, `PureComplexISSample`, `PureComplexISWeights`, `EffectiveSampleSize`); `pipeline/20_is_q10.wl` is the q=10 IS stage (`src/pure_simplicial_compute.wl` is a shim, `*Override` protocol unchanged); row 5b: `run.wl is` merges each p's batches from the profile's batch list (`pipeline/21_is_merge.wl`; `src/concat_samples.wl` is a shim); `pipeline/10_truth.wl` is the truth stage and always writes the final `_truth.wxf`; the old `src/streaming_enumerator*.wl` are shims. 2026-11-22 (row 6): `Compare.wl` (`PureComplexTruthMarginal`, `SampleHistogram`, `HistogramL1Distance`, `IIDL1PValue`, `IsoClassChiSquare`, `PureComplexStatisticHistograms`); `pipeline/50_validate.wl` is the validate stage, one job per process (`COMB_VAL_JOB` = counts, samples, efficiency, 3way, q10_is_vs_mh, q10_warm_vs_prod, results; the `src/validate_*`/`compare_*` scripts are shims); its last job writes every summary as `results/<name>.csv`; `pipeline/22_is_hists.wl` writes the q=10 numV hists and `p{p}q10_is_stat_hists.wxf` (every statistic x 3 targets x all/connected). 2026-11-22 (row 7): `pipeline/60_figures.wl` is the figures stage, one job per process (`COMB_FIG_JOB` = fig2, truth_overlay, 3way, q10_is_vs_mh, q10_warm_vs_prod, sampler_progress, uniformity, ecgrav_compare, q10_stats; the `src/render_*.wl` scripts are shims); q10_stats draws Figures 3-15 from the stat hists, not the 2.8 GB merged stats; sampler_progress reads the 500k batch WXF, not the legacy CSV. Phase 4 is complete. 2026-11-23 (Phase 5, PR A): the Phase 4 shims, superseded scripts (`enumerate_truth.wl`, `run_p{2,3,4}.wl`, `test_streaming*.wl` (now `Enumeration.wlt`), ...) and tracked `archive/` are deleted (history and tag `pre-restructure` keep them); `run.wl is` runs `pipeline/20_is_q10.wl` directly (`COMB_IS_PS`, `COMB_IS_PAR`). 2026-11-23 (Phase 5, PR B): `git mv` into the ideal layout: `src/` is gone; helpers in `pipeline/common/` (renamed `paths`, `names`, `io`, `config`, `ecgrav`, `combresearch`), launchers/monitors/sync in `tools/dev/`, `reference/` holds the `.tex`, Fig 2 notebooks and PDFs; code root = the folder holding `run.wl`; the sync hook skips quietly without `powershell.exe`. 2026-11-23 (Phase 5, PR C): `logs/` and the Betre `.mx` untracked; Phase 5 is complete. 2026-11-23 (Phase 7): a fresh clone, a zip inside another repo and a zip without git all run `check` + the quick profile + `golden_quick` (fixes in `update_ecgrav.wl`, `io.wl`); the laptop run is still open. Next: Phase 6 deliverable (a notebook GUI to discuss with Dr. Betre, `docs/architecture/phase6-deliverable.md`), then q=10 with the exact samplers as reference, then manuscript integration.

## Repo Layout

- `pipeline/` - the stages `run.wl` launches: `10_truth.wl`, `20_is_q10.wl`, `21_is_merge.wl`, `22_is_hists.wl`, `23_is_truth_cells.wl`, `30_mh.wl`, `40_ecgrav.wl`, `50_validate.wl`, `60_figures.wl`; `pipeline/common/` holds the shared helpers every script loads: `paths.wl` (+ `paths.ps1`), `names.wl`, `io.wl`, `config.wl`, `ecgrav.wl`, `combresearch.wl` (Phase 5; were `src/comb_paths.wl`, `lib_*.wl`, `load_*.wl`). There is no `src/` any more.
- `tools/dev/` - developer tools: `.ps1` launchers and monitors, `sync_worktree_data.ps1`, `update_ecgrav.wl`, `install_ecgrav_global.wl`, `backfill_manifest.wl`, `make_check_root.wl`.
- `tests/` - pipeline checks, the ECGrav truth-grid regression, `golden/`.
- `reference/` - reference only: `Pure Clique Complexes.tex`, `fig2/` (the Figure 2 notebooks), `papers/` (related PDFs). The manuscript lives on Overleaf.
- `CombResearch/` - the algorithms as a package laid out like ECGrav (Phase 4): `PacletInfo.wl`, `Kernel/CombResearch.wl` (public symbols with `::usage`), `Kernel/Subpackages/*.wl` (code, private context), `Tests/*.wlt`. Loaded through `pipeline/common/combresearch.wl`. So far: `Enumeration.wl`, `Statistics.wl`, `MHSampler.wl`, `ISSampler.wl`, `Compare.wl`.
- `reference/fig2/` - Figure 2 reference notebooks; do not edit unless explicitly asked. `pipeline/60_figures.wl fig2` is the script version (outputs `data/p3q3_n10000_fig2.wxf`, `figures/fig2/`).
- `ECGrav-upstream/` (main checkout only, gitignored) - shared clone of upstream ECGrav that every script loads. No ECGrav sources are vendored in git.
- `results/` (main checkout) - small result tables: `results/*.csv` from `run.wl validate` (one per summary), the ECGrav regression record.
- `data/` - generated CSV/WXF compute outputs; generally do not edit by hand. One shared copy lives in the main checkout (`C:\CombResearch\data` on the Ryzen PC), never in a worktree; see "Generated outputs" below.
- `figures/` - generated manuscript panels, previews, and review PDFs.
- `docs/` - consolidated technical docs, manuscript draft, and live handoff.
- `logs/` - generated run logs, untracked since Phase 5 (gitignored; git history keeps the old ones). The Betre `data/p4q{4,5}SX*.mx` files are untracked the same way.
- `archive/` - deleted in Phase 5 (git history and tag `pre-restructure` keep it). An ignored `archive/superseded_data` may still sit on disk in the main checkout.

This is a single-project repo rooted at `C:\CombResearch`; there are no major independent subprojects that need nested `CLAUDE.md` files right now.

## Commands

No tracked package or build metadata (`PacletInfo.wl`, `package.json`, `pyproject.toml`, Makefile, or similar); ECGrav comes from the shared upstream clone.

Install/setup:

- No dependency installation step is defined for this repo.
- `wolframscript` must be on `PATH`.
- Wolfram 15.0+ is required (ECGrav declares `WolframVersion -> "15.0+"`). Wolfram 15.0.1 is installed on the Ryzen 7 5800X PC (heavy runs go there), the i7-8750H laptop (32 GB) and the i5-14500T PC.
- ECGrav: `wolframscript -file tools\dev\update_ecgrav.wl` clones github.com/kassabetre/ECGrav into `$CombRoot\ECGrav-upstream` on first use, then fast-forwards it to upstream main. Run it only between runs (running kernels keep the code they loaded), then run `wolframscript -file tests\ecgrav_regression.wl`: counters, aut/autF and exact samplers vs the truth grid, plus an MH smoke test (~10 min). A pass is recorded in `results\ecgrav_regression_passed.wl`; `ecgrav.wl` warns while the loaded commit has not passed.
- Every script loads ECGrav through `pipeline/common/ecgrav.wl`, which `Get`s `Kernel/ECGrav.wl` from the shared clone; the globally installed paclet is never used. `COMB_ECGRAV_DIR=<checkout>` loads another ECGrav checkout instead (e.g. a fork branch being prepared for upstream). The loader sets `$CombECGravVersion` (e.g. `1.18.0-474b5c2`) and `$CombECGravCommit`, and aborts if a function this repo calls (`$CombECGravSymbols`) is missing. Old vendored snapshots (1.0.0, 1.17.0, 1.18.0-474b5c2) are in git history before Phase 1 (tag `pre-restructure`).
- Global paclet (notebooks, `reference/fig2/`, the Wolfram MCP server only): `wolframscript -file tools\dev\install_ecgrav_global.wl` installs the shared clone. Rerun it after `update_ecgrav.wl` moves the clone.
- Do not add or install dependencies without asking first.

Generated outputs (added 2026-11-20):

- Every script takes `data/`, `figures/` and `logs/` from `pipeline/common/paths.wl` (`$CombDataDir`, `$CombFiguresDir`, `$CombLogsDir`) or, in PowerShell launchers, `pipeline/common/paths.ps1`. These resolve to the main checkout (the parent of `git rev-parse --git-common-dir`) even when the script runs from a worktree. Code still runs from the checkout the script lives in: the code root is the folder above the script that holds `run.wl` (`$CombCodeRoot`; the `.ps1` launchers walk up to it the same way). A git root counts as the main checkout only if it holds `run.wl` and `config/cells.wl`. `COMB_ROOT` overrides the output root. If the git call fails twice in a worktree, the main checkout is read from the worktree's `.git` file (`gitdir:` + `commondir`); if that fails too the script stops (`.wl`: Exit 3; `.ps1`: throws) instead of writing to `<worktree>\data`.
- Safety net: `tools/dev/sync_worktree_data.ps1` copies untracked/ignored files from every worktree's `data/`, `figures/`, `logs/` into the main checkout. It never overwrites or deletes; a file that differs from main's goes to `<dir>\_from_worktrees\<worktree>\` and is reported as a conflict. `-DryRun` previews. The committed `.claude/settings.json` runs it on Claude Code SessionStart and SessionEnd (it exits quietly where `powershell.exe` is not on PATH, e.g. macOS/Linux).

```powershell
powershell -ExecutionPolicy Bypass -File tools\dev\sync_worktree_data.ps1 -DryRun
```

One entry point, `run.wl` (Phase 3). It launches the drivers below with `COMB_*` env from the profile, one process per cell×target (MH), per sampler×target (ECGrav) or per p×batch (q=10 IS), at most `jobs N` at once (default 4), with the launchers' log names (so `monitor_mh.ps1`/`monitor_ecgrav.ps1` work). A job runs only when an output is missing; `force` reruns one named stage (never `all`). Options are plain words. Default profile: `paper`. Per-job identity knobs (cells, targets, sampler, tag, N, ...) always come from run.wl; a leftover `COMB_FORCE`/identity env var is ignored with a warning, other leftovers win over the profile. Each running job holds `logs\<log>.lock`; a run.wl killed mid-job leaves its locks, which then block that job until deleted by hand.

```powershell
wolframscript -file run.wl status                                   # store report: manifests, stale/flagged files
wolframscript -file run.wl all dryrun                               # every planned job, run/skip reason, settings + sources
wolframscript -file run.wl mh cells "2,7;3,6" targets facet dryrun
wolframscript -file run.wl mh profile paper cells "2,4;3,5" targets vertex force
wolframscript -file run.wl check                                    # update ECGrav, regression if needed, smoke tests, report
```

What the `cells`, `targets` and `sampler` words set in each stage (guarantee 3: every knob keeps its name; with no word each job takes its plan's value):

| Stage | `cells "p,q;..."` | `targets a,b` | `sampler x` |
|---|---|---|---|
| truth | `COMB_TRUTH_CELLS` (per truth run) | — | — |
| is | q=10 batches and their merge: pick p by `p,10`; IS at truth cells: `COMB_IS_CELLS`; q=10 histograms not planned | — | — |
| mh | one job per cell: `COMB_MH_CELLS` | `COMB_MH_TARGETS` (one job per target) | — |
| ecgrav | `COMB_ECG_CELLS` (one job per target, all cells) | `COMB_ECG_TARGETS` | `COMB_ECG_SAMPLER` (exact, mcmc, legacyfacet) |
| validate | counts: `COMB_VAL_CELLS`; every summary writer skipped (`COMB_VAL_*`, `COMB_EFF_*`, `COMB_3W_*`, p-only `COMB_CMP_PS` stay profile/default) | summary writers skipped | `COMB_VAL_SOURCE` (mh, exact→ecgexact, mcmc→ecgmcmc, legacyfacet); cross-sampler summaries not planned |
| figures | nothing planned | — | — |
| check | ignored (regression uses `COMB_REG_CELLS`) | ignored | — |

The stages, run directly (each reads the same `COMB_*` knobs run.wl sets):

```powershell
# Truth (run.wl truth): always writes p{p}q{q}_truth.wxf.
#   COMB_TRUTH_CELLS (default: the 9-cell grid), COMB_TRUTH_PIPELINE=auto|cheap|bliss|mckay
#   (auto = McKay for p>=4), COMB_TRUTH_PARALLEL, COMB_FORCE. Gates for all 9 cells.
#   To cross-validate a pipeline, run it with COMB_TRUTH_PIPELINE in a scratch COMB_ROOT.
wolframscript -file pipeline\10_truth.wl

# q=10 IS (run.wl is): COMB_IS_PS (p list, default 2,3,4), COMB_N (default 10000),
#   COMB_IS_PAR=1 (ParallelMap), COMB_RUNTAG, COMB_CHUNK, COMB_NN_FIXED.
wolframscript -file pipeline\20_is_q10.wl
powershell -ExecutionPolicy Bypass -File tools\dev\run_parallel.ps1   # one process per p (COMB_PLIST, N, RUNTAG)
wolframscript -file pipeline\21_is_merge.wl          # merge each p's batches
wolframscript -file pipeline\22_is_hists.wl          # q=10 numV hists + p{p}q10_is_stat_hists.wxf
wolframscript -file pipeline/23_is_truth_cells.wl     # 100k IS samples at (3,5), (4,5)

# MH (run.wl mh): COMB_MH_CELLS, COMB_MH_TARGETS, COMB_MH_NUMITER, COMB_MH_BURNIN,
#   COMB_MH_THIN, COMB_MH_SEED, COMB_MH_KERNEL, COMB_FORCE.
wolframscript -file pipeline\30_mh.wl
powershell -ExecutionPolicy Bypass -File tools\dev\run_p4q5_mh_parallel.ps1   # (4,5), one process per target
powershell -ExecutionPolicy Bypass -File tools\dev\run_q10_mh_parallel.ps1    # q=10 200k chains, 4 disagreement cells
powershell -ExecutionPolicy Bypass -File tools\dev\run_q10_mh_overnight.ps1   # q=10 warm-start + second seed, ~5 h
powershell -ExecutionPolicy Bypass -File tools\dev\monitor_mh.ps1

# ECGrav samplers (run.wl ecgrav): COMB_ECG_SAMPLER=exact|mcmc|legacyfacet, COMB_ECG_CELLS,
#   COMB_ECG_TARGETS, COMB_ECG_N, COMB_ECG_SEED, COMB_ECG_TRACE_STEPS, COMB_FORCE
#   -> data/p{p}q{q}_ecg{sampler}_{target}.wxf
wolframscript -file pipeline\40_ecgrav.wl
powershell -ExecutionPolicy Bypass -File tools\dev\run_ecgrav_campaign.ps1   # 3 parallel targets
powershell -ExecutionPolicy Bypass -File tools\dev\monitor_ecgrav.ps1        # COMB_MON_SAMPLER

# Validate (run.wl validate runs every job, then "results": results\*.csv). Jobs:
#   counts (ECGrav counters vs truth), samples (numV L1 vs truth; COMB_VAL_SOURCE=
#   mh|ecgexact|ecgmcmc|ecglegacyfacet, COMB_VAL_CELLS, COMB_VAL_TARGETS, COMB_VAL_THRESHOLD),
#   efficiency (ESS table; COMB_EFF_*), 3way (IS/MH/truth at q=5), q10_is_vs_mh,
#   q10_warm_vs_prod, results.
wolframscript -file pipeline\50_validate.wl samples

# Figures (run.wl figures runs every job): fig2, truth_overlay, 3way, q10_is_vs_mh,
#   q10_warm_vs_prod, sampler_progress, uniformity, ecgrav_compare, q10_stats (Figures 3-15).
wolframscript -file pipeline\60_figures.wl truth_overlay
```

Checks/smoke tests:

```powershell
wolframscript -file CombResearch\Tests\run_tests.wl   # package .wlt tests incl. the enumerators (~3-7 min); also in run.wl check
wolframscript -file tests\ecgrav_regression.wl     # ECGrav vs truth grid; after any ECGrav change
wolframscript -file tests\lib_names_test.wl        # file names vs literals and the store (read-only)
wolframscript -file tests\lib_config_test.wl       # combSetting kinds, precedence, profiles (read-only)
wolframscript -file tests\manifest_test.wl         # manifests + backfill, in its own temp COMB_ROOT
wolframscript -file tools\dev\backfill_manifest.wl # dry run: provenance row/status per store file; "write" to write
wolframscript -file tests\golden\golden_derived.wl check   # refactors must reproduce golden/derived
wolframscript -file tests\run_wl_test.wl           # run.wl planning/safety rules, own temp COMB_ROOT (~5 min)
wolframscript -file tests\fig2_check.wl            # the fig2 job's output vs the reference notebooks' saved numbers
# golden/quick: a quick-profile store in a scratch root, then its check
$env:COMB_ROOT = "C:\scratch\quick"; $env:COMB_ECGRAV_DIR = "C:\CombResearch\ECGrav-upstream"; wolframscript -file run.wl all profile quick
wolframscript -file tests\golden\golden_quick.wl
```

No lint or typecheck command is configured. Use targeted Wolfram scripts as checks. Avoid full overnight or large production runs unless the user asks.

## Coding Rules

- Prefer existing Wolfram patterns and helpers already in `pipeline/common/` and the package, and targeted edits that keep the repo's Wolfram style.
- Use `wolframscript -file` for non-trivial Wolfram execution; shell quoting around Wolfram backticks is fragile.
- Do not edit generated files in `data/`, `figures/`, or `logs/` unless explicitly asked.
- Do not edit Figure 2 reference notebooks in `reference/fig2/` unless explicitly asked.
- Never use `RandomFacetLabeledPureSimplicialComplex` for the facet-labeled distribution (still non-uniform in 1.17.0; it is the harness negative control). Use `RandomUniformFacetLabeledPureSimplicialComplex` (validated 2026-09-26) or exact truth data.
- Load ECGrav only through `pipeline/common/ecgrav.wl` (from a stage: `Get[FileNameJoin[{DirectoryName[$InputFileName], "common", "ecgrav.wl"}]]`); never a bare `Needs["ECGrav`"]`. After `LaunchKernels[]` use `combLoadECGravOnKernels[]`, not `ParallelEvaluate[Needs["ECGrav`"]]`, so subkernels run the same checkout.
- MH sampler vertex target uses `π_V(X) ∝ 1/C(N, numV(X))` (2026-05-14 fix). The earlier `π_V ∝ 1` was wrong by a `C(N, k)` factor and produced L1 = 0.85 vs truth at (3,5). Do NOT revert without re-deriving — see in-code comment at the vertex Switch branch of `mhStep` in `CombResearch/Kernel/Subpackages/MHSampler.wl`.
- At p=4 the cheap pipeline OOMs at (4,5) even sequential. Use `EnumerateUnlabeledPureComplexes[p, q]` (Automatic picks McKay at p >= 4) or `Method -> "McKay"`. Cheap is still fine at (4,4) and below. The old names (`streamingEnumeratePure`, `blissCanonicalKey`, ...) were deleted in Phase 5.
- Algorithms go in the `CombResearch` package: public symbol + `::usage` in `Kernel/CombResearch.wl`, code in `Kernel/Subpackages/`, tests in `Tests/*.wlt`. Stages load it with `Get[FileNameJoin[{DirectoryName[$InputFileName], "common", "combresearch.wl"}]]`, which loads ECGrav first; the package never loads ECGrav itself. Option names that are not System symbols are strings (`"Parallel" -> False`; a caller's bare `Parallel -> False` matches too).
- Read and write generated files only through `paths.wl` / `paths.ps1`. Never hardcode `C:/CombResearch/...`, never build output paths from the script's own checkout (`projectRoot`/`$PSScriptRoot`), and never use cwd-relative `"data/..."`. Large outputs must not be committed through git; they live only in the main checkout.
- The 12 statistics are the package's `PureComplexStatistics[c, p]` with column names `$PureComplexStatisticNames` (`$PureComplexISNames` adds the 3 IS weight columns); after `LaunchKernels[]` call `combLoadCombResearchOnKernels[]` first. The old `statsFor` / `$CombStatsHeaders` (`src/lib_stats.wl`) were deleted in Phase 5. `exportWxfAtomic` is in `pipeline/common/io.wl`; never `Block`-`Get` a pipeline stage for its helpers.
- Build data and log file names with `combFile` / `combName` from `pipeline/common/names.wl` (`combFile["truth", p, q]`, `combFile["mh", p, q, target]`, ...); never concatenate `"p" <> ToString[p] <> ...` by hand. A new data family gets a `combName` rule there and a case in `tests/lib_names_test.wl`. The names are today's flat names; never rename existing WXFs.
- Read `COMB_*` knobs with `combSetting[name, default, kind]` from `pipeline/common/config.wl` (kinds `"string"`, `"expr"`, `"cells"`, `"list"`, `"intList"`, `"flag"`, `"notFalse"`, `"notZero"`); never parse `Environment["COMB_..."]` by hand. Order: env, then the profile named by `COMB_PROFILE` (`config/cells.wl`), then the script default; with no `COMB_PROFILE` scripts behave as before. Keep a knob's name when moving it. Exceptions: `COMB_ROOT`, `COMB_ECGRAV_DIR` (read before `pipeline/common/config.wl` can load) and the `COMB_TEST_*` smoke-test knobs.
- Write data outputs with `exportWxfAtomic[path, expr, extra]` (`pipeline/common/io.wl`): it writes `<file>.manifest.wl` next to the file (sha256, code commit, ECGrav commit, `$Version`, kernels, profile, every resolved setting, plus `extra` such as seeds or `"inputs"`). Pass `None` only for temporary files (IS chunks). Never write one shared manifest file. Manifests written by `tools/dev/backfill_manifest.wl` carry `backfilled -> <|...|>` and a `provenance` `status` (`knownBad` for the pre-fix vertex chains); the tool never replaces a real-run manifest.
- `wolframscript -file x.wl a -b c` passes only `a` to `$ScriptCommandLine`: it drops every argument from the first one that starts with `-` (checked 2026-11-21, 15.0.1). Script arguments are plain words (`write`, `force`, `check`); Phase 3's `run.wl` cannot use `--profile`-style flags as planned.
- Keep changes narrowly scoped. Do not reformat unrelated files.
- Do not add dependencies without asking first.

## Testing and Checking Rules

- Before continuing prior work, inspect `git status --short` and relevant `git diff`.
- For documentation-only changes, `git diff -- CLAUDE.md docs/agent-task.md` is usually enough.
- For code changes, run the smallest relevant Wolfram check or smoke script and record what ran in the handoff.
- Treat q=10 facet/unlabeled IS histograms with caution; ESS collapse is documented in `docs/sampling.md`.

## Git and Worktree Rules

- The worktree may already contain user or agent changes. Do not revert changes you did not make.
- Inspect `git status --short` and relevant diffs before modifying files, especially when resuming prior work.
- Do not commit, push, branch, or clean generated files unless the user asks.
- Any commit or PR whose work wrote outputs must say so: list the files (or globs) written under the main checkout's `data/`, `figures/`, `logs/`, and say they are not in the commit. Figures that should be tracked are committed from the main checkout; logs are not tracked (Phase 5).

## Handoff Protocol

- `CLAUDE.md` (this file) holds the project instructions. There is no `AGENTS.md`.
- Use plan mode before large rewrites or broad research-code changes.
- `docs/agent-task.md` is the live handoff. Update it when the goal, status, decisions, likely files, or validation commands change.
- At the start of a resumed session, read `docs/agent-task.md`, inspect git status/diff, then continue from the recorded state.

