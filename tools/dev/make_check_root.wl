(* make_check_root.wl
   Build a scratch output root for checks: the data/ files that a check
   reads are made available under <dir>/data, so a check run with
   COMB_ROOT=<dir> reads real inputs and writes only into <dir>, never into
   the shared store.

   Usage:
     wolframscript -file tools\dev\make_check_root.wl <dir> <family> [<family> ...]
     wolframscript -file tools\dev\make_check_root.wl --list

   Then run the check with COMB_ROOT=<dir> (PowerShell: $env:COMB_ROOT = "<dir>").

   Source store: $CombDataDir from pipeline/common/paths.wl (the main checkout, or
   COMB_ROOT if that is set when this tool runs).

   Copy vs hard link. A hard link shares the file with the store, and a plain
   Export to an existing file rewrites it in place, which would change the
   store copy too. So files up to $copyLimitBytes are copied, and only larger
   files are hard-linked. The large files (q=10 merged stats, IS batches) are
   inputs that no check rewrites; pipeline/21_is_merge.wl is the only script that
   writes merged stats, so never run it against a check root. A hard link
   needs <dir> on the same volume as the store; if linking fails, the file is
   copied instead.

   Refuses <dir> inside the store root, and an existing <dir>/data that
   already holds a different file of the same name (re-running with the same
   families is fine: identical files are skipped).

   Families are named sets of data/ globs; see $families. "all" = every
   family. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName], 2],
  "pipeline", "common", "paths.wl"}]];

$copyLimitBytes = 300*1024^2;

$families = <|
  "truth"          -> {"p*_truth.wxf", "p*_truth_*.wxf"},
  "mh"             -> {"p*_mh_*.wxf"},
  "ecgexact"       -> {"p*_ecgexact_*.wxf"},
  "ecgmcmc"        -> {"p*_ecgmcmc_*.wxf"},
  "ecglegacyfacet" -> {"p*_ecglegacyfacet_*.wxf"},
  "ishist"         -> {"p*_is_*_numv_hist.wxf"},
  "isq10merged"    -> {"p*q10_merged_stats.wxf"},
  "isq10batches"   -> {"p*q10_n*_stats.wxf"},
  "summaries"      -> {"*_summary.wxf"},
  "mharchive"      -> {"p*_mh_*.wxf.bak", "q10_pilot_archive/*.wxf"},
  "iscsv"          -> {"p*q10_n*_samples.csv"},
  "betre"          -> {"p*SX*.mx"},
  "manifests"      -> {"*.manifest.wl", "q10_pilot_archive/*.manifest.wl"}
|>;

(* Every input of tests/golden/golden_derived.wl. *)
$families["golden"] = Flatten[Lookup[$families, {"truth", "mh", "ecgexact",
  "ecgmcmc", "ecglegacyfacet", "ishist", "isq10merged", "summaries",
  "mharchive"}]] ~Join~ {"p4q10_n500000_samples.csv"};

usage[] := (Print["usage: make_check_root.wl <dir> <family> [<family> ...]"];
  Print["families: ", StringRiffle[Append[Keys[$families], "all"], ", "]]);

sameFileQ[a_, b_] := FileByteCount[a] === FileByteCount[b] &&
  FileHash[a, "SHA256"] === FileHash[b, "SHA256"];

hardLink[src_, dst_] := Module[{r},
  r = If[$OperatingSystem === "Windows",
    RunProcess[{"cmd", "/c", "mklink", "/H", dst, src}],
    RunProcess[{"ln", src, dst}]];
  AssociationQ[r] && r["ExitCode"] === 0 && FileExistsQ[dst]];

placeFile[src_, dst_] := Which[
  FileExistsQ[dst] && sameFileQ[src, dst], "same",
  FileExistsQ[dst],
    Print["make_check_root: ", dst, " exists and differs from the store; ",
      "remove it or use a new root"]; Exit[1],
  FileByteCount[src] > $copyLimitBytes && hardLink[src, dst], "link",
  True, CopyFile[src, dst]; "copy"];

Module[{args, dir, fams, unknown, store, dataOut, files, counts},
  args = Rest[$ScriptCommandLine];
  If[args === {"--list"},
    KeyValueMap[Print[#1, ": ", StringRiffle[#2, " "]] &, $families];
    Exit[0]];
  If[Length[args] < 2, usage[]; Exit[1]];
  dir = ExpandFileName[First[args]];
  fams = Rest[args];
  If[MemberQ[fams, "all"], fams = Keys[$families]];
  unknown = Complement[fams, Keys[$families]];
  If[unknown =!= {}, Print["unknown families: ", unknown]; usage[]; Exit[1]];

  store = ExpandFileName[$CombRoot];
  If[StringStartsQ[ToLowerCase[dir] <> $PathnameSeparator,
       ToLowerCase[store] <> $PathnameSeparator],
    Print["make_check_root: refusing ", dir, ": it is inside the store root ",
      store]; Exit[1]];

  dataOut = FileNameJoin[{dir, "data"}];
  Scan[If[!DirectoryQ[#], CreateDirectory[#, CreateIntermediateDirectories -> True]] &,
    {dataOut, FileNameJoin[{dir, "figures"}], FileNameJoin[{dir, "logs"}]}];

  (* A glob may name a subfolder of data/ ("q10_pilot_archive/*.wxf");
     files keep that relative path in the check root. *)
  files = Union @ Flatten[Map[
    Function[g, With[{sub = FileNameDrop[g, -1]},
      Map[FileNameJoin[{sub, FileNameTake[#]}] &,
        FileNames[FileNameTake[g], FileNameJoin[{$CombDataDir, sub}]]]]],
    Flatten[Lookup[$families, fams]]]];
  If[files === {}, Print["make_check_root: no files matched in ", $CombDataDir];
    Exit[1]];
  Scan[With[{d = FileNameJoin[{dataOut, FileNameDrop[#, -1]}]},
      If[!DirectoryQ[d], CreateDirectory[d, CreateIntermediateDirectories -> True]]] &,
    files];
  counts = Counts[(placeFile[FileNameJoin[{$CombDataDir, #}],
    FileNameJoin[{dataOut, #}]] & /@ files)];
  Print["make_check_root: ", Length[files], " files from ", $CombDataDir,
    " -> ", dataOut, " ", Normal[counts]];
  Print["run checks with COMB_ROOT=", dir]];
