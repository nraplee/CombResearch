(* lib_config_test.wl
   Checks pipeline/common/config.wl and config/cells.wl (Phase 2c).

   1. Each kind parses an env string exactly as the inline code it replaced
      (old parsers copied below as reference).
   2. Precedence: env > COMB_PROFILE settings > script default; an unset or
      empty env falls through; sources are recorded.
   3. config/cells.wl: both profiles load and have the documented keys.
   4. An unknown profile or kind aborts.

   Each part that needs a fresh COMB_PROFILE runs in a child wolframscript,
   because lib_config resolves the profile once per kernel. Reads only.
   Exit 0 pass, 1 fail.

     wolframscript -file tests\lib_config_test.wl *)

$src = FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "common"}];
$self = $InputFileName;
$fail = 0;
check[label_, got_, want_] := If[got === want, Null,
  $fail++; Print["FAIL ", label, ": got ", InputForm[got], ", want ",
    InputForm[want]]];

(* Child mode: COMB_TEST_CHILD=<part> evaluates one part and Puts the result. *)
$child = Environment["COMB_TEST_CHILD"];
If[StringQ[$child],
  SetEnvironment["COMB_TEST_CHILD" -> None];
  result = CheckAbort[
    Get[FileNameJoin[{$src, "config.wl"}]];
    Switch[$child,
      "profile", {$CombProfile,
        combSetting["COMB_VAL_CELLS", {{9, 9}}, "cells"],
        combSetting["COMB_ECG_N", 7, "expr"],
        combSetting["COMB_MH_NUMITER", 123, "expr"],
        Lookup[$CombSettings, {"COMB_VAL_CELLS", "COMB_ECG_N", "COMB_MH_NUMITER"}][[All, "source"]],
        Length[combProfileData["mhChains"]]},
      "none", {$CombProfile, combSetting["COMB_VAL_CELLS", {{9, 9}}, "cells"],
        combProfileData["mhChains"]},
      "kind", combSetting["COMB_X_TEST", 1, "nope"],
      _, "bad child"],
    "aborted"];
  Print["RESULT:", ToString[result, InputForm]];
  Exit[0]];

runChild[part_, env_Association] := Module[{res, out},
  res = RunProcess[{"wolframscript", "-file", $self},
    All, "", ProcessEnvironment -> Join[
      Association[GetEnvironment[]], <|"COMB_TEST_CHILD" -> part|>, env]];
  out = StringCases[res["StandardOutput"], "RESULT:" ~~ x : Except["\n"] .. :> x];
  If[out === {}, Print["child ", part, " printed no result:\n", res["StandardOutput"],
    res["StandardError"]]; $Failed,
    ToExpression[StringTrim[Last[out]]]]];

(* Clear knobs this test sets, in case the caller's shell has them. *)
SetEnvironment[# -> None] & /@ {"COMB_PROFILE", "COMB_VAL_CELLS", "COMB_ECG_N",
  "COMB_MH_NUMITER", "COMB_X_TEST"};
Get[FileNameJoin[{$src, "config.wl"}]];
check["no profile by default", $CombProfile, None];

(* ----- 1. kinds vs the old inline parsers ----- *)
oldCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];
oldList[s_String] := StringTrim /@ StringSplit[StringTrim[s], ","];
oldEnv[e_, default_, f_] := If[StringQ[e] && StringLength[e] > 0, f[e], default];

kindCases = {
  (* kind, env string, default, old result *)
  {"cells", "3,5;4,5", {}, oldEnv["3,5;4,5", {}, oldCells]},
  {"cells", " 2,4 ; 3,4 ", {}, oldEnv[" 2,4 ; 3,4 ", {}, oldCells]},
  {"cells", "4,5", {}, oldEnv["4,5", {}, oldCells]},
  {"list", "vertex, facet", {}, oldEnv["vertex, facet", {}, oldList]},
  {"list", "facet", {}, oldEnv["facet", {}, oldList]},
  {"intList", "2, 3", {}, oldEnv["2, 3", {}, ToExpression /@ oldList[#] &]},
  {"expr", "200000", 0, oldEnv["200000", 0, ToExpression]},
  {"expr", "0.1", 0, oldEnv["0.1", 0, ToExpression]},
  {"expr", "Automatic", 0, oldEnv["Automatic", 0, ToExpression]},
  {"string", "_seed67890_warm14", "", oldEnv["_seed67890_warm14", "", Identity]},
  {"string", " mckay ", "", " mckay "},
  {"flag", "1", False, True}, {"flag", "0", False, False},
  {"flag", "true", False, False},
  {"notFalse", "false", True, False}, {"notFalse", " FALSE ", True, False},
  {"notFalse", "true", True, True}, {"notFalse", "no", True, True},
  {"notZero", "0", True, False}, {"notZero", "1", True, True}};
Do[
  SetEnvironment["COMB_X_TEST" -> c[[2]]];
  check["kind " <> c[[1]] <> " " <> ToString[c[[2]], InputForm],
    combSetting["COMB_X_TEST", c[[3]], c[[1]]], c[[4]]],
  {c, kindCases}];
Print["kind cases: ", Length[kindCases]];

(* unset and empty fall through to the default, for every kind *)
Do[
  SetEnvironment["COMB_X_TEST" -> None];
  check["unset " <> k, combSetting["COMB_X_TEST", "dflt", k], "dflt"];
  SetEnvironment["COMB_X_TEST" -> ""];
  check["empty " <> k, combSetting["COMB_X_TEST", "dflt", k], "dflt"],
  {k, {"string", "expr", "cells", "list", "intList", "flag", "notFalse", "notZero"}}];
SetEnvironment["COMB_X_TEST" -> None];
check["source default", $CombSettings["COMB_X_TEST"]["source"], "default"];
SetEnvironment["COMB_X_TEST" -> "5"];
combSetting["COMB_X_TEST", 1, "expr"];
check["source env", $CombSettings["COMB_X_TEST"], <|"value" -> 5, "source" -> "env"|>];
SetEnvironment["COMB_X_TEST" -> None];
check["2-arg form is string", combSetting["COMB_X_TEST", "d"], "d"];
check["no profile data", combProfileData["mhChains"], Missing["NoProfile"]];

(* ----- 2. precedence through a profile (child kernels) ----- *)
check["child: no profile",
  runChild["none", <||>], {None, {{9, 9}}, Missing["NoProfile"]}];
check["child: quick profile",
  runChild["profile", <|"COMB_PROFILE" -> "quick"|>],
  {"quick", {{2, 4}, {3, 4}}, 5000, 123,
   {"profile quick", "profile quick", "default"}, 1}];
check["child: env beats profile",
  runChild["profile", <|"COMB_PROFILE" -> "quick", "COMB_ECG_N" -> "42"|>],
  {"quick", {{2, 4}, {3, 4}}, 42, 123,
   {"profile quick", "env", "default"}, 1}];
check["child: unknown profile aborts",
  runChild["none", <|"COMB_PROFILE" -> "papr"|>], "aborted"];
check["child: unknown kind aborts", runChild["kind", <|"COMB_X_TEST" -> "1"|>], "aborted"];

(* ----- 3. config/cells.wl ----- *)
profiles = combLoadProfiles[];
check["profile names", Sort[Keys[profiles]], {"paper", "quick"}];
Do[
  check[name <> " keys", Sort[Keys[profiles[name]]],
    Sort[{"settings", "truthRuns", "isBatches", "mhChains", "ecgravRuns"}]];
  check[name <> " settings are COMB_ knobs",
    AllTrue[Keys[profiles[name]["settings"]], StringStartsQ[#, "COMB_"] &], True];
  check[name <> " isBatches per p", Sort[Keys[profiles[name]["isBatches"]]], {2, 3, 4}];
  check[name <> " mhChains are associations",
    AllTrue[profiles[name]["mhChains"], AssociationQ], True],
  {name, {"paper", "quick"}}];
paper = profiles["paper"];
check["paper truth covers the 9-cell grid",
  Sort[Join @@ paper["truthRuns"][[All, "cells"]]],
  Sort[{{2, 4}, {2, 5}, {2, 6}, {2, 7}, {3, 4}, {3, 5}, {3, 6}, {4, 4}, {4, 5}}]];
check["paper (4,5) truth is McKay, sequential",
  Select[paper["truthRuns"], MemberQ[#["cells"], {4, 5}] &][[1, {"pipeline", "parallel"}]],
  <|"pipeline" -> "mckay", "parallel" -> False|>];
check["paper IS batch3 has no p=2", Length[paper["isBatches"][2]], 2];
check["paper warm chains",
  Sort[#["tag"] & /@ Select[paper["mhChains"], KeyExistsQ[#, "tag"] &]],
  Sort[{"_seed67890_warm14", "_seed67890_warm14", "_seed67890_warm18",
    "_seed67890_warm18"}]];

If[$fail == 0, Print["PASS"]; Exit[0], Print["FAILED: ", $fail]; Exit[1]];
