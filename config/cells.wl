(* config/cells.wl
   Named run profiles (Phase 2c). Read by src/lib_config.wl when
   COMB_PROFILE (later run.wl --profile) names one; bare scripts never read
   this file.

   Each profile has:
     "settings"    COMB_* knob -> value, for scripts run once per
                   invocation (validate, compare, render, regression).
                   combSetting gives env > profile > script default.
     "truthRuns"   enumerate_truth.wl invocations: cells, pipeline, parallel
     "isBatches"   q=10 IS batches per p: {runTag, N, chunk}
                   (pure_simplicial_compute.wl via run_p{p}.wl)
     "mhChains"    run_mh_chains.wl groups. "fanOut" -> "target" runs one
                   process per target (the (4,5) launcher); "tag" is
                   COMB_MH_TAG, "initNumV" COMB_MH_INITNUMV
     "ecgravRuns"  run_ecgrav_samplers.wl runs, one process per target
   The run plans are data for Phase 3's run.wl; no script reads them yet.

   "paper": the settings that made the stored data, from the launchers and
   docs/architecture/provenance.md. Regenerating with it reproduces those
   runs; it does not decide which stored outputs need a rerun (provenance.md
   does).
   "quick": a few minutes end to end, for a fresh clone or a scratch
   COMB_ROOT. Its outputs use the same file names as paper outputs, so never
   run it against the shared store with COMB_FORCE=1. *)

Module[{grid9, targets3},
  grid9 = {{2, 4}, {2, 5}, {2, 6}, {2, 7}, {3, 4}, {3, 5}, {3, 6}, {4, 4}, {4, 5}};
  targets3 = {"unlabeled", "facet", "vertex"};
  <|
  "paper" -> <|
    "settings" -> <|
      "COMB_VAL_CELLS" -> grid9,
      "COMB_EFF_CELLS" -> grid9,
      "COMB_ECG_CELLS" -> grid9,
      "COMB_REG_CELLS" -> grid9,
      "COMB_3W_CELLS"  -> {{3, 5}, {4, 5}},
      "COMB_IS_CELLS"  -> {{3, 5}, {4, 5}},
      "COMB_IS_N"      -> 100000,
      "COMB_IS_CHUNK"  -> 5000,
      "COMB_IS_SEED"   -> 42|>,
    (* T1-T4. Cheap OOMs at (4,5) even sequential; (4,4) was McKay too. *)
    "truthRuns" -> {
      <|"cells" -> {{2, 4}, {2, 5}, {2, 6}, {2, 7}, {3, 4}, {3, 5}, {3, 6}},
        "pipeline" -> "cheap", "parallel" -> True|>,
      <|"cells" -> {{4, 4}, {4, 5}}, "pipeline" -> "mckay", "parallel" -> False|>},
    (* I1-I3: batch3 has no p=2. Merged by concat_samples.wl. *)
    "isBatches" -> <|
      2 -> {{"", 500000, 25000}, {"batch2", 1500000, 25000}},
      3 -> {{"", 500000, 25000}, {"batch2", 1500000, 25000},
            {"batch3", 10000000, 25000}},
      4 -> {{"", 500000, 25000}, {"batch2", 1500000, 25000},
            {"batch3", 10000000, 25000}}|>,
    "mhChains" -> {
      (* M2/M5 and the missing (2,7) (3,6) (4,4); vertex reruns per provenance.md *)
      <|"cells" -> DeleteCases[grid9, {4, 5}], "targets" -> targets3,
        "numIter" -> 200000, "burnIn" -> 20000, "thin" -> 5, "seed" -> 12345,
        "kernel" -> "global"|>,
      <|"cells" -> {{4, 5}}, "targets" -> targets3, "fanOut" -> "target",
        "numIter" -> 200000, "burnIn" -> 20000, "thin" -> 5, "seed" -> 12345,
        "kernel" -> "global"|>,
      (* M6 q=10 pilot, kept where no production chain replaced it *)
      <|"cells" -> {{2, 10}}, "targets" -> targets3,
        "numIter" -> 10000, "burnIn" -> 1000, "thin" -> 2, "seed" -> 12345,
        "kernel" -> "global"|>,
      <|"cells" -> {{3, 10}, {4, 10}}, "targets" -> {"vertex"},
        "numIter" -> 10000, "burnIn" -> 1000, "thin" -> 2, "seed" -> 12345,
        "kernel" -> "global"|>,
      (* M8/M9 q=10 production *)
      <|"cells" -> {{3, 10}, {4, 10}}, "targets" -> {"unlabeled", "facet"},
        "fanOut" -> "target",
        "numIter" -> 200000, "burnIn" -> 20000, "thin" -> 5, "seed" -> 12345,
        "kernel" -> "global"|>,
      (* M10 warm starts, second seed *)
      Sequence @@ Flatten[Table[
        <|"cells" -> {{p, 10}}, "targets" -> {t}, "fanOut" -> "target",
          "numIter" -> 1000000, "burnIn" -> 50000, "thin" -> 20,
          "seed" -> 67890, "kernel" -> "global",
          "initNumV" -> If[p == 3, 14, 18],
          "tag" -> "_seed67890_warm" <> ToString[If[p == 3, 14, 18]]|>,
        {p, {3, 4}}, {t, {"unlabeled", "facet"}}]]},
    (* E1-E3 *)
    "ecgravRuns" -> {
      <|"sampler" -> "exact", "cells" -> grid9, "targets" -> targets3,
        "n" -> 100000, "batch" -> 2000, "seed" -> 24680|>,
      <|"sampler" -> "mcmc", "cells" -> grid9, "targets" -> targets3,
        "n" -> 20000, "traceSteps" -> 200000, "seed" -> 24680|>,
      <|"sampler" -> "legacyfacet", "cells" -> {{2, 4}, {3, 4}},
        "targets" -> {"facet"}, "n" -> 20000, "seed" -> 24680|>}|>,

  "quick" -> <|
    "settings" -> <|
      "COMB_VAL_CELLS" -> {{2, 4}, {3, 4}},
      "COMB_EFF_CELLS" -> {{2, 4}, {3, 4}},
      "COMB_ECG_CELLS" -> {{2, 4}, {3, 4}},
      "COMB_ECG_N"     -> 5000,
      "COMB_REG_CELLS" -> {{2, 4}, {3, 4}},
      "COMB_REG_N"     -> 5000,
      "COMB_3W_CELLS"  -> {{2, 4}, {3, 4}},
      "COMB_IS_CELLS"  -> {{2, 4}, {3, 4}},
      "COMB_IS_N"      -> 2000,
      "COMB_IS_CHUNK"  -> 1000,
      "COMB_IS_SEED"   -> 42,
      "COMB_CMP_PS"    -> {2}|>,
    "truthRuns" -> {
      <|"cells" -> {{2, 4}, {3, 4}}, "pipeline" -> "cheap", "parallel" -> True|>},
    "isBatches" -> <|
      2 -> {{"quick", 2000, 1000}},
      3 -> {{"quick", 2000, 1000}},
      4 -> {{"quick", 2000, 1000}}|>,
    "mhChains" -> {
      <|"cells" -> {{2, 4}, {3, 4}}, "targets" -> targets3,
        "numIter" -> 20000, "burnIn" -> 2000, "thin" -> 5, "seed" -> 12345,
        "kernel" -> "global"|>},
    "ecgravRuns" -> {
      <|"sampler" -> "exact", "cells" -> {{2, 4}, {3, 4}}, "targets" -> targets3,
        "n" -> 5000, "batch" -> 1000, "seed" -> 24680|>,
      <|"sampler" -> "mcmc", "cells" -> {{2, 4}, {3, 4}}, "targets" -> targets3,
        "n" -> 2000, "traceSteps" -> 20000, "seed" -> 24680|>}|>
  |>]
