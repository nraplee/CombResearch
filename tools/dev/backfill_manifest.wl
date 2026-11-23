(* backfill_manifest.wl
   Writes a manifest (see pipeline/common/io.wl) for every existing output in the
   data store that has none, from the metadata embedded in the file and the
   provenance table in docs/architecture/provenance.md (Phase 2d).

     wolframscript -file tools\dev\backfill_manifest.wl            dry run
     wolframscript -file tools\dev\backfill_manifest.wl write      write
     ... write force    also replace earlier backfilled manifests
   (Plain words: wolframscript drops every argument from the first one that
   starts with "-".)

   Dry run is the default: it prints, per file, the provenance row, status,
   ECGrav and what it would do, and writes nothing.
   A manifest written by a real run (backfilled -> False) is never replaced,
   even with force.

   The store is $CombDataDir (COMB_ROOT respected), including
   q10_pilot_archive/; folders starting with "_" (_from_worktrees/, _superseded/) are skipped. Files up to 300 MB are
   imported to read their small metadata keys; larger ones (q=10 merged and
   batch3) and non-WXF files (CSV, Betre .mx) get provenance only.

   Backfilled manifest = the lib_io keys, with Missing["Unknown"] where
   nothing was recorded, plus:
     backfilled  <|at, tool, toolCommit, provenanceId|>
     provenance  the provenance row: family, madeBy, date, ecgrav,
                 ecgravSource ("embedded" | "inferred"), settings, status,
                 note
     embedded    the file's small top-level keys (createdAt, seed, numIter,
                 samplerVersion, ...), or Missing["NotRead", reason]
   status: "ok", "knownBad" (pre-fix vertex chains), "smoke" (short
   chains), "negativeControl", "usesKnownBad" (derived from knownBad
   inputs), "external" (Betre). Phase 3 reads it for the stale report. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName], 2], "pipeline", "common",
  "io.wl"}]];

$args = If[ListQ[$ScriptCommandLine], Rest[$ScriptCommandLine], {}];
$write = MemberQ[$args, "write"];
$force = MemberQ[$args, "force"];
$maxImportBytes = 300*10^6;

(* ----- provenance table (docs/architecture/provenance.md, 2026-11-20) -----
   First match wins, so specific rows come before general ones. *)
cellRe[ps_, qs_] := "p[" <> ps <> "]q(" <> qs <> ")";
row[id_, re_, fields_Association] := <|"id" -> id,
  "re" -> RegularExpression["^" <> re <> "$"]|> ~Join~ fields;
likely100 = <|"ecgrav" -> "1.0.0 (likely; global paclet)", "ecgravSource" -> "inferred"|>;

$provenance = {
  row["M3", cellRe["2", "4|5|6"] <> "_mh_vertex\\.wxf|p3q(4|5)_mh_vertex\\.wxf",
    <|"family" -> "MH vertex, pre-fix", "madeBy" -> "run_mh_chains.wl @9468fff",
      "date" -> "2026-05-05/06", "settings" -> "seed 12345; 200k/20k/5 ((2,4) 30k/3k/5)",
      "status" -> "knownBad",
      "note" -> "vertex piRatio = 1 bug; acceptRate 1.0; L1 vs truth 0.68-0.85. Rerun."|> ~Join~ likely100],
  row["M4", "p3q5_mh_vertex\\.2026-05-17\\.wxf\\.bak",
    <|"family" -> "MH (3,5) vertex, post-fix", "madeBy" -> "run_mh_chains.wl @7143104 + uncommitted fix",
      "date" -> "2026-05-14", "settings" -> "seed 12345; 200k; accept 0.576",
      "status" -> "ok", "note" -> "the good (3,5) vertex chain; the live file is M3"|> ~Join~ likely100],
  row["M1", "p2q4_mh_(unlabeled|facet)\\.wxf",
    <|"family" -> "MH smoke (2,4)", "madeBy" -> "run_mh_chains.wl @9468fff",
      "date" -> "2026-05-05", "settings" -> "seed 12345; 30k/3k/thin 5",
      "status" -> "smoke", "note" -> "smoke budget, not 200k"|> ~Join~ likely100],
  row["M2", cellRe["23", "4|5|6"] <> "_mh_(unlabeled|facet)\\.wxf",
    <|"family" -> "MH (2,5)(2,6)(3,4)(3,5)", "madeBy" -> "run_mh_chains.wl @9468fff (several manual runs)",
      "date" -> "2026-05-06", "settings" -> "seed 12345; 200k/20k/5",
      "status" -> "ok", "note" -> ""|> ~Join~ likely100],
  row["M5", "p4q5_mh_(vertex|unlabeled|facet)\\.wxf",
    <|"family" -> "MH (4,5)", "madeBy" -> "run_p4q5_mh_parallel.ps1 @7143104 + fix",
      "date" -> "2026-05-15", "settings" -> "seed 12345; 200k/20k/5",
      "status" -> "ok", "note" -> "vertex is post-fix"|> ~Join~ likely100],
  row["M10", "p[34]q10_mh_(unlabeled|facet)_seed67890_warm(14|18)\\.wxf",
    <|"family" -> "MH q=10 warm, 2nd seed", "madeBy" -> "run_q10_mh_overnight.ps1 @8d10379",
      "date" -> "2026-05-18", "settings" -> "seed 67890; 1M/50k/20",
      "status" -> "ok", "note" -> "initNumV requested 14/18, actual 11/17 (only the requested value is stored)"|> ~Join~ likely100],
  row["M9", "p4q10_mh_unlabeled\\.wxf",
    <|"family" -> "MH q=10 (4,10) unlabeled", "madeBy" -> "run_q10_mh_overnight.ps1 restore step @8d10379",
      "date" -> "2026-05-18", "settings" -> "seed 12345; 200k/20k/5",
      "status" -> "ok", "note" -> "same chain as the 05-17 original (identical deltaNumVCounts)"|> ~Join~ likely100],
  row["M8", "p3q10_mh_(unlabeled|facet)\\.wxf|p4q10_mh_facet\\.wxf",
    <|"family" -> "MH q=10 production", "madeBy" -> "run_q10_mh_parallel.ps1 @955238d",
      "date" -> "2026-05-17", "settings" -> "seed 12345; 200k/20k/5",
      "status" -> "ok", "note" -> ""|> ~Join~ likely100],
  row["M6", "p2q10_mh_(vertex|unlabeled|facet)\\.wxf|p[34]q10_mh_vertex\\.wxf",
    <|"family" -> "MH q=10 pilot", "madeBy" -> "run_q10_mh_pilot.ps1 @955238d",
      "date" -> "2026-05-17", "settings" -> "seed 12345; 10k/1k/thin 2",
      "status" -> "smoke", "note" -> "pilot budget"|> ~Join~ likely100],
  row["M7", "q10_pilot_archive/p[34]q10_mh_(unlabeled|facet)_pilot10k\\.wxf",
    <|"family" -> "MH q=10 pilot archive", "madeBy" -> "copies of M6, saved by hand",
      "date" -> "2026-05-17", "settings" -> "seed 12345; 10k/1k/thin 2",
      "status" -> "smoke", "note" -> "superseded by M8"|> ~Join~ likely100],
  row["T1", "p2q(4|5|6)_truth\\.wxf|p3q(4|5)_truth\\.wxf",
    <|"family" -> "truth, small grid", "madeBy" -> "enumerate_truth.wl cheap, Parallel, @9468fff",
      "date" -> "2026-05-05", "settings" -> "deterministic",
      "status" -> "ok", "note" -> "stored ecGravVersion \"1.0.0\" is a hardcoded label; aut/autF re-verified on latest ECGrav 2026-11-20"|> ~Join~ likely100],
  row["T2", "p2q7_truth\\.wxf|p3q6_truth\\.wxf",
    <|"family" -> "truth, (2,7) (3,6)", "madeBy" -> "enumerate_truth.wl cheap, Parallel, @63c90a5",
      "date" -> "2026-05-08/09", "settings" -> "deterministic",
      "status" -> "ok", "note" -> "no log; (3,6) took 17.2 h; aut/autF re-verified 2026-11-20"|> ~Join~ likely100],
  row["T3", "p4q4_truth(_mckay)?\\.wxf",
    <|"family" -> "truth, (4,4)", "madeBy" -> "enumerate_truth.wl McKay, sequential, @955238d + uncommitted Phase 5a",
      "date" -> "2026-09-25", "settings" -> "deterministic",
      "ecgrav" -> "1.0.0 or 1.17.0 (both installed that day)", "ecgravSource" -> "inferred",
      "status" -> "ok", "note" -> "_truth and _truth_mckay are byte-identical; aut/autF re-verified 2026-11-20"|>],
  row["T4", "p4q5_truth\\.wxf",
    <|"family" -> "truth, (4,5)", "madeBy" -> "enumerate_truth.wl McKay, sequential, @7143104 + uncommitted Phase 4b",
      "date" -> "2026-05-13/14", "settings" -> "deterministic; 17.1 h, 7.9 GB peak",
      "status" -> "ok", "note" -> "renamed from _truth_mckay; aut/autF re-verified 2026-11-20"|> ~Join~ likely100],
  row["I1", "p[234]q10_n500000_(samples\\.csv|stats\\.wxf)",
    <|"family" -> "q=10 IS batch 1", "madeBy" -> "pure_simplicial_compute_overnight.wl, pre-git, serial; stats WXF migrated from CSV @e671bda",
      "date" -> "2026-04-21/22", "settings" -> "SeedRandom[123456+1000p+k], k=1..20; N=500k, chunk 25k",
      "status" -> "ok", "note" -> "migrated rows have Real weights and Real aut at p=4"|> ~Join~ likely100],
  row["I2", "p[234]q10_n1500000_batch2_(samples\\.csv|stats\\.wxf)",
    <|"family" -> "q=10 IS batch2", "madeBy" -> "run_parallel.ps1 -> run_p{p}.wl @965d1ed, 3 processes x 8 kernels",
      "date" -> "2026-04-23", "settings" -> "offset Mod[Hash[\"batch2\",\"MD5\"],10^7] = 2264134; N=1.5M, chunk 25k",
      "status" -> "ok", "note" -> "relaunched after a licence-error crash"|> ~Join~ likely100],
  row["I3", "p[34]q10_n10000000_batch3_(stats|complexes)\\.wxf",
    <|"family" -> "q=10 IS batch3", "madeBy" -> "run_parallel.ps1 @e671bda (p list 3,4)",
      "date" -> "2026-04-23 to 04-27", "settings" -> "offset 6102964; N=10M, chunk 25k",
      "status" -> "ok", "note" -> "no p=2"|> ~Join~ likely100],
  row["I4", "p[234]q10_merged_stats\\.wxf",
    <|"family" -> "q=10 IS merged", "madeBy" -> "concat_samples.wl ~c33b664",
      "date" -> "2026-04-27", "settings" -> "rows in order batch3, batch2, n500000",
      "ecgrav" -> "-", "ecgravSource" -> "inferred",
      "status" -> "ok", "note" -> "mixed row types (Real vs Rational weights)"|>],
  row["I5", "p[234]q10_is_(vertex|unlabeled|facet)_numv_hist\\.wxf",
    <|"family" -> "q=10 IS numV hists", "madeBy" -> "precompute_is_histograms_q10.wl",
      "date" -> "<= 2026-05-17", "settings" -> "from I4",
      "ecgrav" -> "-", "ecgravSource" -> "inferred",
      "status" -> "ok", "note" -> "facet/unlabeled ESS collapse, see docs/sampling.md"|>],
  row["I6", "p[34]q5_is_(vertex|unlabeled|facet)_numv_hist\\.wxf",
    <|"family" -> "IS hists at (3,5) (4,5)", "madeBy" -> "run_is_at_truth_cells.wl @9700ca9 (May version)",
      "date" -> "<= 2026-05-17", "settings" -> "seed 42; N=100k; chunk 5000 assumed",
      "status" -> "ok", "note" -> "no log"|> ~Join~ likely100],
  row["E1", cellRe["234", "\\d+"] <> "_ecgexact_(vertex|unlabeled|facet)\\.wxf",
    <|"family" -> "ECGrav exact", "madeBy" -> "run_ecgrav_samplers.wl (draft before 5118c14) via run_ecgrav_campaign.ps1",
      "date" -> "2026-09-25/26", "settings" -> "seed 24680; N=100k, batch 2000",
      "ecgrav" -> "1.17.0 (vendored, upstream d15739c)", "ecgravSource" -> "embedded",
      "status" -> "ok", "note" -> "rerun on latest ECGrav for consistent provenance"|>],
  row["E2", cellRe["234", "\\d+"] <> "_ecgmcmc_(vertex|unlabeled|facet)\\.wxf",
    <|"family" -> "ECGrav MCMC", "madeBy" -> "run_ecgrav_samplers.wl ~5118c14",
      "date" -> "2026-09-26", "settings" -> "seed 24680; N=20k; trace 200k steps",
      "ecgrav" -> "1.17.0 (vendored, upstream d15739c)", "ecgravSource" -> "embedded",
      "status" -> "ok", "note" -> "old equilibration start rule (fixed upstream 87f2d5d); rerun first"|>],
  row["E3", cellRe["23", "4"] <> "_ecglegacyfacet_facet\\.wxf",
    <|"family" -> "ECGrav legacy facet", "madeBy" -> "run_ecgrav_samplers.wl, by hand",
      "date" -> "2026-09-25", "settings" -> "seed 24680; N=20k",
      "ecgrav" -> "1.17.0 (vendored, upstream d15739c)", "ecgravSource" -> "embedded",
      "status" -> "negativeControl", "note" -> "RandomFacetLabeledPureSimplicialComplex is non-uniform"|>],
  row["S1", "validation_(ecgexact|ecgmcmc|ecglegacyfacet)_summary\\.wxf",
    <|"family" -> "validation summaries", "madeBy" -> "validate_mh_vs_truth.wl ~5118c14",
      "date" -> "2026-09-25/26", "settings" -> "inputs E1-E3",
      "ecgrav" -> "1.17.0 (inputs)", "ecgravSource" -> "inferred",
      "status" -> "ok", "note" -> "no log"|>],
  row["S2", "sampler_efficiency_summary\\.wxf",
    <|"family" -> "sampler efficiency", "madeBy" -> "compare_samplers_efficiency.wl ~5118c14",
      "date" -> "2026-09-26", "settings" -> "9 truth cells",
      "ecgrav" -> "1.17.0", "ecgravSource" -> "embedded",
      "status" -> "usesKnownBad", "note" -> "its MH vertex rows used the pre-fix M3 chains"|>],
  row["S3", "is_mh_truth_3way_summary\\.wxf",
    <|"family" -> "3-way at q=5", "madeBy" -> "compare_3way.wl (May; committed in 9700ca9)",
      "date" -> "2026-05-17", "settings" -> "",
      "ecgrav" -> "-", "ecgravSource" -> "inferred",
      "status" -> "ok", "note" -> "used M4, the good (3,5) vertex chain; a rerun on the live files reads M3"|>],
  row["S4", "q10_is_vs_mh_summary\\.wxf",
    <|"family" -> "q=10 IS vs MH", "madeBy" -> "compare_is_mh_q10.wl",
      "date" -> "2026-05-17", "settings" -> "",
      "ecgrav" -> "-", "ecgravSource" -> "inferred",
      "status" -> "ok", "note" -> "read the original (4,10) unlabeled chain; M9 reproduces it"|>],
  row["S5", "q10_warm_vs_prod_summary\\.wxf",
    <|"family" -> "q=10 warm vs prod", "madeBy" -> "compare_q10_warm_vs_prod.wl",
      "date" -> "2026-05-18", "settings" -> "inputs M8-M10",
      "ecgrav" -> "-", "ecgravSource" -> "inferred",
      "status" -> "ok", "note" -> ""|>],
  row["B1", "p4q[45]SX(FacetLabeled|Unlabeled)\\.mx",
    <|"family" -> "Betre .mx", "madeBy" -> "Dr. Betre; git 28f97f0",
      "date" -> "received 2026-05-15", "settings" -> "",
      "ecgrav" -> "unknown", "ecgravSource" -> "inferred",
      "status" -> "external", "note" -> "MacOSX-ARM64 dumps, unreadable on Windows; git-tracked"|>]};

provenanceFor[rel_String] := SelectFirst[$provenance, StringMatchQ[rel, #["re"]] &, Missing["NoRow"]];

(* ----- store walk ----- *)
storeFiles[] := Module[{all},
  all = Select[FileNames["*", $CombDataDir, Infinity], !DirectoryQ[#] &];
  Select[all, With[{rel = StringReplace[
        StringDrop[#, StringLength[$CombDataDir] + 1], "\\" -> "/"]},
      !StringStartsQ[rel, "_"] &&   (* _from_worktrees/, _superseded/: copies, not outputs *)
      !StringEndsQ[rel, ".manifest.wl" | ".tmp"]] &]];
relName[f_] := StringReplace[StringDrop[f, StringLength[$CombDataDir] + 1], "\\" -> "/"];

embeddedOf[f_String] := Which[
  !StringMatchQ[f, ___ ~~ (".wxf" | ".wxf.bak")], Missing["NotRead", "not a WXF"],
  FileByteCount[f] > $maxImportBytes, Missing["NotRead", "larger than 300 MB"],
  True, With[{x = Quiet @ Import[f, "WXF"]},
    If[AssociationQ[x], Select[x, ByteCount[#] < 2000 &],
      Missing["NotRead", "not an Association"]]]];

firstKnown[vals__] := SelectFirst[{vals}, !MissingQ[#] &, Missing["Unknown"]];
codeCommitFrom[emb_] := If[AssociationQ[emb],
  firstKnown[Lookup[emb, "samplerVersion", Missing[]], Lookup[emb, "enumeratorVersion", Missing[]]],
  Missing["Unknown"]];

backfillManifest[f_String, prov_Association] := Module[{emb, unk = Missing["Unknown"]},
  emb = embeddedOf[f];
  <|"manifestVersion" -> 1,
    "file" -> FileNameTake[f],
    "bytes" -> FileByteCount[f],
    "sha256" -> FileHash[f, "SHA256", All, "HexString"],
    "writtenAt" -> unk,
    "backfilled" -> <|"at" -> DateString["ISODateTime"],
      "tool" -> "tools/dev/backfill_manifest.wl",
      "toolCommit" -> combCodeVersion[]["codeCommit"],
      "provenanceId" -> prov["id"]|>,
    "script" -> prov["madeBy"],
    "codeRoot" -> unk,
    "codeCommit" -> codeCommitFrom[emb],
    "codeDirty" -> unk,
    "ecgravCommit" -> unk,
    "ecgravVersion" -> If[AssociationQ[emb] && StringQ[Lookup[emb, "ecGravVersion", Missing[]]] &&
        prov["ecgravSource"] === "embedded", emb["ecGravVersion"], prov["ecgrav"]],
    "ecgravDir" -> unk,
    "wolframVersion" -> unk, "systemID" -> unk, "kernelCount" -> unk, "sessionSec" -> unk,
    "profile" -> unk, "settings" -> <||>, "settingSources" -> <||>,
    "seed" -> If[AssociationQ[emb], Lookup[emb, "seed", unk], unk],
    "createdAt" -> If[AssociationQ[emb], Lookup[emb, "createdAt", unk], unk],
    "provenance" -> KeyDrop[prov, {"id", "re"}],
    "embedded" -> emb|>];

(* ----- main ----- *)
Print["backfill_manifest: store ", $CombDataDir, If[$write, "  (WRITE", "  (dry run"],
  If[$force, ", force)", ")"]];
files = storeFiles[];
counts = <|"write" -> 0, "exists" -> 0, "real" -> 0, "noRow" -> 0|>;
noRow = {};
Do[
  Module[{rel = relName[f], prov, existing, action},
    prov = provenanceFor[rel];
    existing = combManifest[f];
    action = Which[
      MissingQ[prov], "noRow",
      AssociationQ[existing] && existing["backfilled"] === False, "real",
      AssociationQ[existing] && !$force, "exists",
      True, "write"];
    counts[action]++;
    If[action === "noRow", AppendTo[noRow, rel]];
    If[action =!= "noRow",
      Print["  ", StringPadRight[rel, 46], StringPadRight[prov["id"], 5],
        StringPadRight[prov["status"], 16], StringPadRight[action, 7],
        prov["ecgrav"]]];
    If[action === "write" && $write,
      Module[{m = backfillManifest[f, prov], out = combManifestFile[f], tmp},
        tmp = out <> ".tmp";
        If[FileExistsQ[tmp], DeleteFile[tmp]];
        Put[m, tmp];
        If[FileExistsQ[out], DeleteFile[out]];
        RenameFile[tmp, out]]]],
  {f, files}];

Print[""];
Print["files: ", Length[files], "   ", If[$write, "written: ", "would write: "], counts["write"],
  "   kept (backfilled): ", counts["exists"], "   kept (real run): ", counts["real"],
  "   no provenance row: ", counts["noRow"]];
If[noRow =!= {}, Print["  no row (left alone): ", StringRiffle[noRow, ", "]]];
If[!$write, Print["dry run: nothing written. Rerun with: write"]];
