# Roadmap

How this project is being built, and in what order. Written so a reader can see
where any given file came from and what is still missing.

## The question

> Which local government areas should an off-grid energy company prioritise for
> expansion, and what does each type of market need?

Framed commercially, answered with a typology rather than a ranking.

**Unit of analysis:** the Local Government Area — 774 nationally.

**Scope:** clustering runs on 769 of the 774 LGAs. Five are excluded because
the source data cannot describe them: four Lagos LGAs with no settlement
clusters in the electrification model, and Bakassi, which has no population
figure. They are named wherever the exclusion matters.

The dashboard additionally exposes the seven North-West states as a filtered
view. The national segmentation is the result; the regional view is a lens
onto it, useful because off-grid demand is concentrated there and because
examining one region tests whether the segments carry real structure or merely
recover geography.

---

## Stage 0 — Framing and data acquisition · complete

Sources identified, downloaded unmodified into `data/raw/`, and documented in
`docs/data_provenance.md` with URL, licence, vintage, row count and coverage.
Unit of analysis confirmed as the LGA at 99.87% population coverage, so the
fallback to 109 senatorial districts was not needed.

## Stage 1 — SQL analysis base · complete except the question catalogue

All cleaning, joining and aggregation happens in `sql/`. The loader copies files
into SQLite and does nothing else, so every transformation is readable.

Deliverables: the 774-LGA spine keyed on P-code, indicator tables joined onto it,
an assertion suite run after every rebuild, and a catalogue of 15–20 business
questions with their queries and answers in `sql/10_business_questions.sql`.

**Outstanding: the catalogue holds 8 questions, not 15–20.** The file
`10_business_questions.sql` ends with "Q9 onwards: to come". Either the
remaining questions get written or the target is revised down — but the stage
is not finished while the file says so itself.

## Stage 2 — Clustering · complete

K-Means, hierarchical and DBSCAN compared on the same feature set, with the
chosen segmentation defended on evidence rather than convenience. k=5,
silhouette 0.309, stability 0.992. Ward agrees at ARI 0.602; re-clustering
only the 600 `ok`-flagged LGAs reproduces their assignment at ARI 0.807.
DBSCAN returns one cluster and 57 noise points, so these are divisions of a
continuum rather than natural kinds.

Deliverable: `pipeline/cluster.py`, `pipeline/visualise.py`,
`sql/09_segment_names.sql`, and five figures in `reports/` — `k_selection.png`
from the k search, and the four from `visualise.py`.

**Changed from the original plan: this is not a notebook.** The stage was
planned as `notebooks/02_clustering.ipynb` and built as scripts instead. A
notebook that must be re-run top to bottom to be trusted is a worse artefact
than a script that fails loudly, and standing rule 3 — restart and run all
before every commit — is enforced by construction once the work is a script.

## Stage 2b — Sub-clustering · complete

PROJECT_BRIEF.md promised that if the clusters only recovered geography, the
analysis would say so and then look for structure within the obvious split.
It partly happened: Low-Income Rural Core is a near-solid northern block. Its
274 LGAs divide into four sub-types that a null model of independently
shuffled feature columns does not reproduce — silhouette 0.214 against a null
95th percentile of 0.156, stability ARI 0.902. Reported with both limits: the
excess curve is flat, so the claim is roughly three to five types rather than
exactly four, and k=2 comes back negative.

Deliverable: `pipeline/subcluster.py`,
`pipeline/check_subsegment_fit.py`, `sql/11_subsegment_names.sql`.

## Stage 3 — Segment profiling · complete

Each cluster profiled on its defining indicators, then named and given a
one-paragraph persona: what this type of market looks like, what it needs, and
what an operator should do differently there. Nine profiles — five market
types and the four sub-types inside the largest.

Deliverable: `reports/segment_profiles.md`, with every number generated into
`reports/segment_profile_data.md` by `pipeline/profile_segments.py` rather
than typed. The rule the pair is built on: **restate no number you did not
generate.**

## Stage 4 — Communication

A published Power BI dashboard including a map, a one-page Excel summary, and a
written report for an expansion director.

**Changed 4 Sep 2026: the report is no longer capped at two pages.** It runs as
long as the findings need and is built around its figures rather than around its
paragraphs. The reason is that the two-page format could not carry this project's
actual output without omission: the GEP quality finding (Q7), the cost-versus-
demand inversion (Q8), the North East decision, the segmentation's own limits,
and the segment map cannot be compressed into two pages, and choosing which to
drop would contradict the standard of honesty this project is built on.

Length is not licence. The report is structured so a reader can stop early and
still have the answer: findings first, method behind them, every figure carrying
its own caption.

### Six rules that keep "as long as it needs to be" honest

Agreed 4 Sep 2026, at the same time as the change above. Removing the page cap
removes a constraint that was doing real work, so these replace it. They bind
the same way the analytical thresholds in `sql/` do.

1. **Cap the summary, not the report.** The two-page discipline relocates to the
   front rather than disappearing. Page one stands alone and answers the
   client's question completely. Everything after it is evidence for a reader
   who wants it. A director reads one page; a reviewer reads all of it.

2. **Every section names the decision it informs.** If the sentence "a reader
   needs this in order to decide ___" cannot be finished, the section is cut.
   This is the rule that removes material that is interesting but not useful.

3. **One page per finding, hard.** A local cap, not a global one. Q7 gets a
   page. Q8 gets a page. The segmentation gets a page. Prioritisation happens
   inside each section instead of being abandoned across the whole document.

4. **Figures lead, prose supports.** The segment map carries more than three
   paragraphs would. A section with no figure should be challenged: it may be a
   sentence rather than a section.

5. **Method goes to an appendix, and mostly stays in the repository.** The
   `sql/` files already carry the reasoning in full. The report points at them
   rather than reproducing them.

6. **Read it aloud before shipping.** Anywhere the author skims their own
   document, the client stops reading entirely.

**And pre-register the structure.** The table of contents and a page budget per
section are written BEFORE drafting, the same discipline this project applies to
thresholds, fallbacks and expected row counts. A section that then overruns its
budget is a visible decision rather than an invisible drift.

## Stage 5 — Pipeline

The steps turned into a runnable pipeline, tracked in MLflow, with the database
ported from SQLite to PostgreSQL.

## Stage 6 — Segment-assignment service · optional

An endpoint that assigns an unseen LGA to a segment.

## Stage 7 — Wrap and publish

---

## Standing rules

1. **Every number published must be traceable to the script that produced it.**
2. **Row-count assertion after every join.** If the count changed and it was not
   intended, the analysis is silently corrupt.
3. **Restart and Run All before every commit.** The kernel remembers; the file
   forgets.
4. **Commit at each milestone.** The history is itself part of the record.
5. **Pin the whole dependency tree**, not only the packages chosen directly.
6. **Raw data is never edited.** Corrections happen in SQL, in the open.

## What finished looks like

- A repository whose SQL is the first thing a reader notices, and whose query
  catalogue can be read without running anything.
- A published Power BI dashboard with a map.
- A visual written report, as long as the findings require, with every
  limitation stated in it rather than left for a reader to discover.
- A named, defensible segmentation of Nigerian LGAs with a commercial
  recommendation attached to each segment.
- A reproducible pipeline from raw public files to segment assignment.

## Related work

This project answers the market-entry question for the off-grid energy sector.
Two companion projects answer the questions that follow it: which household to
contact within a market ([solar-targeting-Nigeria](https://github.com/ProfFausat/solar-targeting-Nigeria),
deployed at https://solar-targeting-nigeria.onrender.com/), and whether those
households can pay.
