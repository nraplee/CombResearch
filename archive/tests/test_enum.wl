Needs["ECGrav`"];
Print["Testing enumeration for q=10..."];
Do[
  pq = {p, 10};
  Print["--- pq = ", pq, " ---"];
  t = AbsoluteTiming[
    complexes = GenerateAllFacetLabeledPureSimplicialComplexes[pq];
  ];
  Print["  Time: ", t[[1]], " sec"];
  Print["  Num facet-labeled: ", Length[complexes]];
  t2 = AbsoluteTiming[
    reps = ChooseNonIsomorphicSimplicialComplexes[complexes];
  ];
  Print["  Time for reps: ", t2[[1]], " sec"];
  Print["  Num unlabeled classes: ", Length[reps]];
  ,
  {p, {2, 3, 4}}
];
Print["Done."];
