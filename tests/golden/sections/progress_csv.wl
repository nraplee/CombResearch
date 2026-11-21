(* progress_csv.wl
   Golden/derived for panel C of src/render_sampler_progress.wl: the IS
   unlabeled numV hist recomputed from the legacy CSV
   data/p4q10_n500000_samples.csv (wU = aut/numV! from the CSV aut column,
   which is Real at p=4, NOT the stored wUnlabeled). Only the IS part is
   frozen; the panel's MH chain (fresh, ECGrav-dependent) is not. *)

goldenSection["progress_csv"] := Module[
  {isCsvFile, isCsv, isHeader, isCsvRows, isNumVs, isAuts, isWU,
   isCountsRaw, isCountsTotal, isFracs, rec},
  (* from src/render_sampler_progress.wl:71-83 at bd355d2 *)
  isCsvFile = goldenDataFile["p4q10_n500000_samples.csv"];
  isCsv = Import[isCsvFile, "CSV"];
  isHeader = First[isCsv]; isCsvRows = Rest[isCsv];
  isNumVs = isCsvRows[[All, 1]];
  isAuts  = ToExpression /@ isCsvRows[[All, 2]];
  isWU    = MapThread[#1 / #2! &, {isAuts, isNumVs}];
  isCountsRaw = Merge[Thread[isNumVs -> isWU], Total];
  isCountsTotal = Total[Values[isCountsRaw]];
  isFracs = AssociationThread[Keys[isCountsRaw] -> N[Values[isCountsRaw] / isCountsTotal]];
  rec = <|"header" -> isHeader, "nRows" -> Length[isCsvRows],
    "autTypes" -> KeySort[Counts[ToString[Head[#]] & /@ isAuts]],
    "total" -> isCountsTotal,
    "isFracs" -> isFracs,   (* Merge (first-occurrence) key order, as the script *)
    "isCountsRaw" -> isCountsRaw|>;
  <|"inputs" -> {"p4q10_n500000_samples.csv"},
    "records" -> <|"panelC_isUnlabeled" -> Append[rec, "hash" -> goldenHash[rec]]|>|>];
