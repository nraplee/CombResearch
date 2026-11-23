(* precompute_is_histograms_q10.wl -- SHIM (Phase 4 row 6, 2026-11-22).
   The q=10 IS histograms moved to pipeline/22_is_hists.wl (header there),
   which also writes p{p}q10_is_stat_hists.wxf (every statistic). Deleted in
   Phase 5. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "22_is_hists.wl"}]];
