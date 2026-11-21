(* ecgrav_regression.wl
   Re-validate the loaded ECGrav (see src/load_ecgrav.wl) against the exact
   truth grid. Run it whenever the ECGrav commit changes: after
   tools/dev/update_ecgrav.wl, or with COMB_ECGRAV_DIR pointing at a fork.
   load_ecgrav.wl warns until the loaded commit has passed.

   Checks, on the 9 truth cells (2,4) (2,5) (2,6) (2,7) (3,4) (3,5) (3,6)
   (4,4) (4,5):
     1. counters   Num{Unlabeled,FacetLabeled,VertexLabeled}PureComplexes
                   [p,q,n] equal the truth counts at every n, and
                   NumUnlabeledPureComplexes[p,q] equals the iso count
                   (logic of src/validate_counts_vs_truth.wl).
     2. aut        PureComplexAutomorphismGroupOrder and
                   PureComplexFacetAutomorphismGroupOrder reproduce the stored
                   aut / autF of every truth class (10,882 classes).
     3. exact      the exact samplers RandomVertexLabeled…,
                   RandomUniformFacetLabeled… and RandomUniformUnlabeled…
                   give a numV marginal within L1 < 0.05 of truth
                   (N = COMB_REG_N draws per cell x target, seed 24680).
     4. mh         MH smoke: runMHChain from src/sampler_mh.wl at (2,4),
                   3 targets, 50k iterations, numV L1 < 0.1 (a smoke test: it

   Exit 0 when everything passes, and records the commit in
   $CombResultsDir/ecgrav_regression_passed.wl; exit 1 otherwise.
   Reads only truth WXFs; writes nothing else.

   Env:
     COMB_REG_N       exact-sampler draws per cell x target (default 20000)
     COMB_REG_CELLS   restrict cells, "p,q;p,q" (a restricted run is not
                      recorded as a pass)
     COMB_ECGRAV_DIR  see load_ecgrav.wl *)

$smokeTestSkip = True;
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "src",
  "sampler_mh.wl"}]];   (* loads comb_paths.wl and load_ecgrav.wl *)

$allCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7}, {3, 4}, {3, 5}, {3, 6}, {4, 4}, {4, 5}};
$targets = {"vertex", "unlabeled", "facet"};
$threshold = 0.05;
$mhThreshold = 0.1;
$n = With[{e = Environment["COMB_REG_N"]},
  If[StringQ[e] && StringLength[e] > 0, ToExpression[e], 20000]];
$cells = With[{e = Environment["COMB_REG_CELLS"]},
  If[StringQ[e] && StringLength[e] > 0,
    ToExpression /@ StringSplit[#, ","] & /@ StringSplit[StringTrim[e], ";"],
    $allCells]];

truth[p_, q_] := truth[p, q] = Import[FileNameJoin[{$CombDataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf"}], "WXF"];

piKey = <|"vertex" -> "piVertex", "unlabeled" -> "piUnlabeled", "facet" -> "piFacet"|>;

(* Truth numV marginal, as marginalizeNumV in src/validate_mh_vs_truth.wl. *)
truthMarginal[p_, q_, target_] := With[{t = truth[p, q]},
  Merge[Thread[(#["stats"]["numV"] & /@ t["complexes"]) -> t[piKey[target]]], Total]];

sampleMarginal[numVs_List] := N[Counts[numVs] / Length[numVs]];

l1[a_, b_] := With[{ks = Union[Keys[a], Keys[b]]},
  Total[Abs[Lookup[a, ks, 0.] - Lookup[b, ks, 0.]]]];

failures = {};
fail[msg__] := (AppendTo[failures, StringJoin[ToString /@ {msg}]];
  Print["  *** FAIL ", msg]);

(* 1. counters *)
Print["== counters vs truth =="];
Do[Module[{t = truth @@ c, p = c[[1]], q = c[[2]], byN, bad},
    byN = GroupBy[t["complexes"], #["nV"] &,
      <|"U" -> Length[#], "F" -> Total[(q! / #["autF"]) & /@ #],
        "V" -> Total[(#["nV"]! / #["aut"]) & /@ #]|> &];
    bad = Select[Range[p, p q], Function[n,
      With[{tr = Lookup[byN, n, <|"U" -> 0, "F" -> 0, "V" -> 0|>]},
        tr =!= <|"U" -> NumUnlabeledPureComplexes[p, q, n],
          "F" -> NumFacetLabeledPureComplexes[p, q, n],
          "V" -> NumVertexLabeledPureComplexes[p, q, n]|>]]];
    If[bad =!= {}, fail[c, " counters differ at n = ", bad]];
    If[NumUnlabeledPureComplexes[p, q] =!= t["numIsoClasses"],
      fail[c, " iso count ", NumUnlabeledPureComplexes[p, q], " vs truth ",
        t["numIsoClasses"]]];
    If[bad === {} && NumUnlabeledPureComplexes[p, q] === t["numIsoClasses"],
      Print["  ", c, " ok (", t["numIsoClasses"], " classes)"]]],
  {c, $cells}];

(* 2. aut / autF *)
Print["== aut / autF vs truth =="];
Do[Module[{cs = truth[Sequence @@ c]["complexes"], badA, badF, secs},
    {secs, {badA, badF}} = AbsoluteTiming[{
      Count[cs, x_ /; PureComplexAutomorphismGroupOrder[x["facets"]] =!= x["aut"]],
      Count[cs, x_ /; PureComplexFacetAutomorphismGroupOrder[x["facets"]] =!= x["autF"]]}];
    If[badA + badF > 0,
      fail[c, " aut mismatches ", badA, ", autF mismatches ", badF],
      Print["  ", c, " ok (", Length[cs], " classes, ", Round[secs], " s)"]]],
  {c, $cells}];

(* 3. exact samplers *)
Print["== exact samplers, N = ", $n, " =="];
draw["vertex", p_, q_] := RandomVertexLabeledPureSimplicialComplex[{p, q}, $n];
draw["unlabeled", p_, q_] := RandomUniformUnlabeledPureSimplicialComplex[{p, q}, $n];
draw["facet", p_, q_] := RandomUniformFacetLabeledPureSimplicialComplex[{p, q}, $n];
Do[Module[{d, secs, v},
    SeedRandom[24680];
    {secs, d} = AbsoluteTiming[draw[target, Sequence @@ c]];
    v = l1[sampleMarginal[Length[DeleteDuplicates[Flatten[#]]] & /@ d],
      truthMarginal[Sequence @@ c, target]];
    If[v < $threshold,
      Print["  ", c, " ", target, " L1 = ", Round[v, 0.0001], " (", Round[secs], " s)"],
      fail[c, " ", target, " exact L1 = ", v]]],
  {c, $cells}, {target, $targets}];

(* 4. MH smoke at (2,4) *)
Print["== MH smoke (2,4), 50k iterations =="];
If[MemberQ[$cells, {2, 4}],
  Do[Module[{r, v},
      r = runMHChain[2, 4, target, 50000, burnIn -> 5000];
      v = l1[sampleMarginal[numActive /@ r["trace"]], truthMarginal[2, 4, target]];
      If[v < $mhThreshold,
        Print["  ", target, " L1 = ", Round[v, 0.0001]],
        fail["MH (2,4) ", target, " L1 = ", v]]],
    {target, $targets}]];

Print["== summary: ECGrav ", $CombECGravVersion, " (", $CombECGravCommit, ") =="];
If[failures === {},
  If[$cells === $allCells && !StringEndsQ[$CombECGravCommit, "-dirty"] &&
      $CombECGravCommit =!= "unknown",
    Put[<|"commit" -> $CombECGravCommit, "version" -> $CombECGravVersion,
      "dir" -> $CombECGravDir, "wolfram" -> $Version, "n" -> $n,
      "date" -> DateString["ISODateTime"]|>,
      FileNameJoin[{$CombResultsDir, "ecgrav_regression_passed.wl"}]];
    Print["PASS; recorded in ", FileNameJoin[{$CombResultsDir, "ecgrav_regression_passed.wl"}]],
    Print["PASS (not recorded: restricted cells, dirty or unknown commit)"]];
  Exit[0],
  Print["FAIL: ", Length[failures], " check(s)"]; Scan[Print["  ", #] &, failures];
  Exit[1]];
