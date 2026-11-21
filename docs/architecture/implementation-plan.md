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
wolframscript -file run.wl <check|truth|is|mh|ecgrav|validate|figures|all> [--profile quick|paper] [--cells "3,5;4,5"] [--force] [--dry-run]
```

- **`check`:** update ECGrav, run the regression if the commit changed,
  run the smoke tests, and report stale outputs.
- **Other stages:** set `COMB_*` env and launch the existing `.wl` drivers
  directly, never a `.ps1`, so it runs on any OS. They fan out per target
  or per p with the launchers' log names. The skip rule follows
  guarantee 2.
- **`--dry-run`:** prints the stages, cells, reasons, and every setting
  with its source.
- **New `src/render_fig2.wl`:** Fig 2 (q=3) through `load_ecgrav.wl`, with
  outputs through `comb_paths`. The reference notebooks are untouched.
- Checks:
  - the monitors work on a `run.wl` MH run;
  - the quick profile in a scratch root meets `golden/quick`;
  - `render_fig2.wl` reproduces the notebook's numbers.

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
  no rewrite.
- **Move into `reference/`:** the `.tex`, the Fig 2 notebooks and the
  related PDFs.
- **Hook:** the committed `.claude/settings.json` hook runs
  `powershell.exe`. Make it skip quietly when that isn't available, so
  Claude Code users on macOS or Linux don't see failures.

## Phase 6: upstream to ECGrav (with Dr. Betre)

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
| MH chains | unrecorded (various, ≤ 1.17) | the two aut orders; `RandomVertexLabeled…` only for the chain start | as above | aut values verified via truth; chains validate against truth on all 27 cell × target pairs | **No** |
| ecgmcmc | 1.17.0 | `RandomPureSimplicialComplexMCMC` | **Behaviour change:** the equilibration replica no longer starts from M disjoint facets, a trap under unlabeled weighting (87f2d5d). ESS now reported | L1 vs truth passed at 1.17, but samples come from the old start rule | **Yes, first** (small cells, hours) |
| ecgexact | 1.17.0 | `RandomUniform{Unlabeled,FacetLabeled}PureSimplicialComplex`, `RandomVertexLabeled…`, counters | speedups only; changelog states the distribution is unchanged (474b5c2, 22f1a37) | — | **Yes, second**, for consistent provenance only |
| ecglegacyfacet | 1.17.0 | `RandomFacetLabeledPureSimplicialComplex` (negative control) | none relevant | — | Only if the negative-control comparison is still wanted |

**Order:** ecgmcmc → ecgexact → (optional) ecglegacyfacet. Truth, q=10 IS
and MH stay as they are. Once Phase 2 adds manifests, backfill them with
the provenance in this table, so the "stale" report shows their ECGrav
version honestly instead of forcing reruns.

Checks used (read-only, scripts kept in the session scratchpad):
`check_truth_aut_vs_latest.wl` (truth aut and autF vs latest ECGrav) and
`check_aut_numeric.wl` (q=10 merged stats scan). Worth turning both into
`tests/` checks in Phase 1, so the ECGrav regression covers them.
