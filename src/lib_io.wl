(* lib_io.wl
   Output-file helpers shared by the drivers (Phase 2a), plus one sidecar
   manifest per output (Phase 2d).

   Loads comb_paths.wl if needed. Idempotent.

   Defines:
     exportWxfAtomic[path, expr]          write WXF to path.tmp, then rename
     exportWxfAtomic[path, expr, extra]   over path, so a crash never leaves
                                          a partial file under the final
                                          name, then write its manifest.
                                          Aborts if the WXF is not written.
       extra: Association merged into the manifest (seed, inputs, ...), or
       None for no manifest (temporary files such as IS chunks).
     combWriteManifest[path, extra]       write path's manifest on its own
     combManifestFile[path]               path <> ".manifest.wl"
     combManifest[path]                   the manifest Association, or
                                          Missing["NoManifest"]

   A manifest is <file>.manifest.wl next to the output, written atomically,
   one per output (several processes and worktrees write at once, so there
   is no shared index). Keys (manifestVersion 1):
     file, bytes, sha256, writtenAt (ISO), backfilled (False),
     script, codeRoot, codeCommit, codeDirty,
     ecgravCommit, ecgravVersion, ecgravDir,
     wolframVersion, systemID, kernelCount, sessionSec (kernel session
     time when the output was written),
     profile, settings (name -> value), settingSources (name -> source),
     plus the extra keys (seed, inputs, ...).
   Settings are every combSetting resolved so far in this kernel
   (lib_config.wl); empty when lib_config is not loaded.
   A manifest written by tools/dev/backfill_manifest.wl has backfilled ->
   <|...|> and Missing["Unknown"] for what nobody recorded. *)

If[!ValueQ[$CombRoot],
  Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]]];

combManifestFile[path_String] := path <> ".manifest.wl";

combManifest[path_String] := With[{m = combManifestFile[path]},
  If[FileExistsQ[m], Get[m], Missing["NoManifest"]]];

(* Code version of the checkout running this script: git HEAD and whether
   tracked files are modified, else a VERSION file, else unknown. Cached. *)
combCodeVersion[] := combCodeVersion[] = Module[{head, dirty, vfile},
  head = Quiet @ RunProcess[{"git", "-C", $CombCodeRoot, "rev-parse", "HEAD"}];
  If[AssociationQ[head] && head["ExitCode"] === 0,
    dirty = Quiet @ RunProcess[{"git", "-C", $CombCodeRoot, "status",
      "--porcelain", "--untracked-files=no"}];
    <|"codeCommit" -> StringTrim[head["StandardOutput"]],
      "codeDirty" -> If[AssociationQ[dirty] && dirty["ExitCode"] === 0,
        StringTrim[dirty["StandardOutput"]] =!= "", Missing["Unknown"]]|>,
    vfile = FileNameJoin[{$CombCodeRoot, "VERSION"}];
    <|"codeCommit" -> If[FileExistsQ[vfile],
        "VERSION " <> StringTrim[ReadString[vfile]], Missing["Unknown"]],
      "codeDirty" -> Missing["Unknown"]|>]];

combScriptName[] := Which[
  ListQ[$ScriptCommandLine] && Length[$ScriptCommandLine] > 0 &&
    StringQ[First[$ScriptCommandLine]] && First[$ScriptCommandLine] =!= "",
    First[$ScriptCommandLine],
  StringQ[$InputFileName] && $InputFileName =!= "", $InputFileName,
  True, Missing["Unknown"]];

combWriteManifest[path_String] := combWriteManifest[path, <||>];
combWriteManifest[path_String, extra_Association] := Module[
  {settings, m, out, tmp},
  settings = If[ValueQ[$CombSettings] && AssociationQ[$CombSettings],
    $CombSettings, <||>];
  m = Join[<|
    "manifestVersion" -> 1,
    "file" -> FileNameTake[path],
    "bytes" -> FileByteCount[path],
    "sha256" -> FileHash[path, "SHA256", All, "HexString"],
    "writtenAt" -> DateString["ISODateTime"],
    "backfilled" -> False,
    "script" -> combScriptName[],
    "codeRoot" -> $CombCodeRoot|>,
    combCodeVersion[],
    <|"ecgravCommit"  -> If[ValueQ[$CombECGravCommit], $CombECGravCommit, Missing["NotLoaded"]],
      "ecgravVersion" -> If[ValueQ[$CombECGravVersion], $CombECGravVersion, Missing["NotLoaded"]],
      "ecgravDir"     -> If[ValueQ[$CombECGravDir], $CombECGravDir, Missing["NotLoaded"]],
      "wolframVersion" -> $Version,
      "systemID" -> $SystemID,
      (* Kernels[] would load the parallel subsystem in scripts that never
         use it; those ran on no subkernels. *)
      "kernelCount" -> If[MemberQ[$Packages, "Parallel`"], Length[Kernels[]], 0],
      "sessionSec" -> SessionTime[],
      "profile" -> If[ValueQ[$CombProfile], $CombProfile, None],
      "settings" -> settings[[All, "value"]],
      "settingSources" -> settings[[All, "source"]]|>,
    extra];
  out = combManifestFile[path];
  tmp = out <> ".tmp";
  If[FileExistsQ[tmp], DeleteFile[tmp]];
  Put[m, tmp];
  If[FileExistsQ[out], DeleteFile[out]];
  If[RenameFile[tmp, out] === $Failed,
    (* The output itself is fine; say so loudly and carry on, so a long
       run does not lose its remaining cells over a manifest. *)
    Print["    WARNING: manifest not written for ", path]];
  out];

exportWxfAtomic[path_String, expr_] := exportWxfAtomic[path, expr, <||>];
exportWxfAtomic[path_String, expr_, extra : (_Association | None)] :=
  Module[{tmp, res},
    tmp = path <> ".tmp";
    If[FileExistsQ[tmp], DeleteFile[tmp]];
    Export[tmp, expr, "WXF"];
    If[! FileExistsQ[tmp],
      Print["    ERROR: tmp file not written: ", tmp]; Abort[]];
    If[FileExistsQ[path], DeleteFile[path]];
    res = RenameFile[tmp, path];
    If[res === $Failed,
      Print["    ERROR: rename failed ", tmp, " -> ", path]; Abort[]];
    If[extra =!= None, combWriteManifest[path, extra]];
    path];
