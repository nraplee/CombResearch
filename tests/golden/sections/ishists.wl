(* sections/ishists.wl
   Freezes the 15 stored IS numV histograms p*_is_*_numv_hist.wxf
   (q=10: src/precompute_is_histograms_q10.wl; q=5 truth cells:
   src/run_is_at_truth_cells.wl). They are inputs to compare_is_mh_q10.wl,
   compare_q10_warm_vs_prod.wl, compare_3way.wl and render_3way.wl.
   Every key is kept (p, q, target, sourceN, ESS, fracHist, seed where
   present); these files carry no createdAt. Frozen for identity and for a
   readable record of what the comparisons consumed. *)

goldenSection["ishists"] := Module[{inputs},
  inputs = goldenGlob["p*_is_*_numv_hist.wxf"];
  <|"inputs" -> inputs,
    "records" -> AssociationMap[goldenImport, inputs]|>];
