(* explorer_core.wl
   Everything behind demo/CombResearchExplorer.nb except the panels
   (explorer_panels.wl): loading, parallel kernels, progress, enumeration
   and its checks, statistics, exact distributions. No front end needed, so
   demo/explorer_check.wl runs the same code with wolframscript.

   Runs the same on macOS, Windows and Linux: pure Wolfram Language, all
   paths relative to this file or from pipeline/common/paths.wl.

   Read only: it never writes into data/, figures/, logs/ or results/. (Like
   every script here, paths.wl creates those folders, empty, in a checkout
   that does not have them.)

   ECGrav is the one pipeline/common/ecgrav.wl loads, in this order:
     1. COMB_ECGRAV_DIR, if set (an ECGrav checkout, or "installed");
     2. ECGrav-upstream/ in the main checkout;
     3. ECGrav-upstream/ next to run.wl;
     4. the installed ECGrav paclet.
   ecgrav.wl itself knows 1 and 2; this file sets COMB_ECGRAV_DIR, for this
   kernel only, to get 3 and 4, and forgets its own value when evaluated
   again (so an ECGrav-upstream cloned in between is found). *)

CombExplorer`$ExplorerDir = DirectoryName[$InputFileName];
CombExplorer`$ExplorerRoot = ParentDirectory[CombExplorer`$ExplorerDir];
CombExplorer`$ExplorerReady = False;
If[!ListQ[CombExplorer`$ExplorerLoadLog], CombExplorer`$ExplorerLoadLog = {}];

(* The pipeline helpers (combFile, ...) live in Global`, whatever the
   notebook's own context is. Their Print output goes to the status box;
   paths.wl's Exit (scripts only) becomes an abort, so that the output is
   shown before this file stops. *)
CombExplorer`Private`load[] := Block[
  {Print = Function[CombExplorer`$ExplorerLoadLog = DeleteDuplicates[
     Append[CombExplorer`$ExplorerLoadLog, StringJoin[ToString /@ {##}]]]],
   Exit = Function[Abort[]],
   $Context = "Global`",
   $ContextPath = DeleteDuplicates[Join[{"System`", "Global`"}, $ContextPath]]},
  Module[{common, env, root, ecg},
    common = FileNameJoin[{CombExplorer`$ExplorerRoot, "pipeline", "common"}];
    If[!FileExistsQ[FileNameJoin[{common, "combresearch.wl"}]],
      Print["No CombResearch checkout around ", CombExplorer`$ExplorerDir,
        ": keep the notebook in the demo folder of the repository."];
      Return[False, Module]];
    Get[FileNameJoin[{common, "paths.wl"}]];
    root = Symbol["Global`$CombRoot"];
    env = Environment["COMB_ECGRAV_DIR"];
    If[StringQ[env] && env === CombExplorer`Private`ownSetting,
      SetEnvironment["COMB_ECGRAV_DIR" -> None]; env = None];
    If[!(StringQ[env] && StringLength[env] > 0),
      ecg = SelectFirst[
        FileNameJoin[{#, "ECGrav-upstream"}] & /@ {root, CombExplorer`$ExplorerRoot},
        FileExistsQ[FileNameJoin[{#, "Kernel", "ECGrav.wl"}]] &, None];
      Which[
        ecg === FileNameJoin[{root, "ECGrav-upstream"}], Null,
        StringQ[ecg], SetEnvironment["COMB_ECGRAV_DIR" ->
          (CombExplorer`Private`ownSetting = ecg)],
        PacletFind["ECGrav"] =!= {}, SetEnvironment["COMB_ECGRAV_DIR" ->
          (CombExplorer`Private`ownSetting = "installed")],
        True,
          Print["ECGrav not found. Either run  wolframscript -file ",
            FileNameJoin[{"tools", "dev", "update_ecgrav.wl"}], "  in ",
            CombExplorer`$ExplorerRoot, ", or install the ECGrav paclet, or set ",
            "COMB_ECGRAV_DIR to an ECGrav checkout, then evaluate this cell again."];
          Return[False, Module]]];
    Get[FileNameJoin[{common, "combresearch.wl"}]];
    Get[FileNameJoin[{common, "names.wl"}]];
    MemberQ[$Packages, "ECGrav`"] && MemberQ[$Packages, "CombResearch`"]]];

CombExplorer`$ExplorerReady =
  TrueQ[CheckAbort[CombExplorer`Private`load[], False]];

If[!CombExplorer`$ExplorerReady,
  Print[Style["CombResearch Explorer could not load:", Bold]];
  Scan[Print, CombExplorer`$ExplorerLoadLog];
  With[{env = Environment["COMB_ECGRAV_DIR"]}, Which[
    env === CombExplorer`Private`ownSetting && env === "installed",
      Print["If the installed ECGrav paclet is too old: update it, or run  ",
        "wolframscript -file tools/dev/update_ecgrav.wl  in ",
        CombExplorer`$ExplorerRoot, ". Then Evaluation > Quit Kernel and evaluate again."],
    StringQ[env] && env =!= "" && env =!= CombExplorer`Private`ownSetting,
      Print["COMB_ECGRAV_DIR is set to ", env, ": correct or remove it, quit the ",
        "kernel and evaluate again."]]];
  CombExplorer`$ExplorerLoadLog = {};
  If[TrueQ[$Notebooks], Abort[], Exit[3]]];

BeginPackage["CombExplorer`", {"ECGrav`", "CombResearch`"}];

$ExplorerDir::usage = "Folder of the notebook.";
$ExplorerRoot::usage = "Root of the repository checkout the notebook is in.";
$ExplorerReady::usage = "True once ECGrav and CombResearch are loaded.";
$ExplorerLoadLog::usage = "Lines the loaders printed.";

$ExplorerParallel::usage = "Use parallel kernels (the Parallel checkbox).";
$ExplorerAllowLong::usage = "Allow enumerations above $ExplorerLeafLimit leaves.";
$ExplorerLeafLimit::usage =
  "Facet-labeled complexes above which an enumeration needs \"Allow long runs\".";
$ExplorerHardLimit::usage =
  "Facet-labeled complexes above which an enumeration is never started.";
$ExplorerLaunch::usage =
  "Function that launches subkernels (a test replaces it by a failing one).";
$ExplorerKernelNote::usage = "What happened when kernels were last needed.";
$ExplorerProgress::usage = "Association describing the running job.";
$ExplorerRunning::usage = "True while a job runs.";
$ExplorerFractionKnown::usage =
  "Whether the running job's fraction is a number (set only when that changes).";
$ExplorerStop::usage = "Set by the Stop button; cleared when a job starts.";

ExplorerKernels::usage =
"ExplorerKernels[] launches parallel kernels if needed, loads ECGrav and
	CombResearch on them and gives their number. 0 means: run serially
	($ExplorerKernelNote says why). Respects $ExplorerParallel.";
ExplorerResetKernels::usage =
"ExplorerResetKernels[] closes the parallel kernels and starts new ones.";
ExplorerRun::usage =
"ExplorerRun[label, body] evaluates body with $ExplorerProgress describing it;
	gives $Aborted if it is aborted, and clears the progress either way.";

ExplorerCost::usage =
"ExplorerCost[p, q] gives <|\"classes\", \"leaves\"|>: ECGrav's exact counts of
	unlabeled and facet-labeled complexes, known before enumerating.";
ExplorerRefusal::usage =
"ExplorerRefusal[p, q, method] gives None, or a string saying why this
	enumeration is not started.";
ExplorerEnumerate::usage =
"ExplorerEnumerate[p, q, method] enumerates a cell with progress and gives
	<|\"p\", \"q\", \"reps\", \"method\", \"totalEmitted\", \"seconds\",
	\"kernels\"|>, $Aborted, or a string (refusal).";
ExplorerCountTable::usage =
"ExplorerCountTable[result] compares the numbers of classes per vertex count n
	of an ExplorerEnumerate result with ECGrav's NumUnlabeledPureComplexes and
	with the stored truth: a list of <|\"n\", \"found\", \"ecgrav\", \"truth\",
	\"ok\"|> (truth is Missing[...] without a file).";
ExplorerExamples::usage =
"ExplorerExamples[reps, k] picks k complexes spread over the vertex counts, as
	index -> complex.";

ExplorerTruthFile::usage =
"ExplorerTruthFile[p, q] is the stored truth file: data/ of the main checkout,
	else the copy in data/ next to the notebook, else None.";
ExplorerTruthCells::usage = "ExplorerTruthCells[] lists the cells with a truth file.";
$ExplorerLiveCells::usage = "Small cells panel 3 can enumerate on the spot.";
ExplorerTruth::usage =
"ExplorerTruth[p, q] gives the truth payload of a cell with exact (rational)
	probabilities: from the stored file if there is one, else by enumerating it
	live. Also $Aborted or a string (refusal). Cached for the session.
ExplorerTruth[p, q, \"Live\"] ignores the stored file and the cache.";
ExplorerDistribution::usage =
"ExplorerDistribution[truth, stat] gives a list of <|\"value\", \"classes\",
	\"unlabeled\", \"facet\", \"vertex\"|> with exact probabilities, sorted by
	value.";
ExplorerStatisticNames::usage =
"ExplorerStatisticNames[p] lists the statistics that apply at facet size p.";
ExplorerStatisticLabel::usage = "ExplorerStatisticLabel[name] describes a statistic.";

ExplorerComplexQ::usage =
"ExplorerComplexQ[c] tests for a pure complex: distinct facets, all of the same
	size p >= 2, each without repeated vertices.";
ExplorerRandomComplex::usage =
"ExplorerRandomComplex[p, q, target] is one ECGrav draw, exactly uniform for
	target \"unlabeled\", \"facet\" or \"vertex\".";
ExplorerStatistics::usage =
"ExplorerStatistics[c] is <|name -> value|> of PureComplexStatistics; \"\" where
	a statistic does not apply.";

Begin["`Private`"];

$ExplorerParallel = True;
$ExplorerAllowLong = False;
$ExplorerLeafLimit = 30000;
$ExplorerHardLimit = 3*10^6;   (* (3,6), the largest cell done, has 1.9*10^6 *)
$ExplorerLaunch = LaunchKernels;
$ExplorerKernelNote = "No parallel kernels started yet.";
$ExplorerProgress = <||>;
$ExplorerRunning = False;
$ExplorerStop = False;
$ExplorerFractionKnown = False;


(* ----- parallel kernels ----- *)

(* A license without subkernels, or a sandboxed install, fails to launch or
   gives none. Every failure ends in a serial run. LaunchKernels swallows an
   abort and returns normally, hence the $ExplorerStop test after it. *)
ExplorerKernels[] := Module[{n, ok},
  If[!TrueQ[$ExplorerParallel],
    $ExplorerKernelNote = "Parallel is off: running on one kernel.";
    Return[0, Module]];
  If[Length[Kernels[]] === 0,
    Quiet[TimeConstrained[$ExplorerLaunch[], 180, $Failed]]];
  If[TrueQ[$ExplorerStop], Abort[]];
  n = Length[Kernels[]];
  If[n === 0,
    $ExplorerKernelNote =
      "No parallel kernels could be launched: running on one kernel.";
    Return[0, Module]];
  ok = Quiet @ Check[
    Symbol["Global`combLoadCombResearchOnKernels"][];
    AllTrue[ParallelEvaluate[MemberQ[$Packages, "CombResearch`"] &&
        MemberQ[$Packages, "ECGrav`"]], TrueQ],
    False];
  If[TrueQ[$ExplorerStop], Abort[]];
  If[!TrueQ[ok],
    Quiet[CloseKernels[]];
    $ExplorerKernelNote =
      "The packages did not load on the parallel kernels: running on one kernel.";
    Return[0, Module]];
  n = Length[Kernels[]];
  $ExplorerKernelNote = ToString[n] <> " parallel kernels ready.";
  n];

ExplorerResetKernels[] := (Quiet[CloseKernels[]]; ExplorerKernels[]);


(* ----- progress -----
   $ExplorerProgress: <|"label", "start", "fraction" (a number or
   Indeterminate), "detail"|>. The panels show it with a Dynamic; nothing here
   needs a front end. *)

(* Parallel loses an abort that arrives while a ParallelMap collects its last
   results (checked 2026-11-27, 15.0.1). So a progress report made after Stop
   while the job still runs stops it again:
   - on the main evaluation (between Parallel calls): Abort[];
   - from the enumerators' report task, which runs while a ParallelMap waits:
     the flag of Parallel's own Stop button, which its wait loop turns into
     the usual abort. Each Parallel call Blocks that flag, so only a task can
     set it. At once: an abort that lands in the task's own evaluation is
     lost too, and the flag then stops the job within a report (0.06-0.14 s
     in explorer_check). Waiting 1 s first, against a second abort during
     Parallel's abort handling, made stops slower and once cost a kernel.
   ExplorerRun clears the flag. *)
progress[assoc_] := (
  If[TrueQ[$ExplorerStop] && TrueQ[$ExplorerRunning],
    If[$CurrentTask === None, Abort[], Parallel`Protected`$progressStop = True]];
  $ExplorerProgress = Join[$ExplorerProgress, assoc];
  With[{known = NumberQ[Lookup[$ExplorerProgress, "fraction"]]},
    If[$ExplorerFractionKnown =!= known, $ExplorerFractionKnown = known]];);

SetAttributes[ExplorerRun, HoldRest];
ExplorerRun[label_String, body_] := (
  $ExplorerProgress = <||>;
  progress[<|"label" -> label, "start" -> AbsoluteTime[],
    "fraction" -> Indeterminate, "detail" -> ""|>];
  $ExplorerStop = False;
  Parallel`Protected`$progressStop = False;
  $ExplorerRunning = True;
  (* No AbortKernels[] here: ParallelMap has already stopped its subkernels,
     and a second abort makes Parallel close and relaunch them (25 s).
     Running out of memory throws a SystemException. A job that returns
     after Stop (its abort was lost) counts as stopped. *)
  WithCleanup[
    Catch[CheckAbort[With[{r = body}, If[TrueQ[$ExplorerStop], $Aborted, r]], $Aborted],
      _SystemException,
      Function["Stopped by the system (" <> ToString[#2[[1]]] <> ")."]],
    Parallel`Protected`$progressStop = False;
    $ExplorerRunning = False]);


(* ----- enumeration ----- *)

ExplorerCost[p_Integer, q_Integer] := ExplorerCost[p, q] =
  <|"classes" -> NumUnlabeledPureComplexes[p, q],
    "leaves" -> NumFacetLabeledPureComplexes[p, q]|>;

(* What Automatic stands for (EnumerateUnlabeledPureComplexes::usage). *)
resolveMethod[Automatic, p_] := If[p >= 4, "McKay", "Cheap"];
resolveMethod[m_, _] := m;

ExplorerRefusal[p_Integer, q_Integer, method_] := Module[{cost = ExplorerCost[p, q]},
  Which[
    cost["leaves"] > $ExplorerHardLimit,
      "This cell has " <> ToString[cost["leaves"]] <> " facet-labeled complexes: " <>
        "months or more, with every class kept in memory. The largest cells done " <>
        "so far, (3,6) and (4,5), took 17 hours each.",
    resolveMethod[method, p] === "Cheap" && p >= 4 && cost["leaves"] > 400000,
      "The Cheap method runs out of memory here (measured at (4,5)). " <>
        "Use Automatic or McKay.",
    cost["leaves"] > $ExplorerLeafLimit && !TrueQ[$ExplorerAllowLong],
      "This cell has " <> ToString[cost["leaves"]] <> " facet-labeled complexes, " <>
        "which can take minutes to hours. Tick \"Allow long runs\" in panel 1 to start it anyway.",
    True, None]];

(* Progress of EnumerateUnlabeledPureComplexes. Cheap and BLISS visit every
   facet-labeled complex once, so the fraction is exact; McKay's number of
   leaves is not known in advance. *)
enumerationProgress[method_, cost_][a_Association] := progress[<|
  "fraction" -> If[method === "McKay", Indeterminate,
    N[Min[1, a["leaves"]/Max[1, cost["leaves"]]]]],
  "detail" -> ToString[a["leaves"]] <>
    If[method === "McKay", "", " of " <> ToString[cost["leaves"]]] <>
    " complexes visited, " <> ToString[a["startsDone"]] <> " of " <>
    ToString[a["starts"]] <> " branches finished"|>];

ExplorerEnumerate[p_Integer, q_Integer, method_: Automatic] := Module[
  {why = ExplorerRefusal[p, q, method], m = resolveMethod[method, p], n, cost, t, r},
  If[StringQ[why], Return[why, Module]];
  cost = ExplorerCost[p, q];
  ExplorerRun["Enumerating (p, q) = (" <> ToString[p] <> ", " <> ToString[q] <> ")",
    progress[<|"detail" -> "starting parallel kernels"|>];
    n = ExplorerKernels[];
    progress[<|"detail" -> ""|>];
    {t, r} = AbsoluteTiming[EnumerateUnlabeledPureComplexes[p, q, Method -> method,
      "Parallel" -> n > 0, "Progress" -> enumerationProgress[m, cost]]];
    If[AssociationQ[r],
      <|"p" -> p, "q" -> q, "reps" -> r["isoReps"], "method" -> r["method"],
        "totalEmitted" -> r["totalEmitted"], "seconds" -> t, "kernels" -> n|>,
      "The enumeration failed (" <> ToString[r, InputForm] <> ")."]]];

numVertices[c_] := Length[Union @@ c];

ExplorerCountTable[result_Association] := Module[
  {p = result["p"], q = result["q"], found, file, truth},
  found = Counts[numVertices /@ result["reps"]];
  file = ExplorerTruthFile[p, q];
  truth = If[file === None, None, Counts[#["nV"] & /@ readTruth[file]["complexes"]]];
  Select[
    Table[With[{f = Lookup[found, n, 0], e = NumUnlabeledPureComplexes[p, q, n],
          t = If[truth === None, Missing["NoTruthFile"], Lookup[truth, n, 0]]},
        <|"n" -> n, "found" -> f, "ecgrav" -> e, "truth" -> t,
          "ok" -> f === e && (MissingQ[t] || f === t)|>],
      {n, p, p q}],
    #["found"] > 0 || #["ecgrav"] > 0 || TrueQ[#["truth"] > 0] &]];

ExplorerExamples[reps_List, k_Integer] := Module[{order, pick},
  order = Ordering[numVertices /@ reps];
  pick = If[Length[reps] <= k, order,
    order[[Round[Subdivide[1, Length[reps], k - 1]]]]];
  Association[# -> reps[[#]] & /@ pick]];


(* ----- truth data ----- *)

(* The payload, or None if the file is missing or damaged (the files are
   copied by hand); remembered per file version. *)
readTruth[file_] := If[FileExistsQ[file],
  readTruth[file, {FileDate[file], FileByteCount[file]}], None];
readTruth[file_, version_] := readTruth[file, version] =
  With[{t = Quiet[Import[file, "WXF"]]},
    If[AssociationQ[t] && ListQ[t["complexes"]] && t["complexes"] =!= {}, t, None]];

ExplorerTruthFile[p_Integer, q_Integer] := SelectFirst[
  {Symbol["Global`combFile"]["truth", p, q],
   FileNameJoin[{$ExplorerDir, "data", Symbol["Global`combName"]["truth", p, q]}]},
  With[{t = readTruth[#]}, AssociationQ[t] && t["p"] === p && t["q"] === q] &, None];

ExplorerTruthCells[] := Select[Keys[$CombTruthIsoCounts],
  ExplorerTruthFile @@ # =!= None &];

$ExplorerLiveCells = {{2, 2}, {2, 3}, {3, 2}, {3, 3}, {4, 2}, {4, 3}};

(* pi_V ~ nV!/aut, pi_F ~ q!/autF, pi_U ~ 1 over the classes, as exact
   rationals (the stored payloads hold the same numbers as reals). *)
exactPi[truth_Association] := Module[{q = truth["q"], cs = truth["complexes"], v, f},
  v = #["nV"]!/#["aut"] & /@ cs;
  f = q!/#["autF"] & /@ cs;
  Join[truth, <|"piVertex" -> v/Total[v], "piFacet" -> f/Total[f],
    "piUnlabeled" -> ConstantArray[1/Length[cs], Length[cs]]|>]];

truthCache = <||>;

ExplorerTruth[p_Integer, q_Integer] := Module[{file, r},
  If[KeyExistsQ[truthCache, {p, q}], Return[truthCache[{p, q}], Module]];
  file = ExplorerTruthFile[p, q];
  r = If[file === None, ExplorerTruth[p, q, "Live"],
    ExplorerRun["Reading " <> FileNameTake[file],
      Append[exactPi[readTruth[file]], "source" -> file]]];
  If[AssociationQ[r], truthCache[{p, q}] = r];
  r];

(* Same payload as pipeline/10_truth.wl, in memory only. *)
ExplorerTruth[p_Integer, q_Integer, "Live"] := Module[{e, stats},
  e = ExplorerEnumerate[p, q, Automatic];
  If[!AssociationQ[e], Return[e, Module]];
  stats = ExplorerRun["Statistics of " <> ToString[Length[e["reps"]]] <> " classes",
    allStatistics[e["reps"], p]];
  If[!ListQ[stats], Return[stats, Module]];
  exactPi[<|"p" -> p, "q" -> q, "numIsoClasses" -> Length[e["reps"]],
    "complexes" -> MapThread[
      <|"facets" -> #1, "aut" -> #2["aut"], "autF" -> #2["autF"],
        "nV" -> #2["numV"], "stats" -> #2|> &, {e["reps"], stats}],
    "source" -> "live"|>]];

(* In batches, with a progress report after each: no shared function, so Stop
   can never find a subkernel inside one (it would break the subkernel). *)
allStatistics[reps_List, p_Integer] := Module[
  {n = ExplorerKernels[], total = Length[reps], done = 0, batch},
  Join @@ Table[
    batch = If[n > 0,
      ParallelMap[PureComplexStatistics[#, p] &, b, Method -> "FinestGrained",
        DistributedContexts -> None],
      PureComplexStatistics[#, p] & /@ b];
    done += Length[b];
    progress[<|"fraction" -> N[done/total],
      "detail" -> ToString[done] <> " of " <> ToString[total]|>];
    AssociationThread[$PureComplexStatisticNames -> #] & /@ batch,
    {b, Partition[reps, UpTo[Max[4, 4 n]]]}]];


(* ----- distributions ----- *)

ExplorerDistribution[truth_Association, stat_String] := Module[{marg, classes},
  marg = AssociationMap[PureComplexTruthMarginal[truth, #, stat] &,
    {"unlabeled", "facet", "vertex"}];
  classes = Counts[#["stats"][stat] & /@ truth["complexes"]];
  <|"value" -> #, "classes" -> classes[#], "unlabeled" -> marg["unlabeled"][#],
      "facet" -> marg["facet"][#], "vertex" -> marg["vertex"][#]|> & /@
    Sort[Keys[classes]]];

ExplorerStatisticNames[p_Integer] := DeleteCases[$PureComplexStatisticNames,
  If[p < 3, "num2PathConnComps" | "num3PathConnComps" | "Betti2" | "Betti3",
    If[p < 4, "num3PathConnComps" | "Betti3", None]]];

statisticLabels = <|
  "numV" -> "number of vertices",
  "aut" -> "vertex automorphism group order",
  "autF" -> "facet automorphism group order",
  "connected" -> "connected (1 or 0)",
  "num1VConnComps" -> "connected components of the 1-skeleton",
  "num2VConnComps" -> "2-vertex-connected components",
  "largestCompRatio" -> "largest component / number of vertices",
  "num2PathConnComps" -> "2-path connected components",
  "num3PathConnComps" -> "3-path connected components",
  "Betti1" -> "Betti number 1 (mod 2)",
  "Betti2" -> "Betti number 2 (mod 2)",
  "Betti3" -> "Betti number 3 (mod 2)"|>;
ExplorerStatisticLabel[s_String] := Lookup[statisticLabels, s, s];


(* ----- single complexes ----- *)

ExplorerComplexQ[c_] := MatchQ[c, {{__} ..}] &&
  Length[First[c]] >= 2 && SameQ @@ (Length /@ c) &&
  AllTrue[c, DuplicateFreeQ] && DuplicateFreeQ[Sort /@ c] &&
  AllTrue[Flatten[c], IntegerQ[#] || StringQ[#] &];

ExplorerRandomComplex[p_Integer, q_Integer, target_String] := ExplorerRun[
  "Drawing a random complex",
  If[target === "unlabeled", progress[<|"detail" ->
    "the first unlabeled draw of a cell computes ECGrav's counts for it: " <>
    "about 20 s at (3,10), minutes at (4,9) and (4,10)"|>]];
  Switch[target,
    "unlabeled", RandomUniformUnlabeledPureSimplicialComplex[{p, q}],
    "facet", RandomUniformFacetLabeledPureSimplicialComplex[{p, q}],
    "vertex", RandomVertexLabeledPureSimplicialComplex[{p, q}]]];

ExplorerStatistics[c_List] := ExplorerRun["Computing statistics",
  AssociationThread[$PureComplexStatisticNames -> PureComplexStatistics[c]]];

End[];
EndPackage[];
