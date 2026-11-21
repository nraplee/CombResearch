# Data provenance (Phase 0)

Reconstructed 2026-11-20 on the Ryzen. Sources: the metadata embedded in each
WXF, the logs in `C:\CombResearch\logs`, and git history. The work was
read-only; nothing in the store was changed. This table backs the manifest
backfill in Phase 2 and the to-do list for regenerating data.

General caveats:

- **Wolfram version.** No file records `$Version`. Runs before 2026-09-25
  were almost certainly 14.x. Runs from 2026-09-25 on were probably 15.0.1.
- **ECGrav before 2026-11-18.** Every script before `98d4045` loaded ECGrav
  with a bare `Needs["ECGrav`"]`, so it used whatever paclet was installed
  globally. That was 1.0.0 according to code comments at `7143104` and
  `5118c14`. Truth files say `"1.0.0"`, but that string is hardcoded
  (`enumerate_truth.wl:98`), not detected. Only the Phase 5a ecg* files
  record their real ECGrav: the vendored 1.17.0 (upstream `d15739c`).
- **Version stamps.** `samplerVersion` (MH) and `enumeratorVersion` (truth)
  are the checkout's `git rev-parse HEAD` at run time. They do not show
  uncommitted edits, and several runs used uncommitted code.
- **Dates.** Most data mtimes of 2026-09-25 23:07–23:12 are copy dates. The
  embedded `createdAt` is the real date, and is what the table uses. The
  p4q4 truth and the ecg* files have mtimes equal to their creation time.
- **Machine.** Never recorded. The IS batches logged "8 kernels active"
  (8C/16T), which suggests the Ryzen.

## Table

| # | Family | Files (`data/`) | Made by | Date | ECGrav | Seed / settings |
|---|---|---|---|---|---|---|
| T1 | truth, small grid | `p2q{4,5,6}_truth`, `p3q{4,5}_truth` | `enumerate_truth.wl` cheap, Parallel, `@9468fff`, worktree adoring-hoover (`enumerate_truth_phase3.log`, wall times match) | 2026-05-05 | global, likely 1.0.0 | deterministic |
| T2 | truth, (2,7) (3,6) | `p2q7_truth`, `p3q6_truth` | cheap, Parallel, `@63c90a5` (pre-squash PR #8 commit, on no branch); **no log** | 2026-05-08/09 | global, likely 1.0.0 | deterministic; (3,6) took 17.2 h |
| T3 | truth, (4,4) | `p4q4_truth` = `p4q4_truth_mckay` (byte-identical) | McKay, sequential, `@955238d` + uncommitted Phase 5a (`truth_p4q4_mckay.log`); hand-copied to `_truth` | 2026-09-25 23:12 | global: 1.0.0 **or** 1.17.0 (both installed that day, order unknown) | deterministic |
| T4 | truth, (4,5) | `p4q5_truth` | McKay, sequential, `@7143104` + uncommitted Phase 4b, worktree optimistic-fermi (`enumerate_p4q5_mckay.log`); renamed from `_truth_mckay` (that original is gone) | 2026-05-13/14, 17.1 h, 7.9 GB peak | global, likely 1.0.0 | deterministic |
| I1 | q=10 IS batch 1 | `p{2,3,4}q10_n500000_samples.csv`, `..._stats.wxf` | `pure_simplicial_compute_overnight.wl`, pre-git code, serial (`overnight.log`); stats WXF migrated from CSV by `migrate_csv_to_wxf.wl` `@e671bda` on 04-23 | 2026-04-21/22 | global, likely 1.0.0 | `SeedRandom[123456+1000p+k]`, k=1..20; N=500k, chunk 25k |
| I2 | q=10 IS batch2 | `p{2,3,4}q10_n1500000_batch2_*` | `run_parallel.ps1` → `run_p{p}.wl` `@965d1ed`, 3 processes × 8 kernels; license-error crash, relaunched 01:09 (`compute_p*_batch2.log*`); WXF migrated 04-23 | 2026-04-23 | global, likely 1.0.0 | offset `Mod[Hash["batch2","MD5"],10^7]` = 2264134; N=1.5M, chunk 25k |
| I3 | q=10 IS batch3 | `p{3,4}q10_n10000000_batch3_{stats,complexes}` | `run_parallel.ps1` `@e671bda`, default p list "3,4" (**no p=2**) | 2026-04-23 → 04-26 (p3), 04-27 (p4) | global, likely 1.0.0 | offset 6102964; N=10M, chunk 25k |
| I4 | q=10 merged | `p{2,3,4}q10_merged_stats` | `concat_samples.wl` ≈ `c33b664`, run just before it was committed (`concat_post_batch3.log`) | 2026-04-27 20:42–20:45 | – | rows in order batch3, batch2, n500000; p2 2M rows, p3/p4 12M |
| I5 | q=10 IS numV hists | `p{2,3,4}q10_is_{t}_numv_hist` | `precompute_is_histograms_q10.wl` (key order proves it; committed later in `9700ca9`) | ≤ 2026-05-17 21:04 | – | from I4; no createdAt |
| I6 | IS hists at (3,5) (4,5) | `p{3,4}q5_is_{t}_numv_hist` | `run_is_at_truth_cells.wl` (May version, `9700ca9`); no log | ≤ 2026-05-17 22:21 | global, likely 1.0.0 | seed 42; N=100k; chunk 5000 assumed |
| M1 | MH smoke (2,4) | `p2q4_mh_{unlabeled,facet}` | `run_mh_chains.wl` `@9468fff` (`run_mh_chains_smoke.log`) | 2026-05-05 | global, unknown | seed 12345; **30k**/3k/thin 5 |
| M2 | MH (2,5)(2,6)(3,4)(3,5) | `..._mh_{unlabeled,facet}` | `@9468fff`, several manual runs (`run_mh_chains_full`, `mh_remaining`, `mh_part{A,B,C}`) | 2026-05-06 | global, unknown | 12345; 200k/20k/5 |
| M3 | **MH vertex, pre-fix (wrong)** | `p2q{4,5,6}_mh_vertex`, `p3q{4,5}_mh_vertex` | `@9468fff` (vertex `piRatio = 1` bug) | 2026-05-05/06 | global | acceptRate exactly 1.0; L1 vs truth 0.68–0.85 |
| M4 | MH (3,5) vertex, post-fix | `p3q5_mh_vertex.2026-05-17.wxf.bak` | `@7143104` + uncommitted fix (`mh_p3q5_vertex_fixed.log`) | 2026-05-14 15:48 | global | 12345; 200k; accept 0.576 |
| M5 | MH (4,5) | `p4q5_mh_{vertex,unlabeled,facet}` | `run_p4q5_mh_parallel.ps1`, `@7143104` + fix | 2026-05-15 | global | 12345; 200k; vertex is post-fix |
| M6 | MH q=10 pilot | `p2q10_mh_*`, `p{3,4}q10_mh_vertex` | `run_q10_mh_pilot.ps1`, main checkout `@955238d` | 2026-05-17 | global | 12345; **10k**/1k/thin 2 |
| M7 | MH q=10 pilot archive | `q10_pilot_archive/p{3,4}q10_mh_{unlabeled,facet}_pilot10k` | M6 copies, saved by hand before the production run | 2026-05-17 | global | as M6 |
| M8 | MH q=10 production | `p3q10_mh_{unlabeled,facet}`, `p4q10_mh_facet` | `run_q10_mh_parallel.ps1` `@955238d` | 2026-05-17 | global | 12345; 200k/20k/5 |
| M9 | MH q=10 (4,10) unlabeled | `p4q10_mh_unlabeled` | restore step of `run_q10_mh_overnight.ps1`, `@8d10379`; same chain as the 05-17 original (identical deltaNumVCounts) | 2026-05-18 01:35 | global | 12345; 200k |
| M10 | MH q=10 warm, 2nd seed | `p{3,4}q10_mh_{t}_seed67890_warm{14,18}` | `run_q10_mh_overnight.ps1` `@8d10379` | 2026-05-18 | global | 67890; 1M/50k/20; initNumV requested 14/18, **actual 11/17** (only the requested value is stored) |
| E1 | ECGrav exact | `p*_ecgexact_{t}` (27) | `run_ecgrav_samplers.wl`, draft just before `5118c14`; `run_ecgrav_campaign.ps1` (`ecgexact_*.log`) | 2026-09-25 23:41 – 09-26 00:19 | **1.17.0** vendored (`d15739c`), embedded | 24680; N=100k, batch 2000 |
| E2 | ECGrav MCMC | `p*_ecgmcmc_{t}` (27) | same script ≈ `5118c14` (`ecgmcmc_*.log`) | 2026-09-26 03:00–05:10 | **1.17.0**, embedded | 24680; N=20k; trace 200k steps |
| E3 | ECGrav legacy facet (negative control) | `p{2,3}q4_ecglegacyfacet_facet` | same script, run by hand; no log | 2026-09-25 23:39 | 1.17.0, embedded | 24680; N=20k |
| S1 | validation summaries | `validation_{ecgexact,ecgmcmc,ecglegacyfacet}_summary` | `validate_mh_vs_truth.wl` ≈ `5118c14` | 2026-09-25/26 | inputs E1–E3 | exact one overwritten 11-20, restored (identical to the 09-26 file) |
| S2 | sampler efficiency | `sampler_efficiency_summary` | `compare_samplers_efficiency.wl` ≈ `5118c14`, 9 truth cells only | 2026-09-26 05:13 | 1.17.0 embedded | its MH vertex rows used the **pre-fix** M3 chains |
| S3 | 3-way at q=5 | `is_mh_truth_3way_summary` | `compare_3way.wl` (May; committed later in `9700ca9`) | 2026-05-17 22:21 | – | used M4 (the good (3,5) vertex chain) |
| S4 | q=10 IS vs MH | `q10_is_vs_mh_summary` | `compare_is_mh_q10.wl` | 2026-05-17 21:04 | – | read the original (4,10) unlabeled chain; M9 reproduces it |
| S5 | q=10 warm vs prod | `q10_warm_vs_prod_summary` | `compare_q10_warm_vs_prod.wl` | 2026-05-18 06:16 | – | inputs M8–M10 |
| B1 | Betre `.mx` | `p4q{4,5}SX{FacetLabeled,Unlabeled}.mx` | Dr. Betre; git `28f97f0` | received 2026-05-15 | unknown | MacOSX-ARM64 dumps, unreadable on Windows; only git-tracked files in `data/` |

## Problems found

1. **Five live vertex MH chains are wrong (M3).** `p2q4`, `p2q5`, `p2q6`,
   `p3q4` and `p3q5` `_mh_vertex.wxf` predate the 2026-05-14 vertex fix
   (acceptRate exactly 1.0). The post-fix reruns of (2,4), (2,5), (2,6) and
   (3,4) were written to the optimistic-fermi worktree, which is gone. The
   good (3,5) chain survives only as the `.bak` (M4): the 11-20 consolidation
   replaced it with the stale copy. Consequences:
   - `sampler_efficiency_summary` already used the bad chains for its MH
     vertex rows.
   - Rerunning `compare_3way.wl` or `render_3way.wl` now gives
     L1(MH,T) = 0.848 at (3,5) vertex instead of 0.014.
2. **MH chains missing for 3 of the 9 truth cells.** (2,7), (3,6) and (4,4),
   all targets, plus (3,3), were also lost with optimistic-fermi. "MH
   validates on all 27 cell × target pairs" (AGENTS.md) is not backed by
   stored data any more. 6 cells have MH, and only (4,5) vertex is post-fix.
3. **(2,4) MH unlabeled/facet are 30k smoke chains**, not 200k.
4. **Truth metadata.**
   - `totalFacetLabeled` means the McKay emission count for (4,4) and
     (4,5), but the facet-labeled total for the cheap cells: 2169 against
     3642, and 241742 against 469368.
   - The May cheap (4,4) truth was replaced by the McKay rerun, and no copy
     remains.
   - Iso counts agree with the ECGrav counters on all 9 cells.
5. **Mixed row types in the q=10 merged stats.**
   - Rows migrated from CSV (n500000, batch2) have Real weights,
     `Missing["NotAvailable"]` for absent columns, and Real `aut` at p=4,
     which loses precision above 2^53.
   - batch3 rows have exact Rationals and `""`.
   - The merge is by glob with no manifest, so any extra
     `p{p}q10_*_stats.wxf` would be merged silently on a rerun.
6. **Logs missing** for T2, I6, E3, S1, S2, S4 and S5.
7. **Duplicate store.** This worktree (`ecstatic-wiles-75960d/data`, 3.1 GB)
   still holds byte-identical copies of the store. AGENTS.md says worktrees
   keep no data. `docs/agent-task.md` refers to a
   `data/_from_worktrees/CombResearch/` with Codex p4q5 MH variants; that
   folder does not exist.
8. **Name collision.** `precompute_is_histogram.wl` writes the same file name
   as `precompute_is_histograms_q10.wl`, with no skip guard.

## Regeneration to-do (corrects the plan's "MH: No")

| Data | Action | Why |
|---|---|---|
| MH vertex (2,4) (2,5) (2,6) (3,4) | rerun 200k, seed 12345 | pre-fix, wrong |
| MH vertex (3,5) | restore the `.bak` or rerun | pre-fix live file |
| MH (2,7) (3,6) (4,4), 3 targets | run 200k | missing |
| MH (2,4) unlabeled/facet | optional 200k rerun | smoke budget |
| ecgmcmc, then ecgexact | rerun on latest ECGrav | as in `implementation-plan.md` |
| truth, q=10 IS, other MH | keep | verified correct |

Golden/derived freezes the store **as it is** today, including the bad
chains, which are flagged `knownBad`. Any of the fixes above changes some
input hashes, so the matching golden sections must then be re-baselined on
purpose (`COMB_FORCE=1 ... write <section>`).
