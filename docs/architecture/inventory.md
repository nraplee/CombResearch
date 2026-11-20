# File inventory (generated 2026-11-20 from a 5-reader + critic pass)

Raw records: `inventory_raw.json`. Patterns under data/ figures/ logs/ refer to the main checkout (`src/comb_paths.wl`).


## Group A-core-enum

Dependency core: comb_paths.wl/.ps1 (output root) and load_ecgrav.wl (ECGrav snapshot) are Get'd by nearly everything. Enumerator stack: streaming_enumerator.wl (cheap) <- bliss.wl (primitives) <- mckay.wl (Gets bliss). enumerate_truth.wl Gets all three plus pure_simplicial_compute.wl (inside Block{pListOverride={},sampleSizeOverride=0,useParallelOverride=False} to borrow statsFor - confirmed those override hooks exist at lines 13/14/50 of pure_simplicial_compute.wl). Truth WXFs data/p{p}q{q}_truth.wxf are consumed by (grep) compare_3way, compare_samplers_efficiency, render_3way, render_truth_overlay, run_ecgrav_samplers, run_is_at_truth_cells, run_mh_chains, sampler_mh, validate_counts_vs_truth, validate_mh_vs_truth. Key reproducibility gaps: (1) enumerate_truth default grid = 5 cells and gates only for those 5, while the production truth grid is 9 cells; (2) mckay pipeline writes _truth_mckay.wxf but consumers read _truth.wxf, so (4,5) needs a manual rename; (3) ecGravVersion provenance hardcoded '1.0.0'; (4) all data/**/*.wxf and *.csv gitignored (though data/p4q4SX*.mx and p4q5SX*.mx ARE tracked in git - odd exception); (5) tests use Abort[] not Exit[1] except test_streaming.wl; (6) sync_worktree_data.ps1 + .claude/settings.json are agent/worktree tooling, Windows-only, irrelevant to an outside researcher; (7) migrate_csv_to_wxf.wl is a one-off legacy migration candidate for archive/; concat_samples.wl merges by glob rather than an explicit manifest. All referenced files checked exist: ECGrav-1.0.0/1.17.0/1.18.0-474b5c2 Kernel/ECGrav.wl, pure_simplicial_compute.wl, render_uniformity_check.wl, render_sampler_progress.wl, archive/old_test_scripts/probe_mckay_primitives.wl (comment ref). run_parallel.ps1 and pure_simplicial_compute.wl reference concat_samples.wl in comments only (manual step after IS runs). Default version string '1.18.0-474b5c2' is duplicated in load_ecgrav.wl and install_ecgrav_global.wl.


### `src/comb_paths.wl`
- **kind / stage / status:** library / util / production
- **purpose:** Resolves the shared output root ($CombRoot = parent of `git rev-parse --git-common-dir`, i.e. the main checkout) and defines $CombCodeRoot, $CombDataDir, $CombFiguresDir, $CombLogsDir; creates those three dirs if missing. Idempotent (guarded by ValueQ[$CombRoot]).
- **writes:** `data/ (mkdir)`; `figures/ (mkdir)`; `logs/ (mkdir)`
- **env:** `COMB_ROOT (override output root)`
- **issues:** Depends on git being on PATH (RunProcess git); falls back to code checkout with a printed warning if not - fine for a GitHub clone, but worktree-centric design is author-machine specific; Header comment names C:\CombResearch (doc only, not code); Silently creates data/figures/logs in the main checkout as a side effect of Get

### `src/comb_paths.ps1`
- **kind / stage / status:** library / util / production
- **purpose:** PowerShell twin of comb_paths.wl, dot-sourced by launchers; defines $CombRoot/$CombDataDir/$CombFiguresDir/$CombLogsDir from git common dir (or COMB_ROOT) and creates the dirs.
- **writes:** `data/ (mkdir)`; `figures/ (mkdir)`; `logs/ (mkdir)`
- **env:** `COMB_ROOT`
- **issues:** Windows PowerShell only; duplicates logic of comb_paths.wl (two implementations to keep in sync); Requires git on PATH

### `src/load_ecgrav.wl`
- **kind / stage / status:** library / setup / production
- **purpose:** Single entry point for loading ECGrav: Gets ECGrav/ECGrav-<ver>/Kernel/ECGrav.wl directly (bypassing paclet system), default ver 1.18.0-474b5c2; defines $CombECGravVersion, $CombECGravKernelFile and combLoadECGravOnKernels[] for subkernels. Idempotent per version.
- **loads:** `ECGrav/ECGrav-1.18.0-474b5c2/Kernel/ECGrav.wl (default)`; `ECGrav/ECGrav-1.17.0/Kernel/ECGrav.wl (COMB_ECGRAV_VERSION=1.17.0)`; `ECGrav/ECGrav-1.0.0/Kernel/ECGrav.wl (COMB_ECGRAV_VERSION=1.0.0)`
- **env:** `COMB_ECGRAV_VERSION (default 1.18.0-474b5c2; 1.17.0, 1.0.0, or 'installed' = Needs)`
- **issues:** Default version string duplicated in install_ecgrav_global.wl (two places to update on pin change); Pin 1.18.0-474b5c2 not yet re-validated against truth grid (per AGENTS.md); Requires Wolfram 15.0+ (vendored PacletInfo), but Get path bypasses that check so older kernels may load and misbehave silently; Three vendored snapshots all exist in repo (checked)

### `src/install_ecgrav_global.wl`
- **kind / stage / status:** entry-script / setup / production
- **purpose:** Builds a paclet archive from the pinned vendored ECGrav snapshot, uninstalls every installed ECGrav, and PacletInstalls the snapshot globally so notebooks/src/reference/MCP server (plain Needs) match the scripts.
- **loads:** `ECGrav/ECGrav-1.18.0-474b5c2/PacletInfo.wl (+ whole snapshot dir via CreatePacletArchive)`
- **writes:** `$TemporaryDirectory/ECGrav-*.paclet (temp, deleted)`; `global Wolfram paclet store (machine state)`
- **env:** `COMB_ECGRAV_VERSION`
- **issues:** Manual per-machine step that mutates global Wolfram state (uninstalls any other ECGrav the researcher may have); Not needed for scripts, only for notebooks in src/reference/ - an outside researcher must know to run it before opening reference notebooks; Version default duplicated from load_ecgrav.wl

### `src/sync_worktree_data.ps1`
- **kind / stage / status:** util / util / production
- **purpose:** Safety net: enumerates git worktrees, finds untracked/ignored files in each worktree's data/, figures/, logs/ and copies them into the main checkout; differing files go to <dir>\_from_worktrees\<worktree>\ as conflicts. Never overwrites/deletes. -DryRun, -Quiet switches.
- **loads:** `src/comb_paths.ps1`
- **reads:** `<each worktree>/data/**`; `<each worktree>/figures/**`; `<each worktree>/logs/**`
- **writes:** `data/**, figures/**, logs/** in main checkout`; `data|figures|logs/_from_worktrees/<worktree>/** (conflicts)`
- **env:** `COMB_ROOT`
- **issues:** Developer-workflow tooling (git worktrees, Claude Code hooks); irrelevant to an outside researcher reproducing results; Windows PowerShell only; Uses Get-FileHash on potentially multi-GB WXFs - slow when sizes match but mtimes differ

### `.claude/settings.json`
- **kind / stage / status:** config / util / production
- **purpose:** Committed Claude Code project settings: SessionStart and SessionEnd hooks run src/sync_worktree_data.ps1 -Quiet via powershell.exe (timeout 300 s).
- **loads:** `src/sync_worktree_data.ps1`
- **writes:** `(via sync script) data/**, figures/**, logs/** in main checkout`
- **env:** `CLAUDE_PROJECT_DIR (set by Claude Code)`
- **issues:** Agent-tooling config, Windows-only (powershell.exe); would fail/noise on macOS/Linux Claude Code users; Not part of the scientific pipeline

### `src/streaming_enumerator.wl`
- **kind / stage / status:** library / truth-enum / production
- **purpose:** Baseline 'cheap-key' enumerator: DFS reimplementation of ECGrav GenerateAllFacetLabeledPureSimplicialComplexes emitting facet-labeled complexes one at a time, bucketed by a cheap invariant (numV, degree multiset, pair-overlap multiset) with IsomorphicSimplicialComplexQ inside buckets. Exposes canonicalKey, chooseNonIsoBucketed, streamingEnumeratePure[p,q,Parallel->].
- **loads:** `src/load_ecgrav.wl`
- **issues:** OOMs at p=4 q>=5 even sequential (documented); must use McKay pipeline there; Parallel mode uses all default subkernels (LaunchKernels implicit) - memory scales with core count; Global symbol names (canonicalKey, addOneVertex...) shared across enumerator files

### `src/streaming_enumerator_bliss.wl`
- **kind / stage / status:** library / truth-enum / production
- **purpose:** BLISS canonical-form variant: builds integer-labeled bipartite face-incidence graph with triangle gadgets (bipartiteIncidenceGraph), canonical key via CanonicalGraph edge list (blissCanonicalKey), and streamingEnumeratePureBLISS with same DFS. Kept mainly as the primitive McKay needs; not a speedup on its own.
- **loads:** `src/load_ecgrav.wl`
- **issues:** streamingEnumeratePureBLISS itself is effectively superseded (only cross-validation use); library primitives are required by McKay; Comment references archived probe_mckay_primitives.wl (exists at archive/old_test_scripts/probe_mckay_primitives.wl); Loads load_ecgrav.wl though ECGrav unused in this file

### `src/streaming_enumerator_mckay.wl`
- **kind / stage / status:** library / truth-enum / production
- **purpose:** McKay canonical-augmentation enumerator: DFS without lex constraint, pruned at each step by requiring the just-added vertex to be the canonical-removal vertex (canonicalRemovalVSide via CanonicalGraph+FindGraphIsomorphism); leaf dedup by BLISS key. Exposes streamingEnumeratePureMcKay[p,q,Parallel->]. Production path for p=4.
- **loads:** `src/load_ecgrav.wl`; `src/streaming_enumerator_bliss.wl`
- **issues:** isInCanonicalRemovalOrbit defined but unused (dead code kept 'for future reformulations'); Sets global scriptDir as side effect (clobbers caller's scriptDir if Get'd from elsewhere; harmless since same dir); 5-15x slower per emission than cheap on small cells

### `src/enumerate_truth.wl`
- **kind / stage / status:** entry-script / truth-enum / production
- **purpose:** Truth-enumeration driver: for each (p,q) runs cheap/bliss/mckay enumerator, validates iso counts against gates, computes 12-stat row per iso class via statsFor from pure_simplicial_compute.wl, computes exact piVertex (nV!/aut), piFacet (q!/autF), piUnlabeled (uniform) and atomically writes a WXF per cell.
- **loads:** `src/load_ecgrav.wl`; `src/comb_paths.wl`; `src/streaming_enumerator.wl`; `src/streaming_enumerator_bliss.wl`; `src/streaming_enumerator_mckay.wl`; `src/pure_simplicial_compute.wl (Get inside Block with pListOverride={} to borrow statsFor)`
- **reads:** `data/p{p}q{q}_truth[_bliss|_mckay].wxf (existence check for skip)`
- **writes:** `data/p{p}q{q}_truth.wxf (cheap pipeline)`; `data/p{p}q{q}_truth_bliss.wxf`; `data/p{p}q{q}_truth_mckay.wxf`; `data/*.wxf.tmp (transient)`
- **env:** `COMB_TRUTH_CELLS ("p,q;p,q"; default (2,4),(2,5),(2,6),(3,4),(3,5))`; `COMB_TRUTH_PIPELINE=cheap|bliss|mckay (default cheap)`; `COMB_TRUTH_PARALLEL=true|false (default true)`; `COMB_FORCE=1`; `COMB_ECGRAV_VERSION (via load_ecgrav)`; `COMB_ROOT (via comb_paths)`
- **issues:** Default cells cover only 5 of the 9-cell truth grid; (2,7),(3,6),(4,4),(4,5) require env var and have NO validation gate in expectedIsoCounts (e.g. (4,5)=5532 known but not registered); Output filename depends on pipeline: mckay runs write p{p}q{q}_truth_mckay.wxf, but downstream consumers read p{p}q{q}_truth.wxf - (4,5) via mckay needs manual rename/copy (manual step / hidden convention); Provenance bug: ecGravVersion hardcoded "1.0.0" instead of $CombECGravVersion (stale since pin moved to 1.18.0); Couples to pure_simplicial_compute.wl by Get-ing an entry script and suppressing its main loop via Block override variables (fragile; stats helpers should be a library); projectRoot computed but only used for git sha; enumeratorVersion labels everything streaming_enumerator.wl@sha regardless of pipeline; Truth WXFs are gitignored (data/**/*.wxf); outside researcher must regenerate; (4,5) is very long/memory-heavy and must run sequential; Parallel default may OOM on p=4 with many cores

### `src/test_streaming.wl`
- **kind / stage / status:** test / truth-enum / validation
- **purpose:** Validates cheap streaming enumerator against ECGrav eager GenerateAllFacetLabeledPureSimplicialComplexes + ChooseNonIsomorphicSimplicialComplexes: facet-labeled totals (70/794/666) and iso counts (11/26/66), plus chooseNonIsoBucketed. Exits 1 on failure.
- **loads:** `src/load_ecgrav.wl`; `src/streaming_enumerator.wl`
- **env:** `COMB_TEST_SLOW=1 (adds (2,6) and (3,5); slow, ~4 and ~26 min)`
- **issues:** Comment cites canonical answers from CLAUDE.md/render_uniformity_check.wl/render_sampler_progress.wl (files exist) - provenance of expected counts scattered; Not wired into any test runner; manual invocation only

### `src/test_streaming_bliss.wl`
- **kind / stage / status:** test / truth-enum / validation
- **purpose:** Sanity checks blissCanonicalKey (relabeling invariance, non-iso distinctness) and compares cheap vs BLISS enumerators (parallel) on iso counts with timing/speedup table; aborts on mismatch.
- **loads:** `src/streaming_enumerator.wl (which loads src/load_ecgrav.wl)`; `src/streaming_enumerator_bliss.wl`
- **env:** `COMB_TEST_CELLS (default (2,4),(2,5),(2,6),(3,4),(3,5))`
- **issues:** Default includes (3,5) run twice in parallel - long runtime for a 'smoke test'; Abort[] rather than Exit[1] on failure: wolframscript exit code may not signal failure to CI; Unicode check marks in output

### `src/test_streaming_mckay.wl`
- **kind / stage / status:** test / truth-enum / validation
- **purpose:** Sequentially runs cheap, BLISS and McKay enumerators on each cell, profiling time and peak-memory delta, and asserts all three agree with expected iso counts (default (2,4),(3,4)).
- **loads:** `src/streaming_enumerator.wl (which loads src/load_ecgrav.wl)`; `src/streaming_enumerator_bliss.wl`; `src/streaming_enumerator_mckay.wl`
- **env:** `COMB_TEST_CELLS (default (2,4),(3,4))`
- **issues:** Abort[] instead of nonzero exit on failure; No gate for p=4 cells where McKay is actually the production path

### `src/migrate_csv_to_wxf.wl`
- **kind / stage / status:** util / IS-compute(Fig2) / one-off
- **purpose:** One-shot migration of legacy q=10 importance-sampling CSVs (data/p{p}q10_n{n}[_tag]_samples.csv, 15-column stats+weights) into data/p{p}q10_n{n}[_tag]_stats.wxf associations; skips existing WXFs, leaves CSVs.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/*_samples.csv (expects p{p}q{q}_n{n}[_tag]_samples.csv)`
- **writes:** `data/p{p}q10_n{n}[_tag]_stats.wxf`
- **env:** `COMB_ROOT (via comb_paths)`
- **issues:** q hardcoded to 10 in payload even though parsed q from filename is discarded; Legacy migration; inputs (CSV) are gitignored and not reproducible except by rerunning old pipeline - should move to archive/; projectRoot computed but unused; Non-atomic Export

### `src/concat_samples.wl`
- **kind / stage / status:** util / IS-compute(Fig2) / production
- **purpose:** For p in {2,3,4}, merges all data/p{p}q10_*_stats.wxf (and sibling _complexes.wxf) from multiple IS compute runs into data/p{p}q10_merged_stats.wxf / _merged_complexes.wxf and prints combined ESS for unlabeled/facet weights.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q10_*_stats.wxf`; `data/p{p}q10_*_complexes.wxf`
- **writes:** `data/p{p}q10_merged_stats.wxf`; `data/p{p}q10_merged_complexes.wxf`
- **env:** `COMB_ROOT (via comb_paths)`
- **issues:** Glob p{p}q10_*_stats.wxf picks up EVERY matching file in data/ (any stale/test run) - merged result depends on whatever happens to be in data/, not a declared manifest; q=10 and p list hardcoded; Rerunning is not idempotent-safe if other *_stats.wxf files (e.g. other script outputs) share the pattern; Merged files ~GB scale, gitignored; reproduction requires rerunning long IS compute (pure_simplicial_compute / run_parallel.ps1) first; Non-atomic Export; projectRoot unused

## Group B-IS-fig2

Group B (IS / Figure 2 and Figures 3-15) dataflow:

Figure 2 (q=3): histograms_handoff_v2.nb (Needs ECGrav, global paclet) leaves kernel state for histograms_paper_figures.nb. Both export p3q3_n10000_* CSVs and PDFs to the front end's Directory[], not to repo paths. These are manual notebook steps with no script equivalent, and the outputs are untracked.

Figures 3-15 (q=10): run_parallel.ps1 starts run_p{p}.wl (COMB_N, COMB_RUNTAG, COMB_PLIST) in parallel, each running pure_simplicial_compute.wl (load_ecgrav + comb_paths). Each writes data/p{p}q10_n{N}[_tag]_{stats,complexes}.wxf, chunked and checkpointed, with logs at logs/compute_p{p}[_tag].{log,err}. Then concat_samples.wl (another group) produces data/p{p}q10_merged_{stats,complexes}.wxf. The main checkout holds n500000 + n1500000_batch2 + n10000000_batch3 (p3, p4 only), which gives about 12M rows. From the merged stats:
- render_all_figures.wl writes figures/{manuscript_panels,stacked_previews,combined}.
- precompute_is_histograms_q10.wl writes data/p{p}q10_is_{target}_numv_hist.wxf, consumed by the q10-compare, 3way and warm-vs-prod scripts.

Superseded or dead files:
- pure_simplicial_compute_overnight.wl (sequential, stale CSV comments)
- precompute_is_histogram.wl (same output name as the q10 version)
- pure_simplicial_figures.nb (reads the legacy n500000 CSVs)
- probe_betre_mx.wl (macOS-only .mx files, which are tracked in git under data/; the purpose is settled by ECGrav 1.17 counters)

Library coupling: pure_simplicial_compute.wl is also Get'd as a helper library by enumerate_truth.wl, run_mh_chains.wl and run_ecgrav_samplers.wl, so the stats code and the sampling entry point should be split into a library such as stats.wl.

Main reproducibility gaps:
- The merged dataset recipe (which N and RUNTAGs, then concat) is not encoded anywhere.
- Multi-day runtime and about 9 GB of gitignored data, with no release or download path; small histogram WXFs could be shipped instead.
- PowerShell-only launcher.
- Three duplicate run_p*.wl wrappers.
- Figure 2 is notebook-only, with outputs written to cwd.
- Configuration is env vars plus pre-Get globals.
- Stale CSV-era comments throughout.

Missing-file references: render_all_figures.wl's CSV fallback p{p}q10_merged_samples.csv is never produced. All Get targets (load_ecgrav.wl, comb_paths.wl, comb_paths.ps1, streaming_enumerator_bliss.wl, pure_simplicial_compute.wl, run_p{2,3,4}.wl) exist in src/.


### `src/pure_simplicial_compute.wl`
- **kind / stage / status:** library / IS-compute(Fig2) / production
- **purpose:** Core q=10 importance-sampling (IS) pipeline: draws vertex-labeled pure complexes with ECGrav RandomVertexLabeledPureSimplicialComplex for p in pList, computes 12 per-sample statistics (numV, aut, autF, connectivity, k-path components, Z2 Betti numbers) plus vertex/unlabeled/facet reweighting weights, and writes chunked, checkpointed WXFs that are consolidated per p. It doubles as a helper library: enumerate_truth.wl, run_mh_chains.wl and run_ecgrav_samplers.wl Get it to pull statsFor and friends.
- **loads:** `src/load_ecgrav.wl`; `src/comb_paths.wl`
- **reads:** `data/p{p}q10_n{N}[_nn{nn}][_{runTag}]_chunk_{k}_{stats,complexes}.wxf (resume/consolidate)`
- **writes:** `data/p{p}q10_n{N}[_nn{nn}][_{runTag}]_chunk_{k}_stats.wxf (temporary, deleted after consolidation)`; `data/p{p}q10_n{N}[_nn{nn}][_{runTag}]_chunk_{k}_complexes.wxf (temporary)`; `data/p{p}q10_n{N}[_nn{nn}][_{runTag}]_stats.wxf (Association: headers, rows, p, q, n, runTag, createdAt)`; `data/p{p}q10_n{N}[_nn{nn}][_{runTag}]_complexes.wxf`; `stdout ESS report`
- **env:** `COMB_NN_FIXED (fixed-numV conditional mode, 3-arg sampler form)`; `COMB_RUNTAG (filename suffix plus MD5-hash seed offset)`; `COMB_ROOT (via comb_paths)`; `COMB_ECGRAV_VERSION (via load_ecgrav)`; `Wolfram-level overrides set before Get: pListOverride, sampleSizeOverride (default 10000), nnFixedOverride, runTagOverride, useParallelOverride, chunkSizeOverride (default 25000)`
- **issues:** Side-effectful when Get'd as a library: callers must set pListOverride={} or similar to avoid launching sampling. Mixing a library with an entry script is fragile.; Configuration is a mix of env vars and pre-Get global symbols. There is no CLI or config file, so a run is not self-describing beyond the metadata in the final WXF.; The header comment says the outputs are stats/complexes WXF, but downstream wrappers and docs still talk about *_samples.csv (stale CSV-era naming).; Seeds are deterministic (123456 + runSeedOffset + 1000p + k), but ParallelMap is used only for stats, so results are reproducible. Merged production data, however, came from several runs (n500000 + batch2 + batch3) stitched together by concat_samples.wl, and that is not captured anywhere as a single command.; Production scale (12M rows per p) takes days of compute and the outputs are about 9 GB, gitignored and not in GitHub, so an outside researcher must regenerate or download them from somewhere.; The output root depends on git (comb_paths runs git rev-parse) and falls back to the code root if git is missing.

### `src/pure_simplicial_compute_overnight.wl`
- **kind / stage / status:** entry-script / IS-compute(Fig2) / superseded
- **purpose:** Thin wrapper that sets sampleSizeOverride=500000 and Gets pure_simplicial_compute.wl for all p in {2,3,4} sequentially.
- **loads:** `src/pure_simplicial_compute.wl`
- **writes:** `data/p{2,3,4}q10_n500000[_{runTag}]_{stats,complexes}.wxf (plus transient chunk files)`
- **env:** `COMB_RUNTAG`; `COMB_NN_FIXED`; `COMB_ROOT`; `COMB_ECGRAV_VERSION`
- **issues:** Stale header: claims the output is p{2,3,4}q10_n500000_samples.csv 'next to this script'. The real output is WXF in $CombDataDir.; About 11 h wall-clock, single process. Superseded by run_parallel.ps1 plus run_p{2,3,4}.wl.; Suggests redirecting to overnight.log in cwd, which bypasses $CombLogsDir.

### `src/run_p2.wl`
- **kind / stage / status:** entry-script / IS-compute(Fig2) / production
- **purpose:** Per-p wrapper (p=2) for pure_simplicial_compute.wl with ParallelMap on and sample size taken from COMB_N (default 500000). Launched by run_parallel.ps1.
- **loads:** `src/pure_simplicial_compute.wl`
- **writes:** `data/p2q10_n{N}[_{runTag}]_{stats,complexes}.wxf`
- **env:** `COMB_N`; `COMB_RUNTAG`; `COMB_NN_FIXED`; `COMB_ROOT`; `COMB_ECGRAV_VERSION`
- **issues:** Duplicated logic: run_p2/run_p3/run_p4 are identical except for pListOverride. One script taking p as an argument or env var would do.; Comment says the default is 500000, so a bare run is a multi-hour job.

### `src/run_p3.wl`
- **kind / stage / status:** entry-script / IS-compute(Fig2) / production
- **purpose:** Per-p wrapper (p=3) for pure_simplicial_compute.wl with ParallelMap on and N from COMB_N (default 500000).
- **loads:** `src/pure_simplicial_compute.wl`
- **writes:** `data/p3q10_n{N}[_{runTag}]_{stats,complexes}.wxf`
- **env:** `COMB_N`; `COMB_RUNTAG`; `COMB_NN_FIXED`; `COMB_ROOT`; `COMB_ECGRAV_VERSION`
- **issues:** Copy of run_p2.wl with a different p (duplicated logic).

### `src/run_p4.wl`
- **kind / stage / status:** entry-script / IS-compute(Fig2) / production
- **purpose:** Per-p wrapper (p=4) for pure_simplicial_compute.wl with ParallelMap on and N from COMB_N (default 500000).
- **loads:** `src/pure_simplicial_compute.wl`
- **writes:** `data/p4q10_n{N}[_{runTag}]_{stats,complexes}.wxf`
- **env:** `COMB_N`; `COMB_RUNTAG`; `COMB_NN_FIXED`; `COMB_ROOT`; `COMB_ECGRAV_VERSION`
- **issues:** Copy of run_p2.wl with a different p (duplicated logic).; p=4 is the slowest: about 6 h per 500k samples according to the overnight wrapper comment.

### `src/run_parallel.ps1`
- **kind / stage / status:** launcher(ps1) / IS-compute(Fig2) / production
- **purpose:** Launches one wolframscript process per p (default p in {3,4}) running src/run_p{p}.wl in parallel, with stdout and stderr redirected to logs, and waits for all of them. Passes the sample size via COMB_N and the run tag via COMB_RUNTAG.
- **loads:** `src/comb_paths.ps1`; `src/run_p2.wl`; `src/run_p3.wl`; `src/run_p4.wl`
- **writes:** `logs/compute_p{p}[_{RUNTAG}].log`; `logs/compute_p{p}[_{RUNTAG}].err`; `(via wrappers) data/p{p}q10_n{N}[_{RUNTAG}]_{stats,complexes}.wxf`
- **env:** `N (sample size, default 500000), mapped to COMB_N`; `RUNTAG, mapped to COMB_RUNTAG`; `COMB_PLIST (default "3,4"; p=2 is dropped by default)`; `COMB_ROOT (via comb_paths.ps1)`
- **issues:** Windows PowerShell only (Start-Process, Wait-Process). There is no bash or cross-platform launcher.; Its default pList {3,4} differs from AGENTS.md's implied 'all p'. A fresh researcher would get no p=2 data unless they set COMB_PLIST.; Stale comments refer to p{p}q10_n{N}_{RUNTAG}_samples.csv; the actual outputs are WXF.; The ad hoc env names N and RUNTAG are inconsistent with the COMB_* convention.; Producing the merged 12M-row datasets needs several runs with different RUNTAGs (batch2, batch3) followed by concat_samples.wl. That sequence is undocumented as a single recipe.; Tuned for 8C/16T hardware (Ryzen); giant runtime.

### `src/render_all_figures.wl`
- **kind / stage / status:** render / render / production
- **purpose:** Renders q=10 Figures 3-15 (13 statistics, p in {2,3,4}) as translucent overlaid weighted histograms of the vertex/facet/unlabeled reweightings from the merged IS stats. Exports per-p manuscript panel PDFs, stacked per-figure PDF/PNG previews and a combined multi-page PDF, and prints ESS warnings first.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{2,3,4}q10_merged_stats.wxf (preferred)`; `data/p{2,3,4}q10_merged_samples.csv (legacy fallback; does not exist)`
- **writes:** `figures/manuscript_panels/p{p}q10[conn]SX{Stat}_merged.pdf (about 30 panels)`; `figures/stacked_previews/fig{03..15}_{name}.pdf`; `figures/stacked_previews/fig{03..15}_{name}.png`; `figures/combined/combined_all_figures_merged.pdf`
- **env:** `COMB_ROOT (via comb_paths)`
- **issues:** Depends on p{p}q10_merged_stats.wxf, which only exists after several IS runs plus concat_samples.wl. Nothing in this file or AGENTS.md chains them.; Loads the full 12M-row WXF per p into memory, which is heavy on RAM and slow.; The sampleTag 'merged' and sampleSize=12000000 are hardcoded. Older *_n500k panels in git came from a previous version with a different tag, so tracked figures/ hold mixed generations.; The CSV fallback filename (_merged_samples.csv) is never produced; it is dead code.; No Get of load_ecgrav (not needed), but the header still says the data is in ../data/, which is stale since the switch to comb_paths.; The q=10 facet/unlabeled histograms have a documented ESS collapse (docs/sampling.md), so the figures may be unreliable.

### `src/precompute_is_histogram.wl`
- **kind / stage / status:** util / q10-compare / superseded
- **purpose:** One-off script that aggregates the p=4 q=10 merged IS stats into a numV histogram under unlabeled reweighting, with ESS computed in exact rationals.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p4q10_merged_stats.wxf`
- **writes:** `data/p4q10_is_unlabeled_numv_hist.wxf`
- **env:** `COMB_ROOT (via comb_paths)`
- **issues:** Superseded by precompute_is_histograms_q10.wl, which writes the same output filename (collision: whichever runs last wins). This one has no skip/force guard and always overwrites.; Uses exact-rational weights, which is very slow on 12M rows.; The print message says data/... although it actually writes to $CombDataDir.

### `src/precompute_is_histograms_q10.wl`
- **kind / stage / status:** util / q10-compare / production
- **purpose:** Aggregates the merged 12M-row q=10 IS stats into nine small numV histograms (p in {2,3,4} x target in {vertex, unlabeled, facet}), using float weights and GroupBy, with ESS. These feed the IS-vs-MH q=10 comparisons and the 3-way/warm-vs-prod renders.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{2,3,4}q10_merged_stats.wxf`
- **writes:** `data/p{p}q10_is_{vertex,unlabeled,facet}_numv_hist.wxf (Association p, q, target, sourceN, ESS, fracHist)`
- **env:** `COMB_FORCE=1 (overwrite existing)`; `COMB_ROOT (via comb_paths)`
- **issues:** Requires the merged multi-GB stats WXFs, which are not in git. The small histogram outputs could be committed or released so q=10 comparisons are reproducible without the 12M-row data.; The p, target loops are hardcoded, with no cell restriction knob.; Consumers: compare_is_mh_q10.wl, render_q10_is_vs_mh.wl, compare_q10_warm_vs_prod.wl, render_q10_warm_vs_prod.wl, compare_3way.wl, render_3way.wl, run_is_at_truth_cells.wl (numv_hist references).

### `src/probe_betre_mx.wl`
- **kind / stage / status:** compare/validate / util / dead
- **purpose:** One-off inspector for Dr. Betre's .mx binary dumps of (4,4)/(4,5) facet-labeled and unlabeled samples. It Gets each .mx, lists the new Global symbols, and counts distinct isomorphism classes via blissCanonicalKey, as a cross-check of the (4,5) iso count of 5,532.
- **loads:** `src/comb_paths.wl`; `src/streaming_enumerator_bliss.wl`
- **reads:** `data/p4q4SXFacetLabeled.mx`; `data/p4q4SXUnlabeled.mx`; `data/p4q5SXFacetLabeled.mx`; `data/p4q5SXUnlabeled.mx`
- **writes:** `stdout only`
- **env:** `COMB_ROOT (via comb_paths)`
- **issues:** The .mx files are platform-locked (MacOSX-ARM64 per docs/agent-task.md), so they cannot be loaded on Windows or Linux. The probe cannot succeed on the project machines.; The four .mx files are tracked in git under data/ (unusual: data/ is otherwise gitignored), so binary blobs are in the repo.; Made obsolete by Phase 5a: ECGrav 1.17 exact counters confirmed the 5,532 count (docs/ecgrav_1.17_validation_note.md). This is an archive candidate together with the .mx files.

### `src/pure_simplicial_figures.nb`
- **kind / stage / status:** notebook / render / superseded
- **purpose:** Interactive notebook version of render_all_figures.wl for Figures 3-15. It loads the per-p sample CSVs, prints ESS, and builds 3x1 stacked translucent weighted-histogram columns, displaying them without exporting.
- **loads:** `src/comb_paths.wl (conditional on it sitting next to the notebook)`
- **reads:** `data/p{2,3,4}q10_n500000_samples.csv (legacy CSV; fallback dirs ../data or NotebookDirectory[])`
- **writes:** `none (display only)`
- **env:** `COMB_ROOT (via comb_paths)`
- **issues:** Reads only the legacy n500000 CSVs, which the current compute no longer produces (it writes WXF). It does not use the merged 12M data, so its results diverge from render_all_figures.wl.; Duplicates all panel and style logic from render_all_figures.wl (duplicated logic).; The front end is required (manual step). Its FrontEndVersion says 14.3 while the repo requires 15.0+.

### `src/reference/histograms_handoff_v2.nb`
- **kind / stage / status:** notebook / IS-compute(Fig2) / production
- **purpose:** Figure 2 reference workflow at p=3, q=3. It samples 10k vertex-labeled complexes (seed 123456), classifies them into iso classes using automorphism orders, computes theory distributions, reweights to unlabeled and facet-labeled (paper Eq. 25), runs an exact facet-labeled enumeration as a sanity check using GenerateAllFacetLabeledPureSimplicialComplexes, and exports class tables, distribution CSVs and diagnostic plot PDFs.
- **loads:** `ECGrav` via Needs/ParallelNeeds (the globally installed paclet, not load_ecgrav.wl)`
- **writes:** `{Directory[]}/p3q3_n10000_class_table.csv`; `{Directory[]}/p3q3_n10000_{vertex_theory,facet_formula_theory,unlabeled_uniform_theory,vertex_empirical,weighted_unlabeled,weighted_facet,facet_exact_enumerated}_distribution.csv`; `{Directory[]}/p3q3_n10000_facet_comparison_table.csv`; `{Directory[]}/p3q3_n10000_{unweighted_vertex,vertex_vs_theory,weighted_unlabeled,facet_vs_formula_theory,facet_formula_vs_exact,facet_vs_exact_theory}_plot.pdf`
- **env:** `none (parameters hardcoded in a cell: pq={3,3}, sampleSize=10000, randomSeed=123456, runExactFacetEnumeration, exportResults)`
- **issues:** Exports use bare relative filenames, so they land in the front end's current Directory[] (typically the user's Documents folder), not data/ or figures/. None of the p3q3_* outputs are tracked or in the main checkout's data/.; Uses Needs["ECGrav`"] (global paclet), which bypasses the pinned load_ecgrav.wl. Reproducibility depends on running install_ecgrav_global.wl first.; Manual front-end step only; it cannot be run headless as a script. The do-not-edit rule (AGENTS.md) blocks fixing the paths.; Figure 2 is 'complete', but its regeneration is undocumented as a command.; Its FrontEndVersion is 14.3, while the pinned ECGrav needs 15.0+.

### `src/reference/histograms_paper_figures.nb`
- **kind / stage / status:** notebook / render / production
- **purpose:** Produces the four Figure 2 paper panels (unweighted, vertex-labeled, facet-labeled, unlabeled histograms with theory dots) and a combined 2x2 PDF for p=3, q=3. It has no Import: it consumes variables (baseName, vertexEmpiricalDist, vertexTheoryDist, weightedFacetDist, weightedUnlabeledDist, unlabeledTheoryDist, ...) left in the kernel by histograms_handoff_v2.nb.
- **loads:** `(implicit kernel state from src/reference/histograms_handoff_v2.nb; must be run in the same kernel session after it)`
- **writes:** `{Directory[]}/p3q3_n10000_fig_unweighted.pdf`; `{Directory[]}/p3q3_n10000_fig_vertex_labeled.pdf`; `{Directory[]}/p3q3_n10000_fig_facet_labeled.pdf`; `{Directory[]}/p3q3_n10000_fig_unlabeled.pdf`; `{Directory[]}/p3q3_n10000_fig2_combined.pdf`
- **env:** `none`
- **issues:** Hidden dependency: it works only if handoff_v2.nb was evaluated first in the same kernel. There is no file handoff.; Outputs go to the front end's cwd (relative filenames), not figures/. The Figure 2 PDFs are not tracked in git.; Manual front-end step, not scriptable. The do-not-edit rule prevents refactoring.; The large file size (about 200 KB) comes from embedded output cells.

## Group C-MH-q10

Group C (MH + q=10) all hangs off two Wolfram files: src/sampler_mh.wl (library) and src/run_mh_chains.wl (the only driver). run_mh_chains.wl Gets sampler_mh.wl, comb_paths.wl and pure_simplicial_compute.wl. It loads pure_simplicial_compute.wl only to get statsFor and exportWxfAtomic, and uses Block overrides to stop that script's sampling loop. ECGrav comes in through load_ecgrav.wl, which is pulled in twice: once by sampler_mh.wl and once by pure_simplicial_compute.wl.

The four PowerShell launchers do not compute anything themselves. Each one sets COMB_MH_* env vars and spawns run_mh_chains.wl:
- p4q5 parallel
- q10 pilot
- q10 parallel
- q10 overnight

All MH outputs follow the pattern data/p{p}q{q}_mh_{target}{tag}.wxf. The q10 pilot and q10 production runs write the same untagged filename, so a later reader cannot tell which budget produced a file without opening it.

Downstream consumers:
- validate_mh_vs_truth.wl: checks truth against mh or ecg* samples and writes data/validation_{source}_summary.wxf.
- render_truth_overlay.wl: draws truth vs MH and writes figures/manuscript_panels, stacked_previews and combined.
- compare_is_mh_q10.wl and render_q10_is_vs_mh.wl: need data/p{p}q10_is_{target}_numv_hist.wxf from precompute_is_histograms_q10.wl (another group).
- compare_q10_warm_vs_prod.wl and render_q10_warm_vs_prod.wl: also need the tagged _seed67890_warm{14,18} files from the overnight run.

Every referenced repo file exists: load_ecgrav.wl, comb_paths.wl/.ps1, pure_simplicial_compute.wl, render_all_figures.wl, render_sampler_progress.wl, docs/sampling.md, enumerate_truth.wl, run_ecgrav_samplers.wl and precompute_is_histograms_q10.wl. No hardcoded C:/ paths remain; all paths go through comb_paths.

Reproducibility problems for an outside researcher:
1. All parallel orchestration and monitoring is Windows PowerShell only (Start-Process powershell.exe, hidden windows, Get-Process wolfram).
2. Configuration is env vars only, and the launchers leak them into the parent shell.
3. run_mh_chains.wl defaults to the old 5-cell grid, so no single command regenerates MH for all 9 truth cells. Only (4,5) has a launcher; (2,7), (3,6) and (4,4) depend on someone setting COMB_MH_CELLS by hand.
4. Experiment parameters are scattered and duplicated: seed 67890 and warm numV 14/18 appear in 3 files, and helpers like binMh/l1 are copied into 4 files.
5. Some scripts fail hard on missing inputs (the q10 compare/render warm scripts and render_q10_is_vs_mh); render_truth_overlay instead drops the MH layer silently.
6. validate_mh_vs_truth.wl uses an unseeded Monte Carlo p-value and never exits non-zero on FAIL.
7. Runtimes are long: hours for (4,5) and q=10 at 200k, about 5 hours for the overnight run. The q=10 comparisons also depend on the large 12M-row IS dataset, which is not in git.
8. run_q10_mh_overnight.ps1 has a one-time file-restore step built in.
9. render_q10_is_vs_mh.wl is undocumented: it is not in AGENTS.md and nothing references it.

MH chains themselves are seeded deterministically (default seed 12345), so they are reproducible given the same Wolfram version and ECGrav pin.


### `src/sampler_mh.wl`
- **kind / stage / status:** library / MH / production
- **purpose:** Fixed-ambient-[N=q*p] Metropolis-Hastings sampler over vertex-labeled pure simplicial complexes with acceptance ratios for unlabeled/facet/vertex targets (vertex uses 1/C(N,numV), 2026-05-14 fix); defines proposal kernels (global/local/swap/mixed), mhStep, initialState, warmInitialState, runMHChain, integratedAutocorrTime. When run directly (and $smokeTestSkip not set) runs a 5000-iter smoke test at q=10 for p=2,3,4.
- **loads:** `src/load_ecgrav.wl`
- **issues:** Uses ECGrav PureComplexAutomorphismGroupOrder / PureComplexFacetAutomorphismGroupOrder / RandomVertexLabeledPureSimplicialComplex: results depend on the pinned vendored ECGrav snapshot and Wolfram 15.0+ (proprietary).; Smoke test fires on any Get unless caller sets $smokeTestSkip=True before loading (side-effect-on-load pattern).; RNG is seeded once in initialState/warmInitialState (deterministic for a given seed + Wolfram version), but stream reproducibility across Wolfram versions is not guaranteed.; References docs/sampling.md for kernel benchmarks (exists).

### `src/run_mh_chains.wl`
- **kind / stage / status:** entry-script / MH / production
- **purpose:** MH chain driver: for each (p,q) cell x target runs runMHChain, computes the 12-stat row per kept state via statsFor (from pure_simplicial_compute.wl), and writes one WXF per cell x target; skip-if-exists unless COMB_FORCE=1. Has an inline (3,5)/unlabeled L1<0.05 gate against truth that Aborts on failure.
- **loads:** `src/sampler_mh.wl`; `src/comb_paths.wl`; `src/pure_simplicial_compute.wl`; `src/load_ecgrav.wl (via sampler_mh.wl and pure_simplicial_compute.wl)`
- **reads:** `data/p3q5_truth.wxf (gate only, when p=3,q=5,target=unlabeled, no tag, default init)`
- **writes:** `data/p{p}q{q}_mh_{target}{tag}.wxf (e.g. data/p3q10_mh_facet_seed67890_warm14.wxf); written atomically via exportWxfAtomic`
- **env:** `COMB_MH_CELLS (default 2,4;2,5;2,6;3,4;3,5)`; `COMB_MH_TARGETS (default unlabeled,facet,vertex)`; `COMB_MH_NUMITER (200000)`; `COMB_MH_BURNIN (20000)`; `COMB_MH_THIN (5)`; `COMB_MH_SEED (12345)`; `COMB_MH_KERNEL (global)`; `COMB_MH_TAG ("")`; `COMB_MH_INITNUMV (unset=Automatic)`; `COMB_MH_OUTDIR (overrides $CombDataDir; not documented in header)`; `COMB_FORCE=1`; `COMB_ROOT (via comb_paths.wl)`
- **issues:** Default cell list is the old 5-cell Phase-2 grid, not the current 9-cell truth grid; (2,7),(3,6),(4,4),(4,5) and q=10 need COMB_MH_CELLS set by hand or by a launcher, so there is no single command that regenerates all MH data.; Config is env-var-only; the run parameters for each published WXF exist only in launcher scripts/handoff notes.; Get's pure_simplicial_compute.wl purely for statsFor/exportWxfAtomic, relying on Block[{pListOverride={},sampleSizeOverride=0,...}] to suppress that script's sampling loop - fragile coupling; statsFor should live in a library.; samplerVersion shells out to git rev-parse (needs git on PATH; records HEAD only, not dirty state).; Inline (3,5) gate duplicates logic in validate_mh_vs_truth.wl; gate silently skips if truth WXF missing.; Production runtime: 200k iters x 3 targets per cell; at (4,5) and q=10 this is hours.

### `src/run_p4q5_mh_parallel.ps1`
- **kind / stage / status:** launcher(ps1) / MH / production
- **purpose:** Launches three parallel wolframscript processes of run_mh_chains.wl at cell (4,5), one per target (unlabeled, facet, vertex), redirecting stdout/stderr to per-target logs, then waits and tails logs.
- **loads:** `src/comb_paths.ps1`; `src/run_mh_chains.wl (Start-Process wolframscript -file)`
- **writes:** `data/p4q5_mh_{unlabeled,facet,vertex}.wxf (via run_mh_chains.wl)`; `logs/mh_p4q5_{target}.log`; `logs/mh_p4q5_{target}.err`
- **env:** `COMB_MH_NUMITER`; `COMB_MH_BURNIN`; `COMB_MH_THIN`; `COMB_MH_SEED`; `COMB_MH_KERNEL`; `COMB_FORCE`; `sets COMB_MH_CELLS=4,5 and COMB_MH_TARGETS per child`
- **issues:** Windows PowerShell only (Start-Process -NoNewWindow, $env:, Wait-Process).; Mutates the parent shell's COMB_MH_* env vars, which leak into later commands in the same session.; Builds logs dir as Join-Path $CombRoot 'logs' rather than using $CombLogsDir.; Hardcoded to a single cell (4,5); the other new truth cells have no launcher.; Comment says 'Stop by Task Manager / Get-Process wolfram | Stop-Process' - manual intervention.

### `src/monitor_mh.ps1`
- **kind / stage / status:** monitor / util / production
- **purpose:** Infinite-loop console dashboard that lists wolfram/wolframscript processes (CPU, memory) and, for one cell, tails logs/mh_p{p}q{q}_{target}.log and reports whether data/p{p}q{q}_mh_{target}.wxf exists. Read-only observer.
- **loads:** `src/comb_paths.ps1`
- **reads:** `logs/mh_p{p}q{q}_{target}.log`; `data/p{p}q{q}_mh_{target}.wxf (existence/size/mtime only)`
- **env:** `COMB_MON_INTERVAL (15)`; `COMB_MON_CELL (4,5)`; `COMB_MON_TAIL (4)`
- **issues:** Windows-only (Get-Process wolfram, Clear-Host, PowerShell).; Only understands the mh_p{p}q{q}_{target}.log naming from run_p4q5_mh_parallel.ps1; does not match q=10 pilot/prod/overnight log names.; Not needed for reproduction; pure convenience tooling.

### `src/validate_mh_vs_truth.wl`
- **kind / stage / status:** compare/validate / MH / validation
- **purpose:** For each (p,q) x target, compares a sample source's numV histogram against the exact truth marginal (L1 vs threshold), plus iid multinomial p-value, per-iso-class chi-square when classIdx present, and worst L1 across other stat marginals; prints ASCII overlay + summary and writes a summary WXF. Source selectable: mh, ecgexact, ecgmcmc, ecglegacyfacet.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q{q}_truth.wxf`; `data/p{p}q{q}_{source}_{target}.wxf (source in mh|ecgexact|ecgmcmc|ecglegacyfacet)`
- **writes:** `data/validation_{source}_summary.wxf`
- **env:** `COMB_VAL_CELLS (default 9-cell grid)`; `COMB_VAL_TARGETS`; `COMB_VAL_THRESHOLD (0.05)`; `COMB_VAL_SOURCE (mh)`; `COMB_ROOT (via comb_paths.wl)`
- **issues:** Does not exit non-zero on FAIL (only prints), so it cannot gate an automated pipeline.; iidL1PValue uses RandomVariate without SeedRandom - p-values are nondeterministic run to run.; Output written into data/ alongside inputs; summary overwritten per source.; Script name says mh but it is the general validator for ECGrav sources too (naming confusion).; Defines projectRoot but never uses it.

### `src/render_truth_overlay.wl`
- **kind / stage / status:** render / render / production
- **purpose:** Renders manuscript overlay panels of exact-truth stat marginals (blue) vs MH chain empirical marginals (red) for 11 statistics x 3 targets over the 9-cell truth grid; MH layer skipped where WXF missing. Emits per-panel PDFs, stacked per-figure previews, and a combined multi-page PDF.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q{q}_truth.wxf`; `data/p{p}q{q}_mh_{target}.wxf (optional)`
- **writes:** `figures/manuscript_panels/truthSX{Stat}[_conn]_p{p}q{q}_{target}.pdf`; `figures/stacked_previews/truth_{figNN_stem}_{target}.pdf`; `figures/stacked_previews/truth_{figNN_stem}_{target}.png`; `figures/combined/combined_truth_overlay.pdf`
- **env:** `COMB_TRUTH_CELLS (reused from enumerate_truth.wl as a cell restriction)`; `COMB_ROOT (via comb_paths.wl)`
- **issues:** Header comment says 'Truth/MH overlay' while AGENTS.md describes it as 'truth + MH + IS layers'; there is no IS layer (stale doc).; Reuses env var COMB_TRUTH_CELLS for a different meaning (render restriction).; Style constants and figure list duplicated from render_all_figures.wl (comment cites line numbers 36-56, 211-224 which will drift).; Missing MH WXFs silently produce truth-only panels - a reproducer cannot tell from output whether MH data was absent.; Only reads source mh, not the validated ECGrav exact samplers.; Comment refers to src/render_sampler_progress.wl for q=10 panels (file exists).

### `src/run_q10_mh_pilot.ps1`
- **kind / stage / status:** launcher(ps1) / MH / superseded
- **purpose:** Sequential short MH pilot at q=10 for p in {2,3,4} x {vertex,unlabeled,facet} (10k iter, 1k burn-in, thin 2) via run_mh_chains.wl, timing each and tee-ing output to a log.
- **loads:** `src/comb_paths.ps1`; `src/run_mh_chains.wl (wolframscript -file)`
- **writes:** `data/p{p}q10_mh_{target}.wxf (via run_mh_chains.wl)`; `logs/mh_q10_pilot_p{p}_{target}.log`
- **env:** `COMB_PILOT_NUMITER (10000)`; `COMB_PILOT_BURNIN (1000)`; `COMB_PILOT_THIN (2)`; `sets COMB_MH_CELLS/TARGETS/NUMITER/BURNIN/THIN`
- **issues:** Writes the same filename (data/p{p}q10_mh_{target}.wxf) as the production run_q10_mh_parallel.ps1 - pilot and production outputs are indistinguishable except by numIter inside the WXF; does not set COMB_FORCE so it silently skips if production files exist.; Header says log is logs/mh_q10_pilot_{p}_{target}.log but code writes mh_q10_pilot_p{p}_{target}.log.; Leaks COMB_MH_* env vars into the parent shell.; Windows PowerShell only.

### `src/run_q10_mh_parallel.ps1`
- **kind / stage / status:** launcher(ps1) / q10-compare / production
- **purpose:** Launches 4 parallel hidden powershell.exe children, each running run_mh_chains.wl with COMB_FORCE=1 at 200k iter for (3,10),(4,10) x {unlabeled,facet} (the IS-vs-MH disagreement cells), overwriting pilot results; waits for exit.
- **loads:** `src/comb_paths.ps1`; `src/run_mh_chains.wl (via Start-Process powershell.exe -Command 'wolframscript -file ...')`
- **writes:** `data/p{3,4}q10_mh_{unlabeled,facet}.wxf (via run_mh_chains.wl, forced overwrite)`; `logs/mh_q10_prod_p{p}_{target}.log`
- **env:** `COMB_PROD_NUMITER (200000)`; `COMB_PROD_BURNIN (20000)`; `COMB_PROD_THIN (5)`; `children set COMB_MH_CELLS/TARGETS/NUMITER/BURNIN/THIN, COMB_FORCE=1`
- **issues:** Windows-only: spawns powershell.exe (Windows PowerShell 5) with an inline here-string script and -WindowStyle Hidden.; Cell list hardcoded; p=2 and vertex q=10 chains come only from the pilot at 10k iters, so compare_is_mh_q10/render_q10_is_vs_mh mix pilot and production budgets.; Forced overwrite of a shared filename; seed fixed at default 12345 implicitly.; Multi-hour runtime per chain.

### `src/run_q10_mh_overnight.ps1`
- **kind / stage / status:** launcher(ps1) / q10-compare / one-off
- **purpose:** Phase 4c overnight job: (1) sequentially re-runs p4q10 unlabeled production chain (200k, seed 12345) to restore a clobbered file; (2) launches 4 parallel 1M-iter chains with seed 67890 and warm-start init (numV=14 for p=3, 18 for p=4) at (3,10),(4,10) x {unlabeled,facet}, tagged _seed67890_warm{N}.
- **loads:** `src/comb_paths.ps1`; `src/run_mh_chains.wl (wolframscript -file, and via Start-Process powershell.exe -Command)`
- **writes:** `data/p4q10_mh_unlabeled.wxf (step 1, forced overwrite)`; `data/p{3,4}q10_mh_{unlabeled,facet}_seed67890_warm{14,18}.wxf`; `logs/mh_q10_restore_p4_unlabeled.log`; `logs/mh_q10_overnight_p{p}_{target}_seed67890_warm{N}.log`
- **env:** `sets COMB_MH_CELLS, COMB_MH_TARGETS, COMB_MH_NUMITER, COMB_MH_BURNIN, COMB_MH_THIN, COMB_MH_SEED, COMB_MH_KERNEL, COMB_MH_TAG, COMB_MH_INITNUMV, COMB_MH_OUTDIR, COMB_FORCE`
- **issues:** Step 1 is a one-time repair of a historical file clobber baked into a pipeline script.; Hardcoded warm-init numV values (14,18) and seed 67890 duplicated in compare_q10_warm_vs_prod.wl and render_q10_warm_vs_prod.wl.; ~5 hr wall time; Windows-only (powershell.exe children, hidden windows).; $ErrorActionPreference=Continue: failures do not stop the run; exit codes only printed.; Leaks env vars into parent shell; COMB_MH_OUTDIR set redundantly to the default data dir.

### `src/compare_is_mh_q10.wl`
- **kind / stage / status:** compare/validate / q10-compare / validation
- **purpose:** At q=10 (no truth) compares MH numV histograms against precomputed IS-reweighted numV histograms for p in {2,3,4} x {vertex,unlabeled,facet}; prints ASCII overlays and L1/ESS/accept-rate summary and writes summary WXF.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q10_is_{target}_numv_hist.wxf (from precompute_is_histograms_q10.wl)`; `data/p{p}q10_mh_{target}.wxf`
- **writes:** `data/q10_is_vs_mh_summary.wxf`
- **env:** `COMB_CMP_PS (2,3,4)`; `COMB_CMP_TARGETS (vertex,unlabeled,facet)`; `COMB_ROOT (via comb_paths.wl)`
- **issues:** Depends on the 12M-row IS data (giant, not in git) via precompute_is_histograms_q10.wl.; Mixes MH budgets (pilot 10k for p=2/vertex vs production 200k for disagreement cells) under one filename with no tag.; binMh/cmpBars/asciiBar duplicated across compare_q10_warm_vs_prod.wl, render_q10_is_vs_mh.wl, render_q10_warm_vs_prod.wl.; Summary is print-only analysis; no pass/fail criterion.

### `src/compare_q10_warm_vs_prod.wl`
- **kind / stage / status:** compare/validate / q10-compare / one-off
- **purpose:** At the 4 q=10 disagreement cells, computes pairwise numV L1 among IS, production MH (seed 12345, 200k) and warm-start MH (seed 67890, 1M), prints tables, and writes a summary WXF used to decide whether IS or MH is wrong.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q10_is_{target}_numv_hist.wxf`; `data/p{p}q10_mh_{target}.wxf`; `data/p{p}q10_mh_{target}_seed67890_warm{N}.wxf`
- **writes:** `data/q10_warm_vs_prod_summary.wxf`
- **env:** `COMB_ROOT (via comb_paths.wl)`
- **issues:** No FileExistsQ checks: a missing input makes Import return $Failed and the script errors mid-run.; Cell list and warm numV values hardcoded (duplicated from run_q10_mh_overnight.ps1).; Not parameterized by env; tied to one historical experiment (Phase 4c).

### `src/render_q10_is_vs_mh.wl`
- **kind / stage / status:** render / render / unclear
- **purpose:** Renders a 3x3 grid (p in {2,3,4} x target in {vertex,unlabeled,facet}) of IS-vs-MH numV overlay histograms at q=10 with L1/ESS/acceptance annotations, plus a 1x2 focus panel for (4,10) unlabeled/facet.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q10_is_{target}_numv_hist.wxf`; `data/p{p}q10_mh_{target}.wxf`
- **writes:** `figures/is_vs_mh/q10_is_vs_mh_grid.png`; `figures/is_vs_mh/q10_is_vs_mh_grid.pdf`; `figures/is_vs_mh/q10_p4_focus.png`
- **env:** `COMB_ROOT (via comb_paths.wl)`
- **issues:** Not listed in AGENTS.md commands and not referenced by any other file/doc (undocumented entry point).; Header omits the q10_p4_focus.png output.; No input existence checks: all 9 IS hists and 9 MH WXFs must exist or the render fails.; Overlaps in purpose with compare_is_mh_q10.wl (duplicated helpers) and possibly render_sampler_progress.wl.

### `src/render_q10_warm_vs_prod.wl`
- **kind / stage / status:** render / render / one-off
- **purpose:** Renders a 2x2 grid ((3,10),(4,10) x {unlabeled,facet}) overlaying production MH and warm-start MH numV histograms with IS as black points, annotated with pairwise L1s.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q10_is_{target}_numv_hist.wxf`; `data/p{p}q10_mh_{target}.wxf`; `data/p{p}q10_mh_{target}_seed67890_warm{N}.wxf`
- **writes:** `figures/is_vs_mh/q10_warm_vs_prod.png`; `figures/is_vs_mh/q10_warm_vs_prod.pdf`
- **env:** `COMB_ROOT (via comb_paths.wl)`
- **issues:** Cell list/warm numV hardcoded and duplicated from run_q10_mh_overnight.ps1 and compare_q10_warm_vs_prod.wl.; No input existence checks.; Requires the ~5 hr overnight run plus the IS q=10 pipeline outputs.

## Group D-ECGrav-3way

Two sub-pipelines. (1) ECGrav campaign: enumerate_truth.wl -> data/p{p}q{q}_truth.wxf -> validate_counts_vs_truth.wl (stdout only); run_ecgrav_campaign.ps1 launches 3x run_ecgrav_samplers.wl -> data/p{p}q{q}_ecg{sampler}_{target}.wxf + logs/ecg{sampler}_{target}.{log,err}, watched by monitor_ecgrav.ps1 (log-regex coupled); outputs consumed by validate_mh_vs_truth.wl (COMB_VAL_SOURCE) and compare_samplers_efficiency.wl -> data/sampler_efficiency_summary.wxf (also reads mh WXFs and q10 merged_stats). (2) 3-way at q=5: run_is_at_truth_cells.wl -> data/p{p}q{q}_is_{t}_numv_hist.wxf; with truth + run_mh_chains.wl MH WXFs -> compare_3way.wl -> data/is_mh_truth_3way_summary.wxf and render_3way.wl -> figures/is_vs_mh/q5_is_mh_truth_3way.{png,pdf}. Three render_* sampler diagnostics (ecgrav_compare, sampler_progress, uniformity_check) are self-contained one-offs that rerun enumeration + MH inline, load sampler_mh.wl via cwd-relative Get[\"src/sampler_mh.wl\"] (breaks outside repo root), and write figures/sampler_diagnostics/*.{pdf,png}; render_sampler_progress also needs data/p4q10_n500000_samples.csv. Cross-cutting reproducibility issues: all config via env vars with defaults duplicated per script (9-cell list, parseEnvCells copy-pasted ~6x); launchers/monitor are Windows PowerShell only; all data gitignored so an outsider must regenerate truth (hours at p=4) before anything here runs; no exit codes on validation failure; mix of exportWxfAtomic and plain Export. Missing reference: 'ExpansionRoadmap.md' cited in run_ecgrav_samplers.wl does not exist in the repo. All other loaded files (comb_paths.wl/.ps1, load_ecgrav.wl, streaming_enumerator_bliss.wl, pure_simplicial_compute.wl, sampler_mh.wl, docs/sampling.md) exist.


### `src/run_ecgrav_samplers.wl`
- **kind / stage / status:** entry-script / ECGrav-campaign / production
- **purpose:** Draws samples from ECGrav exact samplers (RandomUniformUnlabeled/RandomUniformFacetLabeled/RandomVertexLabeled), ECGrav MCMC (RandomPureSimplicialComplexMCMC plus a per-sweep trace), or the known-biased legacy facet sampler (negative control), computes the 12-stat row per sample (memoized on BLISS canonical key) and the matching truth iso-class index, and writes a WXF in the same {headers, rows} layout as run_mh_chains.wl.
- **loads:** `src/comb_paths.wl`; `src/load_ecgrav.wl`; `src/streaming_enumerator_bliss.wl`; `src/pure_simplicial_compute.wl`
- **reads:** `data/p{p}q{q}_truth.wxf (optional; for classIdx)`
- **writes:** `data/p{p}q{q}_ecg{exact|mcmc|legacyfacet}_{unlabeled|facet|vertex}.wxf (via exportWxfAtomic from pure_simplicial_compute.wl)`
- **env:** `COMB_ECG_CELLS (default 9-cell truth grid)`; `COMB_ECG_TARGETS (default unlabeled,facet,vertex)`; `COMB_ECG_SAMPLER=exact|mcmc|legacyfacet (default exact)`; `COMB_ECG_N (default 100000 exact / 20000 mcmc)`; `COMB_ECG_BATCH (default 2000)`; `COMB_ECG_SEED (default 24680)`; `COMB_ECG_TRACE_STEPS (default 200000)`; `COMB_ECGRAV_VERSION (via load_ecgrav.wl)`; `COMB_FORCE=1`; `COMB_ROOT (via comb_paths.wl)`
- **issues:** Get's pure_simplicial_compute.wl inside a Block with pListOverride={}, sampleSizeOverride=0, useParallelOverride=False purely to import statsFor/exportWxfAtomic: library and entry-script mixed in one file (fragile side-effect import).; Header comment cites 'ExpansionRoadmap.md §1.2' which does not exist anywhere in the repo.; Default N=100000 x 27 cell-targets is a long run; (4,5) and mcmc trace (200k proposals) are heavy.; Silently records classIdx = Missing["NoTruth"] if truth WXF absent, so truth enumeration is an implicit prerequisite not enforced.; legacyfacet uses forbidden RandomFacetLabeledPureSimplicialComplex (intentional negative control).; Inputs/outputs gitignored; outside researcher must regenerate truth first.; Seed fixed (24680) via SeedRandom but MCMC seed complex is a random draw after SeedRandom only inside processCellTarget; reproducibility depends on ECGrav internals respecting SeedRandom.

### `src/run_ecgrav_campaign.ps1`
- **kind / stage / status:** launcher(ps1) / ECGrav-campaign / production
- **purpose:** Launches run_ecgrav_samplers.wl as three parallel wolframscript processes (one per target) for a given sampler and cell list, waits for all, then greps logs for summary lines.
- **loads:** `src/comb_paths.ps1`; `src/run_ecgrav_samplers.wl (Start-Process wolframscript -file)`
- **reads:** `logs/ecg{sampler}_{target}.log (post-run summary grep)`
- **writes:** `logs/ecg{sampler}_{target}.log`; `logs/ecg{sampler}_{target}.err`; `data/p{p}q{q}_ecg{sampler}_{target}.wxf (via child)`
- **env:** `COMB_ECG_SAMPLER (default exact)`; `COMB_ECG_CELLS (default 9-cell grid)`; `COMB_ECG_N`; `COMB_ECG_SEED`; `COMB_FORCE`; `COMB_ECG_TARGETS (set per child; overwritten in caller's session)`
- **issues:** Windows PowerShell only; no bash/cross-platform equivalent.; Mutates caller's session env ($env:COMB_ECG_TARGETS ends as 'vertex', COMB_ECG_SAMPLER/CELLS persisted) since it sets env rather than scoping it.; Header documents only exact|mcmc but legacyfacet also works (forced to facet target, so the other two children would duplicate the facet run and race on the same output file).; Logs dir built as Join-Path $CombRoot 'logs' rather than a $CombLogsDir variable (minor duplication with comb_paths.ps1).; Duplicates the 9-cell default list also hardcoded in run_ecgrav_samplers.wl.

### `src/monitor_ecgrav.ps1`
- **kind / stage / status:** monitor / ECGrav-campaign / production
- **purpose:** Read-only live console dashboard for an ECGrav campaign: per target parses logs for planned/finished cells, current cell elapsed time, last MCMC diagnostics, warnings, and counts output WXFs.
- **loads:** `src/comb_paths.ps1`
- **reads:** `logs/ecg{sampler}_{target}.log`; `logs/ecg{sampler}_{target}.err`; `data/p*_ecg{sampler}_*.wxf (count only)`; `running process list (wolfram, WolframKernel)`
- **env:** `COMB_MON_SAMPLER (default mcmc, unlike the campaign default exact)`; `COMB_MON_INTERVAL (default 30)`; `COMB_MON_ONCE=1`
- **issues:** Windows PowerShell only.; Tightly coupled to exact Print formats in run_ecgrav_samplers.wl (regex on '^cells\s+=', '(p, q) = ', 'started yyyy-MM-dd ...', 'wrote ', 'done.'); any log-text change breaks it silently.; Default sampler mcmc differs from campaign default exact.; Hardcodes '27 = full 9-cell grid'.; Optional convenience tool; not needed for reproduction.

### `src/validate_counts_vs_truth.wl`
- **kind / stage / status:** compare/validate / compare/validate (ECGrav-campaign) / validation
- **purpose:** Cross-checks ECGrav's exact counters NumUnlabeled/FacetLabeled/VertexLabeledPureComplexes[p,q,n] against per-n counts derived from our truth WXFs (iso count, sum q!/autF, sum n!/aut) for each cell; prints a table and summary, plus q=10 totals for reference.
- **loads:** `src/comb_paths.wl`; `src/load_ecgrav.wl`
- **reads:** `data/p{p}q{q}_truth.wxf`
- **env:** `COMB_VAL_CELLS (default 9-cell grid)`; `COMB_ECGRAV_VERSION (via load_ecgrav.wl)`; `COMB_ROOT`
- **issues:** Output is stdout only (no summary file); pass/fail must be read from logs by hand; no nonzero exit code on mismatch.; Shares env var name COMB_VAL_CELLS with validate_mh_vs_truth.wl, so one setting affects both.; Requires truth WXFs (gitignored); skips missing cells with a message.; Duplicates parseEnvCells / 9-cell default list found in many scripts.

### `src/compare_samplers_efficiency.wl`
- **kind / stage / status:** compare/validate / ECGrav-campaign / production
- **purpose:** Builds an ESS / wall-time / numV-L1 table per (p,q) x target across all available sample sources (our MH, ECGrav MCMC, ECGrav exact, IS reweighting of ECGrav vertex draws, legacy q=10 IS), using truth or the ecgexact histogram as reference; prints table and saves a summary WXF.
- **loads:** `src/comb_paths.wl`; `src/load_ecgrav.wl`; `src/sampler_mh.wl (with $smokeTestSkip=True, for integratedAutocorrTime)`
- **reads:** `data/p{p}q{q}_truth.wxf`; `data/p{p}q{q}_mh_{target}.wxf`; `data/p{p}q{q}_ecgmcmc_{target}.wxf`; `data/p{p}q{q}_ecgexact_{target}.wxf`; `data/p{p}q{q}_ecgexact_vertex.wxf`; `data/p{p}q10_merged_stats.wxf (q=10 only; ~1.36 GB per p)`
- **writes:** `data/sampler_efficiency_summary.wxf`
- **env:** `COMB_EFF_CELLS (default 9 truth cells + (2,10),(3,10),(4,10))`; `COMB_EFF_TARGETS`; `COMB_ROOT`
- **issues:** Each source silently included only if its WXF exists, so the table content depends on what happens to be on disk; no warning for missing sources.; Loads multi-GB p{p}q10_merged_stats.wxf files for q=10 cells (slow, memory heavy).; Hardcodes legacy column indices 14/15 for wUnlabeled/wFacet (coupled to pure_simplicial_compute headers).; Wall seconds machine/load-dependent (documented).; Uses plain Export, not exportWxfAtomic.; Loads ECGrav though it does not appear to call any ECGrav function (only needed for sampler_mh.wl).

### `src/render_ecgrav_compare.wl`
- **kind / stage / status:** render / render / one-off
- **purpose:** Diagnostic figure at p=2 q=4: per-iso-class fractions of truth (q!/|Aut_F|), a fresh 30k MH facet chain, and 30k draws of ECGrav's legacy RandomFacetLabeledPureSimplicialComplex, showing the legacy sampler's bias; prints L1s.
- **loads:** `src/load_ecgrav.wl`; `src/comb_paths.wl`; `src/sampler_mh.wl (cwd-relative Get["src/sampler_mh.wl"])`
- **writes:** `figures/sampler_diagnostics/sampler_ecgrav_compare.pdf`; `figures/sampler_diagnostics/sampler_ecgrav_compare.png`
- **env:** `COMB_ECGRAV_VERSION`; `COMB_ROOT`
- **issues:** Get["src/sampler_mh.wl"] is cwd-relative: fails unless run from repo root (violates AGENTS.md rule).; Recomputes enumeration and runs its own MH chain inline instead of reading data/ (duplicated logic with truth/MH pipeline); not tied to the pinned data.; Uses the forbidden legacy facet sampler (intentionally, as negative control).; Superseded in purpose by the legacyfacet mode of run_ecgrav_samplers.wl + validate_mh_vs_truth.wl.; MH seed is the runMHChain default (12345); ECGrav seed 2024 fixed.

### `src/render_sampler_progress.wl`
- **kind / stage / status:** render / render / one-off
- **purpose:** One-off MH progress figure: panels for p=2 q=4 and p=3 q=4 (fresh enumeration vs fresh MH numV histograms) and p=4 q=10 (IS-reweighted unlabeled from the 500k CSV vs a fresh 25k MH chain).
- **loads:** `src/load_ecgrav.wl`; `src/comb_paths.wl`; `src/sampler_mh.wl (cwd-relative Get["src/sampler_mh.wl"])`
- **reads:** `data/p4q10_n500000_samples.csv`
- **writes:** `figures/sampler_diagnostics/sampler_mh_progress.pdf`; `figures/sampler_diagnostics/sampler_mh_progress.png`
- **env:** `COMB_ECGRAV_VERSION`; `COMB_ROOT`
- **issues:** Get["src/sampler_mh.wl"] is cwd-relative.; Header promises 4 panels (A-D, D = running mean across 4 seeds) but only A-C are built: stale docs.; Depends on p4q10_n500000_samples.csv from pure_simplicial_compute_overnight.wl (large, gitignored).; Panel legend hardcodes 'ESS~4'.; Recomputes enumeration/MH inline rather than using pipeline data; pre-vertex-fix era diagnostic, likely superseded by render_truth_overlay.wl.

### `src/render_uniformity_check.wl`
- **kind / stage / status:** render / render / one-off
- **purpose:** Per-iso-class uniformity check of our MH sampler at p=2 q=4: runs 30k unlabeled and 30k facet chains, matches states to the 11 iso classes, and plots empirical vs truth fractions.
- **loads:** `src/load_ecgrav.wl`; `src/comb_paths.wl`; `src/sampler_mh.wl (cwd-relative Get["src/sampler_mh.wl"])`
- **writes:** `figures/sampler_diagnostics/sampler_mh_uniformity.pdf`; `figures/sampler_diagnostics/sampler_mh_uniformity.png`
- **env:** `COMB_ECGRAV_VERSION`; `COMB_ROOT`
- **issues:** Get["src/sampler_mh.wl"] is cwd-relative.; Self-contained compute+render (enumeration + MH inline) duplicating truth/MH pipeline logic.; Hardcodes 'uniform = 1/11' in legend.; Not referenced in AGENTS.md command list.

### `src/run_is_at_truth_cells.wl`
- **kind / stage / status:** entry-script / 3way / production
- **purpose:** Draws vertex-labeled IS samples (RandomVertexLabeledPureSimplicialComplex) at truth cells (default (3,5),(4,5)), computes numV/|Aut|/|Aut_F| per sample (optionally ParallelMap), and writes reweighted numV fraction histograms + Kish ESS per target.
- **loads:** `src/comb_paths.wl`; `src/load_ecgrav.wl`
- **writes:** `data/p{p}q{q}_is_{vertex|unlabeled|facet}_numv_hist.wxf`
- **env:** `COMB_IS_CELLS (default 3,5;4,5)`; `COMB_IS_N (default 100000)`; `COMB_IS_CHUNK (default 5000)`; `COMB_IS_SEED (default 42)`; `COMB_IS_PAR=1|0 (default 1)`; `COMB_FORCE=1`; `COMB_ECGRAV_VERSION`; `COMB_ROOT`
- **issues:** Seeds per chunk (seed + 1000p + 100q + k) but ParallelMap only computes stats, so sampling is deterministic; however results depend on ECGrav version.; Uses plain Export, not exportWxfAtomic (partial file on crash; skip check only tests size>0).; Not registered with run_parallel or a launcher; manual step before compare_3way.; Duplicates IS weight formulas also in compare_samplers_efficiency.wl and pure_simplicial_compute.wl.

### `src/compare_3way.wl`
- **kind / stage / status:** compare/validate / 3way / production
- **purpose:** At (3,5),(4,5) compares numV marginals of IS histograms, MH chains, and truth per target; prints ASCII overlays and pairwise L1s and saves a summary WXF.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q{q}_truth.wxf`; `data/p{p}q{q}_mh_{target}.wxf`; `data/p{p}q{q}_is_{target}_numv_hist.wxf`
- **writes:** `data/is_mh_truth_3way_summary.wxf`
- **env:** `COMB_3W_CELLS (default 3,5;4,5)`; `COMB_3W_TARGETS (default vertex,unlabeled,facet)`; `COMB_ROOT`
- **issues:** No FileExistsQ checks: missing truth/MH/IS file makes Import return $Failed and the script errors out mid-run.; Depends on MH WXFs that must be post-2026-05-14 vertex fix (AGENTS.md warns about stale vertex WXFs) with no version/provenance check.; Uses truth #["stats"]["numV"] while other scripts use #["nV"] (both exist; inconsistent).; marginalizeTruth/binMh/l1/file builders duplicated verbatim in render_3way.wl.

### `src/render_3way.wl`
- **kind / stage / status:** render / render / production
- **purpose:** Renders a 2x3 grid (cells (3,5),(4,5) x targets vertex/unlabeled/facet) overlaying IS and MH numV histograms with truth points and L1/ESS labels.
- **loads:** `src/comb_paths.wl`
- **reads:** `data/p{p}q{q}_truth.wxf`; `data/p{p}q{q}_mh_{target}.wxf`; `data/p{p}q{q}_is_{target}_numv_hist.wxf`
- **writes:** `figures/is_vs_mh/q5_is_mh_truth_3way.png`; `figures/is_vs_mh/q5_is_mh_truth_3way.pdf`
- **env:** `COMB_ROOT`
- **issues:** Cells and targets hardcoded (ignores COMB_3W_*), no existence checks.; Recomputes L1s instead of reading data/is_mh_truth_3way_summary.wxf; helpers copy-pasted from compare_3way.wl.; Outputs are tracked in git (figures/is_vs_mh/q5_is_mh_truth_3way.*) while inputs are not, so the figure cannot be regenerated from a clone without rerunning truth + MH + IS.

## Group E-nonsrc

Scope: worktree C:\CombResearch\.claude\worktrees\ecstatic-wiles-75960d (read-only, nothing edited) plus main-checkout C:\CombResearch\data and \logs.

Key cross-cutting findings for the diagrams:
1. Manuscript disconnect: docs/Pure Clique Complexes.tex cannot compile from the repo. bibliography.bib and Images/ are missing. Its figure names (Images/p{p}q10[conn]SX{Stat}.pdf, ClqX clique-complex panels, randomSX*, distSX*, facet-labeled/*.pdf) match no renderer output. render_all_figures writes figures/manuscript_panels/p{p}q10[conn]SX{Stat}_merged.pdf, and render_truth_overlay writes truthSX{Stat}_p{p}q{q}_{target}.pdf. No script produces ClqX panels. The tex has two copy errors: p=4 Betti2 uses the SX file in both columns, and the p=3 num1V columns are swapped.
2. Data availability: ~9.0 GB in 147 files lives only in the Ryzen main checkout and is gitignored. 8.7 GB of that is legacy q=10 IS raw data. Truth is only 3.2 MB, ecgexact 107 MB and ecgmcmc 26 MB. These small, high-value sets could be published (release/Zenodo) so a cloner can skip the 17 h (4,5) McKay enumeration. Meanwhile the 4 Betre .mx files are git-tracked without LFS. The largest is 103.6 MB, platform-locked to MacOSX-ARM64, and read only by probe_betre_mx.wl.
3. Orphan/unread data: q10_pilot_archive/*pilot10k (4), p3q5_mh_vertex.2026-05-17.wxf.bak, p{3,4}q10_n10000000_batch3_complexes.wxf (3.2 GB, unread; concat_samples' merged_complexes output absent), the legacy *_samples.csv (only render_sampler_progress reads p4q10_n500000_samples.csv, plus the CSV fallback in render_all_figures), and p4q4_truth_mckay.wxf. Main is also missing p4q5_truth_mckay.wxf (p4q5_truth.wxf is the manual copy) and MH WXFs for (2,7),(3,6),(4,4).
4. Orphan figures: manuscript_panels/*_n500k.pdf (33) and combined/combined_all_figures_n500k.pdf. render_all_figures.wl hardcodes sampleTag="merged", so no current script produces them.
5. Orphan logs: about 40 of 98 tracked logs came from manual shell redirects (enumerate_*, mckay_*, mh_part*, mh_remaining, render*, scaling_probe*, probe_*). Launcher-produced families: compute_p* (run_parallel.ps1), ecg{exact,mcmc}_* (run_ecgrav_campaign.ps1), mh_p4q5_* (run_p4q5_mh_parallel.ps1), mh_q10_{pilot,prod,overnight,restore}_* (q10 .ps1 launchers).
6. ECGrav: the three vendored snapshots differ only by version. 1.18.0-474b5c2 is the default and has not been validated, while all existing ECGrav data comes from 1.17.0. The snapshots are selected through COMB_ECGRAV_VERSION, but WXF payloads do not reliably record the version. Separately, src/enumerate_truth.wl hardcodes the provenance string ecGravVersion="1.0.0", which is now stale. src/ uses 14 ECGrav public symbols: RandomVertexLabeled/RandomUniformUnlabeled/RandomUniformFacetLabeled/RandomFacetLabeled PureSimplicialComplex, RandomPureSimplicialComplexMCMC(+Sweep), Num{Un,Facet,Vertex}LabeledPureComplexes, PureComplex{,Facet}AutomorphismGroupOrder, IsomorphicSimplicialComplexQ, ChooseNonIsomorphicSimplicialComplexes and GenerateAllFacetLabeledPureSimplicialComplexes. Wolfram 15.0+ is a licensed hard dependency. ECGrav/BuildingAndInstallingPaclets.nb is an unreferenced upstream tutorial and contains other users' paths.
7. Archive: no src script loads any archive/ file. src/streaming_enumerator_bliss.wl and docs/agent-task.md only mention archived probe names. The archived scripts are broken: scriptDir-relative Gets of enumerators that are not there, cwd-relative Get["src/sampler_mh.wl"], and bare Needs["ECGrav`"].
8. Doc defects: docs/agent-task.md lines 285-286 and 336-337 are corrupted, with 'src\run_' rendered as 'src' + newline + 'un_'. It also names a plan file that is not in the repo (big-things-happening-it-s-eager-sprout.md) and the wrong path for the q10_warm_vs_prod figure (it is in figures/is_vs_mh/). README, enumeration.md and sampling.md are stale on the Betre cross-check, the exact samplers and the 1.17 facet-sampler L1. Every doc-referenced src/ path (42) exists.
9. Windows-only setup: every launcher is PowerShell. .claude/settings.json runs src/sync_worktree_data.ps1 via powershell.exe on SessionStart/End. Configuration is entirely through ~25 COMB_* env vars, with no single driver or figure-to-command map.
10. docs/handoff/*.jsonl is a 3.1 MB raw Claude transcript. It is unreferenced and has local-path and privacy noise, so it should leave the public repo.
11. docs/architecture/PLAN.md is untracked, presumably the orchestrator's plan. It is not part of this group.


### `README.md`
- **kind / stage / status:** doc / util / production
- **purpose:** Top-level human-facing README: status bullets, a 4-command Quick Start (enumerate_truth, run_mh_chains, validate_mh_vs_truth, render_truth_overlay), the older q=10 IS commands, a layout table and links to docs.
- **loads:** `src/enumerate_truth.wl`; `src/run_mh_chains.wl`; `src/validate_mh_vs_truth.wl`; `src/render_truth_overlay.wl`; `src/pure_simplicial_compute.wl`; `src/render_all_figures.wl`; `src/run_parallel.ps1`; `AGENTS.md`; `docs/agent-task.md`; `docs/enumeration.md`; `docs/sampling.md`
- **issues:** Stale: 'Current open work ... Betre WXF cross-checks' was closed by Phase 5a (ECGrav counters confirmed 5,532); does not mention ECGrav exact samplers, Phase 5a, or the 1.18.0-474b5c2 pin.; Quick Start lists no prerequisites: Wolfram 15.0+ / wolframscript on PATH, no install step, no expected runtimes (truth (4,5) = 17 h, 7.9 GB).; Quick Start does not say enumerate_truth must run before the others or which cells/pipeline (McKay needed at p=4 q>=5 via COMB_TRUTH_PIPELINE/COMB_TRUTH_PARALLEL env vars).; Says data/ is gitignored, but 4 Betre .mx files under data/ are tracked (one 103.6 MB, no LFS).; All commands are PowerShell/Windows syntax (backslash paths, powershell -ExecutionPolicy Bypass).; No explanation of where outputs go (main-checkout redirection via comb_paths) or how a cloner obtains the ~9 GB data (no download/Zenodo link).; No mapping from manuscript figures to commands.

### `AGENTS.md`
- **kind / stage / status:** doc / util / production
- **purpose:** Canonical agent instructions: project overview, layout, setup (Wolfram 15, pinned ECGrav via load_ecgrav.wl, install_ecgrav_global.wl), generated-outputs policy (comb_paths), full command catalogue with env knobs per stage, coding/testing/git/handoff rules. De facto the only complete run-book for the pipeline.
- **loads:** `CLAUDE.md`; `docs/agent-task.md`; `src/comb_paths.wl`; `src/comb_paths.ps1`; `src/load_ecgrav.wl`; `src/install_ecgrav_global.wl`; `src/sync_worktree_data.ps1`; `src/pure_simplicial_compute.wl`; `src/pure_simplicial_compute_overnight.wl`; `src/run_parallel.ps1`; `src/render_all_figures.wl`; `src/enumerate_truth.wl`; `src/run_mh_chains.wl`; `src/run_p4q5_mh_parallel.ps1`; `src/monitor_mh.ps1`; `src/validate_mh_vs_truth.wl`; `src/render_truth_overlay.wl`; `src/validate_counts_vs_truth.wl`; `src/run_ecgrav_samplers.wl`; `src/run_ecgrav_campaign.ps1`; `src/monitor_ecgrav.ps1`; `src/compare_samplers_efficiency.wl`; `src/precompute_is_histograms_q10.wl`; `src/run_q10_mh_pilot.ps1`; `src/run_q10_mh_parallel.ps1`; `src/compare_is_mh_q10.wl`; `src/run_is_at_truth_cells.wl`; `src/compare_3way.wl`; `src/render_3way.wl`; `src/run_q10_mh_overnight.ps1`; `src/compare_q10_warm_vs_prod.wl`; `src/render_q10_warm_vs_prod.wl`; `src/test_streaming.wl`; `src/test_streaming_bliss.wl`; `src/test_streaming_mckay.wl`; `.claude/settings.json`
- **env:** `COMB_TRUTH_CELLS`; `COMB_TRUTH_PIPELINE`; `COMB_TRUTH_PARALLEL`; `COMB_FORCE`; `COMB_MH_CELLS`; `COMB_MH_TARGETS`; `COMB_MH_NUMITER`; `COMB_MH_BURNIN`; `COMB_MH_THIN`; `COMB_MH_SEED`; `COMB_MH_KERNEL`; `COMB_VAL_CELLS`; `COMB_VAL_TARGETS`; `COMB_VAL_THRESHOLD`; `COMB_VAL_SOURCE`; `COMB_ECG_SAMPLER`; `COMB_ECG_CELLS`; `COMB_ECG_TARGETS`; `COMB_ECG_N`; `COMB_ECG_SEED`; `COMB_ECG_TRACE_STEPS`; `COMB_MON_SAMPLER`; `COMB_EFF_CELLS`; `COMB_EFF_TARGETS`; `COMB_ECGRAV_VERSION`; `COMB_ROOT`
- **issues:** Configuration is env-var-only and spread over ~25 COMB_* knobs; no config file or single driver documents which combination reproduces each figure.; Machine-specific content (i5 laptop, Ryzen 7 5800X, C:\CombResearch, Wolfram MCP server) mixed with reproducible instructions.; Overview says 1.18.0-474b5c2 pin not yet re-validated against truth grid; figures were produced under 1.0.0/1.17.0.; Commands are Windows/PowerShell-only; launchers (.ps1) have no POSIX equivalent.; Missing from command list: probe_betre_mx.wl, concat_samples.wl, migrate_csv_to_wxf.wl, precompute_is_histogram.wl, render_q10_is_vs_mh.wl, render_sampler_progress/uniformity_check/ecgrav_compare (only in docs/sampling.md).; Data acquisition for outsiders is not addressed (data/*.wxf ~9 GB gitignored, lives only on Ryzen main checkout).

### `CLAUDE.md`
- **kind / stage / status:** doc / util / production
- **purpose:** Claude Code notes: imports AGENTS.md via @AGENTS.md and adds 3 bullets (plan mode for big rewrites, preserve Wolfram style, don't edit CLAUDE.md).
- **loads:** `AGENTS.md`
- **issues:** Agent-tooling file; irrelevant to an outside researcher (fine to keep but not a reproducibility doc).

### `docs/agent-task.md`
- **kind / stage / status:** doc / util / production
- **purpose:** Live chronological handoff log (525 lines): worktree cleanup, comb_paths shared-output change, ECGrav 1.18 pin consolidation, 12-step Ryzen PC setup checklist (re-validate pin), Phase 5a results, Phase 4b/4c status, decisions, files added per phase.
- **loads:** `AGENTS.md`; `CLAUDE.md`; `src/comb_paths.wl`; `src/comb_paths.ps1`; `src/sync_worktree_data.ps1`; `src/load_ecgrav.wl`; `src/install_ecgrav_global.wl`; `src/test_streaming_mckay.wl`; `src/validate_counts_vs_truth.wl`; `src/validate_mh_vs_truth.wl`; `src/run_ecgrav_campaign.ps1`; `src/monitor_ecgrav.ps1`; `src/compare_samplers_efficiency.wl`; `src/run_ecgrav_samplers.wl`; `src/sampler_mh.wl`; `src/run_mh_chains.wl`; `src/run_q10_mh_overnight.ps1`; `src/compare_q10_warm_vs_prod.wl`; `src/render_q10_warm_vs_prod.wl`; `src/run_is_at_truth_cells.wl`; `src/compare_3way.wl`; `src/render_3way.wl`; `src/precompute_is_histograms_q10.wl`; `src/run_q10_mh_pilot.ps1`; `src/run_q10_mh_parallel.ps1`; `src/compare_is_mh_q10.wl`; `src/probe_betre_mx.wl`; `src/run_p4q5_mh_parallel.ps1`; `src/monitor_mh.ps1`; `src/pure_simplicial_figures.nb`; `src/enumerate_truth.wl`; `src/render_truth_overlay.wl`
- **reads:** `data/p{p}q{q}_truth.wxf`; `data/p*q*_ecgexact_*.wxf`; `data/validation_ecgexact_summary.wxf`; `data/p4q*SXFacetLabeled.wxf (expected from Betre, never arrived)`; `logs/ecgexact_*.log`
- **writes:** `data/phase5a_ecgrav-1.17.0/ (manual backup step, not yet done)`
- **env:** `COMB_FORCE`; `COMB_VAL_SOURCE`; `COMB_ECG_SAMPLER`; `COMB_ECGRAV_VERSION`; `COMB_ECGRAV_MAIN (removed)`; `COMB_MH_TAG`; `COMB_MH_INITNUMV`; `COMB_MH_OUTDIR`; `COMB_ROOT`
- **issues:** Corrupted text: lines 285-286 and 336-337 read '`src' newline 'un_ecgrav_campaign.ps1`' (a '\r' in 'src\run_...' was interpreted as carriage return).; References a Claude plan file 'big-things-happening-it-s-eager-sprout.md' that is not in the repo.; Says q10_warm_vs_prod output is figures/q10_warm_vs_prod.{png,pdf}; actual location is figures/is_vs_mh/.; Contains manual, machine-specific steps (Ryzen checklist, Copy-Item backups, global paclet install, MCP server) that an outside researcher cannot follow.; Records that seeded unlabeled/MCMC runs on 1.18 may differ from Phase 5a and that WXF payloads do not record ECGrav version (provenance gap).; Notes stale vertex MH WXFs from adoring-hoover worktree and missing MH WXFs for (2,7),(3,6),(4,4).; Interleaves history with current state; Phase 4b 'Remaining open items' (Betre .mx) is stale.

### `docs/enumeration.md`
- **kind / stage / status:** doc / truth-enum / production
- **purpose:** Reference for exact truth enumeration: 9-cell grid, WXF payload schema of p{p}q{q}_truth.wxf (complexes, piVertex/piFacet/piUnlabeled), the three enumerators (cheap streaming, BLISS, McKay), commands and env vars, validation scripts.
- **loads:** `src/enumerate_truth.wl`; `src/streaming_enumerator.wl`; `src/streaming_enumerator_bliss.wl`; `src/streaming_enumerator_mckay.wl`; `src/test_streaming.wl`; `src/test_streaming_bliss.wl`; `src/test_streaming_mckay.wl`; `src/validate_mh_vs_truth.wl`; `docs/agent-task.md`
- **reads:** `data/p{p}q{q}_truth.wxf`; `data/p{p}q{q}_truth_{bliss|mckay}.wxf`
- **env:** `COMB_TRUTH_CELLS`; `COMB_TRUTH_PIPELINE`; `COMB_TRUTH_PARALLEL`; `COMB_FORCE`; `COMB_VAL_CELLS`; `COMB_VAL_TARGETS`
- **issues:** Manual step: data/p4q5_truth.wxf must be copied by hand from p4q5_truth_mckay.wxf (no script does it).; (4,5) requires 17.1 h and 7.9 GB sequential McKay; no published truth WXFs for download.; 'Open Enumeration Work' Betre cross-check is stale (closed by ECGrav NumUnlabeledPureComplexes in Phase 5a).; Paths written as data/... rather than the comb_paths main-checkout redirection.

### `docs/sampling.md`
- **kind / stage / status:** doc / MH / production
- **purpose:** Reference for importance-sampling reweighting (weights, ESS table at q=10), ECGrav facet sampler warning, MH sampler state/proposals/targets incl. vertex-target fix, MH validation, MH commands, renderer list.
- **loads:** `src/sampler_mh.wl`; `src/run_mh_chains.wl`; `src/run_p4q5_mh_parallel.ps1`; `src/monitor_mh.ps1`; `src/validate_mh_vs_truth.wl`; `src/render_all_figures.wl`; `src/render_truth_overlay.wl`; `src/render_sampler_progress.wl`; `src/render_uniformity_check.wl`; `src/render_ecgrav_compare.wl`; `docs/enumeration.md`
- **env:** `COMB_MH_CELLS`; `COMB_MH_TARGETS`
- **issues:** Pre-Phase-5a: does not mention ECGrav exact samplers (RandomUniformUnlabeled/FacetLabeled) that the validation note says will replace IS/MH in figures.; Facet-sampler L1 0.427 is the ECGrav 1.0.0 number; under 1.17.0 it is 0.22.; Concludes q=10 facet/unlabeled IS histograms are diagnostic only, yet render_all_figures.wl still renders manuscript q=10 panels from that IS data.

### `docs/ecgrav_1.17_validation_note.md`
- **kind / stage / status:** doc / ECGrav-campaign / one-off
- **purpose:** Results memo to Dr. Betre (2026-09-26) on ECGrav 1.17.0 validation: counters exact on 9 cells, exact samplers pass 27/27, MCMC passes L1 but returns correlated unlabeled samples, legacy facet sampler fails; throughput tables and suggestions.
- **reads:** `data/p{p}q{q}_truth.wxf`; `data/p{p}q{q}_ecgexact_{target}.wxf`; `data/p{p}q{q}_ecgmcmc_{target}.wxf`; `data/p{p}q{q}_ecglegacyfacet_facet.wxf`; `data/sampler_efficiency_summary.wxf`
- **issues:** Correspondence memo with names; numbers are not regenerated by any script into this doc (manual transcription from validate_mh_vs_truth / compare_samplers_efficiency outputs).; Thinned-subset (every 2nd/3rd/5th) analysis and per-sweep trace numbers have no identified committed script producing them (COMB_ECG_TRACE_STEPS in run_ecgrav_samplers.wl may cover the trace).

### `docs/Pure Clique Complexes.tex`
- **kind / stage / status:** doc / render / unclear
- **purpose:** Manuscript draft (article class, biblatex): equivalence classes of labeled complexes, recursive count formula, random uniform pure complex algorithm, statistics section with q=10 figures for numV, Aut, AutF, connectivity, k-path connectivity, Betti numbers, side-by-side SX vs ClqX (clique complex) panels, facet algebra appendix.
- **loads:** `bibliography.bib (MISSING)`; `Images/facet-labeled/{1..9}{,a,b,c,d,e,f}.pdf (MISSING)`; `Images/distSX{Unweighted,Vertexlabeled,Facetlabeled,Unlabeled}.pdf (MISSING)`; `Images/randomSXp{2,3,4}q10{vlabeled,flabeled,unlabeled}.pdf (MISSING)`; `Images/p{2,3,4}q10[conn]SX{NumVertices,AutGorder,facetAutGorder,num1VConnectedComponents,num2VConnectedComponents,ratioOflargestCompVsVertexCount,num2PConnectedComponents,num3PConnectedComponents,Betti1,Betti2,Betti3}.pdf (MISSING)`; `Images/p{2,3,4}q10[conn]ClqX{...}.pdf (MISSING)`
- **issues:** Does not compile from the repo: bibliography.bib and the entire Images/ directory are absent.; Figure filenames (Images/p2q10SXNumVertices.pdf) do not match what render_all_figures.wl produces (figures/manuscript_panels/p2q10SXNumVertices_merged.pdf) nor truth panels (truthSX..._p{p}q{q}_{target}.pdf); no script copies/renames into Images/.; ClqX (clique complex) panels are referenced but no src script produces them (project memory says clique complexes are out of scope).; Bug in tex: p=4 Betti2 row uses p4q10SXBetti2.pdf for both SX and ClqX columns; p=3 num1V row has SX/ClqX columns swapped.; Filename with spaces; only committed once (initial commit), likely out of sync with paper's actual source (Overleaf?).; Contains a 'Questions' section at top (draft notes).

### `docs/handoff/3c923d56-de2e-4a1f-a72d-a3ca7adccbff.jsonl`
- **kind / stage / status:** archive / archive / dead
- **purpose:** Raw Claude Code session transcript (778 lines, 3.1 MB) from 2026-05-05 in the adoring-hoover-18d09b worktree; kept as a handoff artifact. Not read fully per instructions.
- **issues:** Not referenced by any doc or script.; Contains local user paths (C:\Users\darth, worktree names) and full chat history; privacy/noise for a public GitHub repo; should be removed or moved out of docs/.

### `ECGrav/ECGrav-1.18.0-474b5c2/`
- **kind / stage / status:** vendored / setup / production
- **purpose:** Default pinned ECGrav paclet source (upstream github.com/kassabetre/ECGrav main @ 474b5c2f8fec, PacletInfo Version 1.18.0, WolframVersion 15.0+): Kernel/ECGrav.wl + Subpackages/{MCSims,PureComplexes}.wl, LICENSE, SOURCE_COMMIT.txt. Loaded by every script via src/load_ecgrav.wl Get of Kernel/ECGrav.wl; installed globally by src/install_ecgrav_global.wl. Public symbols used by src/: RandomVertexLabeledPureSimplicialComplex, RandomFacetLabeledPureSimplicialComplex (negative control only), RandomUniformUnlabeledPureSimplicialComplex, RandomUniformFacetLabeledPureSimplicialComplex, RandomPureSimplicialComplexMCMC, RandomPureSimplicialComplexMCMCSweep, NumUnlabeledPureComplexes, NumFacetLabeledPureComplexes, NumVertexLabeledPureComplexes, PureComplexAutomorphismGroupOrder, PureComplexFacetAutomorphismGroupOrder, IsomorphicSimplicialComplexQ, ChooseNonIsomorphicSimplicialComplexes, GenerateAllFacetLabeledPureSimplicialComplexes.
- **env:** `COMB_ECGRAV_VERSION (default selects this dir)`
- **issues:** Not yet re-validated against the truth grid; all existing ECGrav sample WXFs/figures were made with 1.17.0 or 1.0.0.; Requires Wolfram 15.0+ (commercial license) — hard barrier for outside researchers.; Seeded unlabeled/MCMC draws may differ from Phase 5a; WXF payloads (per agent-task) do not record ECGrav version except via $CombECGravVersion where scripts store it.; src/enumerate_truth.wl hardcodes provenance ecGravVersion = "1.0.0" even though it now loads this snapshot (stale provenance).

### `ECGrav/ECGrav-1.17.0/`
- **kind / stage / status:** vendored / setup / superseded
- **purpose:** ECGrav upstream v1.17.0 (commit d15739ce, WolframVersion 15.0+), byte-identical to upstream; selectable with COMB_ECGRAV_VERSION=1.17.0 to reproduce Phase 5a (exact/MCMC sampler validation, the ecgexact/ecgmcmc WXFs in data/).
- **env:** `COMB_ECGRAV_VERSION=1.17.0`
- **issues:** Three full ECGrav copies (~0.4-0.8 MB each) vendored side by side; only the version used for published data needs to remain.; Reproducing Phase 5a requires remembering to set the env var; data files do not carry the version.

### `ECGrav/ECGrav-1.0.0/`
- **kind / stage / status:** vendored / setup / superseded
- **purpose:** ECGrav upstream v1.0.0 (WolframVersion 14.2+; no LICENSE or SOURCE_COMMIT.txt in dir); selectable with COMB_ECGRAV_VERSION=1.0.0 to reproduce Phase 4 (IS q=10 data, MH/truth era).
- **env:** `COMB_ECGRAV_VERSION=1.0.0`
- **issues:** Missing LICENSE and SOURCE_COMMIT.txt (provenance only stated in agent-task.md).; The q=10 IS data (data/p*q10_*) feeding current manuscript panels was generated under this version; reproducing them needs this snapshot plus multi-hour runs.

### `ECGrav/BuildingAndInstallingPaclets.nb`
- **kind / stage / status:** notebook / setup / unclear
- **purpose:** Upstream ECGrav tutorial notebook (596 KB) on building/installing/loading the paclet and basic simplicial-complex constructions (FacetLabeledVertexListFromComplex, ComplexFromFacetLabeledVertexList, ...).
- **issues:** Not referenced by any script or doc.; Contains other users' hardcoded paths (C:\Users\Dinosaur\..., /Users/012759760/Library/...) and references ECGrav-1.0.0.paclet in Downloads.; Superseded by src/install_ecgrav_global.wl for this repo's setup.

### `archive/ECGrav-v1.1.0-snapshot/`
- **kind / stage / status:** archive / archive / dead
- **purpose:** Former ECGrav/ECGrav-main snapshot, actually upstream v1.1.0 (cb2dd35, 2026-01-21) though PacletInfo says 1.0.0; archived 2026-11-18 when scripts moved to one pinned dist.
- **issues:** PacletInfo version mislabeled 1.0.0; not loadable via load_ecgrav.wl (path outside ECGrav/).; Referenced only from AGENTS.md / agent-task.md; any data produced with it (old COMB_ECGRAV_MAIN nnFixed mode) is no longer reproducible through the loader.

### `archive/old_logs/`
- **kind / stage / status:** archive / archive / dead
- **purpose:** compute_run.log (early q=10 IS run, N=10000, outputDir C:\CombResearch\) and weight_summary.txt (ESS/top-weight summary written by archive/tests/inspect_weights.wl).
- **issues:** Not referenced anywhere; contains hardcoded C:\CombResearch path.

### `archive/old_renders_n10k/`
- **kind / stage / status:** archive / archive / superseded
- **purpose:** 26 files fig03..fig15_{stat}.{pdf,png}: stacked q=10 figure previews rendered from the N=10k IS run (old render_all_figures sampleTag).
- **issues:** Not referenced; no current script produces n10k renders.

### `archive/old_test_scripts/`
- **kind / stage / status:** archive / archive / dead
- **purpose:** 8 historical probes moved out of src/ (2026-05-16): benchmark_kernels.wl, benchmark_kernels_uniformity.wl, benchmark_samplers.wl (MH proposal-kernel / IS vs MH benchmarks), probe_clique_vs_bipartite.wl, probe_mckay_primitives.wl (McKay canonicalization timing), probe_p4_cheap.wl ((4,4) cheap-pipeline memory), scaling_probe.wl, scaling_probe_streaming.wl (enumeration scaling grid). Logs of their runs live in logs/ (scaling_probe*.log, probe_clique_vs_bipartite.log, mckay_primitives_*.log).
- **loads:** `src/sampler_mh.wl (as cwd-relative Get["src/sampler_mh.wl"])`; `streaming_enumerator.wl / streaming_enumerator_bliss.wl (via scriptDir = archive/old_test_scripts, so these Gets now FAIL)`
- **reads:** `data/p{p}q10_merged_stats.wxf (benchmark_samplers)`
- **env:** `COMB_PROBE_GRID`; `COMB_PROBE_TIMEOUT`
- **issues:** Broken after the move: Get[FileNameJoin[{scriptDir, "streaming_enumerator*.wl"}]] resolves to archive/old_test_scripts/ where the enumerators do not exist; benchmark_* use cwd-relative Get["src/sampler_mh.wl"].; Use bare Needs["ECGrav`"] (violates load_ecgrav rule; would load whatever is globally installed).; probe_mckay_primitives.wl is still mentioned in a comment in src/streaming_enumerator_bliss.wl and in docs/agent-task.md.

### `archive/related_pdfs/`
- **kind / stage / status:** archive / archive / unclear
- **purpose:** Random_Pure_Simplicial_Complexes_with_Fixed_Number_of_Facets-3.pdf (2.6 MB), a related paper/preprint PDF.
- **issues:** Not referenced; possible copyright/licensing concern for a public repo (third-party or unpublished preprint).

### `archive/tests/`
- **kind / stage / status:** archive / archive / dead
- **purpose:** Earliest scratch tests: diagnose_weights.wl and inspect_weights.wl (ESS-collapse diagnosis on q10 sample CSVs; inspect writes weight_summary.txt), render_fig3_test.wl (standalone Fig 3 renderer -> fig3_numVertices_TEST.{pdf,png}, kept here), test_enum.wl (ECGrav full enumeration at q=10 timing), test_per_sample_cost.wl (per-sample stats cost).
- **reads:** `p{p}q10_n500000_samples.csv (in script dir)`; `p{p}q10_n10000_samples.csv (cwd)`
- **writes:** `weight_summary.txt (cwd)`; `fig3_numVertices_TEST.{pdf,png} (script dir)`
- **issues:** Read CSVs from the script's own dir / cwd (pre-comb_paths layout); will not run as is.; Bare Needs["ECGrav`"].

### `figures/manuscript_panels/`
- **kind / stage / status:** render / render / production
- **purpose:** 339 tracked per-panel PDFs (15 MB): 273 truthSX{Stat}[_conn]_p{p}q{q}_{vertex|facet|unlabeled}.pdf over the 9 truth cells (truth + MH + IS overlays) from src/render_truth_overlay.wl; 33 p{2,3,4}q10[conn]SX{Stat}_merged.pdf from src/render_all_figures.wl (sampleTag="merged"); 33 p{2,3,4}q10[conn]SX{Stat}_n500k.pdf from an earlier render_all_figures run.
- **issues:** _n500k panels are orphans: render_all_figures.wl now hardcodes sampleTag="merged", so no current config produces them.; Names do not match manuscript Images/ paths; no script stages panels for the tex.; Generated outputs committed to git while data inputs are not, so figures cannot be regenerated by a cloner without multi-day compute.; q=10 _merged panels are reweighted IS (ESS 25-667) that docs/sampling.md calls diagnostic-only.

### `figures/stacked_previews/`
- **kind / stage / status:** render / render / production
- **purpose:** 92 tracked files: 26 fig{03..15}_{stat}.{pdf,png} stacked q=10 previews from src/render_all_figures.wl; 66 truth_fig{NN}_{stat}_{target}.{pdf,png} stacked truth-overlay previews from src/render_truth_overlay.wl.
- **issues:** Review previews, not manuscript figures, but committed; regenerated outputs overwrite tracked files.

### `figures/combined/`
- **kind / stage / status:** render / render / production
- **purpose:** 3 multi-page review PDFs: combined_truth_overlay.pdf (src/render_truth_overlay.wl), combined_all_figures_merged.pdf (src/render_all_figures.wl), combined_all_figures_n500k.pdf (older render_all_figures run).
- **issues:** combined_all_figures_n500k.pdf is an orphan (no current script config produces it).; src/concat_samples.wl matches 'combined' only as a word in text, not as a producer.

### `figures/is_vs_mh/`
- **kind / stage / status:** render / q10-compare / production
- **purpose:** 7 Phase 4c comparison figures: q10_is_vs_mh_grid.{pdf,png} and q10_p4_focus.png (src/render_q10_is_vs_mh.wl), q10_warm_vs_prod.{pdf,png} (src/render_q10_warm_vs_prod.wl), q5_is_mh_truth_3way.{pdf,png} (src/render_3way.wl).
- **issues:** render_q10_is_vs_mh.wl is not listed in AGENTS.md commands.; Inputs (q10 MH WXFs, IS numv_hist WXFs) are gitignored and only on the Ryzen main checkout.

### `figures/sampler_diagnostics/`
- **kind / stage / status:** render / render / validation
- **purpose:** 6 diagnostic figures: sampler_mh_progress.{pdf,png} (src/render_sampler_progress.wl), sampler_mh_uniformity.{pdf,png} (src/render_uniformity_check.wl), sampler_ecgrav_compare.{pdf,png} (src/render_ecgrav_compare.wl).
- **issues:** Producers not in AGENTS.md command list (only in docs/sampling.md); render_sampler_progress reads the legacy data/p4q10_n500000_samples.csv.

### `C:/CombResearch/data (main checkout, not in git except 4 .mx)`
- **kind / stage / status:** config / util / production
- **purpose:** Shared generated-data store resolved by comb_paths.wl ($CombDataDir). 147 files, 9.0 GB, 1 subdir. Families (count): p{p}q{q}_truth.wxf (9, 3.2 MB total, enumerate_truth.wl) + p4q4_truth_mckay.wxf (1); p{p}q{q}_mh_{vertex,unlabeled,facet}.wxf (27 = cells (2,4),(2,5),(2,6),(3,4),(3,5),(4,5) + q10 p=2,3,4; run_mh_chains.wl); p{3,4}q10_mh_{facet,unlabeled}_seed67890_warm{14,18}.wxf (4; run_q10_mh_overnight.ps1); p{p}q{q}_ecgexact_{target}.wxf (27, 107 MB) and _ecgmcmc_{target}.wxf (27, 26 MB) and p{2,3}q4_ecglegacyfacet_facet.wxf (2) (run_ecgrav_samplers.wl, ECGrav 1.17.0); p{p}q{q}_is_{target}_numv_hist.wxf (15 = q10 x3 from precompute_is_histograms_q10.wl, (3,5),(4,5) x3 from run_is_at_truth_cells.wl); q=10 IS raw (8.7 GB): p{2,3,4}q10_n500000_{samples.csv,stats.wxf}, p{2,3,4}q10_n1500000_batch2_{samples.csv,stats.wxf}, p{3,4}q10_n10000000_batch3_{stats,complexes}.wxf (pure_simplicial_compute.wl via run_parallel.ps1), p{2,3,4}q10_merged_stats.wxf (concat_samples.wl); summaries validation_{ecgexact,ecgmcmc,ecglegacyfacet}_summary.wxf (validate_mh_vs_truth.wl), sampler_efficiency_summary.wxf, q10_is_vs_mh_summary.wxf, q10_warm_vs_prod_summary.wxf, is_mh_truth_3way_summary.wxf; Betre p4q{4,5}SX{FacetLabeled,Unlabeled}.mx (4, git-tracked, read only by probe_betre_mx.wl); q10_pilot_archive/p{3,4}q10_mh_{facet,unlabeled}_pilot10k.wxf (4); p3q5_mh_vertex.2026-05-17.wxf.bak (1).
- **env:** `COMB_ROOT`
- **issues:** ORPHANS (no current src script writes them): q10_pilot_archive/*_pilot10k.wxf (manual copy), p3q5_mh_vertex.2026-05-17.wxf.bak (manual), p4q{4,5}SX*.mx (external from Betre), p{p}q10_*_samples.csv (legacy; pure_simplicial_compute may still write CSV in overnight mode; migrate_csv_to_wxf.wl is a one-shot converter), p4q5_truth.wxf (manual copy of p4q5_truth_mckay — p4q5_truth_mckay.wxf itself is absent from main).; UNREAD (no current consumer): p{3,4}q10_n10000000_batch3_complexes.wxf (3.2 GB; only concat_samples looks for *_complexes siblings to build p{p}q10_merged_complexes.wxf, which does not exist), p4q4_truth_mckay.wxf (cross-check only), the 4 pilot10k files, the .bak.; MISSING vs docs: MH WXFs for (2,7),(3,6),(4,4); p{p}q10_merged_complexes.wxf; data/phase5a_ecgrav-1.17.0 backup; Betre WXF re-exports.; Stale-content risk: vertex MH for (2,4),(2,5),(2,6),(3,4) may be pre-2026-05-14-fix copies (agent-task says rerun before use); p3q5_mh_vertex was replaced Sep 25.; 9 GB exists only on one Windows PC; nothing is published (no Zenodo/release), so a cloner must regenerate everything (truth (4,5) 17 h; q=10 IS multi-day; MH (4,5) ~6 h; ECGrav unlabeled campaign ~2 h).; p4q5SXFacetLabeled.mx (103.6 MB) is committed to git without LFS — over GitHub's 50 MB warning and near the 100 MiB hard limit; .mx is platform-locked (MacOSX-ARM64) and unreadable on Windows/Linux.; WXF payloads lack ECGrav version for Phase 5a data; nondeterminism across ECGrav versions for seeded draws.

### `C:/CombResearch/logs (main checkout; all 98 files tracked in git)`
- **kind / stage / status:** config / util / production
- **purpose:** Run logs ($CombLogsDir). 98 files, 526 KB, flat. Families: compute_p{2,3,4}[_batch{2,3}].{log,err}[.1] (22; run_parallel.ps1), ecg{exact,mcmc}_{vertex,unlabeled,facet}.{log,err} (12; run_ecgrav_campaign.ps1), mh_p4q5_{target}.{log,err} (6; run_p4q5_mh_parallel.ps1), mh_q10_pilot_p{2,3,4}_{target}.log (9; run_q10_mh_pilot.ps1), mh_q10_prod_p{3,4}_{facet,unlabeled}.log (4; run_q10_mh_parallel.ps1), mh_q10_overnight_*_seed67890_warm*.log (4) + mh_q10_restore_p4_unlabeled.log (1) (run_q10_mh_overnight.ps1), overnight.log (manual redirect of pure_simplicial_compute_overnight.wl); manual-redirect logs with no producing launcher: enumerate_*.log, enumerate_truth_{smoke,phase3,full}.log, truth_p4q4_mckay.log, p4q4_cheap_seq.log, mckay_{baseline,v2,v3,v3_p2q5,v3_p3q5}.log, mckay_primitives_{baseline,v2}.log, mh_full.log, mh_p3q3.log, mh_p3q5_vertex_fixed.log, mh_part{A,B,C}.{log,err}, mh_remaining.{log,err}, mh_phase4a_plus_p4q4.log, mh_vertex_fix_batch.log, run_mh_chains_{smoke,full}.log, validate_p3q5_vertex.log, concat_post_batch3.log, render.log, render_post_batch3.log, fixed_n30_smoke_n100k.log, probe_betre_mx.log, probe_clique_vs_bipartite.log, scaling_probe{,_streaming}.log.
- **issues:** ~40 of 98 logs were produced by ad-hoc shell redirection, not by any script (orphans); several correspond to archived probes.; Read only by monitor_mh.ps1 / monitor_ecgrav.ps1 (live dashboards); no script parses logs for results.; Tracked in git while the data they describe is not; .err/.log.1 rotation artifacts committed.; Logs embed machine paths (C:\CombResearch\...).

## Critic pass

{
"scope": "Read-only critic pass on C:\\CombResearch\\.claude\\worktrees\\ecstatic-wiles-75960d. Nothing was edited. git ls-files returns 677 tracked files: 447 under figures/, 98 under logs/, and 132 others.",

"1_untracked_by_inventory": {
 "tracked_files_with_no_record": [
  ".gitignore. It ignores data/**/*.wxf, data/**/*.csv, *.wxf.bak, *.tmp and .claude/* except settings.json. It does NOT ignore *.mx, which is why the four data/p4q{4,5}SX*.mx files are committed. It also does not ignore logs/ or figures/, so both are fully tracked. It references archive/superseded_data/, which does not exist."
 ],
 "covered_only_by_a_directory_record_(ok)": "ECGrav/*/Kernel/Subpackages/{MCSims,PureComplexes}.wl, archive/ECGrav-v1.1.0-snapshot/*, archive/tests/fig3_numVertices_TEST.{pdf,png}, archive/old_renders_n10k/* (26 files)",
 "untracked_on_disk": "docs/architecture/ (the orchestrator's own output)"
},

"2_edge_spot_checks": {
 "confirmed": [
  "enumerate_truth.wl builds truthFile as $CombDataDir/p{p}q{q}_truth[_{pipeline}].wxf, with no suffix for cheap (l.119-121). It hardcodes ecGravVersion=\"1.0.0\" (l.98). defaultCells has 5 cells (l.56). expectedIsoCounts has gates only for (2,4)=11, (2,5)=26, (2,6)=68, (3,4)=66 and (3,5)=445, so (2,7), (3,6), (4,4) and (4,5) have no gate.",
  "No script reads _truth_mckay or _truth_bliss. docs/enumeration.md l.72 states that p4q5_truth.wxf is a manual copy of the McKay output. This confirms a manual step.",
  "run_mh_chains.wl writes {outputDir}/p{p}q{q}_mh_{target}{COMB_MH_TAG}.wxf (l.149), with outputDir = COMB_MH_OUTDIR or $CombDataDir. The (3,5) gate also reads _truth.wxf from outputDir, not $CombDataDir (minor: if COMB_MH_OUTDIR is set, the gate looks in the wrong place).",
  "pure_simplicial_compute.wl names files p{p}q10_n{N}[_nn{k}][_{runTag}]_{stats,complexes}.wxf plus _chunk_{k}_ temporaries (l.158-168), and Gets load_ecgrav.wl and comb_paths.wl.",
  "concat_samples.wl globs FileNames[\"p{p}q10_*_stats.wxf\"] and excludes only the merged file (l.36-39), so any stray *_stats.wxf is merged. It writes merged_complexes only if every input has a complexes sibling (l.106-123); otherwise it prints 'skipped'.",
  "validate_mh_vs_truth.wl reads p{p}q{q}_truth.wxf and p{p}q{q}_{source}_{target}.wxf and writes validation_{source}_summary.wxf. It calls RandomVariate with no SeedRandom (l.153).",
  "render_all_figures.wl reads p{p}q10_merged_stats.wxf, falling back to p{p}q10_merged_samples.csv. It writes manuscript_panels/*_merged.pdf, stacked_previews/fig*.{pdf,png} and combined/combined_all_figures_merged.pdf.",
  "compare_3way.wl and run_is_at_truth_cells.wl use the same isFile pattern, p{p}q{q}_is_{t}_numv_hist.wxf. precompute_is_histograms_q10.wl writes p{p}q10_is_{t}_numv_hist.wxf from p{p}q10_merged_stats.wxf.",
  "run_parallel.ps1 dot-sources comb_paths.ps1 but builds the logs path as Join-Path $CombRoot 'logs'. Its default COMB_PLIST is \"3,4\" and it spawns run_p{p}.wl. Every .ps1 builds the logs path this way and none uses $CombLogsDir.",
  "Three scripts Get[\"src/sampler_mh.wl\"] with a cwd-relative path: render_ecgrav_compare (l.20), render_sampler_progress (l.13) and render_uniformity_check (l.15). Five scripts set $smokeTestSkip=True before loading sampler_mh: run_mh_chains, compare_samplers_efficiency and those three renders.",
  "render_truth_overlay.wl reads only _truth.wxf and _mh_{target}.wxf, with silent $Failed on a missing file. It reuses COMB_TRUTH_CELLS. It has no IS layer, which confirms that the AGENTS.md description is stale.",
  "docs/agent-task.md lines 285-286 and 336-337 are corrupted: 'src' followed by a newline and 'un_ecgrav_campaign.ps1'.",
  "data/p4q5SXFacetLabeled.mx is tracked at 103,604,366 bytes."
 ],
 "wrong_or_imprecise": [
  "Group A groupNotes lists sampler_mh.wl and run_is_at_truth_cells.wl as consumers of _truth.wxf. Neither reads it; they mention truth in comments only. The actual readers are run_mh_chains (gate only), run_ecgrav_samplers, validate_mh_vs_truth, validate_counts_vs_truth, compare_samplers_efficiency, render_truth_overlay, compare_3way and render_3way.",
  "The Group E data record says pure_simplicial_compute 'may still write CSV in overnight mode'. False: no src script exports CSV. CSV appears only in stale comments in pure_simplicial_compute l.30, pure_simplicial_compute_overnight l.4 and run_parallel l.27. Every *_samples.csv is a legacy external input.",
  "Group D says the 'ExpansionRoadmap.md' cited in run_ecgrav_samplers.wl l.123 is missing. It is an upstream ECGrav design doc, also cited inside ECGrav-1.18.0-474b5c2/Kernel/Subpackages/MCSims.wl, so the reference is to upstream and not to a lost file in this repo. It is still not in the repo.",
  "Group D: compare_samplers_efficiency.wl calls no ECGrav function directly. The issue is stated correctly, but its load_ecgrav Get is redundant because sampler_mh.wl already Gets load_ecgrav.",
  "Group C: the run_mh_chains.wl loads list should say load_ecgrav arrives through sampler_mh.wl and through pure_simplicial_compute.wl. It does not Get load_ecgrav directly. That is the inventory's meaning, but it is listed as if it were a direct edge.",
  "Group A, test_streaming.wl: the iso counts '11/26/66' correspond to (2,4), (2,5) and (3,4). enumerate_truth's gate for (2,6) is 68. Not an error, but the record should not imply 66 for (2,6).",
  "Group B describes probe_betre_mx.wl as 'dead'. It is still runnable by intent and fails only because the .mx files are platform-locked. Classify it as an obsolete one-off."
 ]
},

"3_data_handoffs": [
 {"pattern":"data/p{p}q{q}_truth.wxf","writers":["enumerate_truth.wl (cheap pipeline only)","MANUAL copy of p4q5_truth_mckay.wxf, and in practice any McKay cell"],"readers":["run_mh_chains (3,5 gate)","run_ecgrav_samplers (classIdx, optional)","validate_mh_vs_truth","validate_counts_vs_truth","compare_samplers_efficiency","render_truth_overlay","compare_3way","render_3way"]},
 {"pattern":"data/p{p}q{q}_truth_{bliss|mckay}.wxf","writers":["enumerate_truth.wl (COMB_TRUTH_PIPELINE)"],"readers":[],"flag":"WRITTEN_NEVER_READ (needs a manual rename to _truth.wxf)"},
 {"pattern":"data/p{p}q10_n{N}[_nn][_tag]_{stats,complexes}.wxf","writers":["pure_simplicial_compute via run_p{2,3,4}.wl, run_parallel.ps1 and pure_simplicial_compute_overnight","migrate_csv_to_wxf (stats only, from CSV)"],"readers":["concat_samples (glob)","pure_simplicial_compute (resume of chunk files)"]},
 {"pattern":"data/p{p}q10_merged_stats.wxf","writers":["concat_samples"],"readers":["render_all_figures","precompute_is_histograms_q10","precompute_is_histogram (p=4)","compare_samplers_efficiency (q=10)","archive benchmark_samplers"]},
 {"pattern":"data/p{p}q10_merged_complexes.wxf","writers":["concat_samples (conditional)"],"readers":[],"flag":"WRITTEN_NEVER_READ (and absent on disk)"},
 {"pattern":"data/*_samples.csv","writers":[],"readers":["migrate_csv_to_wxf","render_sampler_progress (p4q10_n500000_samples.csv)","render_all_figures fallback (merged_samples.csv, never present)","pure_simplicial_figures.nb (p{p}q10_n500000_samples.csv)","archive/tests/*"],"flag":"READ_NEVER_WRITTEN (legacy external input)"},
 {"pattern":"data/p{p}q10_is_{t}_numv_hist.wxf","writers":["precompute_is_histograms_q10","precompute_is_histogram (p4 unlabeled, collides with the _q10 version)"],"readers":["compare_is_mh_q10","render_q10_is_vs_mh","compare_q10_warm_vs_prod","render_q10_warm_vs_prod"]},
 {"pattern":"data/p{p}q{q}_is_{t}_numv_hist.wxf, q=5 cells (3,5),(4,5)","writers":["run_is_at_truth_cells"],"readers":["compare_3way","render_3way"]},
 {"pattern":"data/p{p}q{q}_mh_{target}.wxf","writers":["run_mh_chains, launched by run_p4q5_mh_parallel.ps1, run_q10_mh_pilot.ps1, run_q10_mh_parallel.ps1 and run_q10_mh_overnight.ps1 step 1, plus manual COMB_MH_CELLS runs"],"readers":["validate_mh_vs_truth (source=mh)","render_truth_overlay","compare_samplers_efficiency","compare_3way","render_3way","compare_is_mh_q10","render_q10_is_vs_mh","compare_q10_warm_vs_prod","render_q10_warm_vs_prod","monitor_mh.ps1 (existence only)"],"flag":"The q=10 pilot and q=10 production runs write the same name. No launcher covers (2,7), (3,6) or (4,4)."},
 {"pattern":"data/p{3,4}q10_mh_{t}_seed67890_warm{14,18}.wxf","writers":["run_q10_mh_overnight.ps1 -> run_mh_chains"],"readers":["compare_q10_warm_vs_prod","render_q10_warm_vs_prod"]},
 {"pattern":"data/p{p}q{q}_ecg{exact|mcmc|legacyfacet}_{t}.wxf","writers":["run_ecgrav_samplers (run_ecgrav_campaign.ps1)"],"readers":["validate_mh_vs_truth (COMB_VAL_SOURCE)","compare_samplers_efficiency (exact and mcmc only)","monitor_ecgrav.ps1 (count)"]},
 {"pattern":"data/{validation_*,sampler_efficiency,q10_is_vs_mh,is_mh_truth_3way,q10_warm_vs_prod}_summary.wxf","writers":["validate_mh_vs_truth","compare_samplers_efficiency","compare_is_mh_q10","compare_3way","compare_q10_warm_vs_prod"],"readers":[],"flag":"WRITTEN_NEVER_READ by any script. render_3way recomputes its L1s; the docs transcribe numbers by hand."},
 {"pattern":"data/p4q{4,5}SX{FacetLabeled,Unlabeled}.mx","writers":[],"readers":["probe_betre_mx"],"flag":"READ_NEVER_WRITTEN (external, from Betre, git-tracked)"},
 {"pattern":"logs/*.log|*.err","writers":["run_parallel","run_p4q5_mh_parallel","run_q10_mh_{pilot,parallel,overnight}","run_ecgrav_campaign","manual shell redirects"],"readers":["monitor_mh (mh_{p4q5}_{t}.log only)","monitor_ecgrav (ecg{s}_{t}.{log,err})","run_ecgrav_campaign (post-run grep)"]},
 {"pattern":"Figure 2 p3q3_n10000_* CSV and PDF","writers":["src/reference/histograms_handoff_v2.nb","histograms_paper_figures.nb (front-end Directory[])"],"readers":["histograms_paper_figures.nb via kernel state, not files"],"flag":"outside data/ and figures/"},
 {"pattern":"Images/*.pdf and bibliography.bib (the manuscript tex)","writers":[],"readers":["docs/Pure Clique Complexes.tex"],"flag":"READ_NEVER_WRITTEN (missing). The renderer outputs figures/manuscript_panels/*_merged.pdf are never staged into Images/."}
],

"key_takeaways_for_diagrams": [
 "Hidden manual steps: (a) copy _truth_mckay.wxf to _truth.wxf; (b) several run_parallel runs with different RUNTAGs, then concat_samples; (c) the Figure 2 notebooks run in one kernel session; (d) copy panels into the tex Images/ folder; (e) install_ecgrav_global before opening the notebooks.",
 "Five summary WXFs and the bliss/mckay truth files are dead ends. CSV inputs and .mx files are external with no producer.",
 "Defaults are inconsistent: the truth and MH drivers default to the old 5-cell grid, while validate, ECGrav and render scripts default to the 9-cell grid. run_parallel defaults to p in {3,4}."
]
}