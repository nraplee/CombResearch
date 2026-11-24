(* explorer_panels.wl
   The panels of demo/CombResearchExplorer.nb. All computing is in
   explorer_core.wl; this file only shows controls and results.

   How a panel stays responsive: every long action is a Button with
   Method -> "Queued", so it runs as an ordinary evaluation and may take
   hours. While it runs, the progress box (a Dynamic) keeps updating and its
   Stop button aborts the evaluation. Results are built once, when the job
   ends, and stored in a view variable that the panel displays. *)

If[!TrueQ[CombExplorer`$ExplorerReady],
  Get[FileNameJoin[{DirectoryName[$InputFileName], "explorer_core.wl"}]]];

BeginPackage["CombExplorer`", {"ECGrav`", "CombResearch`"}];

ExplorerStatusPanel::usage = "ExplorerStatusPanel[] shows what is loaded and the kernels.";
ExplorerEnumeratePanel::usage = "ExplorerEnumeratePanel[] is panel 1.";
ExplorerStatisticsPanel::usage = "ExplorerStatisticsPanel[] is panel 2.";
ExplorerDistributionPanel::usage = "ExplorerDistributionPanel[] is panel 3.";
ExplorerDraw::usage = "ExplorerDraw[c, size] draws a complex: its 1-skeleton, facets shaded.";
ExplorerEnumerationView::usage = "ExplorerEnumerationView[result] is the result part of panel 1.";
ExplorerStatisticsView::usage = "ExplorerStatisticsView[c, source] is the result part of panel 2.";
ExplorerDistributionView::usage =
"ExplorerDistributionView[truth, stat] is the result part of panel 3.";
ExplorerParseComplex::usage =
"ExplorerParseComplex[string] reads a typed facet list, e.g. {{1,2,3},{2,3,4}},
	without evaluating it; None if it is not a pure complex.";

Begin["`Private`"];

(* the target colors of pipeline/60_figures.wl q10_stats *)
targetOrder = {"vertex", "facet", "unlabeled"};
targetNames = <|"vertex" -> "vertex-labeled", "facet" -> "facet-labeled",
  "unlabeled" -> "unlabeled"|>;
targetColors = <|"vertex" -> RGBColor[0.984, 0.757, 0.369],
  "facet" -> RGBColor[0.122, 0.471, 0.706],
  "unlabeled" -> RGBColor[0.890, 0.290, 0.200]|>;

okColor = RGBColor[0.2, 0.65, 0.25];
badColor = RGBColor[0.9, 0.2, 0.2];

(* view variables: what each panel currently shows *)
$view1 = ""; $view2 = ""; $note3 = "";
$result = None;    (* last enumeration of panel 1 *)
$truth = None;     (* cell shown in panel 3 *)

note[s_] := Style[s, Italic];
cellString[{p_, q_}] := "(" <> ToString[p] <> ", " <> ToString[q] <> ")";
seconds[t_] := Which[t < 10, ToString[NumberForm[N[t], {4, 1}]] <> " s",
  t < 120, ToString[Round[t]] <> " s",
  t < 7200, ToString[Round[t/60]] <> " min",
  True, ToString[NumberForm[N[t/3600], {4, 1}]] <> " h"];
prob[x_] := NumberForm[N[x], {5, 4},
  ExponentFunction -> (If[# < -4 && x != 0, #, Null] &)];

(* panel font, and no line breaks inside tables and rows *)
plain[x_] := Style[x, "Panel", LineBreakWithin -> False];
box[title_, body_] := Panel[
  plain[Column[{
    Dynamic[
      If[TrueQ[$ExplorerReady], Style[title, Bold, 14],
        Style["The kernel has restarted: evaluate the notebook again (Start button at the top).",
          Bold, Red]],
      TrackedSymbols :> {$ExplorerReady}],
    body}, Spacings -> 1]],
  ImageMargins -> 4];


(* A Dynamic that stays empty when the kernel is new (notebook saved and
   reopened, or kernel quit) instead of showing internal symbols; box says
   what to do then. *)
SetAttributes[live, HoldFirst];
live[expr_, opts___] := Dynamic[
  If[TrueQ[$ExplorerReady], expr, ""],
  opts];


(* ----- progress box ----- *)

(* Each changing part is its own Dynamic, refreshed once a second whatever
   the number of reports. The moving bar of unknown length is not rebuilt. *)
every[expr_] := Dynamic[Refresh[expr, UpdateInterval -> 1, TrackedSymbols :> {}]];
SetAttributes[every, HoldFirst];

progressBar[True] := every[ProgressIndicator[
  Replace[Lookup[$ExplorerProgress, "fraction"], Except[_?NumberQ] -> 0],
  ImageSize -> {320, 14}]];
progressBar[_] := ProgressIndicator[Appearance -> "Indeterminate", ImageSize -> {320, 14}];

progressBox[] := Panel[Column[{
  every[Row[{Style[Lookup[$ExplorerProgress, "label", ""], Bold], "   ",
    seconds[AbsoluteTime[] - Lookup[$ExplorerProgress, "start", AbsoluteTime[]]]}]],
  Row[{
    Dynamic[progressBar[$ExplorerFractionKnown],
      TrackedSymbols :> {$ExplorerFractionKnown}],
    "   ",
    (* the flag is for kernel launches, which swallow the abort *)
    Button["Stop", $ExplorerStop = True; FrontEndTokenExecute["EvaluatorAbort"],
      Method -> "Preemptive", ImageSize -> Automatic]}],
  every[Style[Lookup[$ExplorerProgress, "detail", ""], Small]]}]];

progressView[] := Dynamic[
  If[TrueQ[$ExplorerRunning], progressBox[], ""],
  TrackedSymbols :> {$ExplorerRunning}];

(* A button whose action may take long; off while something runs. *)
SetAttributes[jobButton, HoldRest];
jobButton[label_, action_] := Button[label, action, Method -> "Queued",
  Enabled -> Dynamic[TrueQ[$ExplorerReady] && !TrueQ[$ExplorerRunning]],
  ImageSize -> Automatic];

parallelCheckbox[] := Row[{
  Checkbox[Dynamic[$ExplorerParallel]], " Parallel"}];


(* ----- status ----- *)

ExplorerStatusPanel[] := box["Status", Column[{
  Grid[{
      {"ECGrav", Row[{Symbol["Global`$CombECGravVersion"], "  (",
        Replace[Symbol["Global`$CombECGravDir"], None -> "installed paclet"], ")"}]},
      {"Package", Symbol["Global`$CombResearchKernelFile"]},
      {"Stored truth", Row[{
        With[{cs = ExplorerTruthCells[]},
          If[cs === {}, "none found in " <> Symbol["Global`$CombDataDir"] <>
              " or data next to the notebook: panel 3 enumerates small cells live",
            ToString[Length[cs]] <> " cells: " <>
              StringRiffle[cellString /@ cs, ", "]]]}]},
      {"Kernels", live[$ExplorerKernelNote,
        TrackedSymbols :> {$ExplorerKernelNote, $ExplorerReady}]}},
    Alignment -> Left, Spacings -> {2, 0.6}],
  Row[{parallelCheckbox[], "     ",
    jobButton["Start kernels now",
      ExplorerRun["Starting parallel kernels", ExplorerKernels[]]], "  ",
    jobButton["Restart kernels",
      ExplorerRun["Restarting parallel kernels", ExplorerResetKernels[]]]}],
  If[$ExplorerLoadLog === {}, Nothing,
    OpenerView[{If[AnyTrue[$ExplorerLoadLog, StringContainsQ["WARNING"]],
        Style["Loader messages (with a warning)", badColor], "Loader messages"],
      Column[Style[#, Small] & /@ $ExplorerLoadLog]}]],
  progressView[]}]];


(* ----- drawing ----- *)

(* A layout is clear when no vertex lies on (or nearly on) an edge that does
   not contain it: such a picture shows another complex. The circular layout
   is the last resort. *)
clearLayoutQ[at_, edges_] := With[
  {limit = 0.04 Max[EuclideanDistance @@@ Subsets[Values[at], {2}]]},
  AllTrue[edges, Function[e, AllTrue[Complement[Keys[at], e],
    segmentDistance[at[#], at[e[[1]]], at[e[[2]]]] > limit &]]]];
segmentDistance[x_, a_, b_] := With[{d = b - a}, If[d . d == 0., Norm[x - a],
  Norm[x - a - Clip[(x - a) . d/(d . d), {0, 1}] d]]];
layout[verts_, edges_] := Module[{g = Graph[verts, UndirectedEdge @@@ edges], place},
  place[m_] := AssociationThread[verts -> N[GraphEmbedding[g, m]]];
  Do[With[{at = place[m]}, If[clearLayoutQ[at, edges], Return[at, Module]]],
    {m, {"SpringElectricalEmbedding", "SpringEmbedding"}}];
  place["CircularEmbedding"]];

ExplorerDraw[c_List, size_: 110] := Module[
  {verts = Union @@ c, p = Length[First[c]], edges, xy, at, labels},
  edges = Union[Sort /@ Flatten[Subsets[#, {2}] & /@ c, 1]];
  at = layout[verts, edges];
  xy = Lookup[at, verts];
  labels = size >= 180;
  Graphics[{
      If[p >= 3, MapIndexed[
          {Opacity[0.25], ColorData[97][First[#2]],
            Polygon[facetPolygon[Lookup[at, #1]]]} &, c], {}],
      {GrayLevel[0.5], AbsoluteThickness[1.2],
        If[p >= 3, Line[Lookup[at, #] & /@ edges],
          MapIndexed[{ColorData[97][First[#2]], AbsoluteThickness[1.8],
            Line[Lookup[at, #1]]} &, c]]},
      If[labels,
        Table[Inset[Framed[Style[v, 10, Black], Background -> White,
            RoundingRadius -> 8, FrameMargins -> 3, FrameStyle -> GrayLevel[0.5]],
          at[v]], {v, verts}],
        {GrayLevel[0.35], AbsolutePointSize[5], Point[xy]}]},
    ImageSize -> {size, size}, PlotRangePadding -> Scaled[0.1], AspectRatio -> 1]];

(* corners in angular order around the center (no ArcTan[0, 0]) *)
facetPolygon[pts_] := With[{m = Mean[pts]},
  SortBy[pts, Arg[Complex @@ N[# - m]] &]];

facetsText[c_] := Style[Row[Row[{"{", Row[#, ","], "}"}] & /@ c, " "], Small];


(* ----- panel 1: enumerate ----- *)

countGrid[rows_] := With[{hasTruth = !AllTrue[rows, MissingQ[#["truth"]] &]},
  Grid[Join[
      {Style[#, Bold] & /@ Join[{"n", "found", "ECGrav"},
        If[hasTruth, {"stored truth"}, {}], {""}]},
      Join[{#["n"], #["found"], #["ecgrav"]},
          If[hasTruth, {#["truth"]}, {}],
          {If[#["ok"], Style["ok", okColor], Style["DIFFERS", badColor, Bold]]}] & /@ rows,
      {Join[{"all", Total[#["found"] & /@ rows], Total[#["ecgrav"] & /@ rows]},
        If[hasTruth, {Total[#["truth"] & /@ rows]}, {}], {""}]}],
    Alignment -> Right, Spacings -> {1.5, 0.4},
    Dividers -> {False, {2 -> GrayLevel[0.7], -2 -> GrayLevel[0.7]}}]];

ExplorerEnumerationView[r_Association] := Module[
  {rows = ExplorerCountTable[r], ex, ok, hasTruth, leaves, nReps = Length[r["reps"]],
   known = Lookup[$CombTruthIsoCounts, Key[{r["p"], r["q"]}], None]},
  ok = AllTrue[rows, #["ok"] &] && (known === None || nReps === known);
  hasTruth = !AllTrue[rows, MissingQ[#["truth"]] &];
  leaves = ExplorerCost[r["p"], r["q"]]["leaves"];
  ex = ExplorerExamples[r["reps"], 12];
  plain @ Column[{
    Row[{Style[ToString[nReps] <> " isomorphism classes", Bold], " at (p, q) = ",
      cellString[{r["p"], r["q"]}], ", method ", r["method"], ", ", seconds[r["seconds"]],
      If[r["kernels"] > 0, " on " <> ToString[r["kernels"]] <> " parallel kernels",
        " on one kernel"], "."}],
    Row[{If[ok, Style["Counts agree for every n", okColor, Bold],
        Style["Counts DIFFER", badColor, Bold]],
      ": our enumeration, ECGrav's NumUnlabeledPureComplexes",
      Which[hasTruth, " and the stored truth.",
        known =!= None, " (no truth file here; the total is compared with our known " <>
          ToString[known] <> ").",
        True, " (we have no truth for this cell)."]}],
    Which[
      r["method"] === "McKay",
        Row[{r["totalEmitted"], " complexes visited after pruning, of ", leaves,
          " facet-labeled ones."}],
      r["totalEmitted"] === leaves,
        Row[{"Visited all ", leaves,
          " facet-labeled complexes (= NumFacetLabeledPureComplexes)."}],
      True, Style[Row[{"Visited ", r["totalEmitted"], " complexes, but ECGrav counts ",
        leaves, "."}], badColor, Bold]],
    Grid[{{
      countGrid[rows],
      Column[{
        note["Examples, from few to many vertices. Click one to send it to panel 2."],
        Grid[Partition[KeyValueMap[exampleButton[#1, #2, nReps] &, ex], UpTo[4]],
          Spacings -> {0.5, 0.5}]}]}},
      Alignment -> {Left, Top}, Spacings -> {4, 1}]},
   Spacings -> 0.8]];

exampleButton[k_, c_, n_] := Button[
  Tooltip[Framed[ExplorerDraw[c, 110], FrameStyle -> GrayLevel[0.8],
    RoundingRadius -> 4, FrameMargins -> 1],
    Column[{Row[{"class ", k, " of ", n}], facetsText[c]}]],
  select[c, "class " <> ToString[k] <> " of " <> ToString[n] <> " from panel 1"],
  Appearance -> "Frameless", Method -> "Queued", ImageSize -> Automatic];

runEnumeration[p_, q_, m_] := Module[{r},
  r = ExplorerEnumerate[p, q, m];
  Which[
    AssociationQ[r], $result = r; $view1 = ExplorerEnumerationView[r],
    r === $Aborted, $view1 = note["Stopped."],
    True, $view1 = note[r]]];

costLine[p_, q_] := With[{c = ExplorerCost[p, q]},
  Style["ECGrav's exact counts: " <> ToString[c["classes"]] <> " classes, " <>
    ToString[c["leaves"]] <> " facet-labeled complexes" <>
    Which[
      c["leaves"] <= 1000, " (seconds)",
      c["leaves"] <= 5000, " (seconds to minutes)",
      c["leaves"] <= $ExplorerLeafLimit, " (minutes)",
      True, " (long: needs \"Allow long runs\")"], Small]];

ExplorerEnumeratePanel[] := DynamicModule[{p = 3, q = 4, m = Automatic},
  box["1. Enumerate all isomorphism classes", Column[{
    Row[{"facet size p ", PopupMenu[Dynamic[p], {2, 3, 4}],
      "    number of facets q ", PopupMenu[Dynamic[q], Range[2, 7]],
      "    method ", PopupMenu[Dynamic[m], {Automatic, "Cheap", "BLISS", "McKay"}]}],
    Row[{parallelCheckbox[], "    ",
      Checkbox[Dynamic[$ExplorerAllowLong]], " Allow long runs", "    ",
      jobButton["Enumerate", runEnumeration[p, q, m]]}],
    live[costLine[p, q], TrackedSymbols :> {p, q, $ExplorerReady},
      SynchronousUpdating -> False],
    progressView[],
    live[$view1, TrackedSymbols :> {$view1, $ExplorerReady}]}, Spacings -> 0.8]]];


(* ----- panel 2: statistics ----- *)

ExplorerParseComplex[s_String] := Module[{h, c},
  h = Quiet[Check[ToExpression[s, InputForm, HoldComplete], $Failed]];
  If[!MatchQ[h, HoldComplete[{{(_Integer | _String) ..} ..}]], Return[None, Module]];
  c = First[h];
  If[ExplorerComplexQ[c], c, None]];
ExplorerParseComplex[_] := None;

select[c_, source_] := ($view2 = ExplorerStatisticsView[c, source]);

ExplorerStatisticsView[c_List, source_String] := Module[{st = ExplorerStatistics[c]},
  If[!AssociationQ[st], Return[note[If[StringQ[st], st, "Stopped."]], Module]];
  plain @ Column[{
    Row[{Style["p = " <> ToString[Length[First[c]]] <> ", q = " <> ToString[Length[c]], Bold],
      "  (", source, ")"}],
    facetsText[c],
    Grid[{{ExplorerDraw[c, 260],
      Grid[Prepend[
          KeyValueMap[{#1, If[#2 === "", Style["does not apply", GrayLevel[0.5]], #2],
              Style[ExplorerStatisticLabel[#1], Small]} &, st],
          Style[#, Bold] & /@ {"statistic", "value", ""}],
        Alignment -> Left, Spacings -> {1.5, 0.4},
        Dividers -> {False, {2 -> GrayLevel[0.7]}}]}},
      Alignment -> {Left, Top}, Spacings -> {3, 1}]},
   Spacings -> 0.8]];

selectClass[k_] := Which[
  $result === None, $view2 = note["Enumerate a cell in panel 1 first."],
  IntegerQ[k] && 1 <= k <= Length[$result["reps"]],
    select[$result["reps"][[k]], "class " <> ToString[k] <> " of " <>
      ToString[Length[$result["reps"]]] <> " from panel 1, " <>
      cellString[{$result["p"], $result["q"]}]],
  True, $view2 = note["Class number: 1 to " <> ToString[Length[$result["reps"]]] <> "."]];

selectRandom[p_, q_, t_] := Module[{c = ExplorerRandomComplex[p, q, t]},
  If[ListQ[c], select[Sort[Sort /@ c], "random, uniform over " <> targetNames[t] <> " complexes"],
    $view2 = note[If[StringQ[c], c, "Stopped."]]]];

selectTyped[s_] := With[{c = ExplorerParseComplex[s]},
  If[c === None,
    $view2 = note["Not a pure complex: type distinct facets of one size, " <>
      "for example {{1,2,3},{2,3,4}}."],
    select[c, "typed in"]]];

ExplorerStatisticsPanel[] := DynamicModule[
  {k = 1, p = 3, q = 6, t = "unlabeled", s = "{{1,2,3},{2,3,4},{3,4,5}}"},
  box["2. Statistics of one complex", Column[{
    Grid[{
        {"From panel 1", Row[{"class number ", InputField[Dynamic[k], Number, FieldSize -> 6],
          "  ", jobButton["Show", selectClass[k]],
          "   (or click an example in panel 1)"}]},
        {"Random (ECGrav)", Row[{"p ", PopupMenu[Dynamic[p], {2, 3, 4}],
          "  q ", PopupMenu[Dynamic[q], Range[2, 10]], "  uniform over ",
          PopupMenu[Dynamic[t], Normal[targetNames]], "  ",
          jobButton["Draw", selectRandom[p, q, t]]}]},
        {"Typed", Row[{InputField[Dynamic[s], String, FieldSize -> 40], "  ",
          jobButton["Use", selectTyped[s]]}]}},
      Alignment -> Left, Spacings -> {2, 0.8}],
    progressView[],
    live[$view2, TrackedSymbols :> {$view2, $ExplorerReady}]}, Spacings -> 0.8]]];


(* ----- panel 3: exact distributions ----- *)

shortValue[v_] := If[IntegerQ[v], v, NumberForm[N[v], {4, 3}]];
exactString[x_] := With[{s = ToString[x, InputForm]},
  If[StringLength[s] <= 40, "exactly " <> s, "exact rational with a " <>
    ToString[IntegerLength[Denominator[x]]] <> "-digit denominator"]];

distributionChart[dist_, stat_] := Module[{n = Length[dist], step, labels, bars},
  step = Ceiling[n/24];
  labels = Table[If[Mod[i - 1, step] == 0,
      With[{l = Style[shortValue[dist[[i]]["value"]], 10]},
        If[n > 12, Rotate[l, 90 Degree], l]], ""], {i, n}];
  bars = Table[Tooltip[N[d[t]],
      Column[{Row[{stat, " = ", shortValue[d["value"]]}],
        Row[{targetNames[t], ": ", prob[d[t]]}], exactString[d[t]],
        Row[{d["classes"], " classes"}]}]],
    {d, dist}, {t, targetOrder}];
  BarChart[bars,
    ChartStyle -> {None, Lookup[targetColors, targetOrder]},
    ChartLabels -> {Placed[labels, Axis], None},
    ChartLegends -> {None, SwatchLegend[Lookup[targetColors, targetOrder],
      Lookup[targetNames, targetOrder]]},
    BarSpacing -> {Automatic, 0.6}, ChartBaseStyle -> EdgeForm[None],
    Frame -> {{True, False}, {True, False}}, FrameLabel -> {None, "probability"},
    PlotRange -> {All, {0, All}}, ImageSize -> 720, AspectRatio -> 0.42]];

distributionGrid[dist_, stat_] := Grid[Join[
    {Style[#, Bold] & /@ Join[{stat, "classes"}, Lookup[targetNames, targetOrder]]},
    Join[{shortValue[#["value"]], #["classes"]}, prob[#] & /@ Lookup[#, targetOrder]] & /@ dist,
    {Join[{"mean", Total[#["classes"] & /@ dist]},
      Table[NumberForm[N[Total[#["value"] #[t] & /@ dist]], {16, 4},
        ExponentFunction -> (If[# < -4, #, Null] &)], {t, targetOrder}]]}],
  Alignment -> Right, Spacings -> {1.5, 0.4},
  Dividers -> {False, {2 -> GrayLevel[0.7], -2 -> GrayLevel[0.7]}}];

ExplorerDistributionView[None, _] := "";
ExplorerDistributionView[truth_Association, stat0_String] := Module[{stat, dist, table},
  stat = If[MemberQ[ExplorerStatisticNames[truth["p"]], stat0], stat0, "numV"];
  dist = ExplorerDistribution[truth, stat];
  table = distributionGrid[dist, stat];
  plain @ Column[{
    Row[{Style[cellString[{truth["p"], truth["q"]}] <> ", " <>
        ExplorerStatisticLabel[stat], Bold], "  (",
      ToString[truth["numIsoClasses"]], " classes, ",
      If[truth["source"] === "live", "enumerated live", FileNameTake[truth["source"]]], ")"}],
    distributionChart[dist, stat],
    If[Length[dist] > 14, Pane[table, {Automatic, 320}, Scrollbars -> {False, True}], table]},
   Spacings -> 1]];

liveLabel[{p_, q_}] := With[{n = ExplorerCost[p, q]["leaves"]}, Which[
  n <= 1000, "  live (seconds)",
  n <= $ExplorerLeafLimit, "  live (minutes)",
  True, "  needs the truth file"]];

cellMenu[] := With[{stored = ExplorerTruthCells[]},
  Join[# -> cellString[#] <> "  stored" & /@ stored,
    # -> cellString[#] <> liveLabel[#] & /@
      Complement[Union[$ExplorerLiveCells, Keys[$CombTruthIsoCounts]], stored]]];

showCell[cell_] := Module[{t = ExplorerTruth @@ cell},
  Which[
    AssociationQ[t], $note3 = ""; $truth = t,
    t === $Aborted, $note3 = note["Stopped."],
    True, $note3 = note[t]]];

ExplorerDistributionPanel[] := With[{menu = cellMenu[]}, DynamicModule[
  {cell = {3, 4}, stat = "numV"},
  box["3. Exact distributions", Column[{
    Row[{"cell (p, q) ", PopupMenu[Dynamic[cell], menu], "  ",
      jobButton["Show", showCell[cell]], "    statistic ",
      live[PopupMenu[Dynamic[stat],
          # -> # <> ": " <> ExplorerStatisticLabel[#] & /@
            ExplorerStatisticNames[If[AssociationQ[$truth], $truth["p"], 4]]],
        TrackedSymbols :> {$truth, $ExplorerReady}]}],
    note["Bars: the exact probability of each value when the complex is uniform over " <>
      "vertex-labeled, facet-labeled or unlabeled complexes. Hover for the exact rational."],
    progressView[],
    live[$note3, TrackedSymbols :> {$note3, $ExplorerReady}],
    live[ExplorerDistributionView[$truth, stat],
      TrackedSymbols :> {$truth, stat, $ExplorerReady}, SynchronousUpdating -> False]}, Spacings -> 0.8]]]];

End[];
EndPackage[];
