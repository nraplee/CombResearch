(* tests/golden/sections/overlay.wl
   Freezes the binned data behind every panel of src/render_truth_overlay.wl
   (default cells = the 9 truth cells, all 3 targets, 11 figures): 91 panels
   per target, 273 records. Per panel: fig, stat, filter, cell, target, mode,
   the bin spec passed to Histogram, the renormalised truth mass per bin,
   MH counts per bin and MH n (MH layer only where p{p}q{q}_mh_{target}.wxf
   exists, as in the script). For fig10 (Automatic bins) the mass is keyed
   by Round[10^6 v] (integer micro-units) and the bin edges Histogram chose
   are stored too, as integers in units of 1e-12.
   Records built from the stale pre-fix vertex MH chains carry "knownBad".
   Each record ends with "hash" = goldenHash of the rest. Renders nothing.
   Helpers: tests/golden/lib/overlay.wl. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "overlay.wl"}]];

goldenSection["overlay"] := Module[{panels, records, inputs},
  panels = ovlAllPanels[];
  records = Association[Map[
    Function[{x}, Module[{rec = ovlPanelRecord @@ x},
      ovlRecordKey[x[[1, 1]], x[[2]], x[[3]]] ->
        Append[rec, "hash" -> goldenHash[rec]]]],
    panels]];
  inputs = Join[
    ovlTruthName @@@ ovlReachableCells,
    Select[Flatten[Table[ovlMHName[c[[1]], c[[2]], t],
      {t, ovlAllTargets}, {c, ovlReachableCells}]], ovlStoreHas]];
  <|"inputs" -> inputs, "records" -> records|>];
