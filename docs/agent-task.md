# Current Agent Task

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
- Not checked: the hook firing in a new session (needs a new session), and
  any render script end to end.

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
    - In `AGENTS.md`, replace "this pin is not yet re-validated" in the
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

1. Read `AGENTS.md`.
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
Read AGENTS.md and docs/agent-task.md. Run git status --short and git diff.
Continue from the current repo state. Do not restart the task from scratch.
```

When switching from Codex to Claude Code:

```text
Read CLAUDE.md, AGENTS.md, and docs/agent-task.md. Run git status --short and
inspect the diff. Continue from the current repo state. Do not restart the task
from scratch.
```
