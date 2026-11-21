(* lib_names_test.wl
   Checks src/lib_names.wl (Phase 2b) produces today's flat file names.

   1. Literal cases: combName[...] === the name scripts built by hand
      before Phase 2b.
   2. Store round trip: every file in $CombDataDir and $CombLogsDir whose
      name has a family's shape is parsed and rebuilt with combName; the
      rebuilt name must be identical. Files of no family (Betre .mx,
      .bak, one-off logs) are listed, not failed.
   3. A call that matches no family aborts.

   Reads only; writes nothing. Exit 0 pass, 1 fail.

     wolframscript -file tests\lib_names_test.wl *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "src",
  "lib_names.wl"}]];

$fail = 0;
check[label_, got_, want_] := If[got === want, Null,
  $fail++; Print["FAIL ", label, ": got ", InputForm[got], ", want ",
    InputForm[want]]];

(* ----- 1. literal cases ----- *)
cases = {
  {combName["truth", 3, 5], "p3q5_truth.wxf"},
  {combName["truth", 4, 5, "cheap"], "p4q5_truth.wxf"},
  {combName["truth", 4, 4, "mckay"], "p4q4_truth_mckay.wxf"},
  {combName["truth", 2, 4, "bliss"], "p2q4_truth_bliss.wxf"},
  {combName["mh", 3, 5, "vertex"], "p3q5_mh_vertex.wxf"},
  {combName["mh", 3, 5, "vertex", ""], "p3q5_mh_vertex.wxf"},
  {combName["mh", 4, 10, "facet", combMHWarmTag[67890, 18]],
    "p4q10_mh_facet_seed67890_warm18.wxf"},
  {combName["ecg", 4, 5, "exact", "unlabeled"], "p4q5_ecgexact_unlabeled.wxf"},
  {combName["ecg", 2, 4, "legacyfacet", "facet"], "p2q4_ecglegacyfacet_facet.wxf"},
  {combName["samples", 3, 6, "mh", "facet"], "p3q6_mh_facet.wxf"},
  {combName["samples", 3, 6, "ecgmcmc", "facet"], "p3q6_ecgmcmc_facet.wxf"},
  {combName["isHist", 4, 10, "unlabeled"], "p4q10_is_unlabeled_numv_hist.wxf"},
  {combISStem[4, 10, 500000], "p4q10_n500000"},
  {combISStem[3, 10, 1500000, None, "batch2"], "p3q10_n1500000_batch2"},
  {combISStem[2, 10, 1000, 30, ""], "p2q10_n1000_nn30"},
  {combISStem[2, 10, 1000, 30, "x"], "p2q10_n1000_nn30_x"},
  {combName["isStats", combISStem[3, 10, 10000000, None, "batch3"]],
    "p3q10_n10000000_batch3_stats.wxf"},
  {combName["isComplexes", combISStem[3, 10, 10000000, None, "batch3"]],
    "p3q10_n10000000_batch3_complexes.wxf"},
  {combName["isChunkStats", "p4q10_n500000", 7], "p4q10_n500000_chunk_7_stats.wxf"},
  {combName["isChunkComplexes", "p4q10_n500000", 7],
    "p4q10_n500000_chunk_7_complexes.wxf"},
  {combName["isSamplesCSV", combISStem[4, 10, 500000]], "p4q10_n500000_samples.csv"},
  {combName["isStats", combMergedStem[2, 10]], "p2q10_merged_stats.wxf"},
  {combName["isComplexes", combMergedStem[2, 10]], "p2q10_merged_complexes.wxf"},
  {combName["isSamplesCSV", combMergedStem[2, 10]], "p2q10_merged_samples.csv"},
  {combISStatsPattern[3, 10], "p3q10_*_stats.wxf"},
  {combName["validationSummary", "ecgexact"], "validation_ecgexact_summary.wxf"},
  {combName["summary", "q10_warm_vs_prod"], "q10_warm_vs_prod_summary.wxf"},
  {combName["log", "mh", 4, 5, "vertex"], "mh_p4q5_vertex.log"},
  {combName["err", "mh", 4, 5, "vertex"], "mh_p4q5_vertex.err"},
  {combName["log", "ecg", "mcmc", "facet"], "ecgmcmc_facet.log"},
  {combName["log", "compute", 3], "compute_p3.log"},
  {combName["err", "compute", 3, "_batch2"], "compute_p3_batch2.err"},
  {combName["log", "mhQ10", "overnight", 4, "facet", combMHWarmTag[67890, 18]],
    "mh_q10_overnight_p4_facet_seed67890_warm18.log"},
  {combName["log", "mhQ10", "pilot", 2, "vertex"], "mh_q10_pilot_p2_vertex.log"},
  {combFile["truth", 3, 5], FileNameJoin[{$CombDataDir, "p3q5_truth.wxf"}]},
  {combFile["log", "mh", 4, 5, "facet"], FileNameJoin[{$CombLogsDir, "mh_p4q5_facet.log"}]}};
Do[check["case " <> ToString[i], cases[[i, 1]], cases[[i, 2]]], {i, Length[cases]}];
Print["literal cases: ", Length[cases]];

(* ----- 2. store round trip ----- *)
int = ToExpression;
cell = "p" ~~ p : DigitCharacter .. ~~ "q" ~~ q : DigitCharacter ..;
word = (LetterCharacter | DigitCharacter) ..;
tagP = ("_seed" ~~ DigitCharacter .. ~~ "_warm" ~~ DigitCharacter ..) | "";
isStemP = cell ~~ "_n" ~~ DigitCharacter .. ~~
  (("_nn" ~~ DigitCharacter ..) | "") ~~ (("_" ~~ (LetterCharacter ~~ word)) | "");
ecgSamplers = "exact" | "mcmc" | "legacyfacet";
targets = "vertex" | "unlabeled" | "facet";

dataRules = {
  StartOfString ~~ cell ~~ "_truth.wxf" ~~ EndOfString :>
    combName["truth", int[p], int[q]],
  StartOfString ~~ cell ~~ "_truth_" ~~ pl : ("mckay" | "bliss") ~~ ".wxf" ~~ EndOfString :>
    combName["truth", int[p], int[q], pl],
  StartOfString ~~ cell ~~ "_mh_" ~~ t : targets ~~ tg : tagP ~~ ".wxf" ~~ EndOfString :>
    combName["mh", int[p], int[q], t, tg],
  StartOfString ~~ cell ~~ "_ecg" ~~ s : ecgSamplers ~~ "_" ~~ t : targets ~~ ".wxf" ~~ EndOfString :>
    combName["ecg", int[p], int[q], s, t],
  StartOfString ~~ cell ~~ "_is_" ~~ t : targets ~~ "_numv_hist.wxf" ~~ EndOfString :>
    combName["isHist", int[p], int[q], t],
  StartOfString ~~ st : (cell ~~ "_merged") ~~ "_" ~~ k : ("stats" | "complexes") ~~ ".wxf" ~~ EndOfString :>
    combName[If[k === "stats", "isStats", "isComplexes"], combMergedStem[int[p], int[q]]],
  StartOfString ~~ st : isStemP ~~ "_chunk_" ~~ k : DigitCharacter .. ~~ "_" ~~ f : ("stats" | "complexes") ~~ ".wxf" ~~ EndOfString :>
    combName[If[f === "stats", "isChunkStats", "isChunkComplexes"], st, int[k]],
  StartOfString ~~ st : isStemP ~~ "_" ~~ k : ("stats" | "complexes") ~~ ".wxf" ~~ EndOfString :>
    combName[If[k === "stats", "isStats", "isComplexes"], st],
  StartOfString ~~ st : isStemP ~~ "_samples.csv" ~~ EndOfString :>
    combName["isSamplesCSV", st],
  StartOfString ~~ "validation_" ~~ s : word ~~ "_summary.wxf" ~~ EndOfString :>
    combName["validationSummary", s],
  StartOfString ~~ s : (word ~~ ("_" ~~ word) ...) ~~ "_summary.wxf" ~~ EndOfString :>
    combName["summary", s]};

logRules = {
  StartOfString ~~ "mh_" ~~ cell ~~ "_" ~~ t : targets ~~ "." ~~ e : ("log" | "err") ~~ EndOfString :>
    combName[e, "mh", int[p], int[q], t],
  StartOfString ~~ "ecg" ~~ s : ecgSamplers ~~ "_" ~~ t : targets ~~ "." ~~ e : ("log" | "err") ~~ EndOfString :>
    combName[e, "ecg", s, t],
  StartOfString ~~ "mh_q10_" ~~ ph : ("pilot" | "prod" | "overnight") ~~ "_p" ~~ p : DigitCharacter .. ~~
      "_" ~~ t : targets ~~ tg : tagP ~~ ".log" ~~ EndOfString :>
    combName["log", "mhQ10", ph, int[p], t, tg],
  StartOfString ~~ "compute_p" ~~ p : DigitCharacter .. ~~ sfx : (("_" ~~ word) | "") ~~ "." ~~ e : ("log" | "err") ~~ EndOfString :>
    combName[e, "compute", int[p], sfx]};

roundTrip[dir_, rules_] := Module[{names, hit = 0, other = {}, rebuilt},
  names = FileNameTake /@ Select[FileNames["*", dir], !DirectoryQ[#] &];
  Do[
    rebuilt = FirstCase[rules, r_ /; StringMatchQ[n, First[r]] :>
      First[StringCases[n, r, 1]], None];
    If[rebuilt === None, AppendTo[other, n],
      hit++; check["round trip " <> n, rebuilt, n]],
    {n, names}];
  Print[dir, ": ", hit, " files round-tripped, ", Length[other],
    " of no family: ", StringRiffle[other, ", "]];
  hit];

If[DirectoryQ[$CombDataDir] && FileNames["*.wxf", $CombDataDir] =!= {},
  roundTrip[$CombDataDir, dataRules];
  roundTrip[$CombLogsDir, logRules],
  Print["store round trip skipped: no WXFs in ", $CombDataDir]];

(* ----- 3. unknown calls abort ----- *)
check["unknown family aborts", CheckAbort[combName["truht", 3, 5], "aborted"], "aborted"];
check["bad arg type aborts", CheckAbort[combName["truth", "3", 5], "aborted"], "aborted"];
check["unknown log aborts", CheckAbort[combName["log", "mh", 4, "vertex"], "aborted"], "aborted"];

If[$fail == 0, Print["PASS"]; Exit[0], Print["FAILED: ", $fail]; Exit[1]];
