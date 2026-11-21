(* lib_io.wl
   Output-file helpers shared by the drivers. Moved from
   pure_simplicial_compute.wl and enumerate_truth.wl (Phase 2), which each
   had their own copy.

   Idempotent; loads nothing.

   Defines:
     exportWxfAtomic[path, expr]  write WXF to path.tmp, then rename over
                                  path, so a crash never leaves a partial
                                  file under the final name. Aborts on
                                  failure. *)

exportWxfAtomic[path_String, expr_] := Module[{tmp, res},
  tmp = path <> ".tmp";
  If[FileExistsQ[tmp], DeleteFile[tmp]];
  Export[tmp, expr, "WXF"];
  If[! FileExistsQ[tmp],
    Print["    ERROR: tmp file not written: ", tmp]; Abort[]];
  If[FileExistsQ[path], DeleteFile[path]];
  res = RenameFile[tmp, path];
  If[res === $Failed,
    Print["    ERROR: rename failed ", tmp, " -> ", path]; Abort[]]];
