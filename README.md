# Market Segmentation for Off-Grid Energy Expansion in Nigeria

**Which local government areas should an off-grid energy operator prioritise for
expansion, and what does each type of market need?**

A pay-as-you-go solar company deciding where to expand faces a problem that looks like customer targeting but sits a level above it. Before asking which household to approach, such company must decide which *market* to enter, where to place agents, stock, service infrastructure and credit exposure. If a company enters the wrong local government area, no amount of household-level targeting will recover the cost.

Nigeria has 774 LGAs and they differ enormously in the things that determine
whether an off-grid energy business succeeds: how many people live there, how
many lack electricity, whether they can pay, and how expensive they are to serve.
Treating that variation as a ranked list loses information. LGAs are not better
and worse versions of each other — they are *different kinds of market*, and each kind calls for a different operating model.

The output is therefore a **typology**, not a ranking: a small number of market
types, each named, profiled, and paired with what an operator should do
differently there.

---

## Status

**In progress.** Stage 0 (data acquisition and provenance) is complete. Stage 1
(SQL analysis base) is under way.

| Stage | Description | Status |
|---|---|---|
| 0 | Framing, data acquisition, provenance | Complete |
| 1 | SQL: spine, joins, analysis base, question catalogue | In progress |
| 2 | Clustering: K-Means, hierarchical, DBSCAN compared | Not started |
| 3 | Segment profiling and operating recommendations | Not started |
| 4 | Power BI dashboard | Not started |
| 5 | Port to PostgreSQL, MLflow-tracked pipeline | Not started |

This repository is a **SQL project whose analytical payload is clustering**, not
a clustering project that happens to use SQL. Every cleaning, joining and
aggregation step lives in `sql/` where it can be read and checked. The loader
copies files and does nothing else.

---

## What is here

```
sql/
  00_checks.sql              assertions — run after every rebuild
  01_build_spine.sql         the 774-LGA spine, keyed on P-code
  02_build_population.sql    LGA population, 2020
  03_analysis_base.sql       spine LEFT JOIN population -> lga_base
  10_business_questions.sql  the query catalogue, with answers recorded
pipeline/
  load_raw.py                raw files -> SQLite, unchanged, fails loudly
data/raw/                    source files exactly as published
docs/data_provenance.md      every source, licence, vintage and discrepancy
PROJECT_BRIEF.md             framing, audience, failure modes
PROJECT_PLAN.md              stage-by-stage plan
```

## Reproducing it

```bash
python pipeline/load_raw.py
sqlite3 data/processed/nigeria_lga.db < sql/01_build_spine.sql
sqlite3 data/processed/nigeria_lga.db < sql/02_build_population.sql
sqlite3 data/processed/nigeria_lga.db < sql/03_analysis_base.sql
sqlite3 data/processed/nigeria_lga.db < sql/00_checks.sql
```

The last command should return `PASS` on all nine checks.

The loader asserts an expected row count for every source and refuses to load if
one has changed. These datasets update annually, so that guard is not decorative.

---

## Data decisions worth knowing before reading any number

Full detail in [`docs/data_provenance.md`](docs/data_provenance.md).

**Population is 2020, and deliberately not adjusted to 2022.** The current COD-PS release for Nigeria publishes admin levels 0–1 only; there is no LGA-level population in it. LGA figures come from the 2020 legacy release. Rescaling those onto 2022 state totals was considered and rejected: state-level change between the two releases runs from −36.6% (FCT) to +28.8% (Katsina) over two years, which is a methodological break between releases, not demography. Rebasing would have presented that break as population change. The column is named `pop_2020`.

**773 of 774 LGAs have a population figure.** Bakassi (NG009005) has none. Both
HDX dataset pages state why: it is thought to be uninhabited, and any actual
population is incorporated in the Akpabuyo (NG009003) record. The population is
absorbed, not lost, which is why the 773 figures still sum exactly to the
published national total. Bakassi is retained in `lga_base` with a NULL
population rather than dropped, so that every count of "774 LGAs" stays true.

**All joins use `lga_pcode`, never `lga_name`.** The 774 LGAs carry only 768
distinct names: Bassa, Ifelodun, Irepodun, Nasarawa, Obi and Surulere each name
two LGAs in two different states. A join on name would misattribute twelve rows
and raise no error at all. Two of those names appear in the top ten most populous LGAs, so the failure would have landed in a headline result looking entirely plausible.

---

## Data sources and attribution

Both datasets are licensed **CC BY-IGO**, which requires attribution.

Administrative boundaries: *Nigeria Subnational Administrative Boundaries
(COD-AB)*, Office for the Surveyor General of the Federation of Nigeria (OSGOF),
eHealth, and the United Nations Cartographic Section (UNCS), via OCHA Field
Information Services Section on the Humanitarian Data Exchange. Licensed
CC BY-IGO. Accessed 21 August 2026.
https://data.humdata.org/dataset/cod-ab-nga

Population: *Nigeria Subnational Population Statistics (COD-PS, 2020 legacy
release)*, UNFPA and the United States Census Bureau PEPFAR program, via UNFPA on the Humanitarian Data Exchange. Licensed CC BY-IGO. Accessed 21 August 2026.
https://data.humdata.org/dataset/cod-ps-nga

---

## Standard of honesty

Carried from the preceding project in this portfolio: every published number
traceable to the script that produced it, negative and inconvenient findings
reported rather than dropped and limitations stated in the deliverable rather
than left for a reader to discover.

---

**Prof. Fausat M. Ibrahim**
Related work: [solar-targeting-Nigeria](https://github.com/ProfFausat/solar-targeting-Nigeria)
— household-level targeting for the same sector, deployed at
https://solar-targeting-nigeria.onrender.com/
