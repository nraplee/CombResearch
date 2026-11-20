# Current architecture (as of 2026-11-20, commit b4d4b20)

Low-level file-flow map of the repo as it actually works today. Built from
`inventory.md` (one record per tracked file). Data and log nodes are grouped
by filename family; all of them live in the main checkout via
`src/comb_paths.wl` / `src/comb_paths.ps1`.

Legend: solid arrow = `Get` / dot-source / launches; dashed arrow = writes or
reads a data/figure family; red node = broken, orphan or manual step;
grey node = superseded / dead.

```mermaid
flowchart LR
  classDef lib fill:#e8f0fe,stroke:#4a6fa5
  classDef entry fill:#e9f7ef,stroke:#2e7d4f
  classDef ps fill:#fff4e0,stroke:#b9770e
  classDef data fill:#f4f4f4,stroke:#777,stroke-dasharray:3 3
  classDef fig fill:#fdf0f6,stroke:#a33d6e
  classDef bad fill:#fde8e8,stroke:#c0392b,color:#7b1c1c
  classDef dead fill:#eeeeee,stroke:#aaa,color:#888

  subgraph SETUP["Setup / plumbing"]
    ECG18["ECGrav/ECGrav-1.18.0-474b5c2 (default pin, NOT validated)"]:::lib
    ECG17["ECGrav/ECGrav-1.17.0 (all Phase 5a data)"]:::lib
    ECG10["ECGrav/ECGrav-1.0.0 (Phase 4)"]:::dead
    BIPN["ECGrav/BuildingAndInstallingPaclets.nb"]:::dead
    LOAD["src/load_ecgrav.wl<br/>env COMB_ECGRAV_VERSION"]:::lib
    INST["src/install_ecgrav_global.wl<br/>(global paclet, for notebooks)"]:::entry
    PATHS["src/comb_paths.wl<br/>git common-dir → $CombDataDir…"]:::lib
    PATHSPS["src/comb_paths.ps1"]:::lib
    SYNC["src/sync_worktree_data.ps1"]:::ps
    HOOK[".claude/settings.json<br/>SessionStart/End hook"]:::ps
  end
  ECG18 & ECG17 & ECG10 --> LOAD
  ECG18 --> INST
  HOOK --> SYNC --> PATHSPS

  subgraph TRUTH["Truth enumeration (exact, q ≤ 7)"]
    ENC["src/streaming_enumerator.wl (cheap)"]:::lib
    ENB["src/streaming_enumerator_bliss.wl"]:::lib
    ENM["src/streaming_enumerator_mckay.wl"]:::lib
    ET["src/enumerate_truth.wl<br/>COMB_TRUTH_CELLS/PIPELINE/PARALLEL"]:::entry
    TS1["src/test_streaming.wl"]:::entry
    TS2["src/test_streaming_bliss.wl"]:::entry
    TS3["src/test_streaming_mckay.wl"]:::entry
  end
  LOAD --> ENC & ENB & ENM
  ENB --> ENM
  ENC & ENB & ENM & PATHS --> ET
  ENC --> TS1
  ENC & ENB --> TS2
  ENC & ENB & ENM --> TS3

  subgraph IS["q=10 importance sampling (Fig 3+)"]
    PSC["src/pure_simplicial_compute.wl<br/>IS sampler + statsFor + exportWxfAtomic"]:::lib
    RP["src/run_p2.wl / run_p3.wl / run_p4.wl"]:::entry
    PSO["src/pure_simplicial_compute_overnight.wl"]:::dead
    RPAR["src/run_parallel.ps1<br/>COMB_PLIST, RUNTAG"]:::ps
    MIG["src/migrate_csv_to_wxf.wl (one-off)"]:::dead
    CAT["src/concat_samples.wl"]:::entry
  end
  LOAD & PATHS --> PSC
  PSC --> RP & PSO
  PSC -. "statsFor (Block-Get)" .-> ET
  RPAR --> RP
  PATHSPS --> RPAR

  subgraph MH["Metropolis–Hastings"]
    SMH["src/sampler_mh.wl"]:::lib
    RMH["src/run_mh_chains.wl<br/>COMB_MH_* knobs"]:::entry
    L45["src/run_p4q5_mh_parallel.ps1"]:::ps
    LQP["src/run_q10_mh_pilot.ps1"]:::dead
    LQ10["src/run_q10_mh_parallel.ps1"]:::ps
    LQO["src/run_q10_mh_overnight.ps1"]:::ps
    MON["src/monitor_mh.ps1"]:::ps
  end
  LOAD --> SMH
  SMH & PSC & PATHS --> RMH
  L45 & LQP & LQ10 & LQO --> RMH

  subgraph ECGC["ECGrav sampler campaign (Phase 5a)"]
    RES["src/run_ecgrav_samplers.wl<br/>COMB_ECG_SAMPLER exact/mcmc/legacyfacet"]:::entry
    REC["src/run_ecgrav_campaign.ps1"]:::ps
    MONE["src/monitor_ecgrav.ps1"]:::ps
    VCT["src/validate_counts_vs_truth.wl"]:::entry
  end
  LOAD & ENB & PSC & PATHS --> RES
  REC --> RES
  LOAD --> VCT

  subgraph CMP["Validation / comparison"]
    VMH["src/validate_mh_vs_truth.wl<br/>COMB_VAL_SOURCE"]:::entry
    CSE["src/compare_samplers_efficiency.wl"]:::entry
    PIH1["src/precompute_is_histogram.wl"]:::dead
    PIHQ["src/precompute_is_histograms_q10.wl"]:::entry
    RIT["src/run_is_at_truth_cells.wl<br/>(own IS loop, q=5)"]:::entry
    C3["src/compare_3way.wl"]:::entry
    CQ["src/compare_is_mh_q10.wl"]:::entry
    CWP["src/compare_q10_warm_vs_prod.wl"]:::entry
  end
  SMH --> CSE
  LOAD --> RIT

  subgraph REN["Rendering"]
    RAF["src/render_all_figures.wl"]:::entry
    RTO["src/render_truth_overlay.wl"]:::entry
    R3["src/render_3way.wl"]:::entry
    RQ["src/render_q10_is_vs_mh.wl"]:::entry
    RWP["src/render_q10_warm_vs_prod.wl"]:::entry
    RDX["src/render_ecgrav_compare.wl<br/>render_sampler_progress.wl<br/>render_uniformity_check.wl<br/>(cwd-relative Get sampler_mh — breaks outside repo root)"]:::bad
    PSF["src/pure_simplicial_figures.nb (legacy CSV)"]:::dead
    PRB["src/probe_betre_mx.wl"]:::dead
  end
  SMH --> RDX
  ENB --> PRB

  subgraph REF["Figure 2 reference (q=3), separate world"]
    NB1["src/reference/histograms_handoff_v2.nb<br/>Needs global ECGrav"]:::entry
    NB2["src/reference/histograms_paper_figures.nb<br/>needs NB1 kernel state"]:::entry
  end
  INST -. "global paclet" .-> NB1
  NB1 --> NB2

  %% ---------- data families ----------
  DT[("data/p{p}q{q}_truth.wxf<br/>9 cells, 3 MB")]:::data
  DTA[("data/…_truth_{bliss,mckay}.wxf")]:::bad
  DRAW[("data/p{p}q10_n{N}[_tag]_{stats,complexes}.wxf<br/>~8.7 GB")]:::data
  DCSV[("data/*_samples.csv (legacy, no writer)")]:::bad
  DMS[("data/p{p}q10_merged_stats.wxf")]:::data
  DMC[("data/p{p}q10_merged_complexes.wxf (never read, absent)")]:::dead
  DMH[("data/p{p}q{q}_mh_{target}.wxf")]:::data
  DMW[("data/p{3,4}q10_mh_*_seed67890_warm*.wxf")]:::data
  DEG[("data/p{p}q{q}_ecg{exact,mcmc,legacyfacet}_{target}.wxf")]:::data
  DH10[("data/p{p}q10_is_{t}_numv_hist.wxf")]:::data
  DH5[("data/p{3,4}q5_is_{t}_numv_hist.wxf")]:::data
  DSUM[("data/*_summary.wxf (never read by code)")]:::bad
  DMX[("data/p4q{4,5}SX*.mx (Betre, Mac-only, 104 MB in git)")]:::bad
  LOGS[("logs/*.log/.err (98 files in git, ~40 hand-redirected)")]:::data

  ET -.-> DT
  ET -.-> DTA
  DTA -. "MANUAL rename (p=4)" .-> DT
  RP -.-> DRAW
  PSO -.-> DRAW
  DCSV -.-> MIG -.-> DRAW
  DRAW -.-> CAT -.-> DMS
  CAT -.-> DMC
  DT -. "(3,5) gate" .-> RMH
  RMH -.-> DMH
  LQO -.-> DMW
  DT -.-> RES
  RES -.-> DEG
  DT -.-> VCT
  DT & DMH & DEG -.-> VMH -.-> DSUM
  DT & DMH & DEG & DMS -.-> CSE -.-> DSUM
  DMS -.-> PIHQ -.-> DH10
  DMS -.-> PIH1 -.-> DH10
  RIT -.-> DH5
  DT & DMH & DH5 -.-> C3 -.-> DSUM
  DH10 & DMH -.-> CQ -.-> DSUM
  DH10 & DMH & DMW -.-> CWP -.-> DSUM
  DMX -.-> PRB
  RPAR & L45 & LQP & LQ10 & LQO & REC -.-> LOGS
  LOGS -.-> MON & MONE

  %% ---------- figures ----------
  FMP[["figures/manuscript_panels/*.pdf (339 files)"]]:::fig
  FSP[["figures/stacked_previews/*.pdf/png"]]:::fig
  FCB[["figures/combined/*.pdf"]]:::fig
  FIM[["figures/is_vs_mh/*"]]:::fig
  FSD[["figures/sampler_diagnostics/*"]]:::fig
  FCWD[["p3q3_n10000_*.pdf/csv in notebook cwd"]]:::bad
  TEX["docs/Pure Clique Complexes.tex<br/>expects Images/*.pdf + bibliography.bib — none exist"]:::bad

  DMS & DCSV -.-> RAF -.-> FMP & FSP & FCB
  DT & DMH -.-> RTO -.-> FMP & FSP & FCB
  DT & DMH & DH5 -.-> R3 -.-> FIM
  DH10 & DMH -.-> RQ -.-> FIM
  DH10 & DMH & DMW -.-> RWP -.-> FIM
  DCSV -.-> RDX -.-> FSD
  DCSV -.-> PSF
  NB1 & NB2 -.-> FCWD
  FMP -. "manual copy + rename" .-> TEX
  FCWD -. manual .-> TEX
```

## What a cloner hits today

1. **No data.** About 9 GB lives only on the Ryzen PC; the GitHub clone has
   none of it except the 104 MB Mac-only `.mx` files. Everything has to be
   regenerated, which takes days (q=10 IS) plus 17 h for (4,5) truth.
2. **No single entry point.** About 15 scripts run in an order kept in
   `AGENTS.md` and people's heads. Configuration is about 30 `COMB_*`
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
