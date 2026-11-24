(* explorer_check.wl
   Headless check of demo/CombResearchExplorer.nb: the code behind each panel
   at (2,4), (3,4) and (3,5), parallel on and off, Stop, the fallbacks, and
   that nothing is written into the store. No front end: what a person still
   has to click is listed in README.md next to this file.

     wolframscript -file demo/explorer_check.wl          about 12 min
     wolframscript -file demo/explorer_check.wl quick    no live (3,5), about 4 min
     wolframscript -file demo/explorer_check.wl full     also (3,5) on one kernel

   Needs the truth files of (2,4), (3,4), (3,5). Exit 1 on any failure. *)

$mode = If[Length[$ScriptCommandLine] > 1, $ScriptCommandLine[[2]], "default"];
If[!MemberQ[{"default", "quick", "full"}, $mode],
  Print["explorer_check: unknown word ", $mode, " (quick, full)"]; Exit[2]];

failures = {};
check[name_, cond_] := (
  Print[If[TrueQ[cond], "  ok    ", "  FAIL  "], name];
  If[!TrueQ[cond], AppendTo[failures, name]]);
section[s_] := Print["\n", s, "   [", Round[SessionTime[]], " s]"];

dir = DirectoryName[$InputFileName];
If[!TrueQ[CheckAbort[Get[FileNameJoin[{dir, "explorer_core.wl"}]];
    CombExplorer`$ExplorerReady, False]],
  Print["  FAIL  ECGrav and CombResearch loaded"]; Exit[1]];
Scan[Print["  ", #] &, CombExplorer`$ExplorerLoadLog];
Get[FileNameJoin[{dir, "explorer_panels.wl"}]];

(* name, size and date of every file of the store *)
snapshot[] := Association[
  # -> {Quiet[FileByteCount[#]], Quiet[FileDate[#]]} & /@
    Select[Join @@ (FileNames["*", #, Infinity] & /@
        {$CombDataDir, $CombFiguresDir, $CombLogsDir, $CombResultsDir}),
      !DirectoryQ[#] &]];
before = snapshot[];
(* CPU seconds used on the subkernels: shows where work really ran *)
subCPU[] := If[Kernels[] === {}, 0, Total[ParallelEvaluate[TimeUsed[]]]];
cells = {{2, 4}, {3, 4}, {3, 5}};

section["load"];
check["ECGrav and CombResearch loaded", $ExplorerReady];
check["truth files of (2,4), (3,4), (3,5) found",
  SubsetQ[ExplorerTruthCells[], cells]];

section["parallel kernels: on, off, launch failure"];
nKernels = ExplorerKernels[];
Print["  ", $ExplorerKernelNote];
check["on: kernels running with both packages", nKernels > 0];
$ExplorerParallel = False;
check["off: 0 kernels", ExplorerKernels[] === 0];
$ExplorerParallel = True;
CloseKernels[];
Block[{$ExplorerLaunch = ($Failed &)},
  check["launch failure: falls back to 0 with a note",
    ExplorerKernels[] === 0 && StringContainsQ[$ExplorerKernelNote, "could be launched"]];
  With[{r = ExplorerEnumerate[2, 4]},
    check["launch failure: enumeration still runs, on one kernel",
      AssociationQ[r] && r["kernels"] === 0 && Length[r["reps"]] === 11]]];
Block[{$ExplorerLaunch = Function[Abort[]]},
  check["abort while launching: gives $Aborted, not a hang",
    ExplorerEnumerate[2, 4] === $Aborted && !$ExplorerRunning]];
Block[{$ExplorerLaunch = Function[$ExplorerStop = True; {}]},
  check["Stop while launching (launch swallows the abort): gives $Aborted",
    ExplorerEnumerate[2, 4] === $Aborted && !$ExplorerRunning]];
check["out of memory: a message, and not running any more",
  StringQ[ExplorerRun["memory test",
    Throw[$Failed, SystemException["MemoryAllocationFailure"]]]] && !$ExplorerRunning];
check["kernels restart", ExplorerResetKernels[] === nKernels];
Block[{combLoadCombResearchOnKernels = (Null &)},
  CloseKernels[]; LaunchKernels[2];
  check["packages missing on the kernels: falls back to 0 with a note",
    ExplorerKernels[] === 0 && StringContainsQ[$ExplorerKernelNote, "did not load"]]];
check["kernels restart after that", ExplorerResetKernels[] === nKernels];

section["panel 1: enumerate"];
results = <||>;
runs = Join[
  Flatten[Table[{c, par}, {c, {{2, 4}, {3, 4}}}, {par, {True, False}}], 1],
  Switch[$mode, "quick", {}, "default", {{{3, 5}, True}},
    "full", {{{3, 5}, True}, {{3, 5}, False}}]];
Do[Module[{c = run[[1]], par = run[[2]], r, rows, name, cpu},
    $ExplorerParallel = par;
    $ExplorerProgress = <||>;
    cpu = subCPU[];
    r = ExplorerEnumerate @@ c;
    cpu = subCPU[] - cpu;
    name = ToString[c] <> If[par, " parallel", " serial"];
    If[!AssociationQ[r], check[name <> ": ran", False]; Continue[]];
    results[run] = r;
    rows = ExplorerCountTable[r];
    Print["  ", name, ": ", Length[r["reps"]], " classes, ", Round[r["seconds"], 0.1],
      " s, ", r["kernels"], " kernels"];
    check[name <> ": known number of classes", Length[r["reps"]] === $CombTruthIsoCounts[c]];
    check[name <> ": every n matches ECGrav and the stored truth",
      rows =!= {} && AllTrue[rows, #["ok"] && IntegerQ[#["truth"]] &]];
    check[name <> ": visited all facet-labeled complexes",
      r["totalEmitted"] === ExplorerCost[Sequence @@ c]["leaves"]];
    check[name <> ": ran on the subkernels if and only if parallel (" <>
        ToString[Round[cpu, 0.1]] <> " CPU s there)",
      (r["kernels"] > 0) === par && If[par, cpu > r["seconds"]/2,
        cpu < Max[1.5, r["seconds"]/5]]];
    check[name <> ": progress ended at 1", $ExplorerProgress["fraction"] === 1.];
    check[name <> ": not running any more", $ExplorerRunning === False]],
  {run, runs}];
$ExplorerParallel = True;
Do[If[KeyExistsQ[results, {c, True}] && KeyExistsQ[results, {c, False}],
    check[ToString[c] <> ": parallel and serial give the same list",
      results[{c, True}]["reps"] === results[{c, False}]["reps"]]],
  {c, cells}];
Do[Module[{log = {}},
    (* McKay: one branch runs for most of the time *)
    EnumerateUnlabeledPureComplexes[3, 4, Method -> "McKay", "Parallel" -> par,
      "Progress" -> (AppendTo[log, #] &)];
    check["(3,4): progress also inside branches, " <> If[par, "parallel", "serial"],
      MemberQ[Partition[log, 2, 1], {a_, b_} /; a["startsDone"] === b["startsDone"] &&
        a["leaves"] < b["leaves"]]]],
  {par, {True, False}}];
Do[With[{r = ExplorerEnumerate[2, 4, m]},
    check["(2,4) method " <> m, AssociationQ[r] && r["method"] === m &&
      AllTrue[ExplorerCountTable[r], #["ok"] &]]],
  {m, {"BLISS", "McKay"}}];
check["(4,2): Automatic is McKay", ExplorerEnumerate[4, 2]["method"] === "McKay"];
check["(3,3): no truth file, ECGrav comparison only",
  With[{rows = ExplorerCountTable[ExplorerEnumerate[3, 3]]},
    ExplorerTruthFile[3, 3] =!= None ||
      AllTrue[rows, #["ok"] && MissingQ[#["truth"]] &]]];
check["(3,6) refused without Allow long runs", StringQ[ExplorerEnumerate[3, 6]]];
check["(3,7), (4,6) refused even with it", Block[{$ExplorerAllowLong = True},
  StringQ[ExplorerRefusal[3, 7, Automatic]] && StringQ[ExplorerRefusal[4, 6, Automatic]] &&
  ExplorerRefusal[3, 6, Automatic] === None && ExplorerRefusal[2, 7, Automatic] === None]];
check["(4,5) Cheap refused even with it",
  Block[{$ExplorerAllowLong = True}, StringQ[ExplorerRefusal[4, 5, "Cheap"]] &&
    ExplorerRefusal[4, 5, Automatic] === None]];
check["examples: 12, spread over the vertex counts",
  With[{ex = ExplorerExamples[results[{{3, 4}, True}]["reps"], 12]},
    Length[ex] === 12 && MinMax[Length[Union @@ #] & /@ Values[ex]] === {4, 12}]];

section["stop: a real interrupt, as the front end sends it"];
(* A second kernel runs the explorer and gets LinkInterrupt[link, 3] (abort)
   some seconds into a (3,5) enumeration, four times in parallel and once
   serially. Its subkernels must survive: an abort must never find one inside
   a shared function call. *)
CloseKernels[];
reply[link_, seconds_] := Module[{r, t0 = AbsoluteTime[]},
  While[AbsoluteTime[] - t0 < seconds,
    If[LinkReadyQ[link],
      r = LinkRead[link];
      If[MatchQ[r, _ReturnPacket], Return[First[r], Module]],
      Pause[0.05]]];
  "no reply"];
SetAttributes[remote, HoldRest];
remote[link_, expr_, seconds_: 120] := (
  LinkWrite[link, Unevaluated[EvaluatePacket[expr]]]; reply[link, seconds]);
(* LinkLaunch of a missing file opens a dialog on Windows: check first *)
kernelFile = First[$CommandLine];
check["kernel program found", StringQ[kernelFile] && FileExistsQ[kernelFile]];
If[StringQ[kernelFile] && FileExistsQ[kernelFile], Module[
  {link, r, t0, dt, pids, core = FileNameJoin[{dir, "explorer_core.wl"}]},
  link = LinkLaunch["\"" <> kernelFile <> "\" -wstp -noicon"];
  With[{core = core}, remote[link, Get[core]; 1]];
  check["second kernel loads the explorer", remote[link, $ExplorerReady]];
  Do[
    With[{par = par}, remote[link, $ExplorerParallel = par; ExplorerKernels[]]];
    pids = remote[link, Sort[ParallelEvaluate[$ProcessID]]];
    LinkWrite[link, Unevaluated[EvaluatePacket[ExplorerEnumerate[3, 5]]]];
    check["(3,5) still running when stopped" <> If[par, ", parallel", ", serial"],
      reply[link, 3 + wait] === "no reply"];
    t0 = AbsoluteTime[];
    LinkInterrupt[link, 3];
    r = reply[link, 60];
    dt = AbsoluteTime[] - t0;
    Print["  stopped after ", Round[dt, 0.01], " s"];
    check["gives $Aborted within 5 s", r === $Aborted && dt < 5];
    check["not running any more", remote[link, $ExplorerRunning] === False];
    check["the same subkernels are still there",
      ListQ[pids] && remote[link, Sort[ParallelEvaluate[$ProcessID]]] === pids];
    check["next enumeration is right", remote[link,
      With[{e = ExplorerEnumerate[2, 4]}, {Length[e["reps"]], e["kernels"] > 0}]] ===
      {11, par}],
    {par, {True, True, True, True, False}}, {wait, {RandomReal[{0, 4}]}}];
  (* Stop while kernels start: the button sets the flag (here a task does) and
     sends the abort, which LaunchKernels swallows *)
  remote[link, CloseKernels[]; $ExplorerParallel = True; 1];
  LinkWrite[link, Unevaluated[EvaluatePacket[
    SessionSubmit[ScheduledTask[$ExplorerStop = True, {1.5}]]; ExplorerEnumerate[3, 5]]]];
  Pause[2];
  LinkInterrupt[link, 3];
  check["Stop while kernels start: gives $Aborted", reply[link, 60] === $Aborted];
  check["and the next enumeration is right", remote[link,
    With[{e = ExplorerEnumerate[2, 4]}, {Length[e["reps"]], e["kernels"] > 0}]] === {11, True}];
  remote[link, CloseKernels[]; 1];
  LinkClose[link]]];
ExplorerKernels[];

section["panel 2: statistics"];
Do[Module[{t = Import[combFile["truth", Sequence @@ c], "WXF"], cs, name = ToString[c]},
    SeedRandom[1];
    cs = RandomSample[t["complexes"], UpTo[20]];
    check[name <> ": recomputed statistics equal the stored ones",
      AllTrue[cs, ExplorerStatistics[#["facets"]] === #["stats"] &]];
    check[name <> ": shown statistics are the ones that apply",
      ExplorerStatisticNames[c[[1]]] === Keys[DeleteCases[cs[[1]]["stats"], ""]]];
    Do[With[{x = ExplorerRandomComplex[c[[1]], c[[2]], target]},
        check[name <> ": random " <> target, ExplorerComplexQ[x] &&
          Dimensions[x] === Reverse[c] && AssociationQ[ExplorerStatistics[x]]]],
      {target, {"unlabeled", "facet", "vertex"}}]],
  {c, cells}];
check["typed: valid", ExplorerParseComplex["{{1,2,3},{2,3,4}}"] === {{1, 2, 3}, {2, 3, 4}}];
check["typed: rejects mixed sizes, repeats, non-lists and code",
  AllTrue[{"{{1,2},{2,3,4}}", "{{1,1,2}}", "{{1,2},{2,1}}", "7", "{", "", "{{}}",
      "{{Print[1],2}}", "{{1},{2}}"}, ExplorerParseComplex[#] === None &]];

section["panel 3: exact distributions"];
Do[Module[{t = ExplorerTruth @@ c, raw, name = ToString[c], byN, p = c[[1]], q = c[[2]]},
    raw = Import[combFile["truth", p, q], "WXF"];
    check[name <> ": read from the stored file",
      t["source"] === combFile["truth", p, q]];
    check[name <> ": exact probabilities equal the stored reals", AllTrue[
      {"piVertex", "piFacet", "piUnlabeled"},
      Max[Abs[N[t[#]] - raw[#]]] < 10^-12 &]];
    check[name <> ": every statistic sums to exactly 1 under every target", AllTrue[
      ExplorerStatisticNames[p], Function[s, With[{d = ExplorerDistribution[t, s]},
        Total[#["unlabeled"] & /@ d] === 1 && Total[#["facet"] & /@ d] === 1 &&
        Total[#["vertex"] & /@ d] === 1 &&
        Total[#["classes"] & /@ d] === $CombTruthIsoCounts[c]]]]];
    (* the numV marginals are ECGrav's exact counts per n, as exact rationals *)
    byN[f_] := f[p, q, #]/f[p, q] &;
    check[name <> ": numV marginals equal ECGrav's exact counts", AllTrue[
      ExplorerDistribution[t, "numV"],
      #["unlabeled"] === byN[NumUnlabeledPureComplexes][#["value"]] &&
      #["facet"] === byN[NumFacetLabeledPureComplexes][#["value"]] &&
      #["vertex"] === byN[NumVertexLabeledPureComplexes][#["value"]] &]]],
  {c, cells}];
Do[Module[{live, stored = ExplorerTruth @@ c, name},
    $ExplorerParallel = par;
    live = ExplorerTruth[Sequence @@ c, "Live"];
    name = ToString[c] <> If[par, " parallel", " serial"];
    check[name <> ": live enumeration gives the stored distributions exactly",
      AssociationQ[live] && live["source"] === "live" && AllTrue[
        ExplorerStatisticNames[c[[1]]],
        ExplorerDistribution[live, #] === ExplorerDistribution[stored, #] &]]],
  {c, If[$mode === "full", cells, {{2, 4}, {3, 4}}]},
  {par, If[c === {3, 5}, {True}, {True, False}]}];
$ExplorerParallel = True;
Block[{ExplorerTruthFile = (None &)},
  CombExplorer`Private`truthCache = <||>;
  check["no truth file: falls back to live enumeration",
    ExplorerTruth[2, 4]["source"] === "live"];
  check["no truth file, big cell: says why instead of starting",
    StringQ[ExplorerTruth[3, 6]]];
  CombExplorer`Private`truthCache = <||>];

section["truth files: damaged ones count as missing"];
Module[{bad = CreateFile[], other = CreateFile[]},
  Export[other, <|"p" -> 2, "q" -> 4, "complexes" -> {1}|>, "WXF"];
  Block[{combFile = (bad &), combName = ("none" &)},
    check["empty file", ExplorerTruthFile[2, 4] === None]];
  Block[{combFile = (other &), combName = ("none" &)},
    check["file of another cell", ExplorerTruthFile[2, 5] === None &&
      ExplorerTruthFile[2, 4] === other]];
  DeleteFile[{bad, other}]];

section["truth files that come with the notebook (demo/data)"];
Block[{combFile = ("none" &)},
  check["all 9 cells found there", Sort[ExplorerTruthCells[]] === Sort[Keys[$CombTruthIsoCounts]]];
  check["with the known numbers of classes", AllTrue[Keys[$CombTruthIsoCounts],
    Import[ExplorerTruthFile @@ #, "WXF"]["numIsoClasses"] === $CombTruthIsoCounts[#] &]]];
check["same bytes as the store's", AllTrue[Keys[$CombTruthIsoCounts], Function[c,
  With[{name = combName["truth", Sequence @@ c]},
    !FileExistsQ[combFile["truth", Sequence @@ c]] ||
      FileHash[combFile["truth", Sequence @@ c]] ===
        FileHash[FileNameJoin[{dir, "data", name}]]]]]];

section["drawing: no vertex on a foreign edge"];
Do[check[ToString[c] <> ": every class drawn clearly", AllTrue[
    Lookup[ExplorerTruth[Sequence @@ c]["complexes"], "facets"],
    Function[x, With[{e = Union[Sort /@ Flatten[Subsets[#, {2}] & /@ x, 1]]},
      CombExplorer`Private`clearLayoutQ[
        CombExplorer`Private`layout[Union @@ x, e], e]]]]],
  {c, cells}];

section["views (built without a front end)"];
check["panel 1 view", !FreeQ[ExplorerEnumerationView[results[{{3, 4}, True}]], _Graphics]];
check["panel 2 view",
  !FreeQ[ExplorerStatisticsView[{{1, 2, 3}, {2, 3, 4}}, "test"], _Graphics]];
Do[check["panel 3 view at " <> ToString[c], AllTrue[ExplorerStatisticNames[c[[1]]],
    With[{v = ExplorerDistributionView[ExplorerTruth @@ c, #]}, !FreeQ[v, _Graphics] &&
      !FreeQ[v, _Grid] && FreeQ[v, $Failed | BarChart]] &]],
  {c, cells}];
(* a DynamicModule holds its body: evaluate that *)
check["every panel evaluates to controls", !FreeQ[ExplorerStatusPanel[], _Button] &&
  AllTrue[{ExplorerEnumeratePanel[], ExplorerStatisticsPanel[], ExplorerDistributionPanel[]},
    MatchQ[#, _DynamicModule] && With[{body = ReleaseHold[Extract[#, 2, Hold]]},
      MatchQ[body, _Panel] && !FreeQ[body, _Button] && !FreeQ[body, _PopupMenu] &&
      FreeQ[body, $Failed]] &]];
check["both progress bars typeset as bars", AllTrue[{True, False}, Function[known,
  With[{b = CombExplorer`Private`progressBar[known] /. Dynamic[Refresh[x_, ___], ___] :> x},
    !FreeQ[ToBoxes[b], AnimatorBox | ProgressIndicatorBox]]]]];
Block[{$ExplorerRunning = True, CombExplorer`Private`$jobPanel = "statistics"},
  check["progress shows only in the panel that started the job", Map[
    Head[First[CombExplorer`Private`progressView[#] /. Dynamic[x_, ___] :> {x}]] &,
    {"status", "enumerate", "statistics", "distributions"}] ===
    {String, String, Panel, String}]];
check["Stop button aborts preemptively", MatchQ[
  Cases[CombExplorer`Private`progressBox[], b : Button["Stop", __] :> Hold[b], Infinity],
  {h_} /; !FreeQ[h, "EvaluatorAbort"] && !FreeQ[h, Method -> "Preemptive"]]];

section["notebook file"];
nb = Get[FileNameJoin[{dir, "CombResearchExplorer.nb"}]];
code = Cases[nb, Cell[s_String, "Input", ___] :> s, Infinity];
check["reads back as a Notebook with 5 input cells",
  Head[nb] === Notebook && Length[code] === 5];
check["every input cell parses", AllTrue[code, SyntaxQ]];
check["no machine paths, .ps1 or process launches in demo/", AllTrue[
  FileNames["*.nb" | "explorer_core.wl" | "explorer_panels.wl" | "build_explorer.wl", dir],
  StringFreeQ[Import[#, "Text"], {"C:\\", "C:/", ".ps1", "RunProcess", "StartProcess"}] &]];

section["read only"];
after = snapshot[];
changed = Union[Keys[KeyComplement[{after, before}]], Keys[KeyComplement[{before, after}]],
  Select[Intersection[Keys[before], Keys[after]], before[#] =!= after[#] &]];
If[changed =!= {}, Print["  changed: ", changed]];
check["data/, figures/, logs/, results/ of " <> $CombRoot <> " unchanged (" <>
  ToString[Length[before]] <> " files)", changed === {}];

CloseKernels[];
Print["\n", If[failures === {}, "ALL PASS",
  ToString[Length[failures]] <> " FAILED: " <> ToString[failures]],
  "   (mode ", $mode, ", ECGrav ", $CombECGravVersion, ", ", Round[SessionTime[]], " s)"];
Exit[If[failures === {}, 0, 1]];
