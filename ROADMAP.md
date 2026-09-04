# Roadmap

How this project is being built, and in what order. Written so a reader can see
where any given file came from and what is still missing.

## The question

> Which local government areas should an off-grid energy company prioritise for
> expansion, and what does each type of market need?

Framed commercially, answered with a typology rather than a ranking.

**Unit of analysis:** the Local Government Area — 774 nationally.

**Scope:** clustering runs on all 774 LGAs. The dashboard additionally exposes
the seven North-West states as a filtered view. The national segmentation is the
result; the regional view is a lens onto it, useful because off-grid demand is
concentrated there and because examining one region tests whether the segments
carry real structure or merely recover geography.

---

## Stage 0 — Framing and data acquisition · complete

Sources identified, downloaded unmodified into `data/raw/`, and documented in
`docs/data_provenance.md` with URL, licence, vintage, row count and coverage.
Unit of analysis confirmed as the LGA at 99.87% population coverage, so the
fallback to 109 senatorial districts was not needed.

## Stage 1 — SQL analysis base · in progress

All cleaning, joining and aggregation happens in `sql/`. The loader copies files
into SQLite and does nothing else, so every transformation is readable.

Deliverables: the 774-LGA spine keyed on P-code, indicator tables joined onto it,
an assertion suite run after every rebuild, and a catalogue of 15–20 business
questions with their queries and answers in `sql/10_business_questions.sql`.

## Stage 2 — Clustering

K-Means, hierarchical and DBSCAN compared on the same feature set, with the
chosen segmentation defended on evidence rather than convenience.

Deliverable: `notebooks/02_clustering.ipynb`.

## Stage 3 — Segment profiling

Each cluster profiled on its defining indicators, then named and given a
one-paragraph persona: what this type of market looks like, what it needs, and
what an operator should do differently there.

Deliverable: `reports/segment_profiles.md`.

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
