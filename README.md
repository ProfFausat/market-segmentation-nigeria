# Market Segmentation for Off-Grid Energy Expansion in Nigeria

**Which local government areas should an off-grid energy operator prioritise for
expansion, and what does each type of market need?**

A pay-as-you-go solar company deciding where to expand faces a problem that looks
like customer targeting but sits a level above it. Before asking which household
to approach, the company must decide which *market* to enter — where to place
agents, stock, service infrastructure and credit exposure. Enter the wrong local
government area and no amount of household-level targeting will recover the cost.

Nigeria has 774 LGAs and they differ enormously in the things that determine
whether an off-grid energy business succeeds: how many people live there, how
many lack electricity, whether they can pay, and how expensive they are to serve.
Treating that variation as a ranked list loses information. LGAs are not better
and worse versions of each other — they are *different kinds of market*, and each
kind calls for a different operating model.

The output is therefore a **typology**, not a ranking: a small number of market
types, each named, profiled, and paired with what an operator should do
differently there.

---

## What this project has found so far

**Nigeria's electrification data cannot speak for a quarter of the country, and
until now nobody had measured by how much.**

The settlement-level electrification model this project depends on (World Bank
GEP) publishes 708,536 settlement clusters with coordinates but no LGA. Assigning
each to an LGA by its single representative coordinate misattributes population
wholesale wherever a cluster is large and the LGAs beneath it are small.

Two independent tests measure the damage
([`sql/04_gep_quality.sql`](sql/04_gep_quality.sql)):

| | result |
|---|---|
| LGAs whose indicators are usable without a caveat | 600 of 774 (73.4% of population) |
| LGAs flagged `suspect` | 169 |
| LGAs with no settlement clusters at all | 4 — Agege, Ajeromi-Ifelodun, Mushin, Shomolu (3.1M people) |
| People in LGAs needing a caveat | 54,439,039 (26.6%) |

Nothing is lost nationally — GEP's total is 1.006× the census projection. The
people are attributed to the wrong LGA. Maiduguri's population appears in Jere,
Kano Municipal's in Kumbotso, Onitsha South's in Ogbaru.

The second test came from auditing the first, which could only detect *net*
displacement and so cleared LGAs that had lost and gained similar numbers from
different neighbours. GEP ships its own state label on every cluster; comparing
it against the assignment found **8.1 million people in the wrong state, 87% of
them in LGAs the first test had passed.** Ado-Odo/Ota in Ogun reads 0.919 —
textbook agreement — with 77% of its attributed population belonging elsewhere.

The full methods review, all nine findings against the first version of the
measure, is in
[`docs/gep_quality_review.md`](docs/gep_quality_review.md). The finding and its
consequences for the segmentation are Q7 of
[`sql/10_business_questions.sql`](sql/10_business_questions.sql).

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
copies files and does nothing else. The one documented exception is
`pipeline/spatial_join.py`: SQLite has no geometry engine, so point-in-polygon
cannot be done in SQL here.

---

## What is here

```
sql/
  00_checks.sql              assertions — run after every rebuild
  01_build_spine.sql         the 774-LGA spine, keyed on P-code
  02_build_population.sql    LGA population, 2020
  03_analysis_base.sql       spine LEFT JOIN population -> lga_base
  04_gep_quality.sql         how far each LGA's energy data can be trusted
  10_business_questions.sql  the query catalogue, with answers recorded
  99_schema.sql              introspection queries — what is in the database
  README.md                  how the sql/ files fit together
pipeline/
  load_raw.py                raw files -> SQLite, unchanged, fails loudly
  spatial_join.py            GEP clusters -> LGA lookup (the SQL exception)
data/raw/                    source files exactly as published, plus MANIFEST.csv
docs/
  data_provenance.md         sources, licences, vintages, discrepancy notes
  gep_quality_review.md      methods review of the GEP quality measure
DATA_ACQUISITION_CHECKLIST.md  what was sought, found, rejected and why
PROJECT_BRIEF.md             framing, audience, failure modes
ROADMAP.md                   stage-by-stage plan
```

## Reproducing it

One source is too large to commit. Before running the pipeline, obtain the GEP
Nigeria results from
[energydata.info](https://energydata.info/dataset/nigeria-global-electrification-platform-gep),
extract the scenario file `ng-2-0_0_0_0_0_0.csv`, gzip it, and place
`ng-2-0_0_0_0_0_0.csv.gz` in `data/raw/`. The download is a single large archive
covering every scenario; there is no per-scenario option. Everything else in
`data/raw/` is committed.

```bash
python pipeline/load_raw.py
python pipeline/spatial_join.py
sqlite3 data/processed/nigeria_lga.db < sql/01_build_spine.sql
sqlite3 data/processed/nigeria_lga.db < sql/02_build_population.sql
sqlite3 data/processed/nigeria_lga.db < sql/03_analysis_base.sql
sqlite3 data/processed/nigeria_lga.db < sql/00_checks.sql
sqlite3 data/processed/nigeria_lga.db < sql/04_gep_quality.sql
```

`00_checks.sql` should return `PASS` on all nine checks; `04_gep_quality.sql`
returns eight more.

The loader asserts an expected row count for every source and refuses to load if
one has changed. It also records a SHA-256 for every file in `data/raw/` and
refuses to load if contents changed while the row count stayed the same. These
datasets update annually, so neither guard is decorative.

---

## Data decisions worth knowing before reading any number

Full detail in [`docs/data_provenance.md`](docs/data_provenance.md).

**Population is 2020, and deliberately not adjusted to 2022.** The current COD-PS
release for Nigeria publishes admin levels 0–1 only; there is no LGA-level
population in it. LGA figures come from the 2020 legacy release. Rescaling those
onto 2022 state totals was considered and rejected: state-level change between
the two releases runs from −36.6% (FCT) to +28.8% (Katsina) over two years, which
is a methodological break between releases, not demography. Rebasing would have
presented that break as population change. The column is named `pop_2020`.

**773 of 774 LGAs have a population figure.** Bakassi (NG009005) has none. Both
HDX dataset pages state why: it is thought to be uninhabited, and any actual
population is incorporated in the Akpabuyo (NG009003) record. The population is
absorbed, not lost, which is why the 773 figures still sum exactly to the
published national total. Bakassi is retained in `lga_base` with a NULL
population rather than dropped, so that every count of "774 LGAs" stays true.

**All joins use `lga_pcode`, never `lga_name`.** The 774 LGAs carry only 768
distinct names: Bassa, Ifelodun, Irepodun, Nasarawa, Obi and Surulere each name
two LGAs in two different states. A join on name would misattribute twelve rows
and raise no error at all. Two of those names appear in the top ten most populous
LGAs, so the failure would have landed in a headline result looking entirely
plausible.

**Energy indicators carry a data-quality flag.** No LGA-level electrification
figure in this project should be read without its `gep_flag`. See the finding
above.

---

## Data sources and attribution

**Administrative boundaries.** *Nigeria Subnational Administrative Boundaries
(COD-AB)*, Office for the Surveyor General of the Federation of Nigeria (OSGOF),
eHealth, and the United Nations Cartographic Section (UNCS), via OCHA Field
Information Services Section on the Humanitarian Data Exchange. Licensed
CC BY-IGO. Accessed 21 August 2026.
https://data.humdata.org/dataset/cod-ab-nga

**Population.** *Nigeria Subnational Population Statistics (COD-PS, 2020 legacy
release)*, UNFPA and the United States Census Bureau PEPFAR program, via UNFPA on
the Humanitarian Data Exchange. Licensed CC BY-IGO. Accessed 21 August 2026.
https://data.humdata.org/dataset/cod-ps-nga

**Electrification.** *Nigeria — Global Electrification Platform (GEP) V2*, World
Bank, via energydata.info. Licensed CC BY 4.0. Accessed 26 August 2026.
Scenario `ng-2-0_0_0_0_0_0`, whose identity was verified against the data itself
rather than against documentation — see `DATA_ACQUISITION_CHECKLIST.md`.
https://energydata.info/dataset/nigeria-global-electrification-platform-gep

**Poverty.** *Nigeria Aggregated Poverty map*, KTH Royal Institute of Technology,
derived from WorldPop, via energydata.info. CC0 1.0. Release year 2013, which is
a limitation stated wherever the figure appears rather than left in a metadata
field. Accessed 26 August 2026.
https://energydata.info/dataset/nigeria-aggregated-poverty-map

**Tree cover loss.** Source: Hansen/UMD/Google/USGS/NASA, via Global Forest
Watch, "Location of tree cover loss in Nigeria", accessed 27 August 2026 from
www.globalforestwatch.org. Licensed CC BY 4.0. Underlying method: Hansen et al.,
*Science* 342 (2013): 850–53. 30% canopy threshold, annual loss 2001–2025, on
GADM v3.6 state boundaries.

CC BY 4.0 requires that credit line wherever the data are **displayed**, not only
where they are cited — so any chart built on it carries
`Source: Hansen/UMD/Google/USGS/NASA` on the panel itself.

---

## Standard of honesty

Carried from the preceding project in this portfolio: every published number
traceable to the script that produced it, negative and inconvenient findings
reported rather than dropped, and limitations stated in the deliverable rather
than left for a reader to discover.

The GEP finding above is the working example. The first version of that measure
flagged 102 LGAs. Reviewing it found the test could not see the failure mode that
mattered most, and the corrected figure is 169. The review that produced that
correction is published alongside the code rather than absorbed into it.

---

**Prof. Fausat M. Ibrahim**
Related work: [solar-targeting-Nigeria](https://github.com/ProfFausat/solar-targeting-Nigeria)
— household-level targeting for the same sector, deployed at
https://solar-targeting-nigeria.onrender.com/
