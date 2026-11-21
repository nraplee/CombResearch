(* tests/golden/lib/q10.wl
   Shared code for the q=10 golden sections q10_p2, q10_p3, q10_p4. Each
   section imports ONE merged IS stats file, p{p}q10_merged_stats.wxf
   (p2: 2M rows, 304 MB; p3/p4: 12M rows, 1.1-1.4 GB), once, and freezes:

     hist_<target>      numV hists exactly as src/precompute_is_histograms_q10.wl
                        processOne computes them (float-early weights,
                        GroupBy-Total, KeySort, ESS), with equalsStoredHist
                        (=== against the stored p{p}q10_is_<target>_numv_hist.wxf
                        fracHist, ESS and sourceN).
     essRender          ESS per weight as src/render_all_figures.wl l.97-112
                        (exact-then-N on the stored, mixed-type weights).
     <fig>              one record per render_all_figures.wl panel for this p
                        (figure list l.214-227): the binned data the panel's
                        Histogram is built from.
     colStats           per column: non-empty count, type counts, exact sum
                        of the Integer entries.

   The rows mix types: batch3 rows carry exact Rational weights and ""
   placeholders, the CSV-migrated batch2/n500000 rows carry Real weights,
   Missing["NotAvailable"] and (p=4) Real aut. Nothing here normalizes
   them: every computation runs on the stored values as the scripts do.

   Bin records (discrete/logdiscrete panels) are keyed by 1-based bin index
   i, bin i = [a + (i-1) dx, a + i dx) for binSpec {a, b, dx}, computed with
   Floor from the same lo/hi the script passes to Histogram. Indices outside
   1..(b-a)/dx (values Histogram drops at the right edge) are kept, not
   dropped. Sums are Total over the group in row order. The continuous
   panel (fig10) is keyed by value as Round[10^6 v] and its Histogram
   rectangles {x1, x2, height} are stored as Round[10^12 x]. *)

(* ===== constants copied from the scripts ===== *)

(* from src/precompute_is_histograms_q10.wl:22-23 at bd355d2 *)
q10TargetColumn = <|"vertex" -> "wVertex", "unlabeled" -> "wUnlabeled",
                    "facet"  -> "wFacet"|>;

(* from src/render_all_figures.wl:214-227 at bd355d2, columns
   {stackedFileStem, csvColumn, panelType, pSubset, filterSpec} only *)
q10Figs = {
  {"fig03_numVertices",      "numV",             "discrete",    Automatic, None},
  {"fig04_autOrder",         "aut",              "logdiscrete", Automatic, None},
  {"fig05_autFOrder",        "autF",             "logdiscrete", Automatic, None},
  {"fig06_autConnected",     "aut",              "logdiscrete", Automatic, "connected"},
  {"fig07_autFConnected",    "autF",             "logdiscrete", Automatic, "connected"},
  {"fig08_num1VConnComps",   "num1VConnComps",   "discrete",    Automatic, None},
  {"fig09_num2VConnComps",   "num2VConnComps",   "discrete",    Automatic, None},
  {"fig10_largestCompRatio", "largestCompRatio", "continuous",  Automatic, None},
  {"fig11_num2PathConnComps","num2PathConnComps","discrete",    {3, 4},    None},
  {"fig12_num3PathConnComps","num3PathConnComps","discrete",    {4},       None},
  {"fig13_Betti1",           "Betti1",           "discrete",    Automatic, None},
  {"fig14_Betti2",           "Betti2",           "discrete",    {3, 4},    None},
  {"fig15_Betti3",           "Betti3",           "discrete",    {4},       None}};

(* from src/render_all_figures.wl:35 (pList) *)
q10PList = {2, 3, 4};

(* ===== helpers copied verbatim ===== *)

(* from src/render_all_figures.wl:115-125 at bd355d2 *)
q10FilterMask[s_, None]        := ConstantArray[True, Length[s["numV"]]];
q10FilterMask[s_, "connected"] := (# == 1 &) /@ s["connected"];

q10ExtractSeries[s_, col_, filterSpec_] := Module[{mask, vals, wV, wF, wU, keep},
  mask = q10FilterMask[s, filterSpec];
  vals = Pick[s[col], mask];
  wV   = Pick[s["wVertex"], mask];
  wF   = Pick[s["wFacet"], mask];
  wU   = Pick[s["wUnlabeled"], mask];
  keep = (! MissingQ[#]) & /@ vals;
  {Pick[vals, keep], Pick[wV, keep], Pick[wF, keep], Pick[wU, keep]}];

(* ===== record builders ===== *)

(* (a) from src/precompute_is_histograms_q10.wl:62-76 at bd355d2 (processOne).
   numVs / weight column are the same elements, in the same order, as
   $cachedRows[[All, 1]] / $cachedRows[[All, col]]. *)
q10HistRecord[s_, p_, target_] := Module[{numVs, w, ess, hist, total, frac,
    storedName, stored},
  numVs = s["numV"];
  w = N[s[q10TargetColumn[target]]];   (* float early *)
  ess = Total[w]^2 / Total[w^2];
  hist = Total /@ GroupBy[Transpose[{numVs, w}], First -> Last];
  total = Total[Values[hist]];
  frac = KeySort @ AssociationThread[Keys[hist] -> Values[hist] / total];
  storedName = "p" <> ToString[p] <> "q10_is_" <> target <> "_numv_hist.wxf";
  stored = goldenImport[storedName];
  <|"target" -> target, "sourceN" -> Length[numVs], "ESS" -> ess,
    "fracHist" -> frac,
    "equalsStoredHist" -> (frac === stored["fracHist"] && ess === stored["ESS"] &&
      Length[numVs] === stored["sourceN"])|>];

(* (b) from src/render_all_figures.wl:100-104 at bd355d2 *)
q10EssRenderRecord[s_] := Module[{wV, wF, wU, essV, essF, essU},
  wV = s["wVertex"]; wF = s["wFacet"]; wU = s["wUnlabeled"];
  essV = N[Total[wV]^2 / Total[wV^2]];
  essF = N[Total[wF]^2 / Total[wF^2]];
  essU = N[Total[wU]^2 / Total[wU^2]];
  <|"n" -> Length[wV], "wVertex" -> essV, "wFacet" -> essF, "wUnlabeled" -> essU|>];

(* Group sums of w by key, in row order, KeySorted. *)
q10KeySums[keys_, w_] := KeySort[Total /@ GroupBy[Transpose[{keys, w}], First -> Last]];

q10SeriesSums[keys_, wV_, wF_, wU_] := <|
  "wVertex" -> q10KeySums[keys, wV], "wFacet" -> q10KeySums[keys, wF],
  "wUnlabeled" -> q10KeySums[keys, wU], "counts" -> KeySort[Counts[keys]]|>;

(* (c) one panel. lo/hi/logVals as in src/render_all_figures.wl:142-199 at
   bd355d2 (makePanelDiscrete l.146-148 + bins l.153, makePanelLogBin
   l.165-168 + bins l.176, makePanelContinuous l.190-194). *)
q10PanelRecord[s_, p_, {fig_, col_, mode_, _, filt_}] := Module[
  {vals, wV, wF, wU, lo, hi, logVals, binSpec, idx, rec, g, rects},
  {vals, wV, wF, wU} = q10ExtractSeries[s, col, filt];
  rec = <|"fig" -> fig, "p" -> p, "stat" -> col, "filter" -> filt,
    "mode" -> mode, "nVals" -> Length[vals]|>;
  If[Length[vals] == 0, Return[Append[rec, "empty" -> True]]];
  Switch[mode,
    "discrete",
      lo = Floor[Min[vals]];
      hi = Ceiling[Max[vals]];
      If[hi <= lo, hi = lo + 1];
      binSpec = {lo - 0.5, hi + 0.5, 1};
      idx = Floor[vals - (lo - 0.5)] + 1;
      rec = Join[rec, <|"binSpec" -> binSpec|>, q10SeriesSums[idx, wV, wF, wU]],
    "logdiscrete",
      logVals = Log10[N[vals]];
      lo = Floor[Min[logVals]];
      hi = Ceiling[Max[logVals]];
      If[hi <= lo, hi = lo + 1];
      binSpec = {lo, hi, 1};
      idx = Floor[logVals - lo] + 1;
      rec = Join[rec, <|"binSpec" -> binSpec|>, q10SeriesSums[idx, wV, wF, wU]],
    "continuous",
      (* Automatic bins are chosen jointly over the three series, so take
         the edges from the same Histogram call (style options dropped; they
         do not affect binning). *)
      g = Histogram[{WeightedData[vals, wV], WeightedData[vals, wF],
        WeightedData[vals, wU]}, Automatic, "PDF"];
      rects = Cases[g, Rectangle[{a_, _}, {b_, h_}, ___] :> {a, b, h}, Infinity];
      (* Integer keys/coordinates in fixed-point units (10^-12 for the
         rectangles, 10^-6 for the values): an Association with Rational
         keys does not survive a WXF round trip (Lookup on the imported
         copy fails, so === is False), Integers do. *)
      rects = Round[10^12 rects];
      rec = Join[rec, <|"binSpec" -> Automatic,
        "rectUnit" -> 10^-12, "valueKeyUnit" -> 10^-6,
        "rectEdges" -> Union[Flatten[rects[[All, {1, 2}]]]],
        "rects" -> rects|>,
        q10SeriesSums[Round[10^6 vals], wV, wF, wU]]];
  Append[rec, "hash" -> goldenHash[rec]]];

(* (d) per-column stats: types by Head ("Integer", "Real", "Rational",
   "String", "Missing", ...), nonEmpty = not "" and not Missing[...]. *)
q10ColStats[s_] := AssociationMap[
  Function[h, Module[{c = s[h]}, <|
    "nonEmpty" -> Length[c] - Count[c, ""] - Count[c, _Missing],
    "types" -> KeySort[KeyMap[ToString, Counts[Head /@ c]]],
    "intSum" -> Total[Cases[c, _Integer]]|>]],
  Keys[s]];

(* ===== section driver ===== *)
q10GoldenSection[p_Integer] := Module[{name, histNames, res},
  name = "p" <> ToString[p] <> "q10_merged_stats.wxf";
  histNames = Table["p" <> ToString[p] <> "q10_is_" <> t <> "_numv_hist.wxf",
    {t, Keys[q10TargetColumn]}];
  res = MemoryConstrained[
    Module[{data, s, recs = <||>, t0 = AbsoluteTime[], tick},
      tick[msg_] := Print["  q10 p=", p, ": ", msg, " (",
        Round[AbsoluteTime[] - t0], " s, ", Round[MemoryInUse[]/1024.^3, 0.01], " GB)"];
      data = goldenImport[name];
      (* from src/render_all_figures.wl:68-70 at bd355d2 (loadSamplesWXF) *)
      s = AssociationThread[data["headers"] -> Transpose[data["rows"]]];
      goldenForget[name]; data = Null;
      tick["loaded " <> ToString[Length[s["numV"]]] <> " rows"];
      Do[recs["hist_" <> t] = q10HistRecord[s, p, t]; tick["hist " <> t],
        {t, Keys[q10TargetColumn]}];
      recs["essRender"] = q10EssRenderRecord[s]; tick["essRender"];
      Do[If[f[[4]] === Automatic || MemberQ[f[[4]], p],
          recs[f[[1]]] = q10PanelRecord[s, p, f]; tick[f[[1]]]],
        {f, q10Figs}];
      recs["colStats"] = q10ColStats[s]; tick["colStats"];
      s = Null;
      recs],
    24*1024^3, $Aborted];
  Print["  q10 p=", p, ": MaxMemoryUsed = ", Round[MaxMemoryUsed[]/1024.^3, 0.01], " GB"];
  If[res === $Aborted, Print["golden: q10 p=", p, " exceeded 24 GB; stopping"]; Exit[2]];
  <|"inputs" -> Prepend[histNames, name], "records" -> res|>];
