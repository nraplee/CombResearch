(* lib/samplecols.wl
   Helpers for sections/samplecols.wl: a compact column summary of one
   sample WXF (MH chain from src/run_mh_chains.wl, or ECGrav sampler output
   from src/run_ecgrav_samplers.wl). Never stores raw rows. *)

(* Embedded scalar metadata kept when present. *)
sampleMetaKeys = {"p", "q", "target", "sampler", "kernel", "seed", "numIter",
  "burnIn", "thin", "acceptRate", "samplerVersion", "ecGravVersion",
  "numSamples", "tag", "initNumV"};

sampleBlankQ[x_] := MatchQ[x, "" | _Missing];

sampleTypeName[x_] := Switch[Head[x],
  Integer, "Integer", Real, "Real", Rational, "Rational", String, "String",
  Missing, "Missing", _, "Other:" <> ToString[Head[x]]];

(* Exact Total of a column whose non-blank entries are all Integers. *)
sampleIntTotal[col_List] := With[{nb = Select[col, !sampleBlankQ[#] &]},
  If[nb =!= {} && VectorQ[nb, IntegerQ], Total[nb], Missing["NotIntegerColumn"]]];

sampleFileRecord[m_Association] := Module[{hs, rows, cols, rec},
  hs = m["headers"];
  rows = m["rows"];
  cols = AssociationThread[hs, Table[rows[[All, j]], {j, Length[hs]}]];
  rec = <|
    "headers" -> hs,
    "rowCount" -> Length[rows],
    "rowLengths" -> Union[Length /@ rows],
    "nonBlankCount" -> (Count[#, x_ /; !sampleBlankQ[x]] & /@ cols),
    "intTotal" -> (sampleIntTotal /@ cols),
    (* Sequential left fold, so the sum is fixed to row order. *)
    "largestCompRatioTotal" -> If[KeyExistsQ[cols, "largestCompRatio"],
      Fold[Plus, 0, cols["largestCompRatio"]], Missing["NoColumn"]],
    "typeCounts" -> (KeySort[Counts[sampleTypeName /@ #]] & /@ cols),
    "meta" -> KeyTake[m, sampleMetaKeys]|>;
  If[ListQ[m["classIdx"]],
    rec["classIdx"] = <|"length" -> Length[m["classIdx"]],
      "total" -> Total[m["classIdx"]], "zeroCount" -> Count[m["classIdx"], 0]|>];
  (* The vertex MH bug (piRatio = 1 before the 2026-05-14 fix) accepts every
     proposal, so a pre-fix vertex chain has acceptRate exactly 1. *)
  If[Lookup[m, "target"] === "vertex" && Lookup[m, "acceptRate"] === 1.,
    rec["knownBad"] = "pre-fix vertex MH chain (acceptRate 1.; pi_V proportional to 1 bug, see AGENTS.md)"];
  rec];
