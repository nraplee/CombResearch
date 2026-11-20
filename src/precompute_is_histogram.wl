(* precompute_is_histogram.wl
   One-time: aggregate the 12M-row IS data at p=4 q=10 into a small numV
   histogram (under unlabeled reweighting) and save to data/. Saves ~2 min
   per render call. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];

Print["loading p4q10_merged_stats.wxf ..."]; $$t0 = AbsoluteTime[];
data = Import[FileNameJoin[{$CombDataDir, "p4q10_merged_stats.wxf"}]];
rows = data["rows"];
Print["  loaded ", Length[rows], " rows in ", AbsoluteTime[] - $$t0, "s"];

Print["computing wU per sample ..."]; $$t0 = AbsoluteTime[];
numVs = rows[[All, 1]];
auts  = rows[[All, 2]];
wU    = MapThread[#1 / #2! &, {auts, numVs}];
Print["  done in ", AbsoluteTime[] - $$t0, "s"];

Print["aggregating histogram ..."]; $$t0 = AbsoluteTime[];
hist = Merge[Thread[numVs -> wU], Total];
total = Total[Values[hist]];
fracHist = AssociationThread[Keys[hist] -> N[Values[hist] / total]];
Print["  done in ", AbsoluteTime[] - $$t0, "s"];
Print["  numV bins: ", Sort[Keys[fracHist]]];

Export[FileNameJoin[{$CombDataDir, "p4q10_is_unlabeled_numv_hist.wxf"}],
  <|"target" -> "unlabeled", "p" -> 4, "q" -> 10,
    "sourceN" -> Length[rows], "fracHist" -> fracHist,
    "ESS" -> N[Total[wU]^2 / Total[wU^2]]|>, "WXF"];
Print["wrote data/p4q10_is_unlabeled_numv_hist.wxf"];
