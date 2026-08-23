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

A published Power BI dashboard including a map, plus a one-page Excel summary and
a two-page client brief for an expansion director.

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
- A named, defensible segmentation of Nigerian LGAs with a commercial
  recommendation attached to each segment.
- A reproducible pipeline from raw public files to segment assignment.

## Related work

This project answers the market-entry question for the off-grid energy sector.
Two companion projects answer the questions that follow it: which household to
contact within a market ([solar-targeting-Nigeria](https://github.com/ProfFausat/solar-targeting-Nigeria),
deployed at https://solar-targeting-nigeria.onrender.com/), and whether those
households can pay.
