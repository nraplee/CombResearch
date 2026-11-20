(* probe_betre_mx.wl (v2)
   .mx files are Mathematica binary dumps that DEFINE symbols rather than
   return values. After Get'ing each file, snapshot Names["Global`*"]
   (or check the obvious symbol name) and inspect.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
dataDir = $CombDataDir;
files = {
  "p4q4SXFacetLabeled.mx", "p4q4SXUnlabeled.mx",
  "p4q5SXFacetLabeled.mx", "p4q5SXUnlabeled.mx"};

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_bliss.wl"}]];

(* Names before Get'ing any of Betre's files. *)
preNames = Names["Global`*"];

Do[
  Module[{path, sizeMB, postNames, newNames, sym, val, head, len, first,
          distinctKeys, t},
    path = FileNameJoin[{dataDir, f}];
    sizeMB = N[FileByteCount[path] / 2.0^20];
    Print["==================================================="];
    Print[f, "   (", Round[sizeMB, 0.1], " MB)"];
    Print["==================================================="];

    Get[path];
    postNames = Names["Global`*"];
    newNames = Complement[postNames, preNames];
    Print["  new symbols defined: ", newNames];

    Do[
      sym = Symbol["Global`" <> nm];
      val = sym;  (* the symbol itself, which is bound to the value *)
      head = Head[val];
      len = If[head === List, Length[val], "N/A"];
      Print["  symbol = ", nm];
      Print["    Head[val]    : ", head];
      Print["    Length[val]  : ", len];
      If[head === List && Length[val] > 0,
        first = val[[1]];
        Print["    val[[1]] head: ", Head[first]];
        Print["    val[[1]] :   : ",
          If[Head[first] === List && Length[first] <= 10,
            first, Short[first, 5]]]];
      (* If list-of-list-of-integer-lists, count distinct iso classes. *)
      If[head === List && Length[val] > 0,
        With[{f1 = val[[1]]},
          If[Head[f1] === List && AllTrue[f1, Head[#] === List &] &&
             AllTrue[f1, AllTrue[#, IntegerQ] &],
            Print["    -> looks like a list of complexes; computing |iso| ..."];
            {t, distinctKeys} = AbsoluteTiming[
              Length @ DeleteDuplicates[blissCanonicalKey /@ val]];
            Print["       distinct iso classes : ", distinctKeys,
                  "   (", Round[t, 0.01], "s wall-clock)"]]]],
      {nm, newNames}];
    preNames = postNames;
    Print[""];
  ],
  {f, files}];

Print["done."];
