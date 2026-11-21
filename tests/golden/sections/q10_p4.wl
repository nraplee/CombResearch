(* q10_p4.wl
   Golden/derived for the q=10 IS data at p=4: p4q10_merged_stats.wxf
   (12M rows, 1.36 GB; batch3 + batch2 + n500000, Real aut in the
   CSV-migrated rows). Freezes the numV hists of
   src/precompute_is_histograms_q10.wl (checked against the stored
   p4q10_is_*_numv_hist.wxf), the ESS block and the per-panel binned data of
   src/render_all_figures.wl for p=4, and per-column stats. All logic is in
   tests/golden/lib/q10.wl. Heavy: run alone, never in parallel with other
   big jobs. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "q10.wl"}]];

goldenSection["q10_p4"] := q10GoldenSection[4];
