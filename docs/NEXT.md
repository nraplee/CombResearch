# Next session — handoff

> Written 2026-04-22 at end of session. Short-lived; delete or overwrite when the open question below resolves.

## Where things stand

- **N=500k CSVs** in `data/p{2,3,4}q10_n500000_samples.csv` — overnight run is the source of truth for Figures 3-15.
- **Figures** rendered and living in `figures/manuscript_panels/` (33 per-panel PDFs), `figures/stacked_previews/` (13 stacked PDFs/PNGs), and `figures/combined_all_figures_n500k.pdf`.
- **Phase B (parallel compute) verified** today at N=2000 via `src/run_parallel.ps1`. Three `wolframscript` processes ran concurrently, each with 8 local subkernels on the stats step; wall-clock ≈ 120s ≈ max(p=4) + kernel-launch overhead, not the 137s serial sum. Smoke-test artifacts (`data/p{2,3,4}q10_n2000_samples.csv`, ~500 KB total) can be deleted at will — they're gitignored.
- **Scripts touched today:** `src/run_parallel.ps1` (switched from `-code` injection to env-var + `-file`; the old approach silently dropped everything after the first space due to `Start-Process -ArgumentList` not auto-quoting), `src/run_p{2,3,4}.wl` (now read `COMB_N` env var instead of expecting `sampleSizeOverride` to be pre-set). Docs updated: `CLAUDE.md`, `docs/PIPELINE.md`.

## The open question (blocks everything else)

q=10 reweighting ESS collapses — numbers from the N=500k run:

| p | ESS unlabeled | ESS facet |
|---|---|---|
| 2 | 369 / 500000 | 244 / 500000 |
| 3 |  26 / 500000 |  21 / 500000 |
| 4 |   4 / 500000 |   4 / 500000 |

For p=4, one sample carries ~44% of the unlabeled mass. Bar heights at p=3,4 are qualitatively the right shape but quantitatively unreliable. `docs/PIPELINE.md` § "Why the hack breaks at q=10" has the full diagnosis.

**Pending Dr. Betre (elijah.raplee@sjsu.edu is the user; Dr. Betre is the advisor):**

a. Push N by ~100× — probably infeasible. ESS is ~flat in N for heavy-tailed IS; 50M samples probably doesn't buy enough, and even the parallel pipeline would take days.
b. Accept variance and publish with prominent ESS caveats; possibly restrict figures to p=2.
c. Swap sampler. Options the professor might propose: direct facet-labeled sampling with Metropolis, unlabeled random-canonical-form generation, etc. Design open.

## What can proceed without Dr. Betre

- Manuscript LaTeX writing (`docs/Pure Clique Complexes.tex`) — sections not depending on final figures.
- Any refactor of the compute pipeline that keeps the CSV schema intact.
- `src/reference/*.nb` Figure 2 artifacts are frozen; do not touch.

## What NOT to do

- **Do not** launch another overnight N=500k run — we have that data.
- **Do not** re-render figures from the existing N=500k data expecting different ESS; it's not a rendering issue.
- **Do not** trust or use `RandomFacetLabeledPureSimplicialComplex` (see CLAUDE.md § Paper Equation References).
