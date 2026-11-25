(* ::Package:: *)

(* Tests for Enumeration.wl: iso-class counts against the truth grid for all
   three methods, Automatic method choice, the canonical key, bucketed dedup
   vs ECGrav, and the parallel path. Run with Tests/run_tests.wl (about 2 min). *)

If[!MemberQ[$Packages, "CombResearch`"],
  Get[FileNameJoin[{If[ValueQ[$CombResearchTestRoot], $CombResearchTestRoot,
    ParentDirectory[DirectoryName[$InputFileName]]], "Tests", "TestPrelude.wl"}]]];

(* ----- counts vs the truth grid, sequential ----- *)
Do[With[{c = cell, m = method},
    VerificationTest[
      Length[EnumerateUnlabeledPureComplexes[c[[1]], c[[2]], Method -> m,
        "Parallel" -> False]["isoReps"]],
      $CombTruthIsoCounts[c],
      TestID -> "count-" <> m <> "-" <> ToString[c[[1]]] <> ToString[c[[2]]]]],
  {cell, {{2, 4}, {2, 5}, {3, 4}}}, {method, {"Cheap", "BLISS", "McKay"}}];

(* cheap and BLISS visit every facet-labeled complex once *)
VerificationTest[
  EnumerateUnlabeledPureComplexes[2, 4, Method -> "Cheap", "Parallel" -> False]["totalEmitted"],
  70, TestID -> "totalEmitted-cheap-24"];

VerificationTest[
  EnumerateUnlabeledPureComplexes[3, 4, Method -> "BLISS", "Parallel" -> False]["totalEmitted"],
  666, TestID -> "totalEmitted-bliss-34"];

(* ----- Progress reports: same result, last report complete ----- *)
Do[With[{m = method, par = parallel},
    VerificationTest[
      Module[{log = {}, opts = {Method -> m, "Parallel" -> par}, r},
        r = EnumerateUnlabeledPureComplexes[2, 4, opts, "Progress" -> (AppendTo[log, #] &)];
        {r === EnumerateUnlabeledPureComplexes[2, 4, opts],
         Last[log]["starts"] === Last[log]["startsDone"] &&
           If[par, Last[log]["starts"] > 12, Last[log]["starts"] === 12],
         Last[log]["leaves"] === r["totalEmitted"],
         OrderedQ[Lookup[log, "leaves"]]}],
      {True, True, True, True},
      TestID -> "progress-" <> m <> If[par, "-parallel", "-serial"]]],
  {method, {"Cheap", "BLISS", "McKay"}}, {parallel, {False, True}}];

(* serial: reports also come from inside a start, not only when one is done
   (McKay: one start runs for most of the time). Parallel: the starts are cut
   into many jobs, so reports come while some are done and some are not. No
   task is left behind. *)
Do[With[{par = parallel},
    VerificationTest[
      Module[{log = {}},
        EnumerateUnlabeledPureComplexes[3, 4, Method -> "McKay", "Parallel" -> par,
          "Progress" -> (AppendTo[log, #] &)];
        {MemberQ[Partition[log, 2, 1], {a_, b_} /; a["leaves"] < b["leaves"] &&
            If[par, 0 < a["startsDone"] < b["startsDone"] < b["starts"],
              a["startsDone"] === b["startsDone"]]],
         Last[log]["leaves"], Tasks[]}],
      {True, 417, {}},
      TestID -> "progress-inside-starts" <> If[par, "-parallel", "-serial"]]],
  {parallel, {False, True}}];

(* ----- Automatic method choice ----- *)
VerificationTest[
  EnumerateUnlabeledPureComplexes[2, 4, "Parallel" -> False]["method"],
  "Cheap", TestID -> "auto-cheap-p2"];

(* two distinct 4-sets: overlap 0, 1, 2 or 3 -> 4 classes *)
VerificationTest[
  Lookup[EnumerateUnlabeledPureComplexes[4, 2, "Parallel" -> False],
    {"method", "isoReps"}] /. {m_, reps_List} :> {m, Length[reps]},
  {"McKay", 4}, TestID -> "auto-mckay-p4"];

VerificationTest[
  Length[EnumerateUnlabeledPureComplexes[4, 2, Method -> "Cheap",
    "Parallel" -> False]["isoReps"]],
  4, TestID -> "cheap-42"];

VerificationTest[
  EnumerateUnlabeledPureComplexes[2, 4, Method -> "Fast"],
  $Failed, {EnumerateUnlabeledPureComplexes::method}, TestID -> "bad-method"];

(* ----- shape of the representatives ----- *)
VerificationTest[
  With[{reps = EnumerateUnlabeledPureComplexes[3, 4, Method -> "McKay",
      "Parallel" -> False]["isoReps"]},
    AllTrue[reps, Function[c,
      Length[c] === 4 && AllTrue[c, Length[#] === 3 && OrderedQ[#] &] &&
      DuplicateFreeQ[c] &&
      Sort[DeleteDuplicates[Flatten[c]]] === Range[Length[DeleteDuplicates[Flatten[c]]]]]]],
  True, TestID -> "reps-shape-34"];

(* ----- canonical key ----- *)
VerificationTest[
  With[{reps = EnumerateUnlabeledPureComplexes[3, 4, Method -> "Cheap",
      "Parallel" -> False]["isoReps"]},
    DuplicateFreeQ[PureComplexCanonicalKey /@ reps]],
  True, TestID -> "key-distinct-34"];

VerificationTest[
  SeedRandom[7];
  With[{reps = EnumerateUnlabeledPureComplexes[3, 4, Method -> "Cheap",
      "Parallel" -> False]["isoReps"]},
    AllTrue[reps, Function[c, Module[{vs = DeleteDuplicates[Flatten[c]], perm, relab},
      perm = AssociationThread[vs -> (10 RandomSample[vs])];
      relab = RandomSample[Sort /@ (c /. perm)];
      PureComplexCanonicalKey[relab] === PureComplexCanonicalKey[c]]]]],
  True, TestID -> "key-invariant-relabel"];

(* ----- bucketed dedup vs ECGrav ----- *)
VerificationTest[
  With[{all = GenerateAllFacetLabeledPureSimplicialComplexes[{2, 4}]},
    {Length[ChooseNonIsomorphicPureComplexesBucketed[all]],
     Length[ChooseNonIsomorphicSimplicialComplexes[all]]}],
  {11, 11}, TestID -> "bucketed-vs-ecgrav-24"];

(* ----- parallel path ----- *)
(* the same result, in the same order, for every way to cut the tree *)
Do[With[{m = method, cells = {{2, 4}, {3, 3}, {4, 2}, {2, 1}}},
    Module[{run, serial},
      run[par_] := EnumerateUnlabeledPureComplexes[#1, #2, Method -> m, "Parallel" -> par] & @@@
        cells;
      serial = run[False];
      Do[With[{k = jobs},
          VerificationTest[
            Block[{CombResearch`Private`$enumerationJobsPerKernel = k}, run[True] === serial],
            True, TestID -> "parallel-same-as-serial-" <> m <> "-" <> ToString[k]]],
        {jobs, {1, 4, 1000}}]]],
  {method, {"Cheap", "BLISS", "McKay"}}];

VerificationTest[
  Length[EnumerateUnlabeledPureComplexes[2, 5, Method -> #, "Parallel" -> True]["isoReps"]] & /@
    {"Cheap", "McKay"},
  {26, 26}, TestID -> "parallel-25"];

VerificationTest[
  Sort[PureComplexCanonicalKey /@ EnumerateUnlabeledPureComplexes[2, 5, Method -> "Cheap",
      "Parallel" -> True]["isoReps"]] ===
    Sort[PureComplexCanonicalKey /@ EnumerateUnlabeledPureComplexes[2, 5, Method -> "McKay",
      "Parallel" -> False]["isoReps"]],
  True, TestID -> "same-classes-cheap-mckay-25"];
