(* lib_names.wl
   One place for the names of generated files (Phase 2). Every name it
   produces is the flat name the scripts used before Phase 2, so existing
   WXFs stay valid: no file is renamed or moved.

   Loads comb_paths.wl. Idempotent.

   combName[family, args...]   bare file name
   combFile[family, args...]   full path: combName under $CombDataDir, or
                               $CombLogsDir for "log" / "err"
   A call that matches no family aborts with a message, so a typo fails
   before a run instead of reading or writing a wrong name.

   Families (p, q, n, k integers; target, source, sampler, pipeline,
   runTag, name strings):
     "truth", p, q                     p3q5_truth.wxf
     "truth", p, q, pipeline           "cheap" -> p3q5_truth.wxf,
                                       else p3q5_truth_mckay.wxf
     "mh", p, q, target                p3q5_mh_vertex.wxf
     "mh", p, q, target, tag           tag appended as given (COMB_MH_TAG,
                                       leading "_" included); see combMHWarmTag
     "ecg", p, q, sampler, target      p3q5_ecgexact_vertex.wxf
     "samples", p, q, source, target   p3q5_{source}_{target}.wxf: source is
                                       "mh" or "ecg<sampler>" (validate / efficiency)
     "isHist", p, q, target            p4q10_is_facet_numv_hist.wxf
     "isStats", stem                   {stem}_stats.wxf
     "isComplexes", stem               {stem}_complexes.wxf
     "isChunkStats", stem, k           {stem}_chunk_{k}_stats.wxf
     "isChunkComplexes", stem, k       {stem}_chunk_{k}_complexes.wxf
     "isSamplesCSV", stem              {stem}_samples.csv (legacy)
     "validationSummary", source       validation_{source}_summary.wxf
     "summary", name                   {name}_summary.wxf
     "log" | "err", "mh", p, q, target        mh_p4q5_vertex.log
     "log" | "err", "ecg", sampler, target    ecgexact_vertex.log
     "log" | "err", "mhQ10", phase, p, target [, tag]
                                              mh_q10_prod_p4_facet.log
                                              (phase pilot | prod | overnight)
     "log" | "err", "compute", p              compute_p3.log
     "log" | "err", "compute", p, suffix      compute_p3{suffix}.log

   IS stems:
     combISStem[p, q, n]                 p4q10_n500000
     combISStem[p, q, n, nn, runTag]     nn None or an integer (adds _nn{nn}),
                                         runTag "" or a tag (adds _{runTag})
     combMergedStem[p, q]                p4q10_merged

   Other helpers:
     combMHWarmTag[seed, initNumV]       "_seed67890_warm14"
     combISStatsPattern[p, q]            "p4q10_*_stats.wxf" (FileNames glob)

   The .ps1 launchers and monitors still build their own log names; they
   match the "log" family. *)

If[!ValueQ[$CombRoot],
  Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]]];

combCell[p_Integer, q_Integer] := "p" <> ToString[p] <> "q" <> ToString[q];

combISStem[p_Integer, q_Integer, n_Integer] := combISStem[p, q, n, None, ""];
combISStem[p_Integer, q_Integer, n_Integer, nn : (None | _Integer),
    runTag_String] :=
  combCell[p, q] <> "_n" <> ToString[n] <>
  If[nn === None, "", "_nn" <> ToString[nn]] <>
  If[runTag === "", "", "_" <> runTag];

combMergedStem[p_Integer, q_Integer] := combCell[p, q] <> "_merged";

combMHWarmTag[seed_Integer, initNumV_Integer] :=
  "_seed" <> ToString[seed] <> "_warm" <> ToString[initNumV];

combISStatsPattern[p_Integer, q_Integer] := combCell[p, q] <> "_*_stats.wxf";

(* ----- data families ----- *)
combName["truth", p_Integer, q_Integer] := combCell[p, q] <> "_truth.wxf";
combName["truth", p_Integer, q_Integer, pipeline_String] :=
  combCell[p, q] <> "_truth" <>
  If[pipeline === "cheap", "", "_" <> pipeline] <> ".wxf";

combName["mh", p_Integer, q_Integer, target_String] :=
  combName["mh", p, q, target, ""];
combName["mh", p_Integer, q_Integer, target_String, tag_String] :=
  combCell[p, q] <> "_mh_" <> target <> tag <> ".wxf";

combName["ecg", p_Integer, q_Integer, sampler_String, target_String] :=
  combName["samples", p, q, "ecg" <> sampler, target];

combName["samples", p_Integer, q_Integer, source_String, target_String] :=
  combCell[p, q] <> "_" <> source <> "_" <> target <> ".wxf";

combName["isHist", p_Integer, q_Integer, target_String] :=
  combCell[p, q] <> "_is_" <> target <> "_numv_hist.wxf";

combName["isStats", stem_String]      := stem <> "_stats.wxf";
combName["isComplexes", stem_String]  := stem <> "_complexes.wxf";
combName["isChunkStats", stem_String, k_Integer] :=
  stem <> "_chunk_" <> ToString[k] <> "_stats.wxf";
combName["isChunkComplexes", stem_String, k_Integer] :=
  stem <> "_chunk_" <> ToString[k] <> "_complexes.wxf";
combName["isSamplesCSV", stem_String] := stem <> "_samples.csv";

combName["validationSummary", source_String] :=
  "validation_" <> source <> "_summary.wxf";
combName["summary", name_String] := name <> "_summary.wxf";

(* ----- logs (names used by the .ps1 launchers) ----- *)
combLogStem["mh", p_Integer, q_Integer, target_String] :=
  "mh_" <> combCell[p, q] <> "_" <> target;
combLogStem["ecg", sampler_String, target_String] :=
  "ecg" <> sampler <> "_" <> target;
combLogStem["mhQ10", phase_String, p_Integer, target_String] :=
  combLogStem["mhQ10", phase, p, target, ""];
combLogStem["mhQ10", phase_String, p_Integer, target_String, tag_String] :=
  "mh_q10_" <> phase <> "_p" <> ToString[p] <> "_" <> target <> tag;
combLogStem["compute", p_Integer] :=combLogStem["compute", p, ""];
combLogStem["compute", p_Integer, suffix_String] :=
  "compute_p" <> ToString[p] <> suffix;
combLogStem[args___] := (
  Print["lib_names: no log family matches combLogStem[",
    StringRiffle[ToString[#, InputForm] & /@ {args}, ", "], "]"];
  Abort[]);

combName["log", args__] := combLogStem[args] <> ".log";
combName["err", args__] := combLogStem[args] <> ".err";

combName[args___] := (
  Print["lib_names: no family matches combName[",
    StringRiffle[ToString[#, InputForm] & /@ {args}, ", "], "]"];
  Abort[]);

combFile[kind : ("log" | "err"), args__] :=
  FileNameJoin[{$CombLogsDir, combName[kind, args]}];
combFile[family_String, args___] :=
  FileNameJoin[{$CombDataDir, combName[family, args]}];
