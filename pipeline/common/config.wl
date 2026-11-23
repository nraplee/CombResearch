(* config.wl
   One place that resolves a script's settings (Phase 2c).

   combSetting[name, default, kind] returns, in this order:
     1. the env var `name` (a COMB_* knob), if set and non-empty;
     2. the value in the named profile's "settings", if COMB_PROFILE names
        a profile in config/cells.wl and that profile sets `name`;
     3. `default`, the script's own default.
   With no COMB_PROFILE every script behaves exactly as before Phase 2c
   (guarantee 3 of docs/architecture/implementation-plan.md). Phase 3's
   run.wl will put CLI flags in front of the env.

   kind says how an env string is parsed (profile values are already
   Wolfram values and are used as they are):
     "string"    the string as given (default)
     "expr"      ToExpression (integers, reals, Automatic, ...)
     "cells"     "p,q;p,q" -> {{p, q}, {p, q}}
     "list"      "a, b" -> {"a", "b"}
     "intList"   "2, 3" -> {2, 3}
     "flag"      True only for "1"            (COMB_FORCE)
     "notFalse"  False only for "false", any case  (COMB_TRUTH_PARALLEL)
     "notZero"   False only for "0"           (COMB_IS_PAR)
   For "flag", "notFalse" and "notZero" an unset env gives the default.

   Loads paths.wl. Idempotent: a second Get keeps the recorded
   settings.

   Defines:
     combSetting[name, default, kind]
     $CombProfile            profile name, or None
     combProfileData[key]    a profile's structured data (e.g. "isBatches"),
                             Missing["NoProfile"] when no profile is set
     $CombSettings           <|name -> <|"value", "source"|>|>, every
                             setting resolved so far; source is "env",
                             "profile <name>" or "default"
     combPrintSettings[]     print $CombSettings as a table
     combLoadProfiles[]      the Association in config/cells.wl *)

If[!ValueQ[$CombRoot],
  Get[FileNameJoin[{DirectoryName[$InputFileName], "paths.wl"}]]];

If[!ValueQ[$CombSettings],
  $CombSettings = <||>;

  combLoadProfiles[] := Module[{f, profiles},
    f = FileNameJoin[{$CombCodeRoot, "config", "cells.wl"}];
    If[!FileExistsQ[f],
      Print["lib_config: profile file missing: ", f]; Abort[]];
    profiles = Get[f];
    If[!AssociationQ[profiles],
      Print["lib_config: ", f, " did not return an Association"]; Abort[]];
    profiles];

  $CombProfile = With[{e = Environment["COMB_PROFILE"]},
    If[StringQ[e] && StringLength[StringTrim[e]] > 0, StringTrim[e], None]];

  $CombProfileData = If[$CombProfile === None, None,
    With[{all = combLoadProfiles[]},
      If[!KeyExistsQ[all, $CombProfile],
        Print["lib_config: unknown COMB_PROFILE \"", $CombProfile,
          "\"; known: ", StringRiffle[Keys[all], ", "]];
        Abort[]];
      Print["lib_config: profile ", $CombProfile];
      all[$CombProfile]]];

  combProfileData[key_String] := If[$CombProfile === None,
    Missing["NoProfile"],
    Lookup[$CombProfileData, key, Missing["NotInProfile", key]]];

  combParseCells[s_String] := Module[{pairs},
    pairs = StringSplit[StringTrim[s], ";"];
    pairs = StringSplit[#, ","] & /@ pairs;
    ToExpression /@ # & /@ pairs];
  combParseList[s_String] := StringTrim /@ StringSplit[StringTrim[s], ","];

  combParseEnv["string", s_]   := s;
  combParseEnv["expr", s_]     := ToExpression[s];
  combParseEnv["cells", s_]    := combParseCells[s];
  combParseEnv["list", s_]     := combParseList[s];
  combParseEnv["intList", s_]  := ToExpression /@ combParseList[s];
  combParseEnv["flag", s_]     := s === "1";
  combParseEnv["notFalse", s_] := ToLowerCase[StringTrim[s]] =!= "false";
  combParseEnv["notZero", s_]  := s =!= "0";
  combParseEnv[kind_, _] := (
    Print["lib_config: unknown setting kind ", InputForm[kind]]; Abort[]);

  combSetting[name_String, default_] := combSetting[name, default, "string"];
  combSetting[name_String, default_, kind_String] := Module[
    {e = Environment[name], fromProfile, value, source},
    fromProfile = If[$CombProfile === None, Missing[],
      Lookup[Lookup[$CombProfileData, "settings", <||>], name, Missing[]]];
    {value, source} = Which[
      StringQ[e] && StringLength[e] > 0,
        If[!MissingQ[fromProfile],
          Print["lib_config: WARNING ", name, "=", e,
            " from the environment overrides profile ", $CombProfile,
            " (", ToString[fromProfile, InputForm], ")"]];
        {combParseEnv[kind, e], "env"},
      !MissingQ[fromProfile], {fromProfile, "profile " <> $CombProfile},
      True, {default, "default"}];
    $CombSettings[name] = <|"value" -> value, "source" -> source|>;
    value];

  combPrintSettings[] := Scan[
    Print["  ", StringPadRight[#, 22], " = ",
      ToString[$CombSettings[#]["value"], InputForm],
      "   (", $CombSettings[#]["source"], ")"] &,
    Keys[$CombSettings]]];
