# Next session — handoff

> Written 2026-04-22 end of day. Short-lived; overwrite when the open question below resolves.

## Where things stand

- **N=500k CSVs** in `data/p{2,3,4}q10_n500000_samples.csv` — still the source of truth for Figures 3-15.
- **Figures** live in `figures/manuscript_panels/` (33 per-panel PDFs), `figures/stacked_previews/` (13 stacked PDFs/PNGs), and `figures/combined_all_figures_n500k.pdf`.
- **Parallel compute** verified earlier today at N=2000 via `src/run_parallel.ps1`.
- **Notebook port (today):** `src/pure_simplicial_figures.nb` was a stale mirror (grouped BarChart, sampleSize=10000). Rewrote as a proper notebook port of `src/render_all_figures.wl` — translucent overlaid `Histogram` (opacity 0.55) matching paper Figure 2 style, one figure per cell for inline review, ESS sanity-check cell. Commit `a74a9e7` on `origin/main`.
- **Email to Dr. Betre sent** — attached the rewritten `src/pure_simplicial_figures.nb`, offered to add him as a GitHub collaborator, and explained the ESS-vs-integrated-area distinction (he'd pushed back thinking reweighting shouldn't change total area — correct about area, but ESS is a variance diagnostic, not an area check). Draft archived at `C:/Users/darth/.claude/plans/check-claude-md-email-response-wobbly-turing.md` if needed. Awaiting his reply.

## The open question (blocks figure work)

q=10 reweighting ESS collapses — unchanged from the N=500k run:

| p | ESS unlabeled | ESS facet |
|---|---|---|
| 2 | 369 / 500000 | 244 / 500000 |
| 3 |  26 / 500000 |  21 / 500000 |
| 4 |   4 / 500000 |   4 / 500000 |

At p=4 one sample carries ~44% of the unlabeled mass. `docs/PIPELINE.md` § "Why the hack breaks at q=10" has the full diagnosis.

**Pending Dr. Betre** (email sent; waiting on his reply):

a. Push N by ~100× — likely infeasible; ESS is ~flat in N for heavy-tailed IS.
b. Accept variance and publish with prominent ESS caveats; possibly restrict figures to p=2.
c. Swap sampler (Metropolis on facet-labeled, unlabeled random-canonical-form, etc.). Design open.

## To do next session

1. When Dr. Betre replies with his GitHub username, add him as a collaborator at https://github.com/nraplee/CombResearch/settings/access (Read access).
2. Once he weighs in on the ESS/sampler question, act on his guidance.
3. If there's bandwidth while waiting, work on manuscript LaTeX sections that don't depend on final figures (see "What can proceed" below).

## What can proceed without Dr. Betre

- Manuscript LaTeX writing (`docs/Pure Clique Complexes.tex`) — sections not depending on final figures.
- Any refactor of the compute pipeline that keeps the CSV schema intact.
- `src/reference/*.nb` Figure 2 artifacts are frozen; do not touch.

## What NOT to do

- **Do not** launch another overnight N=500k run — we have that data.
- **Do not** re-render figures from the existing N=500k data expecting different ESS; it's not a rendering issue.
- **Do not** trust or use `RandomFacetLabeledPureSimplicialComplex` (see CLAUDE.md § Paper Equation References).
