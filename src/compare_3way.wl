(* compare_3way.wl
   Three-way comparison of IS, MH, and truth numV marginals at cells
   where all three exist (currently (3,5) and (4,5)).

   Reads:
     data/p{p}q{q}_truth.wxf                          truth (per iso class)
     data/p{p}q{q}_mh_{target}.wxf                    MH chain stats rows
     data/p{p}q{q}_is_{target}_numv_hist.wxf          IS frac hist

   Prints per (p,q,target) an ASCII overlay and L1s
   {IS, MH, truth} pairwise. Writes a summary WXF.

   Env:
     COMB_3W_CELLS   = "3,5;4,5"  (default)
     COMB_3W_TARGETS = "vertex,unlabeled,facet" (default)
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
dataDir = $CombDataDir;

parseEnvCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];
parseEnvList[s_String] := StringTrim /@ StringSplit[StringTrim[s], ","];

cells = With[{e = Environment["COMB_3W_CELLS"]},
  If[StringQ[e] && StringLength[e] > 0, parseEnvCells[e],
    {{3, 5}, {4, 5}}]];
targets = With[{e = Environment["COMB_3W_TARGETS"]},
  If[StringQ[e] && StringLength[e] > 0, parseEnvList[e],
    {"vertex", "unlabeled", "facet"}]];

truthFile[p_, q_]    := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf"}];
mhFile[p_, q_, t_]   := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_mh_" <> t <> ".wxf"}];
isFile[p_, q_, t_]   := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_is_" <> t <> "_numv_hist.wxf"}];

piKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
          "unlabeled" -> "piUnlabeled"|>;

marginalizeTruth[truth_, t_] := Module[{pi, numVs},
  pi = truth[piKey[t]];
  numVs = #["stats"]["numV"] & /@ truth["complexes"];
  Total /@ GroupBy[Transpose[{numVs, pi}], First -> Last]];

binMh[mh_] := Module[{vals},
  vals = Select[mh["rows"][[All, 1]], NumericQ];
  If[Length[vals] == 0, <||>,
    KeySort @ N[Counts[vals] / Length[vals]]]];

l1[a_, b_] := Module[{keys, av, bv},
  keys = Sort @ Union[Keys[a], Keys[b]];
  av = Lookup[a, #, 0.] & /@ keys;
  bv = Lookup[b, #, 0.] & /@ keys;
  Total[Abs[av - bv]]];

asciiBar[p_, scale_:25] :=
  StringJoin @ ConstantArray["#", Round[p * scale]];

results = {};

Do[
  Module[{p = cell[[1]], q = cell[[2]], truth},
    Print["================================================"];
    Print["cell (", p, ",", q, ")"];
    Print["================================================"];
    truth = Import[truthFile[p, q], "WXF"];
    Do[
      Module[{isData, mh, isBars, mhBars, tBars, keys, isV, mhV, tV,
              l1IsT, l1MhT, l1IsMh, ess, niter, acc},
        isData = Import[isFile[p, q, t], "WXF"];
        mh     = Import[mhFile[p, q, t], "WXF"];
        isBars = isData["fracHist"];
        mhBars = binMh[mh];
        tBars  = marginalizeTruth[truth, t];

        keys = Sort @ Union[Keys[isBars], Keys[mhBars], Keys[tBars]];
        isV  = Lookup[isBars, #, 0.] & /@ keys;
        mhV  = Lookup[mhBars, #, 0.] & /@ keys;
        tV   = N @ Lookup[tBars,  #, 0.] & /@ keys;

        l1IsT  = l1[isBars, tBars];
        l1MhT  = l1[mhBars, tBars];
        l1IsMh = l1[isBars, mhBars];
        ess   = isData["ESS"];
        niter = mh["numIter"];
        acc   = mh["acceptRate"];

        Print[""];
        Print["  target=", t,
          "   IS N=", isData["sourceN"], " ESS=", NumberForm[ess, 4],
          "   MH iters=", niter, " acc=", NumberForm[acc, {4, 3}]];
        Print["    L1(IS, truth) = ", NumberForm[l1IsT,  {6, 4}]];
        Print["    L1(MH, truth) = ", NumberForm[l1MhT,  {6, 4}]];
        Print["    L1(IS, MH)    = ", NumberForm[l1IsMh, {6, 4}]];
        Print[""];
        Print["    ",
          StringPadRight["numV",  6],
          StringPadRight["truth", 12],
          StringPadRight["IS",    12],
          StringPadRight["MH",    12],
          "T=., I=>, M=#"];
        MapThread[Function[{k, tv, iv, mv},
          Print["    ",
            StringPadRight[ToString[k], 6],
            StringPadRight[ToString[NumberForm[tv, {6, 4}]], 12],
            StringPadRight[ToString[NumberForm[iv, {6, 4}]], 12],
            StringPadRight[ToString[NumberForm[mv, {6, 4}]], 12],
            StringPadRight[asciiBar[tv, 25], 25, "."],
            " | ", StringPadRight[asciiBar[iv, 25], 25, " "],
            " | ", asciiBar[mv, 25]]],
          {keys, tV, isV, mhV}];

        AppendTo[results, <|"p" -> p, "q" -> q, "target" -> t,
          "l1IsTruth" -> l1IsT, "l1MhTruth" -> l1MhT,
          "l1IsMh"    -> l1IsMh,
          "isN" -> isData["sourceN"], "isESS" -> ess,
          "mhIter" -> niter, "mhAccept" -> acc|>]],
      {t, targets}]],
  {cell, cells}];

Print[""];
Print["================================================"];
Print["SUMMARY"];
Print["================================================"];
Print["  ",
  StringPadRight["cell",         8],
  StringPadRight["target",      12],
  StringPadRight["IS N",        10],
  StringPadRight["IS ESS",      10],
  StringPadRight["L1(IS,T)",    11],
  StringPadRight["L1(MH,T)",    11],
  "L1(IS,MH)"];
Do[
  Print["  ",
    StringPadRight["(" <> ToString[r["p"]] <> "," <>
                   ToString[r["q"]] <> ")", 8],
    StringPadRight[r["target"], 12],
    StringPadRight[ToString[r["isN"]], 10],
    StringPadRight[ToString[NumberForm[r["isESS"], 4]], 10],
    StringPadRight[ToString[NumberForm[r["l1IsTruth"], {5, 4}]], 11],
    StringPadRight[ToString[NumberForm[r["l1MhTruth"], {5, 4}]], 11],
    NumberForm[r["l1IsMh"], {5, 4}]],
  {r, results}];

Export[FileNameJoin[{dataDir, "is_mh_truth_3way_summary.wxf"}],
  <|"results" -> results, "createdAt" -> DateString[]|>, "WXF"];
Print[""];
Print["wrote is_mh_truth_3way_summary.wxf"];
