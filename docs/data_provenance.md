# Data provenance

One row per file downloaded. Filled in as the files arrived, not afterwards.

Downloaded into `data/raw/`, unmodified, in two batches: the five HDX
administrative and population sources on **21 August 2026** (Stage 0), and the
three analytical sources — electrification, poverty, tree cover loss — on
**26 August 2026** (Stage 1). Every transformation happens in `sql/`.

| Source | File | URL | Downloaded | Licence | Vintage | Rows | Admin level | LGA coverage |
|---|---|---|---|---|---|---|---|---|
| HDX COD-AB | `nga_admin_boundaries.xlsx` | https://data.humdata.org/dataset/cod-ab-nga | 21 Aug 2026 | CC BY-IGO | Attribute `valid_on` 2019‑04‑17, version v01; resource modified 16 Apr 2026; dataset time period 17 Apr 2019 – 30 Oct 2025 | 774 (adm2 sheet); 37 adm1; 109 senatorial districts; 714 adm3 | LGA (adm2), with state and senatorial district | 774 / 774 = 100% |
| HDX COD-PS (legacy) | `nga_admpop_2020.xlsx` | https://data.humdata.org/dataset/cod-ps-nga | 21 Aug 2026 | CC BY-IGO | Projections for 2020; baseline 2006 Census; methods published 2016; resource modified 18 Jun 2021 | 773 (adm2 sheet); 37 adm1; 109 senatorial districts | LGA | 773 / 774 = 99.87% |
| HDX COD-PS 2022 | `nga_admpop_adm1_2022.csv` | https://data.humdata.org/dataset/cod-ps-nga | 21 Aug 2026 | CC BY-IGO | Projections for 2022; resource modified 11 Sep 2024 | 37 | State (adm1) | n/a — not published at LGA level |
| HDX COD-PS 2022 | `nga_admpop_adm0_2022.csv` | https://data.humdata.org/dataset/cod-ps-nga | 21 Aug 2026 | CC BY-IGO | Projections for 2022; resource modified 11 Sep 2024 | 1 | Country (adm0) | n/a |
| HDX gazetteer | `nga_admgz.xlsx` | https://data.humdata.org/dataset/cod-ps-nga | 21 Aug 2026 | CC BY-IGO | Derived from ITOS tabular data; resource modified 11 Sep 2024 | 774 (Admin2); 714 Admin3; 109 SenDist | All levels | 774 / 774 = 100% |
| GEP V2 (World Bank) | `ng-2-0_0_0_0_0_0.csv.gz` | https://energydata.info/dataset/nigeria-global-electrification-platform-gep | 26 Aug 2026 | CC BY 4.0 | Dataset created 2019; page last updated 12 Jun 2025; population field is `Pop2020` | 708,536 settlement clusters, 81 columns | Settlement cluster — **no admin identifier**, see note 6 | 769 / 774 LGAs contain at least one cluster |
| Poverty (KTH / WorldPop) | `povertyrate.csv` | https://energydata.info/dataset/nigeria-aggregated-poverty-map | 26 Aug 2026 | CC0 1.0 | **Release year 2013**; page last updated 17 Jul 2017; derived from WorldPop's 1 km Nigeria poverty surface | 775 | LGA, on **GADM** boundaries — not the COD, see note 7 | not yet joined; 775 GADM units vs 774 COD |
| Tree cover loss (GFW / Hansen-UMD) | `gfw_by_region/treecover_loss_by_region__ha.csv` | https://www.globalforestwatch.org/dashboards/country/NGA/ | 26 Aug 2026 (licence read 27 Aug 2026) | CC BY 4.0 | 30% canopy threshold, annual loss 2001–2025; **methodology changes at 2011**, see note 8 | 853 state-years, not 37 × 25 = 925 | State (adm1), on **GADM v3.6** — not the COD, see note 8 | n/a — state-level attribute |
| GFW state lookup | `gfw_by_region/adm1_metadata.csv` | as above | 26 Aug 2026 | CC BY 4.0 | shipped with the same download; codes 1–37 alphabetical | 37 | State (adm1), GADM v3.6 | n/a |

### Licence and attribution

**cod-ps-nga** (population files and gazetteer) — read from the dataset page's
Additional information panel, 21 August 2026:

- **License:** Creative Commons Attribution for Intergovernmental Organisations
  (**CC BY-IGO**)
- **Source:** UNFPA and United States Census Bureau – PEPFAR program
- **Contributor:** UNFPA
- **Time period of the dataset:** 01 March 2022 – 31 March 2022
- **Expected update frequency:** As needed
- **Methodology:** see the metadata tab on each resource

CC BY-IGO **requires attribution**, so the published README must credit UNFPA
and the US Census Bureau PEPFAR program and name the licence. This is not
optional politeness — it is the licence condition.

**cod-ab-nga** (boundaries) — read from the dataset page, 21 August 2026:

- **License:** Creative Commons Attribution for Intergovernmental Organisations
  (**CC BY-IGO**)
- **Source:** Office for the Surveyor General of the Federation of Nigeria
  (OSGOF), eHealth, United Nations Cartographic Section (UNCS)
- **Contributor:** OCHA Field Information Services Section (FISS)
- **Time period of the dataset:** 17 April 2019 – 30 October 2025
- **Expected update frequency:** Every year

Both datasets are CC BY-IGO, but the sources and contributors are entirely
different — which is why each was checked separately rather than one being
assumed from the other.

Note: the CC BY 4.0 statement in the HDX site footer covers HDX's own website
content, not the datasets. Each dataset carries its own licence field.

**GEP V2** (electrification) — read from the dataset page's "About this data"
panel, 27 August 2026:

- **License:** Creative Commons Attribution 4.0 (**CC BY 4.0**)
- **Organisation:** World Bank Group
- **Created:** 2019 · **Last updated:** 12 June 2025
- No citation format is requested on the page; CC BY 4.0 still requires
  attribution, so the README names the World Bank and the licence.

**Nigeria Aggregated Poverty map** — same panel, 27 August 2026:

- **License:** **CC0 1.0** (public domain dedication — no attribution required)
- **Organisation:** KTH Royal Institute of Technology, Stockholm
- **Release year:** 2013 · **Last updated:** 17 July 2017
- **Derived from:** WorldPop's 1 km Nigeria poverty surface, aggregated to LGA

CC0 imposes no obligation, but this project attributes it anyway. A reader
cannot judge a poverty figure without knowing it came from a 2013 layer.

**Global Forest Watch / Hansen-UMD** (tree cover loss) — read 27 August 2026
from the widget's information panel and from the upstream UMD Global Forest
Change download page:

- **License:** Creative Commons Attribution 4.0 International (**CC BY 4.0**)
- **Source, as GFW states it:** Tree cover loss — Hansen/UMD/Google/USGS/NASA;
  administrative boundaries — Global Administrative Areas database (**GADM**),
  version 3.6
- **Credit required when the data are displayed**, in UMD's exact words:
  `Source: Hansen/UMD/Google/USGS/NASA`
- **Credit required when the data are cited:** Hansen, M. C., P. V. Potapov,
  R. Moore, M. Hancher, S. A. Turubanova, A. Tyukavina, D. Thau, S. V. Stehman,
  S. J. Goetz, T. R. Loveland, A. Kommareddy, A. Egorov, L. Chini, C. O. Justice
  and J. R. G. Townshend. 2013. "High-Resolution Global Maps of 21st-Century
  Forest Cover Change." *Science* 342 (15 November): 850–53.
- **Platform citation, as GFW gives it:** Global Forest Watch. "Location of tree
  cover loss in Nigeria". Accessed 27/08/2026 from www.globalforestwatch.org.

Two things about how this was read, both recorded rather than smoothed over.

The dashboard URL now returns **HTTP 302 to `globalnaturewatch.org`**, a
successor site maintained by Vizzuality. The URL the files were downloaded from
on 26 August is not the URL that resolves today. The files in `data/raw/` are
unchanged and their checksums are in `MANIFEST.csv`; the address is what moved.

The licence text was read from UMD's **GFC-2019 v1.7** page, whose coverage is
2000–2019. The downloaded data runs to 2025 and therefore comes from a later
version. CC BY 4.0 and the credit lines have been constant across Hansen
releases, but this is a licence read from a neighbouring version of the product,
not from the exact one, and it is written down that way.

### Attribution line for the README

CC BY-IGO requires attribution for both datasets. Paste-ready:

> Administrative boundaries: Nigeria Subnational Administrative Boundaries
> (COD-AB), Office for the Surveyor General of the Federation of Nigeria
> (OSGOF), eHealth and the United Nations Cartographic Section (UNCS), via
> OCHA Field Information Services Section on the Humanitarian Data Exchange.
> Licensed CC BY-IGO. Accessed 21 August 2026.
>
> Population: Nigeria Subnational Population Statistics (COD-PS, 2020 legacy
> release), UNFPA and the United States Census Bureau PEPFAR program, via UNFPA
> on the Humanitarian Data Exchange. Licensed CC BY-IGO. Accessed 21 August 2026.
>
> Electrification: Nigeria — Global Electrification Platform (GEP) V2, World
> Bank Group, via energydata.info. Licensed CC BY 4.0. Accessed 26 August 2026.
> Scenario `ng-2-0_0_0_0_0_0`.
>
> Poverty: Nigeria Aggregated Poverty map, KTH Royal Institute of Technology,
> derived from WorldPop, via energydata.info. CC0 1.0. Release year 2013.
> Accessed 26 August 2026.

> Tree cover loss: Hansen/UMD/Google/USGS/NASA, via Global Forest Watch,
> "Location of tree cover loss in Nigeria", accessed 27 August 2026 from
> www.globalforestwatch.org. Licensed CC BY 4.0. Underlying method: Hansen et
> al., *Science* 342 (2013): 850–53.

CC BY 4.0 requires the credit line to appear wherever the data are **displayed**,
not only where they are cited. Any chart or dashboard panel built on tree cover
loss carries `Source: Hansen/UMD/Google/USGS/NASA` on the panel itself. That is
the licence condition, not a stylistic choice.

### "Modified" is not "vintage"

The boundaries resource was **modified 16 April 2026**, but every row in it
carries `valid_on 2019-04-17` and `version v01`. The file was republished
recently; the boundaries it describes were endorsed in 2019. Citing the
modification date as the data's vintage would overstate how current the
boundaries are by seven years. Both dates are recorded above for that reason.

The dataset also updates **annually**, so these files will drift. That is what
the row-count assertions in `pipeline/load_raw.py` exist to catch.

## Source detail — COD-PS 2020

From the workbook's own Metadata sheet:

- Baseline population: **2006 Census**
- Reference year of projections: **2020**
- Source: United States Census Bureau, PEPFAR subnational population programme
- Methods: published 2016 (methodology PDF linked from the workbook)
- ADM2 label: Local Government Area — **773 units**, stated by the publisher
- Disaggregation: 5-year age groups, male and female, open-ended group 80+
- National total: 204,909,220

## Notes on discrepancies

### 1. The 2022 release does not cover LGAs

The current COD-PS release for Nigeria publishes **admin levels 0 and 1 only**.
There is no LGA-level population file in it, and the accompanying technical note
is titled for levels 0–1 as well. LGA population therefore comes from the **2020
release, which HDX marks LEGACY**.

### 2. Bakassi has no population figure — 773 rows, not 774

`nga_admpop_adm2_2020` covers 773 of the 774 LGAs. The absent unit is
**Bakassi, NG009005, Cross River South**.

This is disclosed by the publisher rather than hidden. The workbook's Metadata
sheet states "# of ADM2 unites: 773", its gazetteer sheet sets `CODPSMATCH` to 1
for every LGA except Bakassi, which is 0, and the HDX dataset page states the
reason outright in its Caveats / Comments field:

> COD-AB ADM2 feature "Bakassi" [NG009005] is not represented, but is thought to
> be uninhabited. Any actual population will be incorporated in the "Akpabuyo"
> [NG009003] record.
>
> — HDX, cod-ps-nga, Caveats / Comments, read 21 August 2026

**The population is therefore absorbed, not lost.** This is why the 773 LGA
figures still sum exactly to the publisher's national total of 204,909,220 —
nobody has been dropped from the count.

Two consequences for the analysis:

1. Bakassi's NULL means "no resident population, per the publisher", not
   "value unknown". It cannot be imputed, and it will fall out of any
   density-based clustering. That exclusion must be stated in the write-up
   rather than left to be noticed.
2. **Akpabuyo's density is marginally overstated.** Its population may include
   Bakassi residents while its `area_sqkm` covers only Akpabuyo. Bakassi is
   4.2 km², so the distortion is negligible in practice — but it is a real
   boundary-versus-attribute mismatch and should not be discovered later by
   someone else.

Handled in `03_analysis_base.sql` by a LEFT JOIN, so `lga_base` keeps all 774
rows with a NULL population for Bakassi. An INNER JOIN would have dropped the
row silently and made every later claim of "774 LGAs" false.

**Corroborated from both sides.** The boundaries dataset (cod-ab-nga) carries
the matching caveat independently:

> ADM2 feature "Bakassi" [NG009005] is not represented in the COD-PS, but is
> thought to be uninhabited. Any actual population will be incorporated in the
> "Akpabuyo" [NG009003] COD-PS record.
>
> — HDX, cod-ab-nga, Caveats / Comments, read 21 August 2026

Two separate dataset pages, maintained by different contributors, state the same
thing. That is as well-sourced as this kind of detail gets.

*Other caveats recorded on cod-ab-nga, noted for completeness:* admin level 3
boundaries are "developed for operational purposes only", and two wards in
Ngala, Borno State (Sagir and Wurge) are not demarcated in the shapefile.
Neither affects this project, which works at admin level 2 — but if the analysis
ever descends to ward level, both matter.

*Note on how this entry was reached:* an earlier draft attributed the absence to
the 2002 ICJ ruling and the 2006 transfer of the Bakassi peninsula to Cameroon.
That was an inference from the unusually small area figure, not a sourced claim,
and it was wrong about the publisher's stated reason. It was replaced once the
Caveats field was read. The geopolitical history may well explain *why* the
peninsula is uninhabited, but that is a separate claim requiring its own source.

### 3. The 2020 and 2022 releases must not be mixed

Comparing state totals across the two releases gives changes over two years of:

| State | 2020 → 2022 |
|---|---|
| Federal Capital Territory | −36.6% |
| Akwa Ibom | −12.1% |
| Lagos | −9.3% |
| Katsina | +28.8% |
| Zamfara | +27.7% |
| Sokoto | +27.1% |

National change over the same period is +5.8%, or about 2.9% a year, which is
plausible. The state-level figures are not: populations do not move like that in
twenty-four months. The two releases rest on different producers and methods —
the 2020 file is a US Census Bureau projection off the 2006 census.

**Consequence for the analysis.** Rescaling 2020 LGA shares onto 2022 state
totals was considered and rejected. It would have pushed every FCT LGA down by a
third and every Katsina LGA up by a quarter, and presented a methodological
break as population change. The column is named `pop_2020` and is cited to the
legacy release. The 2022 files stay in `data/raw/` as a documented discrepancy
and a cross-check, not as an input.

### 4. LGA names do not uniquely identify LGAs

774 LGAs carry only **768 distinct names**. Six names each belong to two
different LGAs in two different states:

`Bassa` · `Ifelodun` · `Irepodun` · `Nasarawa` · `Obi` · `Surulere`

All joins use `lga_pcode`. A join on name would misattribute twelve rows and
raise no error. Two of these names appear in the top ten most populous LGAs,
so the failure would have surfaced immediately in a headline result and looked
entirely reasonable.

The gazetteer (`nga_admgz.xlsx`, sheets Admin2 and Admin3) carries
`admin2RefName`, `admin2AltName1_en` and `admin2AltName2_en`, and is the
reference for reconciling spellings when external sources are joined in.

### 5. A spreadsheet row count is not a record count

Sheet `nga_admpop_adm1_2020` reads as 774 rows, of which only 37 hold data. The
remaining 737 carry a single fill-down value in `ADM0_PCODE` and nothing else.
`pipeline/load_raw.py` therefore drops rows with a null key column before
asserting row counts, so the assertion tests records rather than whatever the
parser happened to reach.

### 6. GEP carries coordinates, not an LGA — and the assignment is lossy

GEP publishes 708,536 settlement clusters with longitude and latitude and no
admin-2 identifier. `pipeline/spatial_join.py` assigns each to the LGA polygon
containing its single representative point — the one documented exception to
"all transformation in SQL", because SQLite has no geometry engine.

That assignment is not free. Where a cluster is large and the LGAs beneath it
are small, one point hands an entire settlement's population to whichever LGA it
happens to land in. Measured two ways in `sql/04_gep_quality.sql`, this affects
**169 of 774 LGAs and 54.4 million people**; 8.1 million are attributed to the
wrong *state*. Nothing is lost nationally — GEP's total is 1.006× the census
projection — so this is redistribution, not measurement error.

Every GEP-derived indicator therefore carries a `gep_flag`. Full method and its
nine-point review: `docs/gep_quality_review.md`.

**Not yet used, and worth knowing:** the same dataset page publishes a
**Settlement Clusters (SHP ZIP)** resource — the cluster geometries themselves.
Overlaying polygons instead of assigning centroids would remove most of this
problem at source rather than measuring it. Recorded here as a Stage 2+ option,
not done.

### 7. The poverty map is a 2013 layer on different boundaries

Two things must travel with any poverty figure from this source.

**Vintage.** The dataset's release year is 2013 and it was last touched in 2017.
It is being joined to 2020 population on 2019-endorsed boundaries. That is a
seven-year gap and it must be stated wherever a poverty number appears.

**Boundaries.** It has 775 rows, not 774, because it uses **GADM** units rather
than the COD, and it is keyed on **names** rather than P-codes. Note 4 of this
document explains why a name join is dangerous here: 774 LGAs carry only 768
distinct names. The reconciliation is deliberately deferred to SQL, will be done
explicitly, and every unmatched name will be listed rather than dropped.

### 8. Tree cover loss carries four separate cautions

**a. Absence is recorded as absence, not as zero.**
`treecover_loss_by_region__ha.csv` holds **853 state-year rows, not 37 × 25 =
925**. A state-year with no recorded loss is missing from the file rather than
present with a zero. Aggregating without accounting for that would compute means
over the wrong denominator and make the worst-affected states look average.

**b. There is a methodology break at 2011.** GFW's own widget states it: *"The
data from 2011 onward were produced with an updated methodology that may capture
additional loss. Comparisons between the original 2001-2010 data and future
years should be performed with caution."*

This is the same class of problem as the COD-PS 2020/2022 break in note 3, and
it gets the same answer. A single 2001–2025 total per state would sum across a
change in the instrument and present it as a change in Nigeria's forests.
**Decision: use 2011–2025 only, and say so** — or, if the full series is ever
used, report the two periods separately and never as one figure.

**c. The boundaries are GADM v3.6, not the COD.** GFW attributes loss to
administrative units from the Global Administrative Areas database — the same
boundary family as the poverty map in note 7, and a different one from the spine
this project is built on. At state level the two agree on a count of 37, which
makes it tempting to assume they agree on which 37. The mapping from
`adm1__id` 1–37 to state must be made through `adm1_metadata.csv` and then
matched to COD state names **explicitly, with unmatched names listed**. Note 4
is the reason: names are not identifiers, and a silent name join fails without
raising anything.

**d. "Tree cover loss" is not "deforestation".** GFW is explicit: loss includes
change in both natural and planted forest and need not be human-caused. It is
stand-level replacement of vegetation over 5 m detected at 30 m resolution. Used
here as a proxy for environmental pressure, it must be named as tree cover loss
in the deliverable, never as deforestation.

**e. It is state-level only**, so it enters the segmentation as a **state
attribute applied to every LGA within it** — not an LGA measurement, and
labelled as such wherever it appears.

## Verification status (Stage 0 exit criteria)

- [x] Every source recorded with URL, date, licence and vintage
- [x] Spine has 774 LGAs, unique P-codes, clean state mapping
- [x] Row count, key column and admin level recorded per source
- [x] Missingness noted — one LGA lacks population, 99.87% coverage
- [x] Written note on how names differ between sources
- [x] Unit of analysis confirmed as the LGA; coverage is far above the ~85%
      threshold that would have forced the senatorial-district fallback

## Verification status (Stage 1 sources)

Added 27 August 2026. These three sources arrived on 26 August and were not
recorded here at the time — the acquisition story went into
`DATA_ACQUISITION_CHECKLIST.md` and never reached this file. Four other files,
including `pipeline/load_raw.py`, pointed here for detail that was not present.
That gap is closed by the rows and notes above.

- [x] GEP recorded with URL, date, licence (CC BY 4.0), vintage and row count
- [x] Poverty map recorded — CC0 1.0, and its 2013 vintage flagged as a
      limitation rather than left in a metadata field
- [x] GFW recorded with URL, date, vintage and row count
- [x] **GFW licence confirmed** — CC BY 4.0, read 27 August 2026 from the widget
      information panel and the upstream UMD Global Forest Change page. Display
      credit, citation credit and the version caveat all recorded above.
- [ ] **GADM-to-COD state mapping verified** — outstanding. Two Stage 1 sources
      (GFW, poverty) use GADM boundaries; the spine uses the COD. No figure
      from either is published until the name reconciliation is done in SQL and
      its unmatched rows listed. Note 7 and note 8c.
- [x] Scenario identity of `ng-2-0_0_0_0_0_0` verified against the data itself
      rather than documentation; method in `DATA_ACQUISITION_CHECKLIST.md`
- [x] Cost of the GEP spatial join measured, not assumed — note 6
