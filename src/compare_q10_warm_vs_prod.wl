(* compare_q10_warm_vs_prod.wl
   Compare the warm-start seed-67890 1M-iter MH chains against the
   production seed-12345 200k-iter MH chains and against the IS
   reweighted hist, at the 4 disagreement cells.

   Decision tree:
     L1(MH_warm, MH_prod) small (≈ within sampling noise)
       -> both chains stationary in same region -> IS broken.
     L1(MH_warm, MH_prod) large
       -> at least one is trapped. Compare each to IS and inspect
          which region each chain sits in.

   Reads:
     data/p{p}q10_is_{target}_numv_hist.wxf
     data/p{p}q10_mh_{target}.wxf                       (production)
     data/p{p}q10_mh_{target}_seed67890_warm{N}.wxf     (warm)

   Writes:
     data/q10_warm_vs_prod_summary.wxf
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
dataDir = $CombDataDir;

cells = {{3, 10, "unlabeled", 14}, {3, 10, "facet", 14},
         {4, 10, "unlabeled", 18}, {4, 10, "facet", 18}};

isFile[p_, q_, t_]     := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_is_" <> t <> "_numv_hist.wxf"}];
mhFile[p_, q_, t_]     := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_mh_" <> t <> ".wxf"}];
warmFile[p_, q_, t_, n_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_mh_" <> t <> "_seed67890_warm" <> ToString[n] <> ".wxf"}];

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
  Module[{p = c[[1]], q = c[[2]], t = c[[3]], nW = c[[4]],
          is, prod, warm, isBars, prodBars, warmBars,
          keys, isV, pV, wV, l1IsP, l1IsW, l1PW, prodIter, warmIter},
    Print["================================================"];
    Print["cell (", p, ",", q, ")  target=", t, "  warm@numV=", nW];
    Print["================================================"];
    is   = Import[isFile[p, q, t], "WXF"];
    prod = Import[mhFile[p, q, t], "WXF"];
    warm = Import[warmFile[p, q, t, nW], "WXF"];
    isBars   = is["fracHist"];
    prodBars = binMh[prod];
    warmBars = binMh[warm];

    keys = Sort @ Union[Keys[isBars], Keys[prodBars], Keys[warmBars]];
    isV  = Lookup[isBars,   #, 0.] & /@ keys;
    pV   = Lookup[prodBars, #, 0.] & /@ keys;
    wV   = Lookup[warmBars, #, 0.] & /@ keys;
    l1IsP = l1[isBars, prodBars];
    l1IsW = l1[isBars, warmBars];
    l1PW  = l1[prodBars, warmBars];

    prodIter = prod["numIter"]; warmIter = warm["numIter"];

    Print["  IS ESS = ", NumberForm[is["ESS"], 4]];
    Print["  prod (seed 12345, default init, ", prodIter, " iters)  acc=",
      NumberForm[prod["acceptRate"], {4, 3}]];
    Print["  warm (seed 67890, init@numV=", nW, ", ", warmIter, " iters)  acc=",
      NumberForm[warm["acceptRate"], {4, 3}]];
    Print["  L1(IS,   MH_prod) = ", NumberForm[l1IsP, {6, 4}]];
    Print["  L1(IS,   MH_warm) = ", NumberForm[l1IsW, {6, 4}]];
    Print["  L1(prod, warm)    = ", NumberForm[l1PW,  {6, 4}],
      "  <-- key disambiguator"];
    Print[""];
    Print["    ",
      StringPadRight["numV",  6],
      StringPadRight["IS",    12],
      StringPadRight["prod",  12],
      StringPadRight["warm",  12]];
    MapThread[Function[{k, iv, pv, wvv},
      Print["    ",
        StringPadRight[ToString[k], 6],
        StringPadRight[ToString[NumberForm[iv, {6, 4}]], 12],
        StringPadRight[ToString[NumberForm[pv, {6, 4}]], 12],
        StringPadRight[ToString[NumberForm[wvv, {6, 4}]], 12],
        StringPadRight[asciiBar[iv, 25], 25, " "],
        " | ", StringPadRight[asciiBar[pv, 25], 25, " "],
        " | ", asciiBar[wvv, 25]]],
      {keys, isV, pV, wV}];

    AppendTo[results, <|"p" -> p, "q" -> q, "target" -> t,
      "warmInitNumV" -> nW,
      "isESS" -> is["ESS"],
      "prodIter" -> prodIter, "prodAcc" -> prod["acceptRate"],
      "warmIter" -> warmIter, "warmAcc" -> warm["acceptRate"],
      "l1IsProd" -> l1IsP, "l1IsWarm" -> l1IsW,
      "l1ProdWarm" -> l1PW|>];
    Print[""]],
  {c, cells}];

Print["================================================"];
Print["SUMMARY  (warm vs production, q=10)"];
Print["================================================"];
Print["  ",
  StringPadRight["cell",     8],
  StringPadRight["target",   12],
  StringPadRight["IS ESS",   10],
  StringPadRight["prod acc", 10],
  StringPadRight["warm acc", 10],
  StringPadRight["L1(IS,P)", 11],
  StringPadRight["L1(IS,W)", 11],
  "L1(P,W)"];
Do[
  Print["  ",
    StringPadRight["(" <> ToString[r["p"]] <> "," <>
                   ToString[r["q"]] <> ")", 8],
    StringPadRight[r["target"], 12],
    StringPadRight[ToString[NumberForm[r["isESS"], 4]], 10],
    StringPadRight[ToString[NumberForm[r["prodAcc"], {4, 3}]], 10],
    StringPadRight[ToString[NumberForm[r["warmAcc"], {4, 3}]], 10],
    StringPadRight[ToString[NumberForm[r["l1IsProd"],  {5, 4}]], 11],
    StringPadRight[ToString[NumberForm[r["l1IsWarm"],  {5, 4}]], 11],
    NumberForm[r["l1ProdWarm"], {5, 4}]],
  {r, results}];

Export[FileNameJoin[{dataDir, "q10_warm_vs_prod_summary.wxf"}],
  <|"results" -> results, "createdAt" -> DateString[]|>, "WXF"];
Print[""];
Print["wrote q10_warm_vs_prod_summary.wxf"];
