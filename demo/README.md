# CombResearch Explorer

A Mathematica notebook that shows three pieces of the `CombResearch` package
on real cells (p = facet size, q = number of facets):

1. **Enumerate** all isomorphism classes and compare the counts with ECGrav's
   exact counters and our stored truth.
2. **Statistics** of one complex (from panel 1, random, or typed in).
3. **Exact distributions** of a statistic under the three targets
   (vertex-labeled, facet-labeled, unlabeled).

It only reads: nothing is written to `data/`, `figures/`, `logs/` or
`results/`.

## Open it

You need Wolfram 15 or later (macOS, Windows or Linux), a clone of this
repository, and ECGrav. Keep the notebook in `demo/`.

1. ECGrav: if you have the paclet installed, nothing to do. Or get the
   latest one next to `run.wl`:

   ```
   wolframscript -file tools/dev/update_ecgrav.wl
   ```

   Order of preference: `COMB_ECGRAV_DIR` if set, `ECGrav-upstream/`, the
   installed paclet. The Status box shows which one is loaded.
2. Open `demo/CombResearchExplorer.nb` and choose Evaluation, Evaluate
   Notebook.

The truth files of the 9 cells (`p{p}q{q}_truth.wxf`, 3 MB) come with the
notebook in `demo/data/`, copied from the main store on 2026-11-23. If the
checkout's own `data/` has one, that one is used instead.

## How long things take (Ryzen 7 5800X, 16 kernels)

| Cell | Classes | Automatic |
|---|---|---|
| (2,4), (3,3), (4,2) | 11, 12, 4 | about 1 s |
| (3,4) | 66 | 5 s; 29 s on one kernel |
| (2,6) | 68 | 4 min |
| (3,5) | 445 | 6 min; 35 min on one kernel |
| (4,4) | 278 | 4 min on one kernel (McKay) |
| (2,7) | 177 | 3.7 h |
| (3,6) | 4279 | 17 h |
| (4,5) | 5532 | 17 h on one kernel (McKay), 8 GB of memory |

The first job also starts the parallel kernels (about 10 s). McKay
(Automatic at p = 4) gains little from them, because one branch holds most
of its work; untick Parallel for (4,5). Cells above 30,000 facet-labeled
complexes only start with "Allow long runs", and above 3 million never.

## Files

| File | |
|---|---|
| `CombResearchExplorer.nb` | generated; do not edit |
| `build_explorer.wl` | writes the notebook: text and one line per panel |
| `data/` | copies of the 9 truth files; refresh them if a truth cell is ever recomputed |
| `explorer_core.wl` | loading, kernels, progress, all computing |
| `explorer_panels.wl` | controls and displays |
| `explorer_check.wl` | headless check; words `quick`, `full` |
| `explorer_fe_check.wl` | runs the notebook in a hidden front end and saves pictures |

```
wolframscript -file demo/build_explorer.wl
wolframscript -file demo/explorer_check.wl quick
wolframscript -file demo/explorer_fe_check.wl
```

## What still needs a person

The checks run every panel's code, evaluate the notebook in a hidden front
end, and stop a running job with the command the Stop button sends. They do
not move a mouse. By hand, once per system:

1. Evaluation, Evaluate Notebook in a fresh kernel. Four panels, no
   messages. Also try the Start button.
2. Panel 1: (3,4), **Enumerate**. The bar moves; 66 classes; every row ok.
3. Panel 1: (3,5), **Enumerate**, wait until complexes are counted, click
   **Stop**. It says "Stopped."; then (2,4) still works.
4. Untick **Parallel**, enumerate (2,4): "on one kernel".
5. Click an example picture: its statistics appear in panel 2.
6. Panel 2: **Draw** for each of the three choices; type `{{1,2,3},{3,4,5}}`
   and **Use**; type something wrong and **Use**.
7. Panel 3: (3,5) **Show**, switch the statistic, hover a bar. Then a live
   cell, (3,3) **Show**.
8. On the Mac: the same, and the Status box shows the ECGrav you expect.
