(* fig2_check.wl
   Checks the fig2 job of pipeline/60_figures.wl against the reference notebooks (Phase 3):
   "the fig2 render reproduces the notebook's numbers". Reads the numbers the
   notebooks saved in their output cells; the notebooks are only read.

     $env:COMB_ROOT = "<store with p3q3_n10000_fig2.wxf>"   (optional)
     wolframscript -file tests\fig2_check.wl

   Exact (they do not depend on the random draw):
     - the class table (histograms_handoff_v2.nb, Out[37]): number of classes,
       and per class in order numVertices, numFacets, vertexAutOrder,
       facetAutOrder, numVertexLabelings, numFacetLabelingsFormula, and the
       three theory probabilities (to 1e-12). Representatives may be different
       labelings of the same class, so they are not compared as lists;
     - the exact facet enumeration equals the q!/|Aut_F| formula (to 1e-12).
   Statistical (the seeded draw changed with ECGrav's sampler; see
   render_fig2.wl):
     - the three histograms (paper panels: unweighted/vertex, facet,
       unlabeled), from histograms_paper_figures.nb Out[69], Out[73], Out[75]:
       L1(script, theory) < 2 E and L1(script, notebook) < 2 sqrt(2) E, where
       E is the expected L1 for the panel's effective sample size (N for the
       unweighted draw, Kish ESS for the reweighted panels); L1(notebook,
       theory) is reported.
   Exit 0 pass, 1 fail, 2 missing input. *)

$code = ParentDirectory[DirectoryName[$InputFileName]];
Get[FileNameJoin[{$code, "src", "lib_names.wl"}]];
$ref = FileNameJoin[{$code, "src", "reference"}];

$fail = 0;
check[label_, ok_, detail_ : ""] := If[TrueQ[ok], Print["ok    ", label, " ", detail],
  $fail++; Print["FAIL  ", label, " ", detail]];
l1[a_List, b_List] := Total[Abs[a - b]];
fmt[x_] := ToString[NumberForm[x, {5, 4}]];

(* ----- the notebooks' saved numbers ----- *)
outCell[nb_, label_] := First[Cases[nb, Cell[b_, "Output", ___, CellLabel -> label, ___] :> b, Infinity],
  Missing["NoCell", label]];
nb1 = Get[FileNameJoin[{$ref, "histograms_handoff_v2.nb"}]];
nb2 = Get[FileNameJoin[{$ref, "histograms_paper_figures.nb"}]];
nbTable = Module[{b = outCell[nb1, "Out[37]="], g},
  g = Quiet @ ToExpression[b, StandardForm, Hold];
  Cases[g, Grid[rows_List, ___] :> rows, Infinity, 1]];
If[nbTable === {} || !ListQ[First[nbTable]], Print["fig2_check: cannot read Out[37] of the notebook"]; Exit[2]];
nbTable = Rest[First[nbTable]];   (* drop the header row *)
barHeights[label_] := Cases[outCell[nb2, label], RectangleBox[{_, _}, {_, y_}, ___] :> y, Infinity];
nbBars = <|"vertex" -> barHeights["Out[69]="], "facet" -> barHeights["Out[73]="],
  "unlabeled" -> barHeights["Out[75]="]|>;

(* ----- the script's numbers ----- *)
f = combFile["fig2", 3, 3, 10000];
If[!FileExistsQ[f], Print["fig2_check: missing ", f, "; run pipeline/60_figures.wl fig2"]; Exit[2]];
x = Import[f, "WXF"];
If[!AssociationQ[x] || !AssociationQ[x["ess"]],
  Print["fig2_check: ", FileNameTake[f], " has no ESS (made before Phase 3's fix); rerun ",
    "pipeline/60_figures.wl fig2 with COMB_FORCE=1"]; Exit[2]];
myTable = Rest[x["classTable"]];
Print["fig2_check: ", FileNameTake[f], " (ECGrav ", x["ecGravVersion"], ", N=", x["sampleSize"],
  ", seed ", x["seed"], ") vs src/reference notebooks"];

(* ----- exact ----- *)
check["number of classes", Length[myTable] == Length[nbTable] == 12,
  "(" <> ToString[Length[myTable]] <> " vs " <> ToString[Length[nbTable]] <> ")"];
If[Length[myTable] == Length[nbTable],
  check["class order and integer columns (numV, numFacets, aut, autF, labelings)",
    myTable[[All, {1, 3, 4, 5, 6, 7, 8}]] === nbTable[[All, {1, 3, 4, 5, 6, 7, 8}]]];
  check["theory probabilities (vertex, facet, unlabeled)",
    Max[Abs[N[myTable[[All, 9 ;; 11]]] - N[nbTable[[All, 9 ;; 11]]]]] < 10^-12,
    "max diff " <> ToString[ScientificForm[Max[Abs[N[myTable[[All, 9 ;; 11]]] - N[nbTable[[All, 9 ;; 11]]]]], 2]]];
  check["representatives have the class's vertex and facet counts",
    MapThread[{Length[Union @@ #1[[2]]], Length[#1[[2]]]} === {#2[[3]], #2[[4]]} &, {myTable, nbTable}] //
      AllTrue[#, TrueQ] &]];
check["exact facet enumeration = q!/|Aut_F| formula",
  Max[Abs[Rest[x["facetComparisonTable"]][[All, 4]]]] < 10^-12];

(* ----- statistical ----- *)
theory = <|"vertex" -> x["vertexTheoryDist"][[All, 2]], "facet" -> x["facetTheoryFormulaDist"][[All, 2]],
  "unlabeled" -> x["unlabeledTheoryDist"][[All, 2]]|>;
mine = <|"vertex" -> x["vertexEmpiricalDist"][[All, 2]], "facet" -> x["weightedFacetDist"][[All, 2]],
  "unlabeled" -> x["weightedUnlabeledDist"][[All, 2]]|>;
(* Tolerance from the panel's effective sample size: the expected L1 of a
   histogram with ESS draws is sum_i sqrt(2/pi) sqrt(p_i (1 - p_i) / ESS);
   allow twice that against theory, and twice sqrt(2) times it between the
   script and the notebook (two independent samples). Reweighted panels have
   ESS < N, so a fixed tolerance would be wrong for them. *)
expectedL1[p_List, ess_] := Total[Sqrt[2/Pi] Sqrt[p (1 - p) / ess]];
Do[
  If[Length[nbBars[k]] =!= 12, check["notebook bars " <> k, False, "(cannot read the panel)"],
    Module[{e = expectedL1[theory[k], x["ess"][k]]},
      check[k <> ": script vs theory", l1[mine[k], theory[k]] < 2 e,
        "L1 = " <> fmt[l1[mine[k], theory[k]]] <> " (< " <> fmt[2 e] <> ", ESS " <> ToString[Round[x["ess"][k]]] <> ")"];
      check[k <> ": script vs notebook", l1[mine[k], nbBars[k]] < 2 Sqrt[2] e,
        "L1 = " <> fmt[l1[mine[k], nbBars[k]]] <> " (< " <> fmt[2 Sqrt[2] e] <>
        ")   (notebook vs theory: " <> fmt[l1[nbBars[k], theory[k]]] <> ")"]]],
  {k, {"vertex", "facet", "unlabeled"}}];

Print[""];
If[$fail == 0, Print["fig2_check: PASS"]; Exit[0], Print["fig2_check: FAILED ", $fail]; Exit[1]];
