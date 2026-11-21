(* golden_derived.wl
   Freeze or check golden/derived: values derived from the existing stored
   data (numV marginals, L1 tables, iso counts, stat-column sums, binned
   figure-panel data). A refactor must reproduce them EXACTLY from the same
   inputs. See tests/golden/README.md.

   Usage:
     wolframscript -file tests\golden\golden_derived.wl check [section ...]
     wolframscript -file tests\golden\golden_derived.wl write [section ...]
     wolframscript -file tests\golden\golden_derived.wl list

   With no section names, every section in tests/golden/sections/ runs,
   each in its own wolframscript process, one after another (the q=10
   sections load 0.3-1.4 GB each; never run them in parallel with other
   heavy jobs).

   write  computes and saves tests/golden/derived/<section>.wxf. Refuses
          to overwrite an existing file unless COMB_FORCE=1.
   check  recomputes and compares with ===. Exit code 0 = all match,
          1 = a record differs, 2 = missing input/golden file or error.
          A changed input hash is reported separately: then a record diff
          means the DATA changed, not the code.

   Inputs are read from $CombDataDir (COMB_ROOT respected), so checks can run
   in a scratch root made by tools\dev\make_check_root.wl. The golden files
   are always read from and written to this code checkout. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "golden_common.wl"}]];

allSections[] := Sort[FileBaseName /@ FileNames["*.wl", $GoldenSectionsDir]];

goldenFile[sec_] := FileNameJoin[{$GoldenDerivedDir, sec <> ".wxf"}];

(* First differing position between two expressions, for readable reports. *)
firstDiff[a_, b_] := Which[
  a === b, None,
  AssociationQ[a] && AssociationQ[b],
    If[Keys[a] =!= Keys[b],
      {"keys", Complement[Keys[a], Keys[b]], Complement[Keys[b], Keys[a]]},
      With[{k = SelectFirst[Keys[a], a[#] =!= b[#] &]},
        Prepend[Replace[firstDiff[a[k], b[k]], None -> {}], k]]],
  ListQ[a] && ListQ[b] && Length[a] === Length[b],
    With[{i = SelectFirst[Range[Length[a]], a[[#]] =!= b[[#]] &]},
      Prepend[Replace[firstDiff[a[[i]], b[[i]]], None -> {}], i]],
  True, {"golden" -> shortForm[a], "now" -> shortForm[b]}];

shortForm[e_] := With[{s = ToString[e, InputForm]},
  If[StringLength[s] > 200, StringTake[s, 200] <> "...", s]];

runSection[mode_, sec_] := Module[{file, t0, res, inputs, payload, gold,
    changedIn, recNow, recOld, diffKeys, missing, extra},
  file = FileNameJoin[{$GoldenSectionsDir, sec <> ".wl"}];
  If[!FileExistsQ[file], Print["golden: no section ", sec]; Return[2]];
  Get[file];
  t0 = AbsoluteTime[];
  res = goldenSection[sec];
  If[!AssociationQ[res] || !KeyExistsQ[res, "records"] || !KeyExistsQ[res, "inputs"],
    Print["golden: section ", sec, " returned no <|inputs, records|>"]; Return[2]];
  inputs = AssociationMap[FileHash[goldenDataFile[#], "SHA256", All, "HexString"] &,
    Sort[DeleteDuplicates[res["inputs"]]]];
  Print["golden: ", sec, ": ", Length[res["records"]], " records from ",
    Length[inputs], " inputs in ", Round[AbsoluteTime[] - t0], " s"];
  payload = <|"section" -> sec, "inputs" -> inputs, "records" -> res["records"],
    "meta" -> <|"version" -> $Version, "systemID" -> $SystemID,
      "dataDir" -> $CombDataDir, "createdAt" -> DateString[]|>|>;
  Switch[mode,
    "write",
      If[FileExistsQ[goldenFile[sec]] && Environment["COMB_FORCE"] =!= "1",
        Print["golden: ", goldenFile[sec], " exists; set COMB_FORCE=1 to overwrite"];
        Return[2]];
      If[!DirectoryQ[$GoldenDerivedDir], CreateDirectory[$GoldenDerivedDir]];
      Export[goldenFile[sec], payload, "WXF"];
      Print["golden: wrote ", goldenFile[sec]]; 0,
    "check",
      If[!FileExistsQ[goldenFile[sec]],
        Print["golden: no golden file for ", sec, "; run write first"]; Return[2]];
      gold = Import[goldenFile[sec], "WXF"];
      If[gold["meta", "version"] =!= $Version,
        Print["golden: WARNING golden made with ", gold["meta", "version"],
          ", now ", $Version, "; float results may differ in the last bits"]];
      changedIn = Select[Union[Keys[gold["inputs"]], Keys[inputs]],
        Lookup[gold["inputs"], #] =!= Lookup[inputs, #] &];
      If[changedIn =!= {},
        Print["golden: ", sec, ": INPUTS CHANGED (data, not code): ", changedIn]];
      recOld = gold["records"]; recNow = res["records"];
      missing = Complement[Keys[recOld], Keys[recNow]];
      extra = Complement[Keys[recNow], Keys[recOld]];
      diffKeys = Select[Intersection[Keys[recOld], Keys[recNow]],
        recOld[#] =!= recNow[#] &];
      If[missing =!= {}, Print["  missing records: ", Short[missing, 3]]];
      If[extra =!= {}, Print["  new records: ", Short[extra, 3]]];
      Scan[Print["  DIFF ", #, " at ", firstDiff[recOld[#], recNow[#]]] &,
        Take[diffKeys, UpTo[20]]];
      If[Length[diffKeys] > 20, Print["  ... and ", Length[diffKeys] - 20, " more"]];
      If[missing === {} && extra === {} && diffKeys === {},
        Print["golden: ", sec, ": PASS (", Length[recNow], " records)"]; 0,
        Print["golden: ", sec, ": FAIL (", Length[diffKeys], " differ, ",
          Length[missing], " missing, ", Length[extra], " new)"]; 1],
    _, Print["golden: unknown mode ", mode]; 2]];

Module[{args, mode, secs, codes},
  args = Rest[$ScriptCommandLine];
  mode = If[args === {}, "check", First[args]];
  If[mode === "list", Print[StringRiffle[allSections[], "\n"]]; Exit[0]];
  If[!MemberQ[{"check", "write"}, mode],
    Print["usage: golden_derived.wl check|write|list [section ...]"]; Exit[2]];
  secs = If[Length[args] > 1, Rest[args], allSections[]];
  If[Length[secs] === 1,
    Exit[runSection[mode, First[secs]]]];
  (* Several sections: one process each, so memory is released between
     them. *)
  codes = AssociationMap[
    Function[sec, Module[{r},
      Print["===== ", sec, " ====="];
      r = RunProcess[{"wolframscript", "-file", $InputFileName, mode, sec}];
      Print[StringTrim[r["StandardOutput"]]];
      If[StringTrim[r["StandardError"]] =!= "", Print[r["StandardError"]]];
      r["ExitCode"]]],
    secs];
  Print["===== summary ====="];
  KeyValueMap[Print[#1, ": ", Switch[#2, 0, "ok", 1, "FAIL", _, "ERROR " <> ToString[#2]]] &, codes];
  Exit[Max[Values[codes]]]];
