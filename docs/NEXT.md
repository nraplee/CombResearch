# Next session — handoff

> Written 2026-04-27, after batch3 (4-day unattended sampling run) landed and was processed end-to-end. Overwrite when Dr. Betre's reply arrives and direction is set.

## Where we are

Batch3 is done. We now have the largest IS-reweighting dataset the q=10 pipeline can ever meaningfully produce, and it confirms the heavy-tail diagnosis from `docs/PIPELINE.md`.

**Final merged ESS** (unlabeled / facet, from `logs/concat_post_batch3.log`):

| p | merged N | ESS_unlabeled | ESS_facet |
|---|----------|---------------|-----------|
| 2 | 2,000,000 | 667 | 527 |
| 3 | 12,000,000 | 123 | 118 |
| 4 | 12,000,000 | 25 | 29 |

Read: p=2 fine; p=3 at the borderline; **p=4 confirmed broken-IS-regime** — 24× more samples (500k → 12M) only nudged ESS from 4 to ~27, and the trajectory was non-monotone (12 → 4 → 24 → 25).

## What's on disk now

- `data/p{2,3,4}q10_merged_stats.wxf` — full merged stats with weights. **Load these with the renderer.**
- `data/p{3,4}q10_n10000000_batch3_complexes.wxf` — raw complexes from batch3 only (Dr. Betre asked for these). Legacy batches don't have them.
- `figures/manuscript_panels/*_merged.pdf` — ~30 individual per-panel PDFs (batch1+2+3 combined).
- `figures/combined_all_figures_merged.pdf` — multi-page review PDF.
- `figures/stacked_previews/*.{pdf,png}` — 3-panel column previews.
- `logs/concat_post_batch3.log`, `logs/render_post_batch3.log` — run output.

## Pipeline changes landed in this session

- **`src/concat_samples.wl`** — patched to log a warning and skip the complexes merge when input siblings are missing (legacy migrated WXFs have no complexes), instead of aborting. Stats merge always runs.
- **`src/render_all_figures.wl`** — switched to merged WXFs (`stem` returns `p{p}q10_merged`, `sampleTag = "merged"`); existing `_n500k` outputs untouched on disk.

## When you return

1. **If Dr. Betre has replied:** write a fresh plan reflecting his direction. The drafted email is at `docs/email_betre_post_batch3.md` — confirm the actual sent text matches before throwing it out, then delete the draft.
2. **If no reply yet:** nothing to do. The figures, ESS, and email draft are the deliverable until he weighs in.
3. **Sanity-check the figures** (`figures/combined_all_figures_merged.pdf`) yourself if you haven't already — vertex-labeled bars should be smooth and stable; facet/unlabeled at p=4 will be visibly spiky / outlier-dominated. That's expected and matches the ESS=25/29.

## Pending / blocked

- **Email to Dr. Betre.** Drafted at `docs/email_betre_post_batch3.md`. Awaiting Elijah review → send → delete draft.
- **Sampler swap.** Sketched in the email; concrete plan blocked on Betre's input. Top candidate: Metropolis-Hastings over isomorphism classes with detailed balance against |Aut| (unlabeled measure) or q!/|Aut_F| (facet measure).
- **Manuscript text** updates to caveat the p=4 figures — defer until sampler decision lands.
- **Add Dr. Betre as GitHub collaborator** once he sends his username (carryover from prior handoff).

## If something goes wrong

- **Need to re-render:** `wolframscript -file src/render_all_figures.wl` — reads `_merged_stats.wxf` directly, ~1 min once samples are loaded.
- **Need to re-merge:** `wolframscript -file src/concat_samples.wl`. Idempotent; overwrites `*_merged_*.wxf` from current `data/` contents. Will warn on missing complexes (expected).
- **Want to switch back to N=500k figures:** edit `src/render_all_figures.wl:34` (`sampleTag = "n500k"`) and `:60` (`stem[p_] := "p" <> ToString[p] <> "q" <> ToString[qVal] <> "_n500000"`). The old `_n500k.pdf` outputs are still on disk untouched.
