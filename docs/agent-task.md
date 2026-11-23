# Current Agent Task

## Phase 5 PR B: `git mv` into the ideal layout + hook (2026-11-23, Ryzen, branch `claude/phase5-b-move`, stacked on PR A #39)

- `src/` is gone. `pipeline/common/`: `paths.wl` + `paths.ps1` (were
  `comb_paths.*`), `names.wl`, `io.wl`, `config.wl` (were `lib_*.wl`),
  `ecgrav.wl`, `combresearch.wl` (were `load_*.wl`); the user chose the
  ideal.md names. Symbols are unchanged (`combFile`, `combSetting`,
  `exportWxfAtomic`, `$CombDataDir`, ...); message prefixes and log names
  (`lib_names:`, `check_lib_names.log`, ...) are unchanged too.
- `pipeline/23_is_truth_cells.wl` (was `src/run_is_at_truth_cells.wl`).
- `tools/dev/`: the `.ps1` launchers and monitors, `sync_worktree_data.ps1`,
  `install_ecgrav_global.wl`.
- `reference/`: `Pure Clique Complexes.tex`, `fig2/` (the two notebooks,
  byte-identical), `papers/` (the PDF from `archive/related_pdfs`).
- Code root: `paths.wl` / `paths.ps1` and every launcher walk up to the
  folder that holds `run.wl`. Repo marker: a git root counts as the main
  checkout if it holds `run.wl` and `config/cells.wl` (on main since Phase
  3), so outputs still go to `C:\CombResearch` while its checkout is older.
- Hook: `command -v powershell.exe >/dev/null 2>&1 || exit 0; powershell.exe
  ... tools/dev/sync_worktree_data.ps1 -Quiet`.
- A read-only review of the patch caught `combresearch.wl` still taking one
  `ParentDirectory` to the package (every stage would have aborted); fixed
  before any check ran.
- Checks: see the PR.

## Phase 5 PR A: delete shims, superseded scripts, `archive/` (2026-11-23, Ryzen, branch `claude/phase5-a-delete`)

Order agreed with the user: A (delete) -> B (`git mv` into the ideal
layout, helpers renamed to ideal.md names, hook fix; stacked on A) -> C
(untrack `logs/` and the Betre `.mx`, from main).

- Deleted: the 25 `src/*.wl` shims, `enumerate_truth.wl` (10_truth with
  `COMB_TRUTH_PIPELINE` in a scratch root does its cross-validation),
  `run_p{2,3,4}.wl`, `test_streaming{,_bliss,_mckay}.wl` (every check is in
  `Enumeration.wlt`, already in `run.wl check`), `migrate_csv_to_wxf`,
  `precompute_is_histogram`, `probe_betre_mx`, `pure_simplicial_figures.nb`,
  `pure_simplicial_compute_overnight`, `run_q10_mh_pilot.ps1`, and tracked
  `archive/` except `related_pdfs/` (PR B moves it).
- `pipeline/20_is_q10.wl` gained `COMB_IS_PS` (p list), `COMB_N` and
  `COMB_IS_PAR`; `run.wl is` runs it directly (`COMB_IS_PS` is an identity
  knob), as does `src/run_parallel.ps1`. Bare runs: same defaults.
- `10_truth.wl` calls `PureComplexStatistics` directly;
  `tests/ecgrav_regression.wl` uses `PureComplexMHChain`; the MH/ECGrav
  launchers call `pipeline/30_mh.wl` / `40_ecgrav.wl`; `run.wl check` lost
  the two `test_streaming` smoke jobs.
- CLAUDE.md commands rewritten around the stages; README quick start is
  `run.wl`.
- Checks (scratch roots only, nothing written to the main checkout's
  outputs): see the PR.

## Phase 4 row 7: `pipeline/60_figures.wl` (2026-11-22, Ryzen, branch `claude/phase-4-figures`)

Phase 4 is done. Next: Phase 5 (one `git mv` PR, then delete the shims).

- `pipeline/60_figures.wl`: jobs `fig2`, `truth_overlay`, `3way`,
  `q10_is_vs_mh`, `q10_warm_vs_prod`, `sampler_progress`, `uniformity`,
  `ecgrav_compare`, `q10_stats` (set by `COMB_FIG_JOB`, an identity knob,
  or by a plain word). The 9 `src/render_*.wl` scripts are shims. `run.wl
  figures` keeps the same labels and logs.
- `q10_stats` reads `p{p}q10_is_stat_hists.wxf` (2.8 GB less to load).
  `largestCompRatio` has fixed bins of width 1/20, the same bins Automatic
  chose on the stored samples.
- `sampler_progress` reads the 500k batch WXF, not the legacy CSV.
- On the real store, the stat hists do not exist until `run.wl is` runs.
  Until then the q=10 figures job is held back ("inputs missing").
- Checks (scratch roots only): old vs new render of all 9 jobs: 54 PNGs, 51
  pixel-identical, 3 with rasterization noise (old code rerun shows the same),
  365 PDFs same set, printed numbers identical; q=10 bar heights from stat
  hists vs merged samples: same bins, max diff 1.4e-14; quick store
  `run.wl all profile quick` + `golden_quick` PASS; `run_wl_test`,
  `lib_names_test`, `golden_derived check` (11/11) PASS; real-store
  `run.wl figures dryrun`: all skip, q=10 figures "inputs missing".

## Phase 4 row 6: Compare.wl + `pipeline/50_validate.wl` (2026-11-22, Ryzen, branch `claude/phase-4-compare`)

Next: row 7 (`60_figures.wl`): the renders read `results/` and the new
`p{p}q10_is_stat_hists.wxf` instead of the merged stats (give
`largestCompRatio` fixed bins there).

- Output formats were the user's call; answer: "whatever simplifies the
  processes best; all statistics, unless they're computed elsewhere".
- `CombResearch/Kernel/Subpackages/Compare.wl` (+ `Tests/Compare.wlt`, 15
  tests): `PureComplexTruthMarginal`, `SampleHistogram`,
  `HistogramL1Distance`, `IIDL1PValue`, `IsoClassChiSquare`,
  `PureComplexStatisticHistograms`.
- `pipeline/50_validate.wl`: jobs `counts`, `samples`, `efficiency`, `3way`,
  `q10_is_vs_mh`, `q10_warm_vs_prod`, `results` (`COMB_VAL_JOB`, identity
  knob, or a plain word). The six `src/validate_*` / `compare_*` scripts are
  shims. `run.wl validate` runs them with the same labels and logs, then
  `results tables` last (a "final" job).
- `results/*.csv` (main checkout `results/`): one per summary WXF, written
  from the WXF; `counts_vs_truth.csv` from the counts job.
- `pipeline/22_is_hists.wl` (was `precompute_is_histograms_q10.wl`, shim):
  numV hists unchanged, plus `p{p}q10_is_stat_hists.wxf` (12 statistics x 3
  targets x all/connected). On the store the next `run.wl is` writes only
  these three files (reads the 2.8 GB of merged stats; not run here).
- Not moved: `run_is_at_truth_cells.wl` (sampling, numV/aut/autF only).
- Checks (scratch roots; nothing written to the real store):
  - old (main) vs new code on copies of the real inputs: all 8 summary WXFs
    and the 9 q=10 numV hists identical (`===`, dropping `createdAt`).
  - The stat hists' numV part equals the numV hists exactly, and every hist
    is normalized.
  - Package tests ALL PASS (Compare 15, Enumeration 21, ISSampler 11,
    MHSampler 12, Statistics 12).
  - `lib_names_test`, `lib_config_test` and `run_wl_test` PASS.
  - `run.wl all profile quick` in `C:\scratch\quick6`: ok, with results
    tables last. `golden_quick` PASS (quick makes no q=10 MH, so it expects
    no `q10_is_vs_mh.csv`).
  - `golden_derived check`: all 11 sections PASS.
  - Dry runs on the real store: validate runs counts and results tables only
    (the summaries exist); is runs only the 3 stat-hist files.

## run.wl: later passes within a stage (2026-11-22, Ryzen, branch `claude/run-wl-second-pass`)

Fixes the row 5b wart below: `run.wl` now finishes a stage in one run when
one job's inputs are another job's outputs.

- `laterPasses` in `run.wl`: after a stage's jobs all succeed, the stage is
  planned again (`jobsFor`) and the jobs that were skipped only for
  "inputs missing" are decided again; those now "run" are run. Repeats until
  nothing new runs, at most `$maxPasses` = 4 passes. A failed job stops the
  stage as before; dry runs and the `check` stage are unchanged.
- `run.wl all profile quick` from an empty store: `is` ran the batches, then
  "pass 2" the 3 merges, then "pass 3" the 9 q=10 histograms, in one run.
- Checks (scratch roots; nothing written to the real store): that run ok;
  `golden_quick` PASS; `run_wl_test.wl` PASS (68, new "later pass" checks:
  a real p=2 batch + merge in one run, rerun starts nothing, no pass in a
  dry run); `golden_derived.wl check` (see PR).

## Phase 4 row 5b: q=10 batch merge as a `run.wl is` job (2026-11-22, Ryzen, branch `claude/phase-4-is-merge`, stacked on `claude/phase-4-is`)

Next: row 6 (Compare.wl + `50_validate.wl`). It adds new outputs
(`results/*.csv`, pre-binned q=10 statistics); agree their format with the
user before building it.

- `pipeline/21_is_merge.wl`: `concat_samples.wl` with `COMB_IS_MERGE_PS` and
  `COMB_IS_MERGE_STEMS` (identity knobs). Declared stems are merged in sorted
  file order (= the glob order); unset, it globs as before.
  `src/concat_samples.wl` is a shim.
- `run.wl is`: one merge job per p after its batches, with the profile's
  batch list (paper lists = exactly the files the stored merges came from;
  on the real store all three are skipped, outputs exist).
- Known wart (fixed by the later passes above): jobs are decided once per run, so a fresh store
  needs three `run.wl is` runs (batches, then merges, then the q=10
  histograms; before, the histograms already needed a second run). Fix:
  re-plan once after a stage's jobs finish.
- Checks (scratch roots; nothing written to the real store):
  - old `concat_samples.wl` (glob) vs the shim (glob) vs `21_is_merge.wl`
    with a declared, unsorted stem list: merged stats and complexes
    identical for p = 2, 3, 4 (incl. the stats-only path when a batch has no
    complexes file);
  - `run.wl all profile quick jobs 3` from an empty store: ok;
    `golden_quick` PASS; then `run.wl is` ran the 3 merges, and the next one
    the histograms;
  - `run.wl is dryrun` on the real store: merges skipped, lists shown;
  - `run_wl_test.wl` PASS (57); `golden_derived.wl check` all 11 PASS.

## Phase 4 row 5a: ISSampler.wl + `pipeline/20_is_q10.wl` (2026-11-22, Ryzen, branch `claude/phase-4-is`, stacked on `claude/phase-4-ecgrav`)

Next: 5b (batch merge as a `run.wl is` job, `pipeline/21_is_merge.wl`).

- `CombResearch/Kernel/Subpackages/ISSampler.wl`: the weight formulas and the
  per-chunk sample + statistics step. Public `PureComplexISSample`,
  `PureComplexISWeights`, `$PureComplexISNames`, `EffectiveSampleSize`.
  `Tests/ISSampler.wlt` (11 tests; the reweighting bound scales with the ESS,
  which is only ~N/5 for unlabeled/facet at (2,4)).
- `pipeline/20_is_q10.wl`: the q=10 IS driver on the package.
  `src/pure_simplicial_compute.wl` is a shim that Gets it in the same kernel,
  so `run_p{2,3,4}.wl`, the `*Override` variables, knobs, chunk resume and
  file names are unchanged. `$CombISHeaders` = `$PureComplexISNames`.
- Checks (scratch roots; nothing written to the real store):
  - old code vs new, same seeds: `run_p{2,3,4}.wl` N=250 in 3 chunks
    (parallel stats, 16 subkernels), a tagged p=3 batch and a COMB_NN_FIXED=18
    p=2 batch: all 10 stats/complexes files identical (createdAt aside);
  - chunk resume: chunks 1-2 rebuilt from a finished run, finals deleted;
    the new code resumed at chunk 3 and wrote identical files;
  - `run.wl is profile quick cells "2,10"`: ok;
  - package tests 4 files ALL PASS; `run_wl_test.wl` PASS (54);
    `golden_derived.wl check` all 11 PASS.

## Phase 4 row 4: `pipeline/40_ecgrav.wl` (2026-11-22, Ryzen, branch `claude/phase-4-ecgrav`, stacked on `claude/phase-4-mh`)

Next: row 5 (ISSampler + `20_is_q10.wl`), split into 5a (package + sampling
stage) and 5b (batch merge built into `run.wl is`).

- `pipeline/40_ecgrav.wl`: `run_ecgrav_samplers.wl` on the package
  (`PureComplexCanonicalKey`, `PureComplexStatistics`), same knobs, defaults
  and names. `run.wl ecgrav` runs it; `src/run_ecgrav_samplers.wl` is a
  shim, so `run_ecgrav_campaign.ps1` is unchanged.
- Checks (scratch roots; nothing written to the real store):
  - old code vs shim vs `40_ecgrav.wl` directly: exact (3,4) all three
    targets N=300, mcmc (2,4) unlabeled N=200, legacyfacet (2,4) N=200:
    identical apart from timing fields;
  - `run.wl ecgrav profile quick cells "2,4" targets facet sampler exact`: ok;
  - `run_wl_test.wl` PASS (54 checks); `golden_derived.wl check` all 11 PASS.

## Phase 4 row 3: MHSampler.wl + `pipeline/30_mh.wl` (2026-11-22, Ryzen, branch `claude/phase-4-mh`, stacked on `claude/phase-4-statistics`)

Next: row 4 (`pipeline/40_ecgrav.wl`).

- `CombResearch/Kernel/Subpackages/MHSampler.wl`: `sampler_mh.wl` moved
  verbatim with its derivation; option names became strings. Public
  `PureComplexMHChain` (checks target and kernel), `IntegratedAutocorrelationTime`.
  `Tests/MHSampler.wlt` (12 tests: numV L1 < 0.06 vs the exact marginal at
  (2,4) for all three targets, seed reproducibility, state shape, warm start,
  bad arguments, autocorrelation on constant/iid/AR(1) series).
- `pipeline/30_mh.wl`: `run_mh_chains.wl` on the package, same knobs,
  defaults and names; `samplerVersion` label `CombResearch/MHSampler.wl@<sha>`.
  `run.wl mh` runs it. `src/run_mh_chains.wl` (Gets 30_mh) and
  `src/sampler_mh.wl` (keeps its smoke test) are shims.
- Not done: the four MH `.ps1` launchers still call the shim, not `run.wl`
  (they do more than `run.wl mh`; proving a converted one needs a
  production-sized run).
- Checks (scratch roots; nothing written to the real store):
  - package tests: Enumeration 21/21, Statistics 12/12, MHSampler 12/12;
  - old code (`origin/main`) vs the shim vs `30_mh.wl` directly, same
    seeds: (3,4) unlabeled/facet/vertex 4k iters and a (2,5) facet chain
    with seed 777, mixed kernel, tag, warm start 4: identical (only
    wallSeconds/createdAt/samplerVersion differ);
  - `run.wl mh profile quick cells "2,4" targets facet` in a scratch root: ok;
  - `src/sampler_mh.wl` smoke test (p = 2, 3, 4 at q = 10) runs;
  - `run_wl_test.wl` PASS (53 checks, incl. the mh job runs 30_mh.wl);
  - `golden_derived.wl check`: all 11 sections PASS.

## Phase 4 row 2: Statistics.wl (2026-11-22, Ryzen, branch `claude/phase-4-statistics`)

Next: row 3 (MHSampler + `pipeline/30_mh.wl`).

- `CombResearch/Kernel/Subpackages/Statistics.wl`: the 12 statistics moved
  verbatim from `src/lib_stats.wl`. Public `PureComplexStatistics[c, p]`,
  `$PureComplexStatisticNames`, `PureComplexKPathComponents`,
  `PureComplexBettiNumber`. `Tests/Statistics.wlt` (12 tests).
- `src/lib_stats.wl` is a shim (same Global names, `$CombISHeaders` stays).
  `pure_simplicial_compute.wl` loads the package on its subkernels.
- Checks (scratch roots; nothing written to the real store):
  - package tests: Enumeration 21/21, Statistics 12/12 PASS;
  - the package recomputes the stored stats of all 10,882 truth classes
    (9 cells) exactly; the `statsFor` shim gives the same rows;
  - old code (`origin/main`) vs new code, same seeds: `run_p3.wl` N=200
    (parallel IS), `run_mh_chains.wl` (3,4) vertex+facet 3k iters,
    `run_ecgrav_samplers.wl` (3,4) unlabeled N=300: outputs identical
    (MH differs only in wallSeconds/createdAt/samplerVersion label);
  - `test_streaming.wl`, `test_streaming_mckay.wl` PASS;
  - `golden_derived.wl check`: all 11 sections PASS (33 min).

## Phase 4 row 1: `CombResearch` package + `pipeline/10_truth.wl` (2026-11-21, Ryzen, branch `claude/adoring-brahmagupta-4bc3dc`)

Next: Phase 4 row 2 (Statistics.wl). Agreed order for the rest: Statistics,
MHSampler + `30_mh`, `40_ecgrav`, ISSampler + `20_is_q10`, Compare +
`50_validate`, `60_figures` (`docs/architecture/implementation-plan.md`).

- New package `CombResearch/` laid out like ECGrav: `PacletInfo.wl`,
  `Kernel/CombResearch.wl` (usage messages), `Kernel/Subpackages/Enumeration.wl`
  (cheap, BLISS, McKay moved verbatim), `Tests/Enumeration.wlt`,
  `Tests/TestPrelude.wl`, `Tests/run_tests.wl`. Loaded through
  `src/load_combresearch.wl` (ECGrav first).
- Public: `EnumerateUnlabeledPureComplexes` (Method Automatic = McKay at
  p >= 4), `PureComplexCanonicalKey`, `ChooseNonIsomorphicPureComplexesBucketed`,
  `$CombTruthIsoCounts`, `$CombResearchSubkernelSetup`.
- `pipeline/10_truth.wl`: the truth stage; always writes the final
  `_truth.wxf` (no McKay rename); gates for all 9 cells; exit 1 on a failed
  gate. `run.wl truth` runs it; the rename-pending state is gone. `run.wl
  check` also runs the package tests.
- Shims: `src/streaming_enumerator{,_bliss,_mckay}.wl` keep the old Global
  names. `src/enumerate_truth.wl` unchanged (cross-validation, tagged names).
- Checks (scratch roots; nothing written to the real store):
  - `CombResearch/Tests/run_tests.wl`: Enumeration.wlt 21/21 PASS (4.6 min).
  - `src/test_streaming.wl` ALL PASS, `src/test_streaming_mckay.wl` all gates
    pass (through the shims; the first uses the parallel path).
  - `pipeline/10_truth.wl` regenerated (2,4) (2,5) (2,6) (3,4) (3,5) cheap
    and (4,4) McKay sequential: `complexes`, the three pi vectors and the
    counts are identical (`===`) to the stored files.
  - `run.wl truth profile quick` in an empty root: one job, ok, files
    identical to the store; a second run skips. `run.wl truth dryrun` on the
    real store plans nothing; `run.wl check dryrun` lists the package tests.
  - `tests/run_wl_test.wl` PASS (52 checks), `lib_names_test`,
    `lib_config_test` PASS.
  - `tests/golden/golden_derived.wl check`: all 11 sections PASS (34 min).
- Not done / follow-ups: McKay `totalFacetLabeled` is still the pruned leaf
  count (fix = deliberate golden re-baseline); (2,7), (3,6), (4,5) were not
  regenerated (4-17 h each), covered by gates and the stored data only.

## Phase 3a: regenerate the flagged data (2026-11-21, Ryzen, code `@6db1aa4`, ECGrav 474b5c2)

Next: Phase 4 (`docs/architecture/implementation-plan.md`).

First production use of `run.wl` (profile `paper`, real store). Replaced
files and their manifests were first copied to
`C:\CombResearch\data\_superseded\phase3a\` (70 files).

| Step | Command (`run.wl ...`) | Result | Wall |
|---|---|---|---|
| 1 | `mh cells "2,4;2,5;2,6;3,4;3,5" targets vertex force` | 5 post-fix chains | 69–110 s each |
| 2 | `mh cells "2,7;3,6;4,4" jobs 2` | 9 new chains | 35 min (facet 11–12, unlabeled 7–8, vertex 2–3 min each) |
| 3 | `mh cells "2,4" targets unlabeled,facet force jobs 2` | 200k replaces 30k smoke | 8.4 min |
| 4 | `ecgrav sampler mcmc force jobs 1` | 27 files | 2 h 53 min (unlabeled 2 h 33 min) |
| 4 | `ecgrav sampler exact force jobs 2`, `legacyfacet force` | 27 + 2 files | 15.6 min, 2 min |
| 5 | `validate force`; `validate sampler legacyfacet force` | all summaries rewritten | 3.2 min |
| 6 | `figures` (Figure 2); `render_truth_overlay`, `render_3way`, `render_ecgrav_compare` directly | see below | ~10 min |

- **Validation:** `mh`, `ecgexact`, `ecgmcmc` each 27/27 PASS (L1 < 0.05);
  worst L1 0.029 (MH (4,5) facet), 0.011 (exact), 0.021 (MCMC). Legacy
  facet (negative control) fails as intended, L1 0.22. Counters match truth.
  (3,5) vertex rerun vs the May `.bak`: L1 0.010. `validate` warns that MH
  inputs mix ECGrav commits (16 new on 474b5c2, 11 backfilled M2/M5 chains);
  expected.
- **Golden/derived:** re-baselined `compare`, `efficiency`, `overlay`,
  `samplecols`, `validate` (inputs changed); `ishists`, `progress_csv`,
  `q10_p2/p3/p4`, `truth` unchanged and PASS. `fig2_check` PASS.
- **Store:** `run.wl status` and the backfill dry run flag only the q=10
  pilot chains (M6, M7) and the external Betre `.mx` files.
- **Licence:** the Wolfram MCP servers (one kernel per Claude session) hold
  licence slots. With 5 of them open, `jobs 4` failed 2 jobs within 5 s
  with empty logs; keep `run.wl` plus jobs at ≤ 5 kernels in that state.
- **Not done / follow-ups:**
  - Fixed in this PR: `render_3way.wl` PNG export failed in 15.0.1
    (`ChartLegends -> Placed[..., Top]` stretched panels to ~2800 px;
    `Rasterize::bigraster`) while printing "wrote". Now `Legended`, and a
    failed export exits 1; PNG re-rendered.
  - `comb_paths.wl` falls back to the worktree when `git` fails ("git not
    available"); this happened once in a golden subprocess (the section then
    found no inputs and exited 2). A failing fallback would be safer.
  - `backfill_manifest.wl` keeps M1/M3 rows with `smoke`/`knownBad`; they
    now only match files with real manifests, so nothing is written.

## Phase 3: `run.wl`, golden/quick, `render_fig2.wl` (2026-11-21, Ryzen, branch `claude/phase-3`)

Next: Phase 3a (regenerate the flagged data with `run.wl`; commands and
order in `docs/architecture/implementation-plan.md`), then Phase 4.

- `run.wl` (repo root): stages `check truth is mh ecgrav validate figures
  status all`; words `profile cells targets sampler jobs force dryrun`
  (plain words: wolframscript drops `-` arguments). Default profile `paper`.
  Launches the existing drivers with `COMB_*` env; one process per
  cell×target (MH), sampler×target (ECGrav), p×batch (q=10 IS); at most
  `jobs N` (default 4); launcher log names, so `monitor_mh.ps1` and
  `monitor_ecgrav.ps1` work unchanged (checked on a live run).
  - Skip rule (guarantee 2): runs only when an output is missing; `force`
    for one named stage, never `all`. Done = exit 0, no `$Aborted` in the
    log, and every output it should write is newer than its start.
  - Safety: per-job identity knobs always from run.wl, leftover
    `COMB_FORCE`/`COMB_MH_OUTDIR`/identity env ignored (case-insensitive);
    `<log>.lock` taken atomically, rechecked at start, released only by its
    owner, released (and children killed) on abort; force refused for
    finished q=10 batches; McKay output awaiting rename skipped; partial IS
    cells held back; restricted validate skips global-summary writers;
    malformed `cells`/`sampler`/`targets` words exit 2.
  - `check`: ECGrav update (unless `COMB_ECGRAV_DIR`), regression decided
    after the update, smoke tests, store report. `status`: store report
    (manifests, stale/backfilled/flagged files).
  - `validate` warns when one kind of input (MH chains, ecgexact, ecgmcmc,
    IS hists) mixes ECGrav commits, from the manifests (guarantee 6). Quiet
    on today's store; Phase 3a's new MH chains will make it warn until the
    old chains are rerun too. `CLAUDE.md` maps the cells, targets and
    sampler words to each stage's knobs (guarantee 3).
- `src/render_fig2.wl`: Figure 2 (p=3, q=3) as a script of the two
  reference notebooks (untouched). Data `data/p3q3_n10000_fig2.wxf`
  (manifest), panels `figures/fig2/`. Sample drawn before subkernels launch,
  so the seed reproduces it (two runs identical). In `run.wl figures`.
- Tests: `tests/run_wl_test.wl` (own temp root; ~5 min, two real runs),
  `tests/golden/golden_quick.wl` + `tests/golden/quick/truth.wxf`,
  `tests/fig2_check.wl`. `lib_names`: family `fig2`, MH log name with tag,
  `"job"` log family. `pure_simplicial_compute.wl`: `COMB_CHUNK` knob
  (unset = 25000, as before).
- Plan doc: Phase 3 CLI in plain words, "as built" notes, Phase 3a (the
  data fixes with commands and measured wall times).
- Reviews: three adversarial workflow rounds over run.wl and the tests
  (5 lenses, 3 refuters per finding). Round 1: 31 findings = 13 issues, all
  fixed. Round 2: 9/13 fixes confirmed, 4 incomplete + 10 new, all fixed.
  Round 3: 7/9 confirmed, the 2 partial ones (lock race with a McKay
  rename; relative `COMB_ECGRAV_DIR`) and 2 new nits fixed.
- Checks run (scratch roots, `COMB_ECGRAV_DIR` = shared clone; nothing
  written to the store):
  - `run.wl all profile quick` from an empty store, 4 times as the code
    changed: all stages ok (~12 min); `golden_quick` PASS each time (truth
    exact; exact 0.015-0.028, ecgmcmc 0.029-0.067, MH 0.025-0.106, IS
    vertex 0.014-0.021); `fig2_check` PASS (class table and theory exact,
    enumeration = formula; panels within ESS-based bounds).
  - `run_wl_test`, `lib_names_test`, `lib_config_test`, `manifest_test`: PASS.
  - `run.wl all dryrun` on the real store: plans only the 9 missing MH
    chains ((2,7) (3,6) (4,4)), `validate mh` (never stored) and Figure 2.
  - Final code: `run.wl all profile quick` from an empty store ok,
    `golden_quick` and `fig2_check` PASS; a second `all` on the same store
    started only the jobs that write no data file (check, counts), no data
    job reran. Under `quick` the regression runs every `check`: its
    restricted cells are never recorded as a pass (existing regression rule).
- Not done: Phase 3a; the stale-report CSV in `results/`; `run.wl` cannot
  change `COMB_NN_FIXED`/`COMB_FIG2_N` (run the driver directly for those).

## Phase 2 complete: exit checks (2026-11-21, Ryzen, main @ `459924d`)

The plan's Phase 2 checks, rerun after 2a-2d plus the `.gitignore` fix
(#20-#24) were all merged, in a fresh scratch root (`make_check_root.wl
... golden`, `COMB_ECGRAV_DIR` = shared clone). All pass:

| Check | Result | Wall |
|---|---|---|
| `test_streaming.wl` | ALL PASS | 41 s |
| `test_streaming_bliss.wl` | all gates pass (5 default cells incl. (3,5)) | 17 min |
| `test_streaming_mckay.wl` | all correctness gates pass | 67 s |
| `run_p3.wl` `COMB_N=200` | runs clean | 14 s |
| `lib_names_test`, `lib_config_test`, `manifest_test` | PASS | 44 s |
| `golden/derived` check | all 11 sections ok (compare, efficiency, ishists, overlay, progress_csv, q10_p2/p3/p4, samplecols, truth, validate) | 36 min |

`q10_p4` peaks at 7.7 GB. `validate` prints `General::munfl` underflow
warnings; they do not change any record.

Next: Phase 3 (`run.wl`). Its CLI must use plain words or env, not
`--flags` (wolframscript drops them). The main checkout at
`C:\CombResearch` is behind `origin/main` until it is pulled; until then it
still shows the 147 manifests as untracked.

## Phase 2d: per-output manifests + backfill (2026-11-21, Ryzen, branch `claude/phase-2d`)

Phase 2 is complete with this. Next: Phase 3 (`run.wl`).

- `src/lib_io.wl`: `exportWxfAtomic[path, expr, extra]` now also writes
  `<file>.manifest.wl` (atomic, one per output): file, bytes, sha256,
  writtenAt, script, code commit + dirty flag (or a `VERSION` file),
  ECGrav commit/version/dir, `$Version`, `$SystemID`, kernel count, session
  time, profile, every `combSetting` resolved so far with its source, plus
  `extra`. `extra = None` skips it (IS chunks only). `combManifest[path]`
  reads one. A failed manifest write warns instead of aborting, so a long
  run keeps its remaining cells.
- Writers: truth, MH, ECGrav and final IS files already used
  `exportWxfAtomic`. Switched from plain `Export`: `concat_samples` (records
  `"inputs"`), `precompute_is_histogram(s_q10)` (inputs), `run_is_at_truth_cells`
  (seed rule), the 4 compare summaries and the validation summary. These are
  now atomic too, so a crash no longer leaves a half-written merged file;
  the merge needs room for one extra merged file while it writes.
  `pure_simplicial_compute` records its seed rule, offset, runTag, N, chunk.
- `tools/dev/backfill_manifest.wl` (dry run by default; `write`, `write
  force`): provenance table from `provenance.md` as data (rows T1-B1, most
  specific first), embedded small keys from files up to 300 MB, sha256.
  Each manifest gets `backfilled -> <|at, tool, toolCommit, provenanceId|>`
  and `provenance -> <|..., status|>` (`ok`, `knownBad` = the 5 pre-fix
  vertex chains, `smoke`, `negativeControl`, `usesKnownBad` =
  sampler_efficiency_summary, `external` = Betre .mx). Never replaces a
  real-run manifest. **Dry run on the store: all 147 files match a row;
  nothing written.**
- `make_check_root.wl` family `manifests`; `lib_names_test.wl` skips
  `*.manifest.wl` and `*.tmp`.
- Finding: wolframscript drops every script argument from the first one
  that starts with `-`. The backfill takes plain words; Phase 3's planned
  `run.wl --profile quick` syntax has to change (plain words or env).
- `tests/manifest_test.wl` (new, own temp `COMB_ROOT`).
- Checks run (scratch `COMB_ROOT` reused from 2b/2c, `COMB_ECGRAV_DIR` =
  shared clone; nothing written to the store):
  - `tests/manifest_test.wl`, `lib_config_test.wl`, `lib_names_test.wl`: pass.
  - Backfill dry run on the real store: 147/147 files matched a row.
  - Backfill `write` in the scratch root: 128 manifests in 66 s; a second
    dry run keeps all 128. The 5 files with no row are smoke-run artifacts.
  - Writers run in the scratch root: `enumerate_truth` (2,4),
    `run_mh_chains` (2,4) facet, `run_ecgrav_samplers` (2,4) vertex,
    `run_is_at_truth_cells` (3,5), `run_p3.wl` (`COMB_RUNTAG=smoke2d`,
    N=200), the 4 compares, `validate_mh_vs_truth`,
    `precompute_is_histograms_q10` (`COMB_FORCE=1`). Each left a real-run
    manifest replacing the backfilled one: sha256 matches, ECGrav
    `474b5c2` where loaded, kernels 16 for parallel runs, settings with
    sources, seeds/inputs where given. No chunk manifests, no `.tmp` left.
  - One `compare_3way.wl` run exited with "The product exited because an
    error occurred" after writing its summary and manifest; 3 reruns and
    10 bare-kernel exits did not reproduce it. Seen once, cause unknown.
  - `kernelCount` no longer calls `Kernels[]` unless the parallel package
    is loaded (it cost 1.4 s per script and loaded Parallel for nothing).
- **Store backfilled 2026-11-21** (after #23 merged, from `ee8ea86`, with
  the user's go-ahead): `backfill_manifest.wl write` wrote 147 manifests to
  `C:\CombResearch\data` (incl. 4 in `q10_pilot_archive/`). Verified: every
  sha256 and size matches its file, no `.tmp` left. Status counts: ok 124,
  smoke 11, knownBad 5 (the pre-fix vertex chains), external 4 (Betre
  .mx), negativeControl 2, usesKnownBad 1. No existing file was changed.
  `.gitignore` now ignores `data/**/*.manifest.wl`; before that the
  manifests showed as untracked in the main checkout.
- Data fixes still open (from `provenance.md`): rerun the 5 `knownBad`
  vertex chains (or restore the (3,5) `.bak`), run MH at (2,7) (3,6)
  (4,4), rerun ecgmcmc then ecgexact on latest ECGrav. A rerun replaces
  the backfilled manifest with a real one.

## Phase 2c: `lib_config.wl` + `config/cells.wl` (2026-11-20, Ryzen, branch `claude/phase-2c`)

Last in Phase 2: per-output manifests + `tools/dev/backfill_manifest.wl`
(2d). Then Phase 3 (`run.wl`), which reads the run plans below.

- `src/lib_config.wl`: `combSetting[name, default, kind]` returns the
  non-empty env var, else the value in the profile `COMB_PROFILE` names,
  else the script default. With no `COMB_PROFILE` nothing changes
  (guarantee 3). Kinds reproduce the old inline parsers: `string`, `expr`,
  `cells`, `list`, `intList`, `flag` (`COMB_FORCE`), `notFalse`
  (`COMB_TRUTH_PARALLEL`), `notZero` (`COMB_IS_PAR`). Every resolved setting
  is recorded in `$CombSettings` with its source (`combPrintSettings[]`); an
  env var overriding a profile value prints a warning. An unknown profile or
  kind aborts.
- `config/cells.wl`: profiles `paper` and `quick`. Each has flat
  `"settings"` (knob -> value, for single-invocation scripts) and run plans
  for `run.wl`: `truthRuns` (pipeline/parallel per cell group: cheap for
  the 7 small cells, McKay sequential for (4,4) (4,5)), `isBatches`
  (`{runTag, N, chunk}` per p; batch3 has no p=2), `mhChains` (incl. the
  (4,5) and q=10 per-target fan-out and the 4 warm chains), `ecgravRuns`.
  `paper` values come from the launchers and `provenance.md`. `quick` is a
  few-minute (2,4)+(3,4) profile; its outputs share paper names, so only
  in a fresh clone or scratch root.
- Switched to `combSetting` (knob names unchanged): `compare_3way`,
  `compare_is_mh_q10`, `compare_samplers_efficiency`, `enumerate_truth`,
  `precompute_is_histograms_q10`, `pure_simplicial_compute` (`*Override`
  still wins), `render_truth_overlay`, `run_ecgrav_samplers`,
  `run_is_at_truth_cells`, `run_mh_chains`, `run_p{2,3,4}`,
  `validate_counts_vs_truth`, `validate_mh_vs_truth`,
  `tests/ecgrav_regression`. Left on raw `Environment`: `COMB_ROOT`,
  `COMB_ECGRAV_DIR` (read before lib_config loads) and the `COMB_TEST_*`
  knobs of `test_streaming*.wl`. The `.ps1` launchers are unchanged.
- `tests/lib_config_test.wl` (new, read-only): 20 kind cases against copies
  of the old parsers, unset/empty fall-through for every kind, precedence and
  sources through child kernels with `COMB_PROFILE=quick`, unknown
  profile/kind abort, and the shape of both profiles.
- Checks run (all pass; scratch `COMB_ROOT` reused from 2b,
  `COMB_ECGRAV_DIR` = shared clone; nothing written to the store):
  - `tests/lib_config_test.wl`, `tests/lib_names_test.wl`; `SyntaxQ` on
    all 19 changed `.wl` files.
  - The 20 Phase 2b smoke steps rerun with no profile; the printed
    settings in each log are identical to the 2b logs. The only differences
    are the git sha in `samplerVersion`/`enumeratorVersion`, timings, two
    steps that skip because their 2b output exists, and
    `validate_mh_vs_truth` ecgexact failing (2,4), because the 2b
    `run_ecgrav_samplers` step had replaced the scratch (2,4) ecgexact
    files with N=400 samples (data, not code).
  - `COMB_PROFILE=quick`: `validate_mh_vs_truth` resolves cells
    `{{2,4},{3,4}}` from the profile; `run_ecgrav_samplers` with
    `COMB_ECG_N`/`COMB_ECG_CELLS` set prints the override warnings and uses
    the env values.
- Not done here: the quick profile end to end (needs `run.wl`, Phase 3;
  `golden/quick` waits for it). Validation under `quick` in a scratch root
  that holds paper data fails as expected, since it reads whatever chains
  are there.

## Phase 2b: `lib_names.wl` (2026-11-20, Ryzen, branch `claude/phase-2b-371047`)

Next in Phase 2: `lib_config.wl` + `config/cells.wl`, then manifests +
`backfill_manifest.wl`.

- `src/lib_names.wl`: `combName[family, args...]` (bare name) and
  `combFile[...]` (path under `$CombDataDir`, or `$CombLogsDir` for
  `"log"`/`"err"`), plus `combISStem`, `combMergedStem`, `combMHWarmTag`,
  `combISStatsPattern`. Families: truth (with pipeline), mh (with tag), ecg,
  samples (validate/efficiency source), isHist, isStats/isComplexes,
  isChunk*, isSamplesCSV, validationSummary, summary, and the launcher log
  names (mh, mhQ10, ecg, compute). Every name is today's flat name; a call
  matching no family aborts.
- 20 scripts switched from hand-built `"p" <> ToString[p] <> ...` names:
  `compare_3way`, `compare_is_mh_q10`, `compare_q10_warm_vs_prod`,
  `compare_samplers_efficiency`, `concat_samples`, `enumerate_truth`,
  `precompute_is_histogram(s_q10)`, `pure_simplicial_compute`,
  `render_3way`, `render_all_figures`, `render_q10_is_vs_mh`,
  `render_q10_warm_vs_prod`, `render_sampler_progress`,
  `render_truth_overlay`, `run_ecgrav_samplers`, `run_is_at_truth_cells`,
  `run_mh_chains`, `validate_counts_vs_truth`, `validate_mh_vs_truth`,
  `tests/ecgrav_regression`. Scripts with their own output dir
  (`COMB_MH_OUTDIR`, `outputDir`) keep it and use `combName`.
- Left alone: `migrate_csv_to_wxf.wl` (parses legacy CSV names),
  `probe_betre_mx.wl` (fixed Betre `.mx` names), figure file names, and the
  `.ps1` launchers/monitors (their log names match the "log" family; Phase 3
  `run.wl` will use `combFile["log", ...]`).
- `tests/lib_names_test.wl` (new, read-only): 36 literal cases; every file
  in the store whose name has a family's shape is parsed and rebuilt
  (138 data files, 51 logs, all identical); unknown calls abort.
- Checks run (all pass; scratch `COMB_ROOT` from `make_check_root.wl ...
  golden`, `COMB_ECGRAV_DIR` = the shared clone, nothing written to the
  store):
  - `tests/lib_names_test.wl`, against the real store.
  - Read-only drivers rerun: summaries from `compare_is_mh_q10`,
    `compare_q10_warm_vs_prod` are `===` the stored ones (except
    `createdAt`). `compare_3way` matches except the (3,5) vertex row,
    which now reads the pre-fix chain in the store (`mhAccept` 1.0; the May
    summary used the good chain). `validate_mh_vs_truth` ecgexact differs only
    in the unseeded `iidPValue`.
  - Run clean: `validate_counts_vs_truth` (0 mismatches),
    `validate_mh_vs_truth` (mh), `compare_samplers_efficiency` (2,4)+(3,5),
    `render_3way`, `render_q10_is_vs_mh`, `render_q10_warm_vs_prod`,
    `render_truth_overlay`, `render_sampler_progress`,
    `precompute_is_histograms_q10` (finds and skips all 9 existing hists).
  - Writers, at small size: `enumerate_truth` (2,4) cheap (equal to the store
    except provenance fields) and mckay (`p2q4_truth_mckay.wxf`),
    `run_mh_chains` (2,4) and with `COMB_MH_TAG=_seed67890_warm5`,
    `run_ecgrav_samplers` (2,4) N=400, `run_is_at_truth_cells` (3,5) N=600,
    `run_p3.wl` `COMB_N=200` (`p3q10_n200_{stats,complexes}.wxf`),
    `tests/ecgrav_regression.wl` (2,4).
  - Not run: `concat_samples`, `render_all_figures`,
    `precompute_is_histogram` (each loads 0.3-2.8 GB merged stats); their
    names are covered by the test's literal cases and store round trip.
- Gotcha found: a script that `Abort[]`s still exits 0 from wolframscript,
  and in a scratch root without `ECGrav-upstream` every ECGrav-loading
  script aborts. Set `COMB_ECGRAV_DIR=C:\CombResearch\ECGrav-upstream` for
  scratch-root checks and grep logs for `no ECGrav at`.

## Phase 2a: shared stats/io libraries + fixes (2026-11-20, Ryzen, branch `claude/phase-2-6f3995`)

Phase 2 is split into PRs: **2a** (this), then `lib_names.wl`,
`lib_config.wl` + `config/cells.wl`, and manifests + `backfill_manifest.wl`.

- `src/lib_stats.wl`: `statsFor` and its helpers moved verbatim from
  `pure_simplicial_compute.wl`, plus `$CombStatsHeaders` (12 columns) and
  `$CombISHeaders` (+ 3 weights). Loads ECGrav via `load_ecgrav.wl`.
- `src/lib_io.wl`: `exportWxfAtomic` (one copy instead of two).
- `pure_simplicial_compute.wl`, `enumerate_truth.wl`, `run_mh_chains.wl`,
  `run_ecgrav_samplers.wl` `Get` the libs; the three drivers no longer
  `Block`-`Get` the IS script.
- Fixes: `enumerate_truth.wl` records `$CombECGravVersion` instead of the
  hardcoded `"1.0.0"`; `render_ecgrav_compare`, `render_sampler_progress`,
  `render_uniformity_check` load `sampler_mh.wl` from their own folder
  instead of cwd-relative `src/`; `comb_paths.wl`/`.ps1` repo-marker guard
  (git root used only if it holds `src/comb_paths.wl`).
- Checks run (all pass; scratch `COMB_ROOT`, nothing written to the store):
  - `DownValues` of the 6 moved functions, `headers` and `exportWxfAtomic`
    are `===` to HEAD's (`398baaf`) `pure_simplicial_compute.wl`.
  - New `statsFor` reproduces the stored stats of all 10,882 truth classes
    (9 cells), 0 mismatches.
  - `test_streaming`, `test_streaming_bliss`, `test_streaming_mckay`: pass.
  - `enumerate_truth.wl` (2,4)+(3,4): gates pass; (2,4) WXF equals the
    stored one except provenance fields; `ecGravVersion` = `1.18.0-474b5c2`.
  - `run_mh_chains.wl` (2,4) 4k iters, `run_ecgrav_samplers.wl` (2,4) N=400,
    `run_p3.wl` `COMB_N=200` (16 kernels): run clean, schemas as before.
  - Repo-marker guard: inside an unrelated git repo both `comb_paths.wl` and
    `.ps1` fall back to the unpacked folder; from a worktree they still
    give `C:\CombResearch`.
  - `golden/derived` check in a scratch root (see PR).
  - `render_ecgrav_compare`, `render_sampler_progress`,
    `render_uniformity_check`, launched from a folder outside the repo with
    a scratch `COMB_ROOT`: all load `sampler_mh.wl`, run clean, and write
    their 3 PDF+PNG pairs (MH facet L1 0.019; ECGrav legacy facet 0.43, the
    expected negative control).

## Phase 1: latest upstream ECGrav (2026-11-20, Ryzen, branch `claude/phase1-ecgrav-upstream`)

- Shared clone `C:\CombResearch\ECGrav-upstream` (gitignored), made and
  updated by `tools/dev/update_ecgrav.wl`; currently upstream main 474b5c2,
  the same code as the old vendored 1.18.0 snapshot.
- `src/load_ecgrav.wl` loads `COMB_ECGRAV_DIR` or the shared clone, sets
  `$CombECGravCommit`/`$CombECGravVersion`, checks the 13 ECGrav functions
  we call, and warns until the commit passes the regression.
- `tests/ecgrav_regression.wl`: counters, aut/autF (all 10,882 classes) and
  exact samplers (N=20k) vs the 9-cell truth grid, plus an MH smoke test at
  (2,4). **Passed on 474b5c2** (exact L1 0.007-0.022; MH 0.014-0.045), so the
  1.18 pin question is closed. The record is in `C:\CombResearch\results\`.
- Vendored `ECGrav/` (1.0.0, 1.17.0, 1.18.0-474b5c2, BuildingAndInstalling
  Paclets.nb) removed; they are in history at tag `pre-restructure`.
  `COMB_ECGRAV_VERSION` is gone. `install_ecgrav_global.wl` installs the
  shared clone, for notebooks only.
- `$CombResultsDir` (`results/`) added to `comb_paths.wl`/`.ps1` and the
  sync script.
- The "Ryzen PC setup checklist" below is superseded wherever it talks about
  vendored snapshots or re-validating the pin: run `update_ecgrav.wl`, then
  the regression.

## Phase 0 safety net (2026-11-20, Ryzen, branch `claude/codebase-update-plan-fac1d9`)

Done (uncommitted):
- `docs/architecture/provenance.md`: how every data family was made (script,
  commit, date, ECGrav, seed, N), plus the problems found and the corrected
  regeneration list.
- `tools/dev/make_check_root.wl`: scratch `COMB_ROOT` for checks. It copies
  files up to 300 MB and hard-links larger ones. Family `golden` = every
  input of the golden reference.
- `tests/golden/`: golden/derived, 11 sections (truth, samplecols, ishists,
  validate, compare, efficiency, overlay, q10_p2/p3/p4, progress_csv), frozen
  in `tests/golden/derived/*.wxf`. The README explains how to use it.
  golden/quick waits for the quick profile (Phase 2/3).

Data findings (not fixed; need a decision):
- The live `p2q{4,5,6}` and `p3q{4,5}` `_mh_vertex.wxf` predate the vertex
  fix (acceptRate 1.0).
- The good (3,5) chain is only `p3q5_mh_vertex.2026-05-17.wxf.bak`.
- No MH exists at (2,7), (3,6) or (4,4); it was lost with worktree
  optimistic-fermi.
- `is_mh_truth_3way_summary` no longer reproduces at (3,5) vertex.

Not done: the `pre-restructure` tag on `main`, and the commit/PR.

## Worktree and Codex cleanup (2026-11-20, Ryzen PC, after #14)

Done:
- Codex worktree `C:\Users\darth\.codex\worktrees\a514\CombResearch`
  (branch `codex-docs-code-cleanup`) audited, then removed with its branch:
  - Its one commit (3f806a9) is patch-identical to PR #11 on main.
  - Its 6 modified `logs/mh_p4q5_*` files were a failed relaunch (empty `.log`,
    `.err` = WolframScript config-file error) that truncated the real logs;
    main's tracked logs are the real 2026-05-15 production run.
  - Its 3 `data/p4q5_mh_*.wxf` (2026-05-16) were broken runs: facet and
    unlabeled have acceptRate 0 and a constant numV step over 200k
    iterations (2 s wall); vertex has no sampler commit and L1 = 2.0 vs
    truth (disjoint support). Main's p4q5 MH WXFs are the validated
    2026-05-15 chains (sampler_mh.wl@7143104). The temporary copies in
    `data/_from_worktrees/` and `logs/_from_worktrees/` were deleted.
  - Codex app state in `~/.codex` (sessions, memories, config) was left
    alone; its memory and goal stores hold nothing about this project.
- Removed the merged Claude worktrees `crazy-dhawan-f7fd60` and
  `determined-morse-e55578` (both clean; sync dry run: nothing missing in
  main). An empty `determined-morse-e55578` folder may remain while a
  process holds it; delete it later.
- Deleted 8 stale local branches; each was in main or identical to the
  head of its merged PR (#1, #7, #8, #10, #12, #13).
- Committed the May Phase 4c outputs that were never tracked:
  `figures/is_vs_mh/*` (7) and `logs/mh_q10_*.log` (18). Deleted
  `data/q10_pilot_archive/p4q10_mh_unlabeled_smoke1k_DELETE_ME.wxf`.
- `.gitignore`: `data/**/*.wxf`, `data/**/*.wxf.bak`, `data/**/*.csv`, so data
  in subfolders (`data/q10_pilot_archive/`, backups) is ignored too.

Not done: deleting the merged remote branches on GitHub
(`claude/crazy-dhawan-f7fd60`, `claude/ecgrav-new-samplers-testing-b1ea3c`,
`claude/github-pull-review-a3e9d6`).

## One shared output location (2026-11-20, Ryzen PC)

**Goal:** all generated data/figures/logs live once, in the main checkout
(`C:\CombResearch`), whichever worktree runs the script.

Why: `data/*.wxf` is gitignored (~9 GB, too big for git), and about half the
scripts built paths from their own checkout. On the Ryzen the truth grid and
all 59 Phase 5a ECGrav sampler WXFs existed only in the
`ecstatic-wiles-75960d` worktree; the main checkout had only 2 of 9 truth
files.

Done:
- Main checkout fast-forwarded 955238d -> 83a4b60. Its staged figure renames
  were identical to the ones already on main.
- Copied the 123 data files from the `ecstatic-wiles-75960d` worktree into
  `C:\CombResearch\data` (byte-verified). Main now has all 9 truth cells +
  `p4q4_truth_mckay` and all Phase 5a `*_ecg*` WXFs. The older
  `p3q5_mh_vertex.wxf` (May 17) is kept as `p3q5_mh_vertex.2026-05-17.wxf.bak`;
  the Sep 25 one replaced it. Other Claude worktrees had nothing missing.
- The Codex worktree's different May 16 `p4q5_mh_{facet,unlabeled,vertex}.wxf`
  and its modified `mh_p4q5_*` logs are in
  `C:\CombResearch\{data,logs}\_from_worktrees\CombResearch\`. Codex cleanup is
  the next task.
- New `src/comb_paths.wl` / `src/comb_paths.ps1`: output root = parent of
  `git rev-parse --git-common-dir` (the main checkout), `COMB_ROOT` overrides.
  All 24 scripts and 8 launchers that touch `data/`, `figures/` or `logs/`
  now use `$CombDataDir` / `$CombFiguresDir` / `$CombLogsDir`. Hardcoded
  `C:/CombResearch`, checkout-relative `projectRoot/data` and cwd-relative
  `"data/..."` paths are gone. Launchers run code from `$PSScriptRoot`
  (`run_q10_mh_overnight.ps1` no longer points at the crazy-dhawan worktree).
- New `src/sync_worktree_data.ps1` (safety net, never overwrites or deletes;
  differing files go to `<dir>\_from_worktrees\<worktree>\`). Runs from the
  committed `.claude/settings.json` on Claude Code SessionStart and
  SessionEnd; `.gitignore` now ignores `.claude/*` except `settings.json`.
- `AGENTS.md`: "Generated outputs" section, coding rule, and a git rule that
  commits/PRs must list outputs written to the main checkout.
- `src/pure_simplicial_figures.nb` loads `comb_paths.wl` when it sits in
  `src/` (falls back to `../data/`, then the notebook folder for the
  zip-alongside-CSVs layout).
- Other machines / fresh clones: `comb_paths` creates missing
  `data/`, `figures/`, `logs/`, and handles git < 2.31 (relative
  `--git-common-dir`). `validate_counts_vs_truth.wl` and
  `validate_mh_vs_truth.wl` now end with a list of missing input files and
  the command that generates them, instead of a summary that looked like a
  pass; `validate_mh_vs_truth.wl` no longer overwrites its summary WXF when
  nothing was validated.

Checked 2026-11-20 on the Ryzen, running from the worktree:
- `comb_paths.wl` resolves to `C:\CombResearch` (sees a main-only probe
  file), is idempotent, and honors `COMB_ROOT`; `comb_paths.ps1` agrees.
- All 25 edited `.wl` files parse; all 10 `src/*.ps1` files parse.
- `sync_worktree_data.ps1 -DryRun` found exactly the 3 Codex conflicts and
  119 files already in main; `-Quiet` (the hook command) is silent and exits 0.
- `COMB_VAL_CELLS="2,4;3,4;4,4" validate_counts_vs_truth.wl`: all match on
  ECGrav 1.18.0-474b5c2.
- `COMB_VAL_CELLS="3,5" COMB_VAL_SOURCE=ecgexact validate_mh_vs_truth.wl`:
  PASS, L1 0.005-0.006, reading the Phase 5a (1.17.0) samples from main. It
  overwrote main's 27-cell `validation_ecgexact_summary.wxf`; restored from
  the worktree's identical Sep 26 copy.
- Fresh standalone clone of this branch with no data (only the 4 tracked
  `.mx` files), where `comb_paths` resolves to the clone itself:
  - With no truth, both validators now name the missing files and the
    generating command, and write no summary WXF.
  - `COMB_ROOT` set to an empty folder: `data/`, `figures/` and `logs/` are created.
  - Generated from scratch: `enumerate_truth` (2,4),(3,4) (gate 66 ok),
    `validate_counts` all match, `run_ecgrav_samplers` exact N=20000,
    `validate_mh_vs_truth` ecgexact 6/6 PASS (L1 <= 0.017), `run_mh_chains`
    (2,4), `render_truth_overlay` (60 panels, 33 previews into the clone's
    `figures/`), `test_streaming_mckay` gates pass.
  - MH (2,4) at a cut-down 20k iterations failed unlabeled (L1 0.060); rerun
    at the default 200k it passes (L1 0.0167). It was chain length, not paths.
- `pure_simplicial_figures.nb` setup cell, run as if opened from the
  worktree, resolves `dataDir` to `C:\CombResearch\data`.
- Not checked: the hook firing in a new session (needs a new session), the
  q=10 render scripts end to end, and the laptop.

Outputs written to the main checkout by this work (not in the commit): the
data copies above, `data/_from_worktrees/`, `logs/_from_worktrees/`.

Still untracked in the main checkout from May (Phase 4c runs): 7
`figures/is_vs_mh/*`, 18 `logs/mh_q10_*.log`, `data/q10_pilot_archive/`
(includes a `*_DELETE_ME.wxf` smoke file). Commit the figures/logs from main.

## ECGrav dist consolidation (2026-11-18)

**Goal:** every script uses one ECGrav distribution.

Done:
- Upstream github.com/kassabetre/ECGrav main @ 474b5c2 (2026-11-11, v1.18.0
  + 19 commits) vendored at `ECGrav/ECGrav-1.18.0-474b5c2/`. Its `Kernel/` is
  byte-identical to upstream (CR-insensitive diff). It is now the default in
  `src/load_ecgrav.wl`.
- All 11 scripts that used a bare `Needs["ECGrav`"]` now `Get`
  `load_ecgrav.wl`: `enumerate_truth`, `pure_simplicial_compute`, three
  `render_*` scripts, `run_is_at_truth_cells`, `sampler_mh`,
  `streaming_enumerator{,_bliss,_mckay}` and `test_streaming`.
  `load_ecgrav.wl` is now idempotent.
- The three `ParallelEvaluate[Needs["ECGrav`"]]` calls are now
  `combLoadECGravOnKernels[]`. Previously subkernels silently loaded the
  installed paclet.
- Removed the `COMB_ECGRAV_MAIN` switch from `pure_simplicial_compute.wl`.
  nnFixed mode works on the pinned dist.
- Moved `ECGrav/ECGrav-main` to `archive/ECGrav-v1.1.0-snapshot/`. Despite
  its PacletInfo saying 1.0.0, it was upstream v1.1.0 (cb2dd35).
- Provenance check: `ECGrav-1.0.0` = upstream v1.0.0 and `ECGrav-1.17.0` =
  upstream v1.17.0, both byte-identical. Both are kept and selectable with
  `COMB_ECGRAV_VERSION`.
- Changes 1.17.0 -> 474b5c2 that matter here, from the upstream CHANGELOG:
  - Unlabeled exact sampler 4-230x faster per sample.
  - Facet-labeled sampler free-n setup 25x faster.
  - MCMC no longer starts a replica in the disjoint-facets trap.
  - MCMC usage text no longer promises independent samples, and the result
    gains `"effectiveSampleSize"` keys. These answer our validation note.
  - Upstream says sampler distributions are unchanged. API changes to the
    14 functions we call are additive only.
  - Seeded runs of the unlabeled sampler and the MCMC may differ from Phase 5a.

Checked 2026-11-18 on the i5-14500T laptop (Wolfram 15.0.1, no truth WXFs here):
- Static: no bare `Needs["ECGrav` remains in `src/*.wl` outside
  `load_ecgrav.wl`, the vendor diff is empty, and the diff was reviewed.
- Smoke test:
  - The loader picks up 1.18.0-474b5c2, and a second load is a no-op.
  - `combLoadECGravOnKernels[]` gives both subkernels the new snapshot.
  - `NumUnlabeledPureComplexes` totals match truth: (2,4)=11, (2,5)=26,
    (3,4)=66, (4,4)=278, (4,5)=5532.
- `src\test_streaming_mckay.wl`: all gates pass. Cheap, bliss and mckay agree
  at (2,4)=11 and (3,4)=66.
- Unlabeled exact sampler at q=10, after one-time setup:
  - (4,10): 0.015 s/sample (1.17.0 pilot: 3.9 s). Setup is ~85 s per
    process, paid on the first draw.
  - (3,10): 0.004 s/sample (1.17.0: 0.49 s). Setup is ~9 s.
- Not checked: the distribution re-validation (needs truth WXFs, on the
  Ryzen PC).
- `src/reference/` notebooks still use `ParallelNeeds["ECGrav`"]`, which loads
  the installed paclet; left unedited per the rules. To match, the laptop's
  global paclet was replaced 1.0.0 -> 474b5c2 with the new
  `src/install_ecgrav_global.wl`. A plain `Needs` and subkernel
  `ParallelNeeds` were both verified to resolve to it, and the (4,5) total
  is 5532.
- The Wolfram 15 "Services for AIs" option added a user-scope `Wolfram` MCP
  server to `~/.claude.json` on the laptop (a Wolfram kernel running
  AgentTools). It is kept global by user choice.

## Ryzen PC setup checklist (next session there, after pulling)

**Do this first on the Ryzen 7 5800X PC.** Its truth WXFs and Phase 5a
sample WXFs are untracked (`data/*.wxf` is gitignored), so they exist only
there. The laptop has done steps 2-3; nothing else here has run on the Ryzen.
Tick items off in this file and commit the results (handoff protocol).

1. **Pull.** Run `git status --short` first and keep any local work there
   (do not revert it). Then `git pull`. This brings in commits 98d4045
   (pinned loader) and baa6a3d (global-install script).
   - The `COMB_ECGRAV_MAIN` env switch and `ECGrav/ECGrav-main` are gone.
     Unset `COMB_ECGRAV_MAIN` / `COMB_ECGRAV_VERSION` if a shell or profile
     sets them, so the default pin is used.
2. **Wolfram.** `wolframscript -version` should report 15.0.1 (the pin needs
   15.0+). If `wolframscript` is not found, add
   `C:\Program Files\Wolfram Research\WolframScript` to PATH and open a new
   shell. Use `-file` scripts, not `-code`: PowerShell 5.1 strips quotes.
3. **Global paclet.** `wolframscript -file src\install_ecgrav_global.wl`.
   - Expect `installed ECGrav 1.18.0 (1.18.0-474b5c2)`. It uninstalls every
     other installed ECGrav. That is intended: Phase 4/5a reproduce through
     `COMB_ECGRAV_VERSION=1.0.0` / `1.17.0`, not the global paclet.
   - Needed only for notebooks, `src/reference/` and the Wolfram MCP server;
     scripts always `Get` the vendored snapshot.
4. **Wolfram MCP server (optional).** For Claude Code to use the Wolfram
   kernel on this PC, enable Wolfram's "Services for AIs" option. It adds a
   user-scope `Wolfram` server to `~/.claude.json` (laptop: done, kept
   global). It applies only to new Claude Code sessions. Its kernel loads
   the global paclet from step 3.
5. **Smoke test.** `wolframscript -file src\test_streaming_mckay.wl`. Expect
   `ECGrav loaded: 1.18.0-474b5c2` and all gates passing.
6. **Truth files present.** (2026-11-20: done; all 9 are in
   `C:\CombResearch\data`.) `data\p{p}q{q}_truth.wxf` for all 9 cells:
   (2,4) (2,5) (2,6) (2,7) (3,4) (3,5) (3,6) (4,4) (4,5). `p4q5_truth.wxf`
   is a copy of `p4q5_truth_mckay.wxf`. If any is missing, stop: the
   (4,5) re-enumeration took 17 h.
7. **Counters vs truth.** `wolframscript -file src\validate_counts_vs_truth.wl`.
   Expect every n on all 9 cells to match, as Phase 5a did.
8. **Back up the Phase 5a (1.17.0) exact-sampler outputs** before
   overwriting them. They are gitignored, so this copy is the only one. The
   WXF payload does not record the ECGrav version.
   ```powershell
   New-Item -ItemType Directory -Force data\phase5a_ecgrav-1.17.0
   Copy-Item data\p*q*_ecgexact_*.wxf, data\validation_ecgexact_summary.wxf data\phase5a_ecgrav-1.17.0\
   ```
9. **Exact-sampler campaign on the pin.** Without `COMB_FORCE=1` it skips
   every existing WXF and re-validates nothing.
   ```powershell
   $env:COMB_FORCE = '1'; powershell -ExecutionPolicy Bypass -File src\run_ecgrav_campaign.ps1; Remove-Item Env:COMB_FORCE
   ```
   - It runs 3 parallel processes, 100k samples each, all 9 cells.
   - Phase 5a wall time on 1.17.0: vertex and facet ~15 min each,
     unlabeled ~2 h 10 min. Unlabeled should be much faster now.
   - Monitor with `src\monitor_ecgrav.ps1`.
   - Check `logs\ecgexact_*.log` for `unmatched samples: 0`.
10. **Distribution validation.**
    ```powershell
    $env:COMB_VAL_SOURCE = 'ecgexact'; wolframscript -file src\validate_mh_vs_truth.wl
    ```
    Pass means all 27 cell x target L1 < 0.05. Compare against the Phase 5a
    backup: 1.17.0 ranged 0.006-0.030.
11. **Optional MCMC check.** Run the campaign with
    `$env:COMB_ECG_SAMPLER='mcmc'` (back up `*_ecgmcmc_*.wxf` first), then
    validate with `COMB_VAL_SOURCE=ecgmcmc`. This checks the trap fix and
    the new `"effectiveSampleSize"` keys. `compare_samplers_efficiency.wl`
    gives ESS/s.
12. **Record and commit.**
    - Put the results in this file.
    - In `CLAUDE.md`, replace "this pin is not yet re-validated" in the
      overview.
    - Note the Ryzen global install under Setup.
    - Commit and push in one commit.
    - Then move on to q=10 with the exact samplers as the reference.

## Phase 5a goal

**Phase 5a (started 2026-09-25): validate the ECGrav 1.17.0 samplers** against
our truth grid and repeat the Phase 4 metrics (numV L1, per-class fit, ESS,
ESS/s). Requested by Dr. Betre. Plan: Claude plan file
`big-things-happening-it-s-eager-sprout.md` (steps 0-6 summarized below).

New in ECGrav (v1.0.0 -> v1.17.0, github.com/kassabetre/ECGrav @ d15739c):
exact rejection-free `RandomUniformFacetLabeledPureSimplicialComplex` and
`RandomUniformUnlabeledPureSimplicialComplex` (n free, drawn from the counts),
ECGrav's own `RandomPureSimplicialComplexMCMC` (labeling 0/1/2), faster
`RandomVertexLabeledPureSimplicialComplex`, and exact counters
`Num{Vertex,Facet,Un}LabeledPureComplexes`.

### Phase 5a status

- Step 0 DONE: 1.17.0 source vendored at `ECGrav/ECGrav-1.17.0/`. Its
  PacletInfo says WolframVersion 15.0+, which the paclet system filters out
  on 14.3, so `src/load_ecgrav.wl` `Get`s the kernel file directly (works on
  14.3). User is installing Wolfram 15.0.1 (2026-09-25); after that a global
  PacletInstall also works, but the loader stays the pinned path.
  (4,4) truth regenerated via McKay (278 classes, 262 s) ->
  `data/p4q4_truth.wxf`. Other truth/MH WXFs copied from the
  `adoring-hoover-18d09b` worktree and `C:\CombResearch\data`.
- Step 1 DONE: `src/validate_counts_vs_truth.wl` - ECGrav U/F/V counts match
  our truth EXACTLY per n on all 9 cells. **(4,5) iso count 5,532
  independently confirmed** (NumUnlabeledPureComplexes[4,5]). This closes
  the Betre .mx cross-check item.
- Step 2 IN PROGRESS: `src/run_ecgrav_samplers.wl` written; smoke run at
  (2,4),(3,4), N=20k, all 3 targets: 0 unmatched samples, all classes hit
  (vertex misses 2 rare classes at (3,4)). Validation harness extended but
  its first run was interrupted by the Wolfram upgrade.
- Step 2 DONE (2026-09-26): full exact campaign, 9 cells x 3 targets,
  N=100k each (`src
un_ecgrav_campaign.ps1`, ~1 h). **27/27 PASS**, numV L1
  0.002-0.011 (mean ~0.006 vs 0.018 for our MH), per-class chi-square p
  0.058-0.977, iid p-values look uniform (min 0.018 of 27), 0 unmatched
  samples. Negative control `ecglegacyfacet` at (2,4),(3,4): FAILS as
  required (L1 0.22, chi-square p = 0; was 0.43 under 1.0.0).
- Step 4 partial: `src/compare_samplers_efficiency.wl` ran on the 9 cells.
  Exact samplers: tau ~0.5 (draws independent), ESS/s 150-15000. Our MH:
  ESS/s 1-13 for unlabeled/facet. IS from vertex draws: ESS/N falls to
  ~0.001 by (3,6)/(4,5) - same collapse as Phase 3.
- Step 3 DONE (2026-09-26, 03:00-05:10): ECGrav MCMC, 9 cells x 3 targets,
  N=20k. All converged, 0 unmatched. **27/27 PASS** the Phase 4 criterion
  (numV L1 < 0.05; range 0.006-0.030). Wall: vertex/facet ~15 min each,
  unlabeled ~2 h 10 min.
  - Caveat: ECGrav's returned samples are NOT independent for unlabeled.
    corrT (2-5 sweeps) is shorter than the numV τ_int per sweep (1.5-4.6),
    so ESS/N on the sample stream is only 0.31-0.73 for unlabeled
    (0.53-0.96 facet/vertex). The usage message promises independent samples.
  - (4,5) unlabeled fails the strict iid/per-class checks (iid p = 0.000,
    class p = 0.001, L1 0.0296 vs ~0.018 expected at its ESS ~13k). This is
    probably autocorrelation plus possibly slow mixing; not yet separated.
    Follow-up: rerun (4,5) unlabeled with longer spacing, or report the
    corrT issue to Betre.
  - ESS/s: ECGrav MCMC beats our MH (unlabeled 7-44 vs 3-9; facet 65-624 vs
    1-12) but is 10-100x behind the exact samplers.
- q=10 exact runs deferred by user (plan: 100k facet, ~10k unlabeled per p).
- q=10 timing pilot: unlabeled exact is slow (88 ms / 494 ms / 3.9 s per
  sample at p=2/3/4); facet 1.7 / 4.5 / 25 ms; vertex 0.4 ms.
- STALE DATA: the vertex MH WXFs copied from `adoring-hoover-18d09b`
  ((2,4),(2,5),(2,6),(3,4),(3,5)) fail with L1 ~0.7-0.85 - they predate the
  2026-05-14 vertex fix. Rerun before using them. (4,5) vertex MH (from
  `C:\CombResearch\data`) is post-fix and passes (L1 0.0086).
- ECGrav 1.17.0 also installed globally (Wolfram 15.0.1, 2026-09-25).

### Findings so far

- ECGrav MCMC (`RandomPureSimplicialComplexMCMCSweep`) is the same global
  remove-one/add-one kernel on N = p q labels as our `proposeGlobal`, with
  weights 1/C(N,k) (vertex), FacetStabilizer*q!/(C(N,k) k!) (facet),
  Aut/(C(N,k) k!) (unlabeled). These equal our π_V/π_F/π_U on labeled
  states (FacetStabilizer = aut/autF). Vertex weight dated 05/14/2026 - same
  fix as ours.
- Exact samplers run serially unless kernels are already launched
  ($KernelCount > 0); we parallelize per target process instead.

### Phase 5a next steps

1. Once Wolfram 15 is up: `COMB_VAL_SOURCE=ecgexact COMB_VAL_CELLS="2,4;3,4"`
   validate smoke data; debug harness if needed.
2. Negative control: `COMB_ECG_SAMPLER=legacyfacet COMB_ECG_CELLS="2,4"` then
   validate with `COMB_VAL_SOURCE=ecglegacyfacet` (must FAIL, L1 ~0.43).
3. Full exact campaign: `src
un_ecgrav_campaign.ps1` (9 cells, N=100k).
4. MCMC campaign: `COMB_ECG_SAMPLER=mcmc` (N=20k), long - ask user first.
5. q=10 exact: `COMB_ECG_CELLS="2,10;3,10;4,10"` after a timing pilot.
6. `src/compare_samplers_efficiency.wl` for the ESS table.
7. Missing MH WXFs for (2,7),(3,6),(4,4) - rerun `run_mh_chains.wl` if the
   efficiency table needs our MH at those cells.

## Previous goal (Phase 4b, complete 2026-05-15)

**Phase 4b complete (2026-05-15).** Truth+MH on 9 cells × 3 targets, all 27 combinations PASS at L1 < 0.05. (4,5) MH chains landed and validated:
- unlabeled L1 = 0.0253
- facet L1 = 0.0294
- vertex L1 = 0.0086

Renderer produces 273 manuscript panels, all with full overlays (no truth-only rows remaining).

Remaining open items:

1. ~~Disambiguate MH-stationary vs MH-trapped at p=4 q=10 unlabeled/facet~~
   — closed by Phase 4c part 3 (warm-start + second seed). See below.
2. **Betre cross-check**: Dr. Betre has independent (4,4) and (4,5) facet-labeled
   and unlabeled samples in `.mx` files. Platform-locked to MacOSX-ARM64.
   Betre asked to re-export as WXF. When `.wxf` files land in
   `C:\CombResearch\data\`, cross-check our (4,5) iso count = 5,532.
3. **Next-phase decision** (user input needed): manuscript text integration
   (Phase 5), attempt (4,6) via McKay, broaden q=10 comparison to remaining
   Figure 3+ statistics, or other priorities.

## Current status (2026-05-15)

- **Truth grid expanded to 9 cells**: `(2,4), (2,5), (2,6), (2,7), (3,4), (3,5), (3,6), (4,4), (4,5)`. (4,4) and (4,5) are first-ever p=4 enumerations in this project. (4,5) iso count = 5,532, via `streamingEnumeratePureMcKay` sequential, 17.1 hr wall-clock, 7.9 GB peak. Cheap pipeline OOM'd at (4,5) even sequential — McKay is the only viable path at p=4 q≥5.
- **MH chains validated at all 9 cells × 3 targets = 27 cell×target combinations PASS** (mean L1 = 0.018, all below 0.05 threshold vs truth on numV marginal). See `src/validate_mh_vs_truth.wl` for the harness.
- **(4,5) MH chains** ran in parallel (3 processes, one per target) via `src/run_p4q5_mh_parallel.ps1` overnight on 2026-05-15. Total wall-clock ~6 hr.
- **Vertex target bug found + fixed.** Before 2026-05-14, `mhStep`'s vertex branch used `piRatio = 1`, which gave a marginal-on-iso of `C(N, k) · k!/|Aut(Y)|` — wrong by a factor of `C(N, k)` against the manuscript's intrinsic `π_V ∝ k!/|Aut(Y)|`. Manifested as L1 = 0.85 at (3,5) vertex. Fixed by setting `piRatio = Binomial[nMax, m] / Binomial[nMax, mY]`. All vertex MH WXFs re-run with the fix.
- **Renderer extended** to 9 cells × including p=4 panels. 273 manuscript panels + 33 stacked previews + `figures/combined_truth_overlay.pdf`.
- **McKay enumerator integer-labeled** (was string-labeled). `bipartiteIncidenceGraph` build dropped ~120 µs → ~55 µs per call. McKay-on-cliques angle (Betre's suggestion) was investigated and rejected — speedup at p≤3 only (1.2-1.4×), slower at p=4.
- **`enumerate_truth.wl` extended**: env vars `COMB_TRUTH_PIPELINE` (cheap|bliss|mckay) and `COMB_TRUTH_PARALLEL` (true|false). Tagged filenames `p{p}q{q}_truth_{pipeline}.wxf` for cross-validation.

## Decisions made

- McKay-style canonical-augmentation enumerator is the production path at p=4.
- `data/p4q5_truth.wxf` is the cheap-style filename but is copied from `p4q5_truth_mckay.wxf` (cheap pipeline failed at this cell).
- Vertex target's `π_V(X)` is `∝ 1/C(N, numV(X))` (not `∝ 1`). See `mhStep` in `src/sampler_mh.wl`.
- (4,5) MH chains ran in 3 parallel processes via `src\run_p4q5_mh_parallel.ps1`, monitored via `src\monitor_mh.ps1`.
- Betre's `.mx` re-export request was sent (user-mediated via email/Slack).

## Files modified this session

- `src/sampler_mh.wl` — vertex target fix
- `src/streaming_enumerator_bliss.wl` — integer-labeled `bipartiteIncidenceGraph`
- `src/streaming_enumerator_mckay.wl` — `canonicalRemovalVSide` for integer labels
- `src/enumerate_truth.wl` — pipeline + parallelism env vars, tagged filenames, payload `pipeline` field
- `src/render_truth_overlay.wl` — `reachableCells` 5 → 9, p=4 enabled in fig defaults
- 2026-05-16 Codex comment audit: refreshed stale headers/comments in sampler,
  truth/MH drivers, overlay renderer, streaming enumerators, and p=4 probe;
  `validate_mh_vs_truth.wl` now defaults to the current 9-cell grid.
- 2026-05-16 Codex doc consolidation: replaced historical planning docs with
  `docs/enumeration.md` and `docs/sampling.md`; README and source references
  now point at the consolidated docs.
- 2026-05-16 Codex archive cleanup: moved historical benchmark/probe/scaling
  scripts from `src/` to `archive/old_test_scripts/`; production renderers and
  smoke tests remain in `src/`.

## Files added this session (Phase 4c part 3)

- `src/run_q10_mh_overnight.ps1` — orchestrator for the overnight job.
  Step 1 restores `p4q10_mh_unlabeled.wxf` at the production 200k budget
  (a smoke test had overwritten it). Step 2 launches 4 parallel
  wolframscript processes at 1M iter, seed 67890, warm-start at
  numV=14 (p=3) or numV=18 (p=4). Outputs tagged
  `_seed67890_warm{N}` so production is never clobbered.
- `src/compare_q10_warm_vs_prod.wl` — per-cell L1 table comparing IS,
  production-seed, and warm-seed chains. Reports L1(prod, warm) as the
  key disambiguator.
- `src/render_q10_warm_vs_prod.wl` — 2x2 grouped-bar overlay
  (IS / prod / warm) at the 4 disagreement cells. Output:
  `figures/q10_warm_vs_prod.{png,pdf}`.

Sampler patches enabling the overnight job:
- `src/sampler_mh.wl`: added `warmInitialState[p,q,nMax,mTarget,seed]`
  that constructs q distinct random p-subsets of `{1..mTarget}` embedded
  in `[nMax]`. `runMHChain` gained option `initNumV` (default
  Automatic = existing random-vertex-labeled init).
- `src/run_mh_chains.wl`: added env vars `COMB_MH_TAG` (output-filename
  suffix), `COMB_MH_INITNUMV` (forwards to runMHChain), and
  `COMB_MH_OUTDIR` (override the output dir — needed when running the
  worktree script with outputs going to the main checkout). Tag and
  initNumV are persisted to the payload. The (3,5) inline gate is
  skipped for non-default tag or initNumV.

## Files added this session (Phase 4c part 2)

- `src/run_is_at_truth_cells.wl` — chunked IS sampler at (3,5) and (4,5),
  100k samples each, ParallelMap on the {numV, |Aut|, |Aut_F|} stats step.
  Writes the same `data/p{p}q{q}_is_{target}_numv_hist.wxf` schema as the
  q=10 aggregator so the comparison/render code is shared.
- `src/compare_3way.wl` — per (p, q, target) prints L1 against truth for
  both IS and MH plus the IS-vs-MH L1, with an ASCII overlay. Writes
  `data/is_mh_truth_3way_summary.wxf`.
- `src/render_3way.wl` — 2x3 grid of grouped bar overlays (truth, IS, MH).
  Output: `figures/q5_is_mh_truth_3way.{png,pdf}`.

## Files added this session (Phase 4c part 1)

- `src/precompute_is_histograms_q10.wl` — aggregates the merged 12M-row q=10 IS
  stats into 9 small numV-fraction WXFs (one per p × target). Uses GroupBy for
  the bin aggregation; the older Merge[Thread[..., Total]] was unusably slow on
  2M+ rows. Outputs: `data/p{2,3,4}q10_is_{vertex,unlabeled,facet}_numv_hist.wxf`.
- `src/run_q10_mh_pilot.ps1` — sequential 10k-iter MH pilot at q=10 for all 9
  (p, target) combos. Environment-overridable iter count.
- `src/run_q10_mh_parallel.ps1` — production launcher: 4 parallel
  wolframscript processes, one per cell × target at (3,10) and (4,10) ×
  {unlabeled, facet}. 200k iter, 20k burn-in, thin 5; ~45 min wall when run
  in parallel.
- `src/compare_is_mh_q10.wl` — bins MH numV column 1, compares against
  precomputed IS frac-hist, prints per-bin ASCII overlay + per-cell L1 and
  summary table. Writes `data/q10_is_vs_mh_summary.wxf`.
- Pilot archive: `data/q10_pilot_archive/p{3,4}q10_mh_{unlabeled,facet}_pilot10k.wxf`
  preserved before production rerun overwrote the WXFs.

## Files added this session (previous: Phase 4b)

- `src/validate_mh_vs_truth.wl` — MH-vs-truth validation harness
- `src/test_streaming_mckay.wl` — McKay correctness gate + profiler
- `archive/old_test_scripts/probe_mckay_primitives.wl` — archived per-primitive time attribution probe
- `archive/old_test_scripts/probe_clique_vs_bipartite.wl` — archived clique-graph vs bipartite speedup measurement
- `archive/old_test_scripts/probe_p4_cheap.wl` — archived (4,4) cheap pipeline scaling probe
- `src/probe_betre_mx.wl` — inspector for Betre's `.mx` files
- `src/run_p4q5_mh_parallel.ps1` — 3-process parallel launcher for (4,5) MH
- `src/monitor_mh.ps1` — dashboard for running MH chains

## Likely files for the next agent

- `src/sampler_mh.wl` — if MH semantics need further work
- `src/run_p4q5_mh_parallel.ps1` — if (4,5) MH chains need to be rerun
- `src/validate_mh_vs_truth.wl` — MH-vs-truth validation harness
- `data/p4q5_mh_*.wxf` — output of validated (4,5) MH chains
- `data/p4q*SXFacetLabeled.wxf`, `data/p4q*SXUnlabeled.wxf` — Betre's data (when he re-exports)

## Commands/checks to run

```powershell
# Smoke check: McKay still correct at small cells
wolframscript -file src\test_streaming_mckay.wl

# Validate any (cell × target) combination
COMB_VAL_CELLS="3,5" COMB_VAL_TARGETS="vertex" wolframscript -file src\validate_mh_vs_truth.wl

# Launch (4,5) MH chains (manual)
powershell -ExecutionPolicy Bypass -File src\run_p4q5_mh_parallel.ps1

# Monitor (4,5) MH progress
powershell -ExecutionPolicy Bypass -File src\monitor_mh.ps1
```

## Handoff notes

Before continuing, the next agent must:

1. Read `CLAUDE.md`.
2. Read `CLAUDE.md` if using Claude Code.
3. Read this file.
4. Run `git status --short`.
5. Inspect `git diff` (especially the live MH-vs-truth fix and the renderer change).
6. Check whether `data/p4q5_mh_*.wxf` exist (user may have launched manually).
7. Continue from the current repo state, not hidden chat history.

## Last updated by

Claude Code on 2026-11-18 (ECGrav dist consolidation onto upstream 474b5c2)
Claude Code on 2026-09-25 (Phase 5a ECGrav 1.17 sampler validation, in progress)
Claude Code on 2026-05-18 (Phase 4c part 3: warm-start + second-seed disambiguation, Phase 4c CLOSED)

## Tool switch prompts

When switching from Claude to Codex:

```text
Read CLAUDE.md and docs/agent-task.md. Run git status --short and git diff.
Continue from the current repo state. Do not restart the task from scratch.
```

When switching from Codex to Claude Code:

```text
Read CLAUDE.md and docs/agent-task.md. Run git status --short and
inspect the diff. Continue from the current repo state. Do not restart the task
from scratch.
```
