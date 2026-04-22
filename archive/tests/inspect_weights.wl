toNum[x_String] := N[ToExpression[x]];
toNum[x_] := N[x];

out = OpenWrite["weight_summary.txt"];
Do[
  fname = "p" <> ToString[p] <> "q10_n10000_samples.csv";
  data = Import[fname];
  headers = First[data];
  rows = Rest[data];
  cols = AssociationThread[headers -> Transpose[rows]];

  numV = cols["numV"];
  wU = toNum /@ cols["wUnlabeled"];
  wF = toNum /@ cols["wFacet"];
  totU = Total[wU];
  totF = Total[wF];

  WriteString[out, "===== p = ", p, " =====\n"];
  essU = totU^2/Total[wU^2];
  essF = totF^2/Total[wF^2];
  WriteString[out, "ESS_U=", Round[essU], "  ESS_F=", Round[essF], "\n"];

  topU = Reverse[Sort[wU/totU]][[;; 10]];
  topF = Reverse[Sort[wF/totF]][[;; 10]];
  WriteString[out, "top-10 unlabeled w (frac): ",
    Round[topU, 0.0001], "\n"];
  WriteString[out, "top-10 facet w     (frac): ",
    Round[topF, 0.0001], "\n"];
  WriteString[out, "max share: U=", Round[Max[wU]/totU, 0.0001],
    "  F=", Round[Max[wF]/totF, 0.0001], "\n"];

  WriteString[out, "numV range: ", {Min[numV], Max[numV]}, "\n"];

  byVU = SortBy[Normal @ Merge[Thread[numV -> wU], Total], First];
  byVF = SortBy[Normal @ Merge[Thread[numV -> wF], Total], First];
  byVV = SortBy[Tally[numV], First];

  WriteString[out, "numV vert-lab (count): ",
    {#[[1]], #[[2]]} & /@ byVV, "\n"];
  WriteString[out, "numV unlabeled (frac): ",
    {#[[1]], Round[#[[2]]/totU, 0.001]} & /@ byVU, "\n"];
  WriteString[out, "numV facet-lab (frac): ",
    {#[[1]], Round[#[[2]]/totF, 0.001]} & /@ byVF, "\n"];
  ,
  {p, {2, 3, 4}}];
Close[out];
Print["wrote weight_summary.txt"];
