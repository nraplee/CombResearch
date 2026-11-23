(* manifest_test.wl
   Checks the per-output manifests (pipeline/common/io.wl) and
   tools/dev/backfill_manifest.wl (Phase 2d), in a fresh temporary
   COMB_ROOT that the test creates and deletes. Never touches the store.

   1. exportWxfAtomic writes <file>.manifest.wl: sha256 and bytes match the
      file, settings come from combSetting with their sources, extra keys
      are merged, None writes no manifest, a rewrite replaces it.
   2. backfill_manifest.wl (child process): the dry run writes nothing;
      write writes manifests for files with a provenance row, with the row
      and the embedded metadata; files with no row are left alone; a real
      manifest is never replaced, even with force; force replaces
      backfilled ones.
   Exit 0 pass, 1 fail.

     wolframscript -file tests\manifest_test.wl *)

$root = FileNameJoin[{$TemporaryDirectory, "comb_manifest_test_" <> ToString[RandomInteger[10^9]]}];
CreateDirectory[$root];
SetEnvironment["COMB_ROOT" -> $root];
SetEnvironment[# -> None] & /@ {"COMB_PROFILE", "COMB_MH_SEED", "COMB_FORCE"};
$code = ParentDirectory[DirectoryName[$InputFileName]];
Get[FileNameJoin[{$code, "pipeline", "common", "names.wl"}]];
Get[FileNameJoin[{$code, "pipeline", "common", "config.wl"}]];
Get[FileNameJoin[{$code, "pipeline", "common", "io.wl"}]];

$fail = 0;
check[label_, got_, want_] := If[got === want, Null,
  $fail++; Print["FAIL ", label, ": got ", InputForm[got], ", want ", InputForm[want]]];
sha[f_] := FileHash[f, "SHA256", All, "HexString"];

(* ----- 1. writer ----- *)
SetEnvironment["COMB_MH_SEED" -> "777"];
seed = combSetting["COMB_MH_SEED", 12345, "expr"];
iters = combSetting["COMB_MH_NUMITER", 200000, "expr"];
f1 = combFile["mh", 2, 4, "facet"];
exportWxfAtomic[f1, <|"p" -> 2, "q" -> 4, "rows" -> Range[10]|>, <|"inputs" -> {"x.wxf"}|>];
m = combManifest[f1];
check["manifest exists", AssociationQ[m], True];
check["manifest file name", FileNameTake[combManifestFile[f1]], "p2q4_mh_facet.wxf.manifest.wl"];
check["sha256", m["sha256"], sha[f1]];
check["bytes", m["bytes"], FileByteCount[f1]];
check["file", m["file"], "p2q4_mh_facet.wxf"];
check["backfilled", m["backfilled"], False];
check["settings", KeyTake[m["settings"], {"COMB_MH_SEED", "COMB_MH_NUMITER"}],
  <|"COMB_MH_SEED" -> 777, "COMB_MH_NUMITER" -> 200000|>];
check["setting sources", KeyTake[m["settingSources"], {"COMB_MH_SEED", "COMB_MH_NUMITER"}],
  <|"COMB_MH_SEED" -> "env", "COMB_MH_NUMITER" -> "default"|>];
check["extra merged", m["inputs"], {"x.wxf"}];
check["profile", m["profile"], None];
check["wolfram", m["wolframVersion"], $Version];
(* a git checkout records its sha; a zip (no git, or inside another repo)
   records VERSION or Missing["Unknown"] (Phase 7) *)
check["code commit is a sha, VERSION or unknown in a zip",
  If[Quiet @ Check[ToLowerCase[ExpandFileName[StringTrim[RunProcess[{"git", "-C", $CombCodeRoot,
        "rev-parse", "--show-toplevel"}, "StandardOutput"]]]] ===
        ToLowerCase[ExpandFileName[$CombCodeRoot]], False],
    StringQ[m["codeCommit"]] && StringMatchQ[m["codeCommit"], RegularExpression["[0-9a-f]{40}"]],
    MatchQ[m["codeCommit"], Missing["Unknown"] | _String?(StringStartsQ[#, "VERSION "] &)]],
  True];
check["required keys", Complement[{"manifestVersion", "file", "bytes", "sha256",
  "writtenAt", "backfilled", "script", "codeCommit", "codeDirty", "ecgravCommit",
  "ecgravVersion", "wolframVersion", "systemID", "kernelCount", "sessionSec",
  "profile", "settings", "settingSources"}, Keys[m]], {}];
check["no tmp left", FileExistsQ[combManifestFile[f1] <> ".tmp"] || FileExistsQ[f1 <> ".tmp"], False];

exportWxfAtomic[f1, <|"p" -> 2, "q" -> 4, "rows" -> Range[20]|>];
m2 = combManifest[f1];
check["rewrite updates sha", m2["sha256"], sha[f1]];
check["rewrite drops old extra", KeyExistsQ[m2, "inputs"], False];

f2 = combFile["isChunkStats", "p2q10_n100", 1];
exportWxfAtomic[f2, Range[5], None];
check["None: file written", FileExistsQ[f2], True];
check["None: no manifest", combManifest[f2], Missing["NoManifest"]];

(* ----- 2. backfill ----- *)
runBackfill[args___] := RunProcess[{"wolframscript", "-file",
    FileNameJoin[{$code, "tools", "dev", "backfill_manifest.wl"}], args}, All, "",
  ProcessEnvironment -> Join[Association[GetEnvironment[]], <|"COMB_ROOT" -> $root|>]];

Export[combFile["truth", 3, 5], <|"p" -> 3, "q" -> 5, "complexes" -> Range[3],
  "ecGravVersion" -> "1.0.0", "enumeratorVersion" -> "streaming_enumerator.wl@9468fff",
  "createdAt" -> "Tue 5 May 2026 21:45:17"|>, "WXF"];
Export[combFile["mh", 3, 5, "vertex"], <|"seed" -> 12345, "samplerVersion" -> "sampler_mh.wl@9468fff",
  "rows" -> Range[100]|>, "WXF"];
Export[FileNameJoin[{$CombDataDir, "unrelated_thing.wxf"}], <|"a" -> 1|>, "WXF"];
truthF = combFile["truth", 3, 5]; vertexF = combFile["mh", 3, 5, "vertex"];

r = runBackfill[];
check["dry run exit", r["ExitCode"], 0];
check["dry run writes nothing", combManifest[truthF], Missing["NoManifest"]];
check["dry run reports", StringContainsQ[r["StandardOutput"], "would write: 2"], True];

r = runBackfill["write"];
check["write exit", r["ExitCode"], 0];
mt = combManifest[truthF]; mv = combManifest[vertexF];
check["truth backfilled", AssociationQ[mt] && AssociationQ[mt["backfilled"]], True];
check["truth row", mt["backfilled"]["provenanceId"], "T1"];
check["truth sha", mt["sha256"], sha[truthF]];
check["truth code commit from embedded", mt["codeCommit"], "streaming_enumerator.wl@9468fff"];
check["truth createdAt", mt["createdAt"], "Tue 5 May 2026 21:45:17"];
check["truth embedded keeps small keys only",
  {KeyExistsQ[mt["embedded"], "p"], KeyExistsQ[mt["embedded"], "ecGravVersion"]}, {True, True}];
check["truth ecgrav inferred", mt["ecgravVersion"], "1.0.0 (likely; global paclet)"];
check["vertex chain flagged", {mv["backfilled"]["provenanceId"], mv["provenance"]["status"]},
  {"M3", "knownBad"}];
check["vertex seed", mv["seed"], 12345];
check["no row left alone", combManifest[FileNameJoin[{$CombDataDir, "unrelated_thing.wxf"}]],
  Missing["NoManifest"]];
check["real manifest kept", combManifest[f1]["backfilled"], False];
check["manifest has no manifest", FileExistsQ[combManifestFile[combManifestFile[f1]]], False];

before = combManifest[truthF]["backfilled"]["at"];
Pause[1.1];
r = runBackfill["write"];
check["second write keeps backfilled", combManifest[truthF]["backfilled"]["at"], before];
r = runBackfill["write", "force"];
check["force replaces backfilled", combManifest[truthF]["backfilled"]["at"] =!= before, True];
check["force keeps real", combManifest[f1]["backfilled"], False];

DeleteDirectory[$root, DeleteContents -> True];
If[$fail == 0, Print["PASS"]; Exit[0], Print["FAILED: ", $fail]; Exit[1]];
