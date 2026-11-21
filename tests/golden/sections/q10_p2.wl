(* q10_p2.wl
   Golden/derived for the q=10 IS data at p=2: p2q10_merged_stats.wxf
   (2M rows, 304 MB; batch2 + n500000 only, no batch3). Freezes the numV
   hists of src/precompute_is_histograms_q10.wl (checked against the stored
   p2q10_is_*_numv_hist.wxf), the ESS block and the per-panel binned data of
   src/render_all_figures.wl for p=2, and per-column stats. All logic is in
   tests/golden/lib/q10.wl. Heavy: run alone, never in parallel with other
   big jobs. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "q10.wl"}]];

goldenSection["q10_p2"] := q10GoldenSection[2];
