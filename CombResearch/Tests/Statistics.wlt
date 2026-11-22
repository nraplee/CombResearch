(* ::Package:: *)

(* Tests for Statistics.wl: hand-checked small complexes, the "" pattern by p,
   agreement with ECGrav's automorphism orders, and invariance under
   relabelling. Run with Tests/run_tests.wl. *)

If[!MemberQ[$Packages, "CombResearch`"],
  Get[FileNameJoin[{If[ValueQ[$CombResearchTestRoot], $CombResearchTestRoot,
    ParentDirectory[DirectoryName[$InputFileName]]], "Tests", "TestPrelude.wl"}]]];

statsAssoc[c_, p_] := AssociationThread[$PureComplexStatisticNames -> PureComplexStatistics[c, p]];

VerificationTest[Length[$PureComplexStatisticNames], 12, TestID -> "names-12"];

VerificationTest[
  $PureComplexStatisticNames,
  {"numV", "aut", "autF", "connected", "num1VConnComps", "num2VConnComps",
   "largestCompRatio", "num2PathConnComps", "num3PathConnComps",
   "Betti1", "Betti2", "Betti3"},
  TestID -> "names-order"];

(* triangle boundary (p = 2): a cycle *)
VerificationTest[
  Lookup[statsAssoc[{{1, 2}, {1, 3}, {2, 3}}, 2],
    {"numV", "connected", "num1VConnComps", "num2VConnComps", "largestCompRatio",
     "num2PathConnComps", "num3PathConnComps", "Betti1", "Betti2", "Betti3"}],
  {3, 1, 1, 1, 1., "", "", 1, "", ""}, TestID -> "triangle-boundary"];

(* two disjoint edges *)
VerificationTest[
  Lookup[statsAssoc[{{1, 2}, {3, 4}}, 2],
    {"numV", "connected", "num1VConnComps", "largestCompRatio", "Betti1"}],
  {4, 0, 2, 0.5, 0}, TestID -> "two-edges"];

(* 4-cycle *)
VerificationTest[
  PureComplexBettiNumber[{{1, 2}, {2, 3}, {3, 4}, {1, 4}}, 1], 1, TestID -> "square-betti1"];

(* tetrahedron boundary (p = 3): a 2-sphere *)
VerificationTest[
  Lookup[statsAssoc[Subsets[Range[4], {3}], 3],
    {"numV", "connected", "num2PathConnComps", "num3PathConnComps", "Betti1", "Betti2", "Betti3"}],
  {4, 1, 1, "", 0, 1, ""}, TestID -> "tetra-boundary"];

(* two triangles sharing one vertex: cut vertex, two 2-path components *)
VerificationTest[
  Lookup[statsAssoc[{{1, 2, 3}, {3, 4, 5}}, 3],
    {"numV", "connected", "num2VConnComps", "num2PathConnComps", "Betti1", "Betti2"}],
  {5, 1, 2, 2, 0, 0}, TestID -> "bowtie"];

(* one 3-simplex (p = 4): contractible *)
VerificationTest[
  Lookup[statsAssoc[{{1, 2, 3, 4}}, 4],
    {"numV", "num2PathConnComps", "num3PathConnComps", "Betti1", "Betti2", "Betti3"}],
  {4, 1, 1, 0, 0, 0}, TestID -> "simplex-p4"];

VerificationTest[
  PureComplexStatistics[{{1, 2, 3}, {3, 4, 5}}] === PureComplexStatistics[{{1, 2, 3}, {3, 4, 5}}, 3],
  True, TestID -> "p-from-facet"];

(* aut and autF are ECGrav's *)
VerificationTest[
  With[{reps = EnumerateUnlabeledPureComplexes[3, 4, Method -> "Cheap",
      "Parallel" -> False]["isoReps"]},
    AllTrue[reps, Function[c, With[{s = statsAssoc[c, 3]},
      s["aut"] === PureComplexAutomorphismGroupOrder[c] &&
      s["autF"] === PureComplexFacetAutomorphismGroupOrder[c]]]]],
  True, TestID -> "aut-matches-ecgrav-34"];

(* every statistic is a class invariant *)
VerificationTest[
  SeedRandom[11];
  With[{reps = EnumerateUnlabeledPureComplexes[3, 4, Method -> "Cheap",
      "Parallel" -> False]["isoReps"]},
    AllTrue[reps, Function[c, Module[{vs = DeleteDuplicates[Flatten[c]], perm},
      perm = AssociationThread[vs -> (100 + RandomSample[vs])];
      PureComplexStatistics[RandomSample[Sort /@ (c /. perm)], 3] ===
        PureComplexStatistics[c, 3]]]]],
  True, TestID -> "stats-invariant-relabel-34"];

(* the facet-weight identity behind piFacet: Sum over classes q!/autF = the
   number of facet-labeled complexes (70 at (2,4), the cheap DFS leaf count) *)
VerificationTest[
  With[{reps = EnumerateUnlabeledPureComplexes[2, 4, Method -> "Cheap",
      "Parallel" -> False]["isoReps"]},
    Total[(4! / statsAssoc[#, 2]["autF"]) & /@ reps]],
  70, TestID -> "facet-weights-sum-24"];
