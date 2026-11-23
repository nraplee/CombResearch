# Implementation plan: from the current repo to the ideal flow

Revised 2026-11-20. It keeps the developer guarantees found by two
adversarial reviews of the first draft (file:line evidence below comes from
them) and follows the project direction:

- always run on the latest upstream ECGrav;
- eventually merge our algorithms into ECGrav;
- no data publishing;
- LaTeX on Overleaf;
- no git history rewrites;
- licensing left to Dr. Betre.

Companion to `current.md` and `ideal.md`.

## Two users, one codebase

| | Outside researcher (clone or zip) | Us (Ryzen PC + laptop, Claude Code worktrees) |
|---|---|---|
| Gets data by | regenerating: `run.wl all --profile quick` or `paper` | the shared store in `C:\CombResearch\data` |
| Gets ECGrav by | `run.wl check` cloning upstream main | the same shared clone, or `COMB_ECGRAV_DIR` pointing at a fork branch we're preparing for Betre |
| Configures with | named profiles in `config/cells.wl` | today's per-script defaults and `COMB_*` env knobs, plus profiles when named |
| Outputs go to | `<clone>/data`, `figures`, `results` | the main checkout, from any worktree |
| Platform | any OS with Wolfram 15+ | Windows; `.ps1` launchers and monitors stay |

## Developer guarantees (hold after every phase)

1. **One output root, decided in one place.**
   - `comb_paths.wl` / `.ps1` keep the git-common-dir logic, which lets
     worktrees share outputs. A plain clone resolves to itself (checked:
     `git -C src rev-parse --git-common-dir` gives `../.git`).
   - A repo-marker guard handles a zip unpacked inside another repo: the
     git root is accepted only if it contains `src/comb_paths.wl`, otherwise
     the code checkout is used. `COMB_ROOT` still overrides.
   - `$CombResultsDir` is added, and `results` joins the sync script's
     folder list.
2. **Existing data stays valid and is never rerun by accident.**
   - No phase renames or moves existing WXFs. One naming helper produces
     today's flat names.
   - An output with no manifest counts as up to date and is rerun only with
     `--force`. `--force` covers only the stage and cells named on the
     command line, never `all`.
   - Outputs made with an older ECGrav commit are **reported as stale**, not
     rerun automatically.
3. **Bare scripts behave exactly as today.**
   - With no `--profile` and no `COMB_PROFILE`, settings resolve to each
     script's current defaults. For example, `enumerate_truth.wl` keeps its
     5 cells and the cheap pipeline, so it never OOMs on (4,5).
   - Order: CLI flag, then `COMB_*` env, then named profile, then script
     default. `run.wl` prints each setting with its source and warns when a
     leftover env var overrides a named profile.
   - Every existing `COMB_*` knob keeps its name. `CLAUDE.md` maps
     `--cells` to each stage's own knob (`COMB_TRUTH_CELLS`,
     `COMB_MH_CELLS`, `COMB_ECG_CELLS`, `COMB_VAL_CELLS`, `COMB_IS_CELLS`,
     and p-only `COMB_CMP_PS`).
4. **Old entry points keep working until their replacement is proven.** A
   folded script becomes a shim that `Get`s the new code *in the same
   kernel*. That preserves the `*Override` protocol: `run_p3.wl:4-10` sets
   `pListOverride` and `sampleSizeOverride` before `Get`ting
   `pure_simplicial_compute.wl`. Shims go only in Phase 5.
5. **Long runs stay parallel and monitorable.**
   - `run.wl` fans out one process per target (MH, ECGrav) or per p (IS).
   - It keeps the launchers' log names: `mh_p{p}q{q}_{target}.log`,
     `ecg{sampler}_{target}.log`, `compute_p{p}[_{tag}].log`, plus `.err`.
   - `monitor_mh.ps1` and `monitor_ecgrav.ps1` must work unchanged.
6. **ECGrav updates never surprise a run.**
   - ECGrav is pulled only at the start of a `run.wl` invocation, never
     during one. Running kernels keep the code they loaded.
   - Every output records the ECGrav commit it was made with.
   - The validate stage warns when its inputs mix ECGrav commits (for
     example IS batches made before and after an update).
7. **One branch and one PR per step, from `main`.** Checks run in a scratch
   root (Phase 0), never against the shared store.

## Phase 0: safety net

- **Provenance table.** For each data family in the store, record the
  ECGrav version, `$Version`, seed, runTag, N and chunk size that made it,
  from the logs and `docs/agent-task.md`. Known so far:
  - q=10 IS: ECGrav 1.0.0 (`pure_simplicial_compute.wl:23`).
  - truth: labelled `"1.0.0"` by a hardcoded string (`enumerate_truth.wl:98`).
  - ecgexact and ecgmcmc: 1.17.0.
  - MH chains: unrecorded.
  - The merged q=10 IS is batches `n500000`, `batch2` and `batch3`, with
    seeds from `Hash[runTag]` (`pure_simplicial_compute.wl:37-38`).

  The table also gives the regeneration to-do list under the latest ECGrav.
- **Golden reference, in two parts.** It is stored as code in
  `tests/golden/`, read from `$CombCodeRoot`, never written through
  `$CombRoot`.
  - `golden/derived`: values computed from the existing WXFs. These are L1
    tables, numV marginals, iso counts, stat-column sums, and a hash of the
    binned data behind each figure panel. Refactors must reproduce them
    **exactly** from the same inputs. p-values are left out, because
    `validate_mh_vs_truth.wl:153` draws with no seed.
  - `golden/quick`: produced by the quick profile. Later runs must match
    truth exactly. Samplers must stay within tolerance (L1 vs truth < 0.05),
    not equal earlier values, since ECGrav keeps changing.
- **Scratch check root.** `tools/dev/make_check_root.wl <dir> <families>`
  hard-links the needed WXFs from the store into a scratch `COMB_ROOT`.
  Checks read real inputs and write only to scratch.
- Tag `pre-restructure` on `main`.

## Phase 1: track the latest upstream ECGrav

This phase replaces the pin.

- **Shared clone.** `tools/dev/update_ecgrav.wl`, later called by
  `run.wl check`, keeps one clone of `github.com/kassabetre/ECGrav` at
  `$CombRoot/ECGrav-upstream`. That folder is gitignored and shared by all
  worktrees like `data/`. The script fetches and fast-forwards to
  `origin/main`, and records the commit.
- **`load_ecgrav.wl`** loads `Kernel/ECGrav.wl` from, in order:
  1. `COMB_ECGRAV_DIR`, any ECGrav checkout, for example our fork branch;
  2. the shared clone.
  - It sets `$CombECGravCommit`, keeps `combLoadECGravOnKernels[]`, and
    keeps the `installed` mode.
  - It drops the `COMB_ECGRAV_VERSION` snapshot values.
- **Symbol check.** After loading, assert that the 14 ECGrav symbols we
  use exist. They are listed in one place in the loader:
  - `RandomVertexLabeled…`, `RandomUniformUnlabeled…`,
    `RandomUniformFacetLabeled…` and `RandomFacetLabeledPureSimplicialComplex`;
  - `RandomPureSimplicialComplexMCMC` and its `Sweep` variant;
  - `Num{Un,Facet,Vertex}LabeledPureComplexes`;
  - the automorphism-order functions;
  - `IsomorphicSimplicialComplexQ` and `ChooseNonIsomorphic…`.

  An upstream rename then fails with one clear message instead of
  mid-run.
- **ECGrav regression** (`tests/ecgrav_regression.wl`). It runs when the
  commit differs from the last one that passed, which is recorded in
  `$CombResultsDir`:
  - the counters against truth on all 9 cells;
  - the exact samplers at small N against truth;
  - an MH smoke test.

  This makes "re-validate whenever ECGrav changes" automatic.
- **Remove the vendored snapshots** `ECGrav/ECGrav-*` and
  `BuildingAndInstallingPaclets.nb`. They stay in git history.
  `install_ecgrav_global.wl` installs from the shared clone, for notebook
  use only.
- **Update `CLAUDE.md`:** the "pinned snapshot" rules become "latest
  upstream, loaded via `load_ecgrav.wl`". Remove the snapshot-update
  procedure and the global-install step from the Ryzen checklist.
- Check: the regression passes on today's upstream main, and the three
  smoke tests pass.

## Phase 2: shared libraries and config, no behaviour change

| New file | Contents | Replaces |
|---|---|---|
| `src/lib_io.wl` | `exportWxfAtomic`; a **sidecar manifest** per output, `<file>.manifest.wl`, written atomically | helper inside `pure_simplicial_compute.wl` |
| `src/lib_names.wl` | `combFile[...]` for every data family and log, producing **today's** names | path builders in about 20 scripts |
| `src/lib_stats.wl` | `statsFor` and the 12-column schema | helper inside `pure_simplicial_compute.wl` |
| `src/lib_config.wl` | `combSetting`, using the precedence in guarantee 3 | `Environment["COMB_*"]` parsing in 19 scripts |
| `config/cells.wl` | profiles `quick` and `paper`: cells, N, seeds, targets, the IS batch list `{runTag, N, chunk}` per p, the warm-chain list `{p, target, seed, initNumV, numIter, thin, tag}`, and the (4,5) per-target MH settings | settings that today live only in `.ps1` launchers |

- **One manifest per output, never one shared file.** Up to 4 processes
  and other worktrees write at once. Each manifest records sha256, ECGrav
  commit, `$Version`, `$SystemID`, kernel count, seed, profile, settings,
  git sha (or a `VERSION` file when there is no git), and wall time.
- `tools/dev/backfill_manifest.wl --dry-run` writes manifests for existing
  WXFs from embedded metadata and the provenance table.
- Point `enumerate_truth.wl`, `run_mh_chains.wl` and
  `run_ecgrav_samplers.wl` at `lib_stats` / `lib_io` directly. They stop
  `Block`-Getting `pure_simplicial_compute.wl`.
- Fixes:
  - the hardcoded `ecGravVersion = "1.0.0"`;
  - the 3 renders that `Get["src/sampler_mh.wl"]` relative to the current
    folder;
  - the `comb_paths` guard.
- Checks:
  - `test_streaming*.wl`;
  - `run_p3.wl` with `COMB_N` small;
  - `golden/derived` in a scratch root.

## Phase 3: `run.wl`, one entry point over today's `.wl` scripts

```
wolframscript -file run.wl <check|truth|is|mh|ecgrav|validate|figures|all> [profile quick|paper] [cells "3,5;4,5"] [targets vertex,facet] [force] [dryrun]
```

Options are plain words: wolframscript drops every script argument from the
first one that starts with `-` (found in Phase 2d), so `--profile` cannot
work.

- **`check`:** update ECGrav, run the regression if the commit changed,
  run the smoke tests, and report stale outputs.
- **Other stages:** set `COMB_*` env and launch the existing `.wl` drivers
  directly, never a `.ps1`, so it runs on any OS. They fan out per target
  or per p with the launchers' log names. The skip rule follows
  guarantee 2.
- **`dryrun`:** prints the stages, cells, reasons, and every setting
  with its source.
- **New `src/render_fig2.wl`:** Fig 2 (q=3) through `load_ecgrav.wl`, with
  outputs through `comb_paths`. The reference notebooks are untouched.
- Checks:
  - the monitors work on a `run.wl` MH run;
  - the quick profile in a scratch root meets `golden/quick`;
  - `render_fig2.wl` reproduces the notebook's numbers.

**As built (2026-11-21).** Differences from the text above:

- No `profile` word means `COMB_PROFILE`, else `paper`, so every stage has a
  run plan. Bare driver scripts are unchanged (guarantee 3 is about them).
- Fan-out: MH one process per cell×target, ECGrav per sampler×target, q=10 IS
  per p×batch, at most `jobs N` (default 4) at once. Extra stage `status`
  prints the store report only.
- Skip rule as guarantee 2, plus: a job also counts as done only if every
  output it should write is newer than its start (wolframscript exits 0
  after `Abort[]`); `force` is refused for a finished q=10 batch (the driver
  cannot rerun it); a McKay truth output waiting for its rename is skipped
  with a hint; a cell with only some IS-at-truth-cell hists is held back.
- Per-job identity knobs (cells, targets, sampler, tag, runTag, N, ...)
  always come from `run.wl`: a leftover env var cannot change them, and a
  leftover `COMB_FORCE` never reaches a job. Names are compared
  case-insensitively (Windows).
- Each running job holds `<log>.lock`, taken atomically and checked again
  right before start, so two `run.wl` processes do not run the same job.
- `validate` with `cells`/`targets` skips the jobs that write a global
  summary (a partial run would overwrite it). The q=10 histogram step moved
  to `is`. The q=10 merge (`concat_samples.wl`) stays manual until Phase 4.
- `validate` warns when one kind of input mixes ECGrav commits (guarantee
  6, read from the manifests), within a family only: MH and ECGrav samples
  differ by design, and truth is exact.
- `golden/quick` (`tests/golden/golden_quick.wl`): truth exact; sampler
  tolerances per sampler for the quick budget (exact 0.05, MCMC 0.10, MH 0.15);
  see `tests/golden/README.md`.
- `render_fig2.wl`: exact parts (class table, theory, enumeration) match the
  notebook exactly; the seeded draw cannot, because ECGrav's sampler changed,
  so the panels are checked against theory and against the notebook's saved
  bars with ESS-based tolerances (`tests/fig2_check.wl`). The draw happens
  before subkernels launch, so a seed reproduces it.
- Three adversarial review rounds (workflows, 3 refuters per finding):
  13 issues, then 4 incomplete fixes and 10 new, then 2 partial fixes and 2
  nits, all fixed; `tests/run_wl_test.wl` covers them.

## Phase 3a: regenerate the flagged data (first real `run.wl` runs)

The store's backfilled manifests flag what is wrong or missing
(`provenance.md`, "Problems found"). Fixing it is the first production use
of `run.wl`, with the `paper` profile's settings (`config/cells.wl`): MH
200k / 20k burn-in / thin 5, seed 12345; ECGrav exact N=100k, MCMC N=20k,
seed 24680. Each rerun writes a real manifest over the backfilled one.

| # | Data | Command (on the Ryzen) | Why | Wall time |
|---|---|---|---|---|
| 1 | MH vertex (2,4) (2,5) (2,6) (3,4) (3,5) | `run.wl mh profile paper cells "2,4;2,5;2,6;3,4;3,5" targets vertex force` | `knownBad`: pre-fix (acceptRate 1.0) | about 2 min in all (a post-fix 200k vertex chain takes 0.3-0.4 min) |
| 2 | MH (2,7) (3,6) (4,4), all 3 targets | `run.wl mh profile paper cells "2,7;3,6;4,4"` | missing (lost with a worktree) | about 40 min per cell fanned out per target (facet 30-40 min, unlabeled 10-12, vertex < 1); about 2.5 h one cell at a time |
| 3 | ecgmcmc, all 9 cells, then ecgexact | `run.wl ecgrav profile paper` (mcmc run, then exact) | made with ECGrav 1.17.0; MCMC start rule changed upstream (87f2d5d) | MCMC about 1.75 h, exact about 35 min, 3 targets in parallel; unlabeled dominates both. Latest ECGrav has speedups, so likely less |
| 3b | ecglegacyfacet (2,4) (3,4) (optional) | `run.wl ecgrav profile paper` (legacyfacet run) | only if the negative-control comparison is still wanted | about 1 min |
| 4 | MH (2,4) unlabeled, facet at 200k (optional) | `run.wl mh profile paper cells "2,4" targets unlabeled,facet force` | `smoke`: 30k chains today | about 30 min (facet), 11 min (unlabeled) |

Wall times are from the stored outputs' own `wallSeconds` (backfilled
manifests, `embedded`), Ryzen, ECGrav 1.0.0/1.17.0.

- **(3,5) vertex:** rerun it with the rest instead of restoring
  `p3q5_mh_vertex.2026-05-17.wxf.bak`. That chain was made with uncommitted
  code and would keep a backfilled manifest. Keep the `.bak` as a
  cross-check: the rerun's numV marginal should be within L1 0.05 of it.
- **Order:** 1 and 2, then 3. MH and ECGrav runs are separate processes and
  may overlap on the Ryzen (8C/16T, 32 GB). Run 4 and 3b only if wanted.
- **Then, as part of this phase:**
  - `run.wl validate` for sources `mh`, `ecgmcmc` and `ecgexact` on all 9
    cells × 3 targets, L1 < 0.05. This restores "validated on all 27 cell ×
    target pairs" with stored data behind it.
  - Rerun the derived summaries that read the replaced inputs:
    `validation_*`, `sampler_efficiency_summary` (its status becomes `ok`),
    and `is_mh_truth_3way_summary`.
  - Re-baseline the golden/derived sections whose inputs changed, on
    purpose (`COMB_FORCE=1 ... golden_derived.wl write <section>`), and say
    so in the PR.
  - Update `provenance.md` (M1, M3, the missing cells, E1–E3 superseded) and
    `CLAUDE.md` (drop the rule about pre-fix vertex WXFs; correct the
    validation claim in the summary).
- **Check:** `backfill_manifest.wl` (dry run) shows no `knownBad` or
  `smoke` row left among live files, except the q=10 pilot chains (M6, M7),
  which stay as they are.

## Phase 4: build the `CombResearch` package and the pipeline stages

The algorithms move into a package laid out like ECGrav: `PacletInfo.wl`,
`Kernel/CombResearch.wl`, and `Kernel/Subpackages/*.wl`. Each public symbol
gets `::usage`, and tests go in `.wlt` `VerificationTest` files. This keeps
upstreaming a copy-and-adapt job. Workflow code goes into `pipeline/`
stages. One PR per row, each checked against `golden/derived`, with
in-kernel shims left behind.

| Package piece | Pipeline stage | From | Notes |
|---|---|---|---|
| `Enumeration.wl` | `10_truth.wl` | 3 enumerators, `enumerate_truth.wl`, `test_streaming*.wl` | picks cheap or McKay per cell; writes the final `_truth.wxf` (no manual rename); gates for all 9 cells |
| `Statistics.wl` | (all) | `statsFor` | — |
| `ISSampler.wl` | `20_is_q10.wl` | `pure_simplicial_compute.wl`, `run_p{2,3,4}.wl`, `concat_samples.wl` | batches from the config; merge built in; chunk resume unchanged; `*Override` variables map to settings |
| `MHSampler.wl` | `30_mh.wl` | `sampler_mh.wl`, `run_mh_chains.wl` | chains and warm starts from the config; adds the missing (2,7), (3,6), (4,4) chains |
| — | `40_ecgrav.wl` | `run_ecgrav_samplers.wl` | — |
| `Compare.wl` | `50_validate.wl` | `validate_*`, `compare_*`, `precompute_is_histograms_q10`, `run_is_at_truth_cells` | writes `results/*.csv`; pre-bins the 10 q=10 statistics × 3 weights so figures don't read the 2.8 GB merged stats |
| — | `60_figures.wl` | 8 `render_*.wl`, `render_fig2.wl` | reads `results/`; `render_sampler_progress` stops reading the legacy CSV |

The `.ps1` launchers become thin callers of `run.wl` with the same log
names.

**Order (agreed 2026-11-21):** Enumeration, Statistics, MHSampler,
`40_ecgrav`, ISSampler, Compare, figures. MH goes before IS because it is
smaller and fully checkable against truth; IS (chunk resume, `*Override`) is
the riskiest move and waits until the package pattern is proven.

**As built, row 1 (Enumeration / `10_truth.wl`, 2026-11-21):**

- `CombResearch/PacletInfo.wl`, `Kernel/CombResearch.wl` (usage messages;
  refuses to load unless `ECGrav`` is already loaded),
  `Kernel/Subpackages/Enumeration.wl` (the three enumerators moved verbatim
  into the private context), `Tests/Enumeration.wlt` + `TestPrelude.wl` +
  `run_tests.wl`. `src/load_combresearch.wl` loads ECGrav, then the package.
- Public: `EnumerateUnlabeledPureComplexes[p, q, Method -> Automatic |
  "Cheap" | "BLISS" | "McKay", "Parallel" -> True]` (Automatic = McKay for
  p >= 4; result gains a `"method"` key), `PureComplexCanonicalKey`,
  `ChooseNonIsomorphicPureComplexesBucketed`, `$CombTruthIsoCounts` (gates
  for all 9 cells), `$CombResearchSubkernelSetup` (how parallel code loads
  ECGrav on subkernels; the loader sets it to `combLoadECGravOnKernels`).
- `pipeline/10_truth.wl` always writes the final `_truth.wxf`; `run.wl
  truth` runs it and no longer has a "waiting for rename" state.
  `src/enumerate_truth.wl` is unchanged (cross-validation, tagged names) and
  runs on the package through the shims `src/streaming_enumerator*.wl`.
- Still as before: McKay's `totalFacetLabeled` is the pruned leaf count,
  not the facet-labeled total (golden truth's known finding). Fixing it
  changes stored-data semantics, so it is a separate, deliberate change.

**As built, row 2 (Statistics, 2026-11-22):** `Kernel/Subpackages/Statistics.wl`
(moved verbatim from `src/lib_stats.wl`); public `PureComplexStatistics[c, p]`,
`$PureComplexStatisticNames`, `PureComplexKPathComponents`,
`PureComplexBettiNumber`; `Tests/Statistics.wlt`. `src/lib_stats.wl` is a shim
(same Global names; `$CombISHeaders` stays there until ISSampler).
`pure_simplicial_compute.wl` loads the package on its subkernels
(`combLoadCombResearchOnKernels[]`). No pipeline stage for this row.

**As built, row 3 (MHSampler / `30_mh.wl`, 2026-11-22):**
`Kernel/Subpackages/MHSampler.wl` (moved verbatim from `src/sampler_mh.wl`,
with its derivation; option names became strings); public
`PureComplexMHChain[p, q, target, numIter, opts]` (checks target and
kernel) and `IntegratedAutocorrelationTime`; `Tests/MHSampler.wlt`.
`pipeline/30_mh.wl` is `run_mh_chains.wl` on the package (same knobs,
defaults and file names; `samplerVersion` label now
`CombResearch/MHSampler.wl@<sha>`); `run.wl mh` runs it.
`src/run_mh_chains.wl` and `src/sampler_mh.wl` are shims (the latter
keeps its smoke test). The (2,7), (3,6), (4,4) chains were already added
in Phase 3a. Not done: the four MH `.ps1` launchers still call
`run_mh_chains.wl` (the shim) rather than `run.wl`. Making them thin
`run.wl` callers is left for a separate PR: they do more than `run.wl mh`
(the q=10 pilot writes the production file names; the overnight launcher
has a one-time file-restore step), and proving a converted launcher needs
a production-sized run.

**As built, row 4 (`40_ecgrav.wl`, 2026-11-22):** `pipeline/40_ecgrav.wl` is
`run_ecgrav_samplers.wl` on the package (`PureComplexCanonicalKey`,
`PureComplexStatistics`), same knobs, defaults and names; `run.wl ecgrav`
runs it; `src/run_ecgrav_samplers.wl` is a shim, so
`run_ecgrav_campaign.ps1` is unchanged. The count check
(`validate_counts_vs_truth.wl`) stays in `validate`; folding it into the
ECGrav regression is left for `50_validate`.

**As built, row 5a (ISSampler / `20_is_q10.wl`, 2026-11-22):** the row is
split in two PRs. 5a: `Kernel/Subpackages/ISSampler.wl` (the weight
formulas and the per-chunk sample + statistics step from
`pure_simplicial_compute.wl`; public `PureComplexISSample`,
`PureComplexISWeights`, `$PureComplexISNames`, `EffectiveSampleSize`),
`Tests/ISSampler.wlt`; `pipeline/20_is_q10.wl` is the driver on the
package, and `src/pure_simplicial_compute.wl` is a shim that `Get`s it in
the same kernel, so `run_p{2,3,4}.wl`, the `*Override` variables, the
knobs, chunk resume and the file names are unchanged (`run.wl is` keeps
launching `run_p{p}.wl`). Subkernels load the package instead of
receiving `DistributeDefinitions` of the helpers. 5b (next PR): the batch
merge (`concat_samples.wl`) becomes a `run.wl is` job driven by the
profile's batch list.

**As built, row 5b (merge, 2026-11-22):** `pipeline/21_is_merge.wl` is
`concat_samples.wl` with two knobs, `COMB_IS_MERGE_PS` and
`COMB_IS_MERGE_STEMS` (identity knobs in `run.wl`). With stems it merges
exactly those batches, in sorted file order, which is the order the glob
gives, so a declared list of the same files reproduces the old merge;
without, it globs as before (`src/concat_samples.wl` is a shim). `run.wl
is` plans one merge job per p after that p's batches, with the profile's
batch list (the paper lists name exactly the files the stored merges came
from). Like every job it is decided when the stage is planned, so on a
fresh store the merge (and the q=10 histograms) run on the next `run.wl
is`; `force` remerges. The scheduler is unchanged.

**As built, row 6 (Compare / `50_validate.wl`, 2026-11-22):** the output
formats were left to "whatever simplifies the process"; the choices:

- `Kernel/Subpackages/Compare.wl`: the helpers each comparison script had
  its own copy of, once: `PureComplexTruthMarginal` (exact marginal of any
  statistic under a target), `SampleHistogram` (unweighted / weighted),
  `HistogramL1Distance`, `IIDL1PValue`, `IsoClassChiSquare`, and
  `PureComplexStatisticHistograms` (the pre-binning); `Tests/Compare.wlt`.
- `pipeline/50_validate.wl`: one stage file, one job per process, named by
  `COMB_VAL_JOB` (an identity knob) or a plain word: `counts`, `samples`,
  `efficiency`, `3way`, `q10_is_vs_mh`, `q10_warm_vs_prod`, `results`. Each
  job is its old script's code on the package, same knobs, inputs, output
  names and payloads; the six old scripts are shims that set the job.
  `run_is_at_truth_cells.wl` stays as it is: it samples rather than
  compares, and it computes only numV/aut/autF, so it has no package
  piece to use.
- `results/*.csv`: the `results` job (run last in `run.wl validate`, a
  "final" job, so it sees the summaries the other jobs just wrote) writes
  every summary WXF that exists as a flat table, one row per result, nested
  fields as `name_field` columns: `validation_{source}.csv`,
  `sampler_efficiency.csv`, `is_mh_truth_3way.csv`, `q10_is_vs_mh.csv`,
  `q10_warm_vs_prod.csv`; `counts` writes `counts_vs_truth.csv` (one row per
  cell and vertex count). The WXFs stay the source; the CSVs are derived, so
  no summary is recomputed to make them. Manifests as for data.
- Pre-binning: `pipeline/22_is_hists.wl` (was
  `precompute_is_histograms_q10.wl`, still in the `is` stage) also writes
  `data/p{p}q10_is_stat_hists.wxf`: every one of the 12 statistics x the 3
  targets x {all, connected}, exact value -> weighted fraction, plus ESS
  and counts per filter. Exact values, not bins, so the figures can bin as
  they like (decades for aut/autF); row 7's `render_all_figures` should
  give `largestCompRatio` fixed bins, since `Automatic` bins on the
  distinct values could differ from those on the raw samples. The numV
  hists are unchanged and still written; existing files are skipped, so on
  the store only the three new files are made (it reads the 2.8 GB of
  merged stats once).

**As built, row 7 (`60_figures.wl`, 2026-11-22):**

- `pipeline/60_figures.wl`: one stage file, one job per process, named by
  `COMB_FIG_JOB` (an identity knob) or a plain word: `fig2`,
  `truth_overlay`, `3way`, `q10_is_vs_mh`, `q10_warm_vs_prod`,
  `sampler_progress`, `uniformity`, `ecgrav_compare`, `q10_stats`. Each
  job is its old script's code with the same knobs, inputs, outputs and
  panels. The 9 `src/render_*.wl` scripts are now shims. `run.wl figures`
  keeps its labels and log names.
- On the package: the numV marginals, sample fractions and L1 come from
  Compare.wl, and the diagnostic MH chains from `PureComplexMHChain`
  (same seeds, same random stream).
- `q10_stats` (was `render_all_figures`) reads
  `p{p}q10_is_stat_hists.wxf` instead of the merged stats. Each panel is
  a Histogram of the distinct values, weighted by their fractions. With
  the same bins, the bars match the raw-sample bars to rounding.
  `largestCompRatio` gets fixed bins of width 1/20, from the 1/20 below
  the smallest value to just past the largest. On the stored samples,
  Automatic chose exactly those bins (1/10 to 21/20) for every p and
  target. On the distinct values it would choose others.
- `sampler_progress` panel C reads the first 500k batch's stats WXF (the
  same rows as `p4q10_n500000_samples.csv`) instead of the legacy CSV.
- "Reads `results/`" was not done: the CSVs hold summaries (L1, ESS, p
  values), not the bars a panel draws, so the renders still read the data
  files and recompute their labels with the same Compare.wl functions.
- With this row, Phase 4 is done.

## Phase 5: reorganise and delete

- **One mechanical `git mv` PR** into `CombResearch/`, `pipeline/`,
  `tests/`, `reference/`, `tools/dev/`. It updates:
  - every `Get` path;
  - `.ps1` code-root discovery: walk up to the folder that holds `run.wl`.
    Today `run_p4q5_mh_parallel.ps1:27`, `run_parallel.ps1:48` and
    `comb_paths.ps1:20` rely on `$PSScriptRoot`;
  - the sync hook path;
  - `CLAUDE.md`.

  Check: each launcher with `-DryRun` or tiny N, and the hook command.
- **Delete:** shims, superseded scripts, `archive/`. Git history and the
  `pre-restructure` tag keep them.
- **Untrack:** `logs/` and the Betre `.mx` files. They stay in history;
  no rewrite. *As built (PR C, 2026-11-23):* `git rm --cached` plus
  `/logs/` and `data/*.mx` in `.gitignore`. Pulling it into the main
  checkout deletes those files from the store, so back them up first
  (procedure in `docs/agent-task.md`).
- **Move into `reference/`:** the `.tex`, the Fig 2 notebooks and the
  related PDFs.
- **Hook:** the committed `.claude/settings.json` hook runs
  `powershell.exe`. Make it skip quietly when that isn't available, so
  Claude Code users on macOS or Linux don't see failures.

**As built, PR A (delete, 2026-11-23):** done first, so the move PR does not
move files that are about to go. Order: A delete, B move (stacked on A, with
the `reference/` moves and the hook), C untrack (from main).

- Deleted the 25 shims and `enumerate_truth.wl`, `run_p{2,3,4}.wl`,
  `test_streaming*.wl` (their checks are all in `Enumeration.wlt`), the
  superseded scripts of the ideal.md mapping, and tracked `archive/` except
  `related_pdfs/`.
- `run_p{p}.wl` set `*Override` variables; `pipeline/20_is_q10.wl` now reads
  the same settings as knobs (`COMB_IS_PS`, `COMB_N`, `COMB_IS_PAR`; an
  Override still wins), so `run.wl is` and `run_parallel.ps1` call the stage
  directly. `COMB_IS_PS` is an identity knob.
- Callers moved to package symbols: `PureComplexStatistics` (10_truth),
  `PureComplexMHChain` (ECGrav regression).

**As built, PR B (move, 2026-11-23):**

- Helpers in `pipeline/common/` under the ideal.md names (`paths`, `names`,
  `io`, `config`, `ecgrav`, `combresearch`); `src/` is gone.
  `run_is_at_truth_cells.wl` became `pipeline/23_is_truth_cells.wl`.
- Code root: walk up to the folder that holds `run.wl` (`.wl` and `.ps1`).
  The repo-marker guard of guarantee 1 now asks for `run.wl` and
  `config/cells.wl` instead of `src/comb_paths.wl`, so a main checkout that
  has not pulled this layout yet still receives the outputs.
- Launchers, monitors and the sync script are in `tools/dev/`; the hook
  exits 0 when `powershell.exe` is not on PATH.
- `reference/`: the `.tex`, `fig2/` notebooks (unchanged), `papers/`.

## Phase 6: upstream to ECGrav (with Dr. Betre)

Deliverable for the first conversation with Betre (a GUI that shows each
candidate piece): `phase6-deliverable.md`.

- Agree with Betre which pieces he wants:
  - `Enumeration` (exact unlabeled enumeration with McKay) and `Statistics`
    are the clearest gaps.
  - `MHSampler` overlaps ECGrav's `RandomPureSimplicialComplexMCMC`, so
    compare first.
- For each piece:
  1. Adapt it to ECGrav naming, options and usage-message style on a fork
     branch.
  2. Develop against it with `COMB_ECGRAV_DIR`.
  3. Bring its `.wlt` tests along.
  4. Open the PR.
- After a merge, our package drops that piece and calls the ECGrav version.
  The ECGrav regression and `golden/derived` confirm identical results.

## Phase 7: prove it from outside

- `README.md` quickstart.
- On the laptop, with no env vars set, in a new folder:
  - `git clone` and `run.wl all --profile quick`;
  - the same from a **GitHub zip** unpacked inside an unrelated git repo;
  - the same with git missing from PATH. ECGrav then needs a manual clone,
    and the check stage says so.
- Optional: CI on `--profile quick`. It needs a Wolfram Engine licence in
  CI.

## Decisions (2026-11-20)

1. **ECGrav tracking:** one shared, gitignored upstream clone in the main
   checkout, for now. No submodule.
2. **No escape hatch.** There are no deadlines, so runs use upstream main
   only. Drop the temporary `COMB_ECGRAV_DIR`-at-an-old-commit idea.
   `COMB_ECGRAV_DIR` stays only for pointing at a fork branch while
   preparing code for ECGrav.
3. **Upstreaming:** the user will ask Dr. Betre which pieces he wants and in
   what form (PRs or files). Phase 6 waits on that.

## Which existing data to regenerate under the latest ECGrav

Upstream main today is `474b5c2` (2026-11-11), the same commit as the
vendored `ECGrav-1.18.0-474b5c2`, so "latest" is what the scripts already
load. The review went through ECGrav's CHANGELOG and the commit history
from v1.0.0 to main, for the 14 ECGrav functions our code calls, and
checked two things against the stored data.

| Data family | Made with | ECGrav functions it depends on | What changed upstream since | Checked | Regenerate? |
|---|---|---|---|---|---|
| truth, 9 cells | older ECGrav (stored label `"1.0.0"` is hardcoded) | `IsomorphicSimplicialComplexQ`, `ChooseNonIsomorphicSimplicialComplexes`, `PureComplex{,Facet}AutomorphismGroupOrder` | aut-order code rewritten for speed (61b0916, 4abc0df); old code was correct when it finished but could hit `GroupElements::nomem` on very symmetric complexes. Mixed-facet-size overcount fix (2adc441) cannot affect pure complexes | **Latest ECGrav reproduces the stored aut and autF for all 10,882 classes across the 9 cells, zero mismatches.** Iso counts already matched the 1.17 counters (Phase 5a), and the counters' values are unchanged since | **No** |
| q=10 IS (`p{2,3,4}q10_*`), April 2026 | ECGrav ≤ v1.1.0 | `RandomVertexLabeledPureSimplicialComplex`, the two aut orders | Parallel-branch fix (8367114) is for code added after v1.1.0. The commit records chi-square tests showing the generator was always uniform. Speedups change seeded draws, not the distribution | **All 26M rows have positive numeric aut, autF and weights** (no `$Aborted`). Oddity: some p=4 `aut` values are stored as Real, not Integer | **No** (correct as is; look at the Real values) |
| MH chains | unrecorded (various, ≤ 1.17) | the two aut orders; `RandomVertexLabeled…` only for the chain start | as above | aut values verified via truth. **Phase 0 (`provenance.md`) found:** the live vertex chains at (2,4), (2,5), (2,6), (3,4) and (3,5) are from before the fix (acceptRate 1.0). The good (3,5) chain is only the `.bak`. No MH exists at (2,7), (3,6) or (4,4) | **Yes for those:** rerun the 4 vertex chains, restore or rerun (3,5) vertex, and run the 3 missing cells. Keep the rest |
| ecgmcmc | 1.17.0 | `RandomPureSimplicialComplexMCMC` | **Behaviour change:** the equilibration replica no longer starts from M disjoint facets, a trap under unlabeled weighting (87f2d5d). ESS now reported | L1 vs truth passed at 1.17, but samples come from the old start rule | **Yes, first** (small cells, hours) |
| ecgexact | 1.17.0 | `RandomUniform{Unlabeled,FacetLabeled}PureSimplicialComplex`, `RandomVertexLabeled…`, counters | speedups only; changelog states the distribution is unchanged (474b5c2, 22f1a37) | — | **Yes, second**, for consistent provenance only |
| ecglegacyfacet | 1.17.0 | `RandomFacetLabeledPureSimplicialComplex` (negative control) | none relevant | — | Only if the negative-control comparison is still wanted |

**These reruns are Phase 3a** (commands, order and follow-up there).
Truth, q=10 IS and the other MH chains stay as they are. The store's
manifests were backfilled with this provenance in Phase 2d (2026-11-21), so
the stale report shows their ECGrav version honestly instead of forcing
reruns.

Checks used (read-only, scripts kept in the session scratchpad):
`check_truth_aut_vs_latest.wl` (truth aut and autF vs latest ECGrav) and
`check_aut_numeric.wl` (q=10 merged stats scan). Worth turning both into
`tests/` checks in Phase 1, so the ECGrav regression covers them.
