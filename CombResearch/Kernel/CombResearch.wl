(* ::Package:: *)

(* CombResearch: the algorithms of the CombResearch project (exact enumeration
   of pure simplicial complexes, statistics, samplers), laid out like ECGrav
   (this file declares the public symbols with ::usage; Kernel/Subpackages/*.wl
   hold the code in the private context) so pieces can be upstreamed into
   ECGrav as a copy-and-adapt job.

   Requires ECGrav` to be loaded first. In this repo every script loads it
   through src/load_combresearch.wl, which loads ECGrav via src/load_ecgrav.wl
   and then Gets this file. This file never loads ECGrav itself, so it can
   never pick up a globally installed ECGrav paclet by accident.

   Subpackages:
     Enumeration.wl   exact unlabeled enumeration (cheap key, BLISS, McKay)
     Statistics.wl    the 12 per-complex statistics
     MHSampler.wl     Metropolis-Hastings for the three targets *)

If[!MemberQ[$Packages, "ECGrav`"],
  Print["CombResearch: load ECGrav first (src/load_combresearch.wl does both)."];
  Abort[]];

BeginPackage["CombResearch`", {"ECGrav`"}];

Unprotect @@ Names["CombResearch`*"];
ClearAll @@ Names["CombResearch`*"];


(* ::Section:: *)
(* Enumeration *)

EnumerateUnlabeledPureComplexes::usage =
"EnumerateUnlabeledPureComplexes[p, q] enumerates one representative of every
	isomorphism class of pure simplicial complexes with q facets of p vertices
	each (no two facets equal), and returns
	<|\"isoReps\" -> {complex, ...}, \"totalEmitted\" -> n, \"numBuckets\" -> k,
	\"method\" -> \"Cheap\" | \"BLISS\" | \"McKay\"|>.
	Each complex is a list of q facets, each a sorted list of vertex labels 1..nV.
	Options:
	  Method -> Automatic | \"Cheap\" | \"BLISS\" | \"McKay\". Automatic picks
	    \"McKay\" for p >= 4 and \"Cheap\" otherwise (the cheap pipeline runs out
	    of memory at (4,5)).
	  \"Parallel\" -> True | False: spread the DFS starting states over
	    subkernels. Use False for memory-bound cells (p = 4).
	\"totalEmitted\" counts DFS leaves visited. For \"Cheap\" and \"BLISS\" that is
	the number of facet-labeled complexes; for \"McKay\" it is smaller (pruned).
	\"numBuckets\" is the number of distinct keys used for bucketing.";

EnumerateUnlabeledPureComplexes::method =
"Method -> `1` is not one of Automatic, \"Cheap\", \"BLISS\", \"McKay\".";

PureComplexCanonicalKey::usage =
"PureComplexCanonicalKey[complex] gives a canonical form of a simplicial
	complex (a list of facets): the sorted edge list of the BLISS canonical graph
	of its vertex-facet incidence graph (with a triangle gadget on each facet so
	no automorphism swaps vertices and facets). Two complexes have equal keys if
	and only if they are isomorphic.";

ChooseNonIsomorphicPureComplexesBucketed::usage =
"ChooseNonIsomorphicPureComplexesBucketed[complexes] keeps one complex of every
	isomorphism class in the list, like ECGrav's
	ChooseNonIsomorphicSimplicialComplexes, but first groups the complexes by a
	cheap invariant (number of vertices, vertex degrees, facet-pair overlaps) and
	tests isomorphism only within a group.";

$CombResearchSubkernelSetup::usage =
"$CombResearchSubkernelSetup is a function called with no arguments before
	parallel work that needs ECGrav on the subkernels (the \"Cheap\" enumerator
	calls IsomorphicSimplicialComplexQ there). The default runs
	ParallelNeeds[\"ECGrav`\"]. src/load_combresearch.wl sets it to
	combLoadECGravOnKernels so subkernels load the same ECGrav checkout.";

$CombTruthIsoCounts::usage =
"$CombTruthIsoCounts is an association {p, q} -> number of isomorphism classes
	of pure simplicial complexes with q facets of size p, for the 9 cells of the
	project's truth grid. Used as validation gates.";


(* ::Section:: *)
(* Statistics *)

PureComplexStatistics::usage =
"PureComplexStatistics[complex, p] gives the 12 statistics of a pure simplicial
	complex with facets of size p, in the order of $PureComplexStatisticNames:
	number of vertices; vertex automorphism group order (ECGrav
	PureComplexAutomorphismGroupOrder); facet automorphism group order
	(PureComplexFacetAutomorphismGroupOrder); connected (1 or 0); number of
	connected and of 2-vertex-connected components of the 1-skeleton; largest
	component size / number of vertices (a Real); number of 2-path and 3-path
	connected components; Betti numbers 1, 2, 3 over Z_2. Entries that do not
	apply at this p (2-path and Betti2 for p < 3, 3-path and Betti3 for p < 4)
	are \"\".
PureComplexStatistics[complex] takes p from the first facet.";

$PureComplexStatisticNames::usage =
"$PureComplexStatisticNames is the list of the 12 statistic names, in the
	order PureComplexStatistics returns them.";

PureComplexKPathComponents::usage =
"PureComplexKPathComponents[complex, k] gives the number of k-path connected
	components: (k-1)-simplices are joined when they lie in a common facet.";

PureComplexBettiNumber::usage =
"PureComplexBettiNumber[complex, k] gives the k-th Betti number of the
	complex over Z_2 (rank-nullity on the mod-2 boundary matrices).";


(* ::Section:: *)
(* MHSampler *)

PureComplexMHChain::usage =
"PureComplexMHChain[p, q, target, numIter] runs a Metropolis-Hastings chain over
	pure simplicial complexes with q facets of size p, vertex-labeled inside a
	fixed ambient set of N = q p labels, whose marginal over isomorphism classes
	is target: \"unlabeled\" (uniform over classes), \"facet\" (uniform over
	facet-labeled complexes) or \"vertex\" (uniform over vertex-labeled
	complexes on numV vertices). It returns <|\"p\", \"q\", \"N\", \"target\",
	\"numIter\", \"burnIn\", \"thin\", \"seed\", \"trace\" -> {state, ...},
	\"acceptRate\", \"deltaNumVCounts\", \"wallSeconds\"|>; each state is a sorted
	list of q sorted facets. The start is one ECGrav
	RandomVertexLabeledPureSimplicialComplex draw after SeedRandom[seed].
	Options: \"burnIn\" -> 0, \"thin\" -> 1, \"seed\" -> 12345, \"verbose\" -> True,
	\"kernel\" -> \"global\" | \"local\" | \"swap\" | \"mixed\" (proposal),
	\"initNumV\" -> Automatic | m (warm start: q random p-subsets of 1..m).";

PureComplexMHChain::target = "Target `1` is not one of \"unlabeled\", \"facet\", \"vertex\".";
PureComplexMHChain::kernel = "Kernel `1` is not one of \"global\", \"local\", \"swap\", \"mixed\".";

IntegratedAutocorrelationTime::usage =
"IntegratedAutocorrelationTime[x] estimates the integrated autocorrelation time
	of the series x (summing autocorrelations until the first non-positive one)
	and returns <|\"tau\" -> t, \"ess\" -> n/(2 t), \"lagsUsed\" -> k|>, or
	<|\"tau\" -> Infinity, \"ess\" -> 0|> for a constant series.";


Begin["`Private`"];

Get[FileNameJoin[{DirectoryName[$InputFileName], "Subpackages", "Enumeration.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "Subpackages", "Statistics.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "Subpackages", "MHSampler.wl"}]];

End[];

Protect @@ DeleteCases[Names["CombResearch`*"], "$CombResearchSubkernelSetup"];

EndPackage[];
