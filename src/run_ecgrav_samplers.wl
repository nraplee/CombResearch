(* run_ecgrav_samplers.wl -- SHIM (Phase 4 row 4, 2026-11-22).
   The ECGrav sampler driver moved to pipeline/40_ecgrav.wl (same knobs
   COMB_ECG_*, same defaults, same output names; header there). This file
   runs it in the same kernel, so run_ecgrav_campaign.ps1 and bare runs
   behave as before. Deleted in Phase 5. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "40_ecgrav.wl"}]];
