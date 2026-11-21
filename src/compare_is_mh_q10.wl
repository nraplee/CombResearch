(* compare_is_mh_q10.wl
   Compare MH-sampled numV histograms against IS-reweighted numV
   histograms at q=10 for p in {2, 3, 4} and target in
   {vertex, unlabeled, facet}.

   No truth exists at q=10. The expectation is:
   - p=2: IS and MH should agree closely (IS ESS ~ 500-700).
   - p=3: borderline agreement (IS ESS ~ 100-120). Bin-wise diff
     should track 1/sqrt(ESS).
   - p=4: large disagreement on rare bins because IS is broken
     (ESS ~ 25). MH is the trusted side here.

   Reads:
     data/p{p}q10_is_{target}_numv_hist.wxf  (IS hists)
     data/p{p}q10_mh_{target}.wxf            (MH chains)

   Writes:
     data/q10_is_vs_mh_summary.wxf  (table of L1s, ESS)

   Env:
     COMB_CMP_PS       = "2,3,4"                 (default)
     COMB_CMP_TARGETS  = "vertex,unlabeled,facet" (default)
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "lib_names.wl"}]];
dataDir = $CombDataDir;

parseEnvList[s_String] := StringTrim /@ StringSplit[StringTrim[s], ","];

resolvedPs = With[{e = Environment["COMB_CMP_PS"]},
  If[StringQ[e] && StringLength[e] > 0,
    ToExpression /@ parseEnvList[e], {2, 3, 4}]];

resolvedTargets = With[{e = Environment["COMB_CMP_TARGETS"]},
  If[StringQ[e] && StringLength[e] > 0, parseEnvList[e],
    {"vertex", "unlabeled", "facet"}]];

isFile[p_, t_] := combFile["isHist", p, 10, t];
mhFile[p_, t_] := combFile["mh", p, 10, t];

binMh[mh_Association] := Module[{vals},
  vals = Select[mh["rows"][[All, 1]], NumericQ];
  If[Length[vals] == 0, <||>,
    KeySort @ N[Counts[vals] / Length[vals]]]];

cmpBars[isBars_, mhBars_] := Module[{keys, iv, mv, diffs, l1},
  keys  = Sort @ Union[Keys[isBars], Keys[mhBars]];
  iv    = Lookup[isBars, #, 0.] & /@ keys;
  mv    = Lookup[mhBars, #, 0.] & /@ keys;
  diffs = Abs[iv - mv];
  l1    = Total[diffs];
  <|"keys" -> keys, "is" -> iv, "mh" -> mv, "diff" -> diffs,
    "l1" -> l1|>];

asciiBar[p_, scale_:30] :=
  StringJoin @ ConstantArray["#", Round[p * scale]];

printOverlay[label_String, cmp_] := Module[
  {keys, is, mh, diffs},
  keys = cmp["keys"]; is = cmp["is"]; mh = cmp["mh"]; diffs = cmp["diff"];
  Print["  ", label, "   L1 = ", NumberForm[cmp["l1"], {6, 4}]];
  Print["    ",
    StringPadRight["numV", 6],
    StringPadRight["IS", 12],
    StringPadRight["MH", 12],
    StringPadRight["|d|", 11],
    "overlay (IS=., MH=#)"];
  MapThread[
    Function[{k, i, m, d},
      Print["    ",
        StringPadRight[ToString[k], 6],
        StringPadRight[ToString[NumberForm[i, {6, 4}]], 12],
        StringPadRight[ToString[NumberForm[m, {6, 4}]], 12],
        StringPadRight[ToString[NumberForm[d, {5, 4}]], 11],
        StringPadRight[asciiBar[i, 25], 25, "."],
        " | ", asciiBar[m, 25]]],
    {keys, is, mh, diffs}]];

allResults = {};

Do[
  Module[{p = pp},
    Print["========================================"];
    Print["p = ", p, "  (N = ", p*10, ")"];
    Print["========================================"];
    Do[
      Module[{iFile, mFile, isData, mhData, isBars, mhBars, cmp, ess,
              acc, niter},
        iFile = isFile[p, target];
        mFile = mhFile[p, target];
        If[!FileExistsQ[iFile],
          Print["  *** skip: missing IS ", FileNameTake[iFile]];
          Continue[]];
        If[!FileExistsQ[mFile],
          Print["  *** skip: missing MH ", FileNameTake[mFile]];
          Continue[]];
        isData = Import[iFile, "WXF"];
        mhData = Import[mFile, "WXF"];
        isBars = isData["fracHist"];
        mhBars = binMh[mhData];
        cmp    = cmpBars[isBars, mhBars];
        ess    = isData["ESS"];
        acc    = mhData["acceptRate"];
        niter  = mhData["numIter"];
        printOverlay[
          "target=" <> target <>
          "   IS ESS=" <> ToString[NumberForm[ess, 4]] <>
          "   MH iters=" <> ToString[niter] <>
          "   acc=" <> ToString[NumberForm[acc, {4, 3}]],
          cmp];
        AppendTo[allResults, <|"p" -> p, "target" -> target,
          "l1" -> cmp["l1"], "isESS" -> ess, "mhIter" -> niter,
          "acceptRate" -> acc|>];
        Print[""]],
      {target, resolvedTargets}]],
  {pp, resolvedPs}];

(* Summary table *)
Print["========================================"];
Print["SUMMARY  (q=10)"];
Print["========================================"];
Print["  ",
  StringPadRight["p", 4],
  StringPadRight["target",  12],
  StringPadRight["IS ESS",  12],
  StringPadRight["MH iters", 12],
  StringPadRight["MH acc",  10],
  "L1(IS, MH)"];
Do[
  Print["  ",
    StringPadRight[ToString[r["p"]], 4],
    StringPadRight[r["target"], 12],
    StringPadRight[ToString[NumberForm[r["isESS"], 4]], 12],
    StringPadRight[ToString[r["mhIter"]], 12],
    StringPadRight[ToString[NumberForm[r["acceptRate"], {4, 3}]], 10],
    NumberForm[r["l1"], {6, 4}]],
  {r, allResults}];

Export[combFile["summary", "q10_is_vs_mh"],
  <|"results" -> allResults, "createdAt" -> DateString[]|>, "WXF"];
Print[""];
Print["wrote q10_is_vs_mh_summary.wxf"];
