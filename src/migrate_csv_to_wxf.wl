(* migrate_csv_to_wxf.wl
   One-shot migration: for every legacy ..._samples.csv in data/, write the
   equivalent ..._stats.wxf. Does NOT produce a ..._complexes.wxf (the raw
   complexes weren't saved for legacy runs). Leaves the original CSV in place.

   Skips any CSV whose corresponding _stats.wxf already exists. *)

qVal = 10;

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
Get[FileNameJoin[{scriptDir, "comb_paths.wl"}]];
dataDir = $CombDataDir;

expectedHeaders = {"numV", "aut", "autF", "connected",
  "num1VConnComps", "num2VConnComps", "largestCompRatio",
  "num2PathConnComps", "num3PathConnComps",
  "Betti1", "Betti2", "Betti3",
  "wVertex", "wUnlabeled", "wFacet"};

parseCell[x_] := Which[
  x === "" || x === "Missing" || x === Null, "",
  NumberQ[x], x,
  StringQ[x], With[{v = ToExpression[x]}, If[NumericQ[v], N[v], x]],
  True, x];

parseRow[row_] := parseCell /@ row;

(* Extract (p, n, runTag) from filename like p4q10_n1500000_batch2_samples.csv
   runTag may be empty. *)
parseStem[base_] := Module[{m},
  m = StringCases[base,
    StartOfString ~~ "p" ~~ p : DigitCharacter .. ~~
    "q" ~~ q : DigitCharacter .. ~~
    "_n" ~~ n : DigitCharacter .. ~~
    opt : (("_" ~~ (LetterCharacter | DigitCharacter) ..) | "") ~~
    "_samples" ~~ EndOfString
    :> {ToExpression[p], ToExpression[n], StringTrim[opt, "_"]}];
  If[m === {}, $Failed, First[m]]];

migrateOne[csvPath_] := Module[{base, stemParts, p, n, runTag,
    wxfPath, raw, headers, body, rows, assoc},
  base = FileBaseName[csvPath];
  stemParts = parseStem[base];
  If[stemParts === $Failed,
    Print["  SKIP (unrecognized stem): ", base]; Return[Null]];
  {p, n, runTag} = stemParts;
  wxfPath = FileNameJoin[{dataDir,
    StringReplace[base, "_samples" ~~ EndOfString -> "_stats"] <> ".wxf"}];
  If[FileExistsQ[wxfPath],
    Print["  SKIP (WXF exists): ", FileNameTake[wxfPath]]; Return[Null]];

  Print["  loading ", base, ".csv ..."];
  raw = Import[csvPath, "CSV"];
  If[raw === $Failed, Print["    ERROR: import failed"]; Return[Null]];
  headers = First[raw];
  body    = Rest[raw];
  If[headers =!= expectedHeaders,
    Print["    ERROR: header mismatch"]; Return[Null]];
  rows = parseRow /@ body;
  assoc = <|
    "headers"    -> expectedHeaders,
    "rows"       -> rows,
    "p"          -> p,
    "q"          -> qVal,
    "n"          -> Length[rows],
    "runTag"     -> runTag,
    "sourceFile" -> base <> ".csv",
    "createdAt"  -> DateString[]|>;
  Export[wxfPath, assoc, "WXF"];
  Print["  wrote ", FileNameTake[wxfPath], " (", Length[rows], " rows)"]];

Print["dataDir = ", dataDir];
csvs = FileNames["*_samples.csv", dataDir];
Print["found ", Length[csvs], " CSV files"];
Do[migrateOne[c], {c, csvs}];
Print["-----------------------------------------"];
Print["Done."];
