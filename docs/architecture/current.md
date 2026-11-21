# Current architecture (as of 2026-11-20, commit b4d4b20)

How the repo works today, at the file level. Built from `inventory.md`, which
has one record per tracked file. There is one overview, then one small
diagram per stage. Data and log nodes are grouped by filename family; all of
them live in the main checkout via `src/comb_paths.wl` / `src/comb_paths.ps1`.

Legend: solid arrow = `Get` / dot-source / launches. Dashed arrow = reads or
writes a data or figure family. Red = broken, orphaned or manual step. Grey
= superseded or dead. Every `.wl` that touches outputs also Gets
`src/comb_paths.wl`; those edges are left out after diagram 1 to keep the
views readable.

## 0. Overview

```mermaid
flowchart LR
  classDef stage fill:#e9f7ef,stroke:#2e7d4f,color:#1d2228
  classDef data fill:#f4f4f4,stroke:#777,stroke-dasharray:3 3,color:#1d2228
  classDef bad fill:#fde8e8,stroke:#c0392b,color:#7b1c1c
  classDef fig fill:#fdf0f6,stroke:#a33d6e,color:#1d2228

  S1["1 Setup<br/>ECGrav loader, paths"]:::stage
  S2["2 Truth enumeration"]:::stage
  S3["3 q=10 IS sampling"]:::stage
  S4["4 MH chains"]:::stage
  S5["5 ECGrav campaign"]:::stage
  S6["6 Validation and comparison"]:::stage
  S7["7 Rendering"]:::stage
  NB["Fig 2 notebooks<br/>src/reference"]:::bad
  TEX["manuscript .tex"]:::bad

  DT[("truth WXF")]:::data
  DIS[("IS raw + merged<br/>~8.7 GB")]:::data
  DMH[("MH WXF")]:::data
  DEG[("ECGrav sample WXF")]:::data
  DSUM[("summary WXF<br/>never read")]:::bad
  FIG[["figures/"]]:::fig

  S1 --> S2 & S3 & S4 & S5
  S2 -.-> DT
  S3 -.-> DIS
  S4 -.-> DMH
  S5 -.-> DEG
  DT & DIS & DMH & DEG -.-> S6 -.-> DSUM
  DT & DIS & DMH -.-> S7 -.-> FIG
  FIG -. "manual copy" .-> TEX
  NB -. "manual" .-> TEX
```

## 1. Setup and plumbing

```mermaid
flowchart LR
  classDef lib fill:#e8f0fe,stroke:#4a6fa5,color:#1d2228
  classDef entry fill:#e9f7ef,stroke:#2e7d4f,color:#1d2228
  classDef ps fill:#fff4e0,stroke:#b9770e,color:#1d2228
  classDef dead fill:#eeeeee,stroke:#aaa,color:#555
  classDef bad fill:#fde8e8,stroke:#c0392b,color:#7b1c1c

  E18["ECGrav-1.18.0-474b5c2<br/>default pin, not validated"]:::bad
  E17["ECGrav-1.17.0<br/>made all Phase 5a data"]:::lib
  E10["ECGrav-1.0.0"]:::dead
  BIP["BuildingAndInstallingPaclets.nb"]:::dead
  LOAD["src/load_ecgrav.wl<br/>COMB_ECGRAV_VERSION"]:::lib
  INST["src/install_ecgrav_global.wl"]:::entry
  GLOB["global paclet store"]:::bad
  PATHS["src/comb_paths.wl"]:::lib
  PPS["src/comb_paths.ps1"]:::lib
  SYNC["src/sync_worktree_data.ps1"]:::ps
  HOOK[".claude/settings.json hooks"]:::ps
  ALL["every src .wl script"]:::entry
  ALLPS["every src .ps1 launcher"]:::ps

  E18 & E17 & E10 --> LOAD --> ALL
  E18 --> INST --> GLOB
  PATHS --> ALL
  PPS --> ALLPS
  HOOK --> SYNC --> PPS
```

## 2. Truth enumeration

```mermaid
flowchart LR
  classDef lib fill:#e8f0fe,stroke:#4a6fa5,color:#1d2228
  classDef entry fill:#e9f7ef,stroke:#2e7d4f,color:#1d2228
  classDef data fill:#f4f4f4,stroke:#777,stroke-dasharray:3 3,color:#1d2228
  classDef bad fill:#fde8e8,stroke:#c0392b,color:#7b1c1c

  ENC["streaming_enumerator.wl<br/>cheap key"]:::lib
  ENB["streaming_enumerator_bliss.wl"]:::lib
  ENM["streaming_enumerator_mckay.wl"]:::lib
  PSC["pure_simplicial_compute.wl<br/>borrowed for statsFor"]:::lib
  ET["enumerate_truth.wl<br/>COMB_TRUTH_*"]:::entry
  T1["test_streaming.wl"]:::entry
  T2["test_streaming_bliss.wl"]:::entry
  T3["test_streaming_mckay.wl"]:::entry
  DT[("p{p}q{q}_truth.wxf")]:::data
  DTA[("p{p}q{q}_truth_mckay.wxf<br/>_truth_bliss.wxf")]:::bad

  ENB --> ENM
  ENC & ENB & ENM --> ET
  PSC --> ET
  ENC --> T1
  ENC & ENB --> T2
  ENC & ENB & ENM --> T3
  ET -. "cheap" .-> DT
  ET -. "bliss, mckay" .-> DTA
  DTA -. "MANUAL rename" .-> DT
```

## 3. q=10 importance sampling

```mermaid
flowchart LR
  classDef lib fill:#e8f0fe,stroke:#4a6fa5,color:#1d2228
  classDef entry fill:#e9f7ef,stroke:#2e7d4f,color:#1d2228
  classDef ps fill:#fff4e0,stroke:#b9770e,color:#1d2228
  classDef data fill:#f4f4f4,stroke:#777,stroke-dasharray:3 3,color:#1d2228
  classDef dead fill:#eeeeee,stroke:#aaa,color:#555
  classDef bad fill:#fde8e8,stroke:#c0392b,color:#7b1c1c

  PSC["pure_simplicial_compute.wl"]:::lib
  RP["run_p2.wl, run_p3.wl, run_p4.wl"]:::entry
  RPAR["run_parallel.ps1<br/>COMB_PLIST, RUNTAG"]:::ps
  PSO["pure_simplicial_compute_overnight.wl"]:::dead
  MIG["migrate_csv_to_wxf.wl"]:::dead
  CAT["concat_samples.wl"]:::entry
  CSV[("*_samples.csv<br/>legacy, no writer")]:::bad
  RAW[("p{p}q10_n{N}_tag_stats.wxf<br/>and _complexes.wxf")]:::data
  MS[("p{p}q10_merged_stats.wxf")]:::data
  MC[("merged_complexes.wxf<br/>never read")]:::dead
  LOG[("logs/compute_p*.log")]:::data

  PSC --> RP & PSO
  RPAR --> RP
  RPAR -.-> LOG
  RP & PSO -.-> RAW
  CSV -.-> MIG -.-> RAW
  RAW -.-> CAT
  CAT -.-> MS
  CAT -.-> MC
```

## 4. MH chains

```mermaid
flowchart LR
  classDef lib fill:#e8f0fe,stroke:#4a6fa5,color:#1d2228
  classDef entry fill:#e9f7ef,stroke:#2e7d4f,color:#1d2228
  classDef ps fill:#fff4e0,stroke:#b9770e,color:#1d2228
  classDef data fill:#f4f4f4,stroke:#777,stroke-dasharray:3 3,color:#1d2228
  classDef dead fill:#eeeeee,stroke:#aaa,color:#555

  SMH["sampler_mh.wl"]:::lib
  PSC["pure_simplicial_compute.wl<br/>exportWxfAtomic"]:::lib
  RMH["run_mh_chains.wl<br/>COMB_MH_*"]:::entry
  L45["run_p4q5_mh_parallel.ps1"]:::ps
  LQP["run_q10_mh_pilot.ps1"]:::dead
  LQ["run_q10_mh_parallel.ps1"]:::ps
  LQO["run_q10_mh_overnight.ps1"]:::ps
  MON["monitor_mh.ps1"]:::ps
  DT[("p3q5_truth.wxf<br/>gate only")]:::data
  DMH[("p{p}q{q}_mh_{target}.wxf")]:::data
  DMW[("q10 seed67890_warm*.wxf")]:::data
  LOG[("logs/mh_*.log")]:::data

  SMH & PSC --> RMH
  L45 & LQP & LQ & LQO --> RMH
  DT -.-> RMH
  RMH -.-> DMH
  LQO -.-> DMW
  L45 & LQP & LQ & LQO -.-> LOG
  LOG -.-> MON
```

## 5. ECGrav sampler campaign

```mermaid
flowchart LR
  classDef lib fill:#e8f0fe,stroke:#4a6fa5,color:#1d2228
  classDef entry fill:#e9f7ef,stroke:#2e7d4f,color:#1d2228
  classDef ps fill:#fff4e0,stroke:#b9770e,color:#1d2228
  classDef data fill:#f4f4f4,stroke:#777,stroke-dasharray:3 3,color:#1d2228

  LOAD["load_ecgrav.wl"]:::lib
  ENB["streaming_enumerator_bliss.wl"]:::lib
  PSC["pure_simplicial_compute.wl"]:::lib
  RES["run_ecgrav_samplers.wl<br/>COMB_ECG_*"]:::entry
  REC["run_ecgrav_campaign.ps1"]:::ps
  MON["monitor_ecgrav.ps1"]:::ps
  VCT["validate_counts_vs_truth.wl<br/>prints only"]:::entry
  DT[("p{p}q{q}_truth.wxf")]:::data
  DEG[("p{p}q{q}_ecg{sampler}_{target}.wxf")]:::data
  LOG[("logs/ecg*.log")]:::data

  LOAD & ENB & PSC --> RES
  REC --> RES
  DT -.-> RES -.-> DEG
  REC -.-> LOG -.-> MON
  LOAD --> VCT
  DT -.-> VCT
```

## 6. Validation and comparison

```mermaid
flowchart LR
  classDef entry fill:#e9f7ef,stroke:#2e7d4f,color:#1d2228
  classDef data fill:#f4f4f4,stroke:#777,stroke-dasharray:3 3,color:#1d2228
  classDef dead fill:#eeeeee,stroke:#aaa,color:#555
  classDef bad fill:#fde8e8,stroke:#c0392b,color:#7b1c1c

  DT[("truth")]:::data
  DMH[("MH")]:::data
  DMW[("MH warm")]:::data
  DEG[("ECGrav samples")]:::data
  MS[("q10 merged_stats")]:::data
  VMH["validate_mh_vs_truth.wl"]:::entry
  CSE["compare_samplers_efficiency.wl"]:::entry
  PIH["precompute_is_histograms_q10.wl"]:::entry
  PIH1["precompute_is_histogram.wl"]:::dead
  RIT["run_is_at_truth_cells.wl<br/>own IS loop, q=5"]:::entry
  H10[("p{p}q10_is_{t}_numv_hist.wxf")]:::data
  H5[("p{3,4}q5_is_{t}_numv_hist.wxf")]:::data
  C3["compare_3way.wl"]:::entry
  CQ["compare_is_mh_q10.wl"]:::entry
  CW["compare_q10_warm_vs_prod.wl"]:::entry
  SUM[("*_summary.wxf<br/>never read by code")]:::bad

  DT & DMH & DEG -.-> VMH
  DT & DMH & DEG & MS -.-> CSE
  MS -.-> PIH -.-> H10
  MS -.-> PIH1 -.-> H10
  RIT -.-> H5
  DT & DMH & H5 -.-> C3
  H10 & DMH -.-> CQ
  H10 & DMH & DMW -.-> CW
  VMH & CSE & C3 & CQ & CW -.-> SUM
```

## 7. Rendering and manuscript

```mermaid
flowchart LR
  classDef entry fill:#e9f7ef,stroke:#2e7d4f,color:#1d2228
  classDef data fill:#f4f4f4,stroke:#777,stroke-dasharray:3 3,color:#1d2228
  classDef fig fill:#fdf0f6,stroke:#a33d6e,color:#1d2228
  classDef dead fill:#eeeeee,stroke:#aaa,color:#555
  classDef bad fill:#fde8e8,stroke:#c0392b,color:#7b1c1c

  MS[("q10 merged_stats")]:::data
  DT[("truth + MH")]:::data
  H[("IS histograms + MH warm")]:::data
  CSV[("legacy *_samples.csv")]:::bad
  RAF["render_all_figures.wl"]:::entry
  RTO["render_truth_overlay.wl"]:::entry
  R3["render_3way.wl"]:::entry
  RQ["render_q10_is_vs_mh.wl<br/>render_q10_warm_vs_prod.wl"]:::entry
  RDX["render_ecgrav_compare.wl<br/>render_sampler_progress.wl<br/>render_uniformity_check.wl"]:::bad
  PSF["pure_simplicial_figures.nb"]:::dead
  NB1["histograms_handoff_v2.nb<br/>needs global paclet"]:::bad
  NB2["histograms_paper_figures.nb<br/>needs NB1 kernel state"]:::bad
  FMP[["manuscript_panels, stacked_previews, combined"]]:::fig
  FIM[["figures/is_vs_mh"]]:::fig
  FSD[["figures/sampler_diagnostics"]]:::fig
  FCW[["p3q3 PDFs in notebook cwd"]]:::bad
  TEX["Pure Clique Complexes.tex<br/>Images/ and .bib missing"]:::bad

  MS -.-> RAF -.-> FMP
  DT -.-> RTO -.-> FMP
  DT & H -.-> R3 -.-> FIM
  H -.-> RQ -.-> FIM
  CSV -.-> RDX -.-> FSD
  CSV -.-> PSF
  NB1 --> NB2 -.-> FCW
  FMP -. "manual copy and rename" .-> TEX
  FCW -. "manual" .-> TEX
```

`render_ecgrav_compare`, `render_sampler_progress` and
`render_uniformity_check` are red because they `Get["src/sampler_mh.wl"]`
by a path relative to the current folder, so they fail unless run from the
repo root.

## What a cloner hits today

1. **No data.** About 9 GB lives only on the Ryzen PC; the GitHub clone has
   none of it except the 104 MB Mac-only `.mx` files. Everything has to be
   regenerated, which takes days (q=10 IS) plus 17 h for (4,5) truth.
2. **No single entry point.** About 15 scripts run in an order kept in
   `CLAUDE.md` and people's heads. Configuration is about 30 `COMB_*`
   environment variables. Parallel runs need Windows PowerShell.
3. **Manual steps in the chain.** McKay truth must be renamed by hand from
   `_truth_mckay.wxf` to `_truth.wxf`. The `.tex` needs figures copied by
   hand into an `Images/` folder that does not exist, and their names do
   not match what the renderers write. The Fig 2 notebooks write to their
   own cwd and need the global paclet.
4. **Two worlds.** Fig 2 comes from interactive notebooks; the rest comes
   from scripts. The ECGrav pin (1.18) differs from the version that made
   the data (1.17), and the WXF files do not record which version made them.
5. **Clutter.** Superseded or one-off files sit beside production ones:
   `run_q10_mh_pilot`, `precompute_is_histogram`, `migrate_csv_to_wxf`,
   `pure_simplicial_compute_overnight`, `probe_betre_mx`,
   `pure_simplicial_figures.nb`, three diagnostic renders, `archive/`, the
   tracked logs, and dev-only worktree sync tooling.
6. **Dead outputs.** Every `*_summary.wxf` and `merged_complexes` is written
   and never read; L1 tables are transcribed into the docs by hand.

See `inventory.md` for every per-file issue, plus the critic's
cross-checks.
