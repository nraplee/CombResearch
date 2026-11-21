(* tests/golden/sections/validate.wl
   Freezes src/validate_mh_vs_truth.wl: per cell x target, the numV truth
   marginal vs the sample marginal (keys/truth/sample/diff vectors, L1,
   pass at the script's default threshold 0.05), sample count n, unmatched
   classIdx count, per-iso-class chi-square {chi2, df, bins, pValue} and
   the L1 of every other stat marginal. iidPValue is excluded (unseeded
   RandomVariate at validate_mh_vs_truth.wl:153).

   Sources:
     ecgexact, ecgmcmc   all 27 default cell x target combinations
     ecglegacyfacet      facet at (2,4) and (3,4) (the files that exist)
     mh                  every default cell x target whose
                         p{p}q{q}_mh_{target}.wxf exists in the store
   For ecg* each row is compared exactly with the matching row of
   data/validation_{source}_summary.wxf ("storedSummaryMatch"). There is no
   validation_mh_summary.wxf, so mh rows are only frozen. The stale
   pre-fix vertex chains (acceptRate 1, made before the 2026-05-14 vertex
   fix) are frozen as they are and marked "knownBad".

   Record keys: "<source>/p{p}q{q}/<target>", plus "summary/<source>".
   Helpers: tests/golden/lib/validate.wl. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "validate.wl"}]];

$valKnownBadVertex = {{2, 4}, {2, 5}, {2, 6}, {3, 4}, {3, 5}};
$valKnownBadReason = "stale pre-fix MH vertex chain (pi_V proportional to 1, " <>
  "made before the 2026-05-14 vertex fix; acceptRate 1)";

(* Fields of a stored summary row that the golden recomputes. *)
$valCompared = {"p", "q", "target", "source", "n", "l1", "pass",
  "classChi2", "unmatched", "otherStatL1"};

valSummaryName[source_] := "validation_" <> source <> "_summary.wxf";

valAllCombos[] := Flatten[Table[Append[c, t], {c, valDefaultCells}, {t, valDefaultTargets}], 1];
valCombos["ecglegacyfacet"] := {{2, 4, "facet"}, {3, 4, "facet"}};
valCombos["mh"] := Select[valAllCombos[],
  FileExistsQ[FileNameJoin[{$CombDataDir, valSampleName["mh", #[[1]], #[[2]], #[[3]]]}]] &];
valCombos[_] := valAllCombos[];

valRecord[source_, {p_, q_, t_}, stored_] := Module[{r, cmp, rec, srow},
  r = valCell[source, p, q, t];
  cmp = r["cmp"];
  rec = <|"n" -> r["n"],
    "keys" -> cmp["keys"], "truth" -> cmp["truth"], "sample" -> cmp["mh"],
    "diff" -> cmp["diff"], "l1" -> r["l1"], "pass" -> r["pass"],
    "unmatched" -> r["unmatched"], "classChi2" -> r["classChi2"],
    "otherStatL1" -> r["otherStatL1"]|>;
  If[stored =!= None,
    srow = Select[stored["results"], #["p"] === p && #["q"] === q && #["target"] === t &];
    rec["storedSummaryMatch"] = Length[srow] === 1 &&
      KeyTake[First[srow], $valCompared] === KeyTake[r, $valCompared]];
  If[source === "mh" && t === "vertex" && MemberQ[$valKnownBadVertex, {p, q}],
    rec["knownBad"] = $valKnownBadReason];
  source <> "/p" <> ToString[p] <> "q" <> ToString[q] <> "/" <> t -> rec];

goldenSection["validate"] := Module[{inputs = {}, records = <||>},
  Do[
    Module[{combos = valCombos[source], stored = None},
      If[source =!= "mh",
        stored = goldenImport[valSummaryName[source]];
        AppendTo[inputs, valSummaryName[source]];
        (* summary-level check: same threshold and the same row set *)
        records["summary/" <> source] = <|
          "threshold" -> stored["threshold"],
          "rows" -> Length[stored["results"]],
          "storedSummaryMatch" -> (stored["threshold"] === valThreshold &&
            Sort[{#["p"], #["q"], #["target"]} & /@ stored["results"]] === Sort[combos])|>];
      Do[
        inputs = Join[inputs, {valTruthName[c[[1]], c[[2]]],
          valSampleName[source, c[[1]], c[[2]], c[[3]]]}];
        AppendTo[records, valRecord[source, c, stored]],
        {c, combos}]],
    {source, {"ecgexact", "ecgmcmc", "ecglegacyfacet", "mh"}}];
  <|"inputs" -> DeleteDuplicates[inputs], "records" -> records|>];
