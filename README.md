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

Two findings, in the order they had to happen. The second is not trustworthy
without the first.

### 1. Nigeria's electrification data cannot speak for a quarter of the country

**And until now nobody had measured by how much.**

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

### 2. Five market types — and the largest one is really four

769 LGAs holding 83.7 million people without electricity divide into five
types on seven features
([`sql/08_cluster_features.sql`](sql/08_cluster_features.sql),
[`pipeline/cluster.py`](pipeline/cluster.py)). Names and ordering live in one
table so they cannot drift
([`sql/09_segment_names.sql`](sql/09_segment_names.sql)).

| # | Market type | LGAs | Unserved | Electrified | Stand-alone solar | Off-grid market |
|---|---|---|---|---|---|---|
| 1 | Low-Income Rural Core | 274 | 47.6M | 0.29 | 0.59 | yes |
| 2 | Deep Off-Grid Frontier | 26 | 5.3M | 0.04 | 0.72 | yes |
| 3 | Grid-Arrival Markets | 135 | 18.8M | 0.37 | 0.10 | no |
| 4 | Grid-Served Hinterland | 292 | 11.3M | 0.83 | 0.05 | no |
| 5 | Served Metros | 42 | 0.7M | 0.97 | 0.00 | no |

**Only two of the five are off-grid markets at all.** They hold 63.2% of the
unserved population. The other three are grid stories at three different stages,
and the deliverable says so rather than presenting five opportunities where
there are two.

**How firmly this stands.** Silhouette 0.309 — weak separation. Bootstrap
stability 0.992. Two independent checks, and they answer different questions.
Ward agglomerative clustering on the same matrix agrees with K-Means at **ARI
0.602** across all 769 LGAs: the broad structure survives a change of
algorithm, though the exact boundaries move. Re-clustering only the 600 LGAs
whose GEP data is flagged `ok` reproduces their assignment at **ARI 0.807**:
the segmentation is not being driven by the LGAs the data-quality test cannot
vouch for, which given the finding above is the check that matters more.
DBSCAN returns a single cluster and 57 noise points: there are no density gaps
in this data. These are **divisions of a continuum**, not natural kinds, and
every figure in `reports/` is built to say so. **41 of 769 LGAs (5.3%) have a
negative silhouette** — they sit closer to a market type other than their own.
33 of those 41 are in Grid-Arrival Markets, which is what a category defined by
being mid-transition should look like.

**The largest segment sub-divides.** `PROJECT_BRIEF.md`, written before any data
was loaded, named the failure mode "segments that only recover geography" and
committed to looking for structure *within* an obvious split if one appeared.
One did: Low-Income Rural Core is a near-solid northern block. Tested against a
null model — each feature column shuffled independently, preserving every
marginal distribution while destroying the joint structure — its 274 LGAs
divide into four types that shuffled data does not reproduce (silhouette 0.214
against a null 95th percentile of 0.156, stability ARI 0.902).
[`sql/11_subsegment_names.sql`](sql/11_subsegment_names.sql):

| # | Sub-type | LGAs | Unserved | Defining fact |
|---|---|---|---|---|
| 1 | Off-Plan Grid Edge | 115 | 17.3M | 3.5 km from a line, 7% scheduled for grid by 2030 |
| 2 | Solar-Default Remote | 63 | 13.3M | 75% least-cost served by stand-alone solar, the highest in the country |
| 3 | Lower-Poverty Rural | 77 | 14.2M | Poverty 0.32 against 0.49–0.61 |
| 4 | Grid-Bound Exception | 19 | 2.9M | 24% stand-alone solar — not an off-grid market |

Two caveats travel with that, and they are in the file rather than here only:
the excess-over-null curve is **flat** (k=3 gives +0.047, k=4 gives +0.058,
k=6 gives +0.037), so the defensible claim is *real structure, roughly three to
five types*, not *exactly four*. And **k=2 comes back negative (−0.081)** —
worse than shuffled data. The intuitive split, cutting the north in two, is the
one division this data refuses.

---

## Status

**In progress.** Stages 0 to 3 are complete, except that the business-question
catalogue holds 8 of its planned 15–20. Stage 4 — the Power BI dashboard and
the written client report — is next.

| Stage | Description | Status |
|---|---|---|
| 0 | Framing, data acquisition, provenance | Complete |
| 1 | SQL: spine, joins, analysis base, question catalogue | Complete except the catalogue (8 of 15–20) |
| 2 | Clustering: K-Means, hierarchical, DBSCAN compared | Complete |
| 2b | Sub-clustering the largest segment against a null model | Complete |
| 3 | Segment profiling and operating recommendations | Complete |
| 4 | Power BI dashboard | Not started |
| 5 | Port to PostgreSQL, MLflow-tracked pipeline | Not started |

This repository is a **SQL project whose analytical payload is clustering**, not
a clustering project that happens to use SQL. Every cleaning, joining and
aggregation step lives in `sql/` where it can be read and checked. The loader
copies files and does nothing else. The documented exceptions are
`pipeline/spatial_join.py` — SQLite has no geometry engine, so point-in-polygon
cannot be done in SQL here — and the clustering itself, which scikit-learn does
and SQLite cannot.

---

## What is here

```
sql/
  00_checks.sql              assertions — run after every rebuild
  01_build_spine.sql         the 774-LGA spine, keyed on P-code
  02_build_population.sql    LGA population, 2020
  03_analysis_base.sql       spine LEFT JOIN population -> lga_base
  04_gep_quality.sql         how far each LGA's energy data can be trusted
  05_forest.sql              tree cover loss, area-normalised, 2011 break measured
  06_poverty.sql             GADM -> COD name reconciliation, 27 pairs by hand
  07_gep_indicators.sql      population-weighted LGA energy indicators
  08_cluster_features.sql    the seven clustering features, correlations checked
  09_segment_names.sql       cluster number -> market type. The single source
  10_business_questions.sql  the query catalogue, with answers recorded
  11_subsegment_names.sql    the four sub-types inside the largest segment
  99_schema.sql              introspection queries — what is in the database
  README.md                  how the sql/ files fit together
pipeline/
  load_raw.py                raw files -> SQLite, unchanged, fails loudly
  spatial_join.py            GEP clusters -> LGA lookup (the SQL exception)
  cluster.py                 K-Means / Ward / DBSCAN, k selection, stability
  visualise.py               the four report figures, names read from SQL
  subcluster.py              is there structure inside the largest segment?
  check_subsegment_fit.py    diagnostic: does a sub-type belong to its parent?
  make_post_figure.py        a legible silhouette summary for slides and posts
  profile_segments.py        every number the Stage 3 profiles may quote
reports/
  segment_profiles.md        the nine market-type profiles -- the deliverable
  segment_profile_data.md    generated: the numbers those profiles cite
  k_selection.png            how k was chosen, and how flat the curve is
  segment_fingerprint.png    what distinguishes each market type
  segment_map.png            where each one is — small multiples
  segment_scale.png          commercial weight, sorted by size not priority
  segment_silhouette.png     one bar per LGA — the honesty check
  post_confidence.png        the same data summarised, legible at small size
  subsegment_fingerprint.png inside Low-Income Rural Core
  subsegment_map.png         where the four sub-types are
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
# load and build the analysis base
python pipeline/load_raw.py
python pipeline/spatial_join.py
sqlite3 data/processed/nigeria_lga.db < sql/01_build_spine.sql
sqlite3 data/processed/nigeria_lga.db < sql/02_build_population.sql
sqlite3 data/processed/nigeria_lga.db < sql/03_analysis_base.sql
sqlite3 data/processed/nigeria_lga.db < sql/00_checks.sql
sqlite3 data/processed/nigeria_lga.db < sql/04_gep_quality.sql

# indicators and clustering features
sqlite3 data/processed/nigeria_lga.db < sql/05_forest.sql
sqlite3 data/processed/nigeria_lga.db < sql/06_poverty.sql
sqlite3 data/processed/nigeria_lga.db < sql/07_gep_indicators.sql
sqlite3 data/processed/nigeria_lga.db < sql/08_cluster_features.sql

# segment, name, draw
python pipeline/cluster.py
sqlite3 data/processed/nigeria_lga.db < sql/09_segment_names.sql
python pipeline/visualise.py

# sub-cluster the largest segment, name, check
python pipeline/subcluster.py
sqlite3 data/processed/nigeria_lga.db < sql/11_subsegment_names.sql
python pipeline/check_subsegment_fit.py

# regenerate every number the profiles quote
python pipeline/profile_segments.py
```

`00_checks.sql` should return `PASS` on all nine checks; `04_gep_quality.sql`
returns eight more, `09_segment_names.sql` five, and `11_subsegment_names.sql`
seven. Every SQL file that produces a headline number records the answer it
produced, dated, as a comment at the foot of the file — so a rerun that gives a
different answer is visible rather than silent.

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

**774 LGAs, but 769 are segmented.** The clustering covers every LGA that has
both a population figure and at least one settlement cluster. Five do not: the
four Lagos LGAs with no GEP clusters at all (Agege, Ajeromi-Ifelodun, Mushin,
Shomolu, 3.1M people between them) and Bakassi, which has no population. They
are excluded from the segmentation and named every time the exclusion matters,
rather than quietly dropped to make a round number.

**All joins use `lga_pcode`, never `lga_name`.** The 774 LGAs carry only 768
distinct names: Bassa, Ifelodun, Irepodun, Nasarawa, Obi and Surulere each name
two LGAs in two different states. A join on name would misattribute twelve rows
and raise no error at all. Two of those names appear in the top ten most populous
LGAs, so the failure would have landed in a headline result looking entirely
plausible.

**Energy indicators carry a data-quality flag.** No LGA-level electrification
figure in this project should be read without its `gep_flag`. See the finding
above. It does not stop at the analysis: the flag is carried into every segment
profile, because the least trustworthy data in the country sits in the segment
with the smallest remaining access gap — 23 of the 42 Served Metros LGAs are
flagged `suspect`.

**A cluster number is never a market type.** scikit-learn labels clusters 0–4 in
an order decided by where the centroids happened to initialise. Those labels are
kept, permanently and unchanged, in `lga_segments.seg_kmeans`. Every figure,
table and paragraph joins to `segment_names` for the name and the display order,
so a rename is a one-row change and nothing downstream can disagree about what
"segment 3" means. `sql/09_segment_names.sql` explains why at length: an earlier
draft named one segment for its density, which was true, and the recommendation
that followed was the opposite of the right advice for the one market where an
off-grid asset is most likely to be stranded.

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

The clustering is the second. The chart every clustering write-up opens with — a
two-dimensional scatter with five tidy coloured clouds — is **not in this
repository**. A silhouette of 0.309 and a DBSCAN that finds no dense regions
both say the segments are divisions of a continuum. Projecting seven dimensions
onto two discards most of the variance and then invites a reader to judge
separation by eye in the space where it was destroyed. The figures that replaced
it report that 41 of 769 LGAs sit closer to a market type other than their own,
at full size, because a client allocating capital is entitled to know which
recommendations stand on firm ground.

---

**Prof. Fausat M. Ibrahim**
Related work: [solar-targeting-Nigeria](https://github.com/ProfFausat/solar-targeting-Nigeria)
— household-level targeting for the same sector, deployed at
https://solar-targeting-nigeria.onrender.com/
