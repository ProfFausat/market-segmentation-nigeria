# Data provenance

One row per file downloaded. Filled in as the files arrived, not afterwards.

All files downloaded **21 August 2026** into `data/raw/`, unmodified. Every
transformation happens in `sql/`.

| Source | File | URL | Downloaded | Licence | Vintage | Rows | Admin level | LGA coverage |
|---|---|---|---|---|---|---|---|---|
| HDX COD-AB | `nga_admin_boundaries.xlsx` | https://data.humdata.org/dataset/cod-ab-nga | 21 Aug 2026 | CC BY-IGO | Attribute `valid_on` 2019‑04‑17, version v01; resource modified 16 Apr 2026; dataset time period 17 Apr 2019 – 30 Oct 2025 | 774 (adm2 sheet); 37 adm1; 109 senatorial districts; 714 adm3 | LGA (adm2), with state and senatorial district | 774 / 774 = 100% |
| HDX COD-PS (legacy) | `nga_admpop_2020.xlsx` | https://data.humdata.org/dataset/cod-ps-nga | 21 Aug 2026 | CC BY-IGO | Projections for 2020; baseline 2006 Census; methods published 2016; resource modified 18 Jun 2021 | 773 (adm2 sheet); 37 adm1; 109 senatorial districts | LGA | 773 / 774 = 99.87% |
| HDX COD-PS 2022 | `nga_admpop_adm1_2022.csv` | https://data.humdata.org/dataset/cod-ps-nga | 21 Aug 2026 | CC BY-IGO | Projections for 2022; resource modified 11 Sep 2024 | 37 | State (adm1) | n/a — not published at LGA level |
| HDX COD-PS 2022 | `nga_admpop_adm0_2022.csv` | https://data.humdata.org/dataset/cod-ps-nga | 21 Aug 2026 | CC BY-IGO | Projections for 2022; resource modified 11 Sep 2024 | 1 | Country (adm0) | n/a |
| HDX gazetteer | `nga_admgz.xlsx` | https://data.humdata.org/dataset/cod-ps-nga | 21 Aug 2026 | CC BY-IGO | Derived from ITOS tabular data; resource modified 11 Sep 2024 | 774 (Admin2); 714 Admin3; 109 SenDist | All levels | 774 / 774 = 100% |

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

## Verification status (Stage 0 exit criteria)

- [x] Every source recorded with URL, date, licence and vintage
- [x] Spine has 774 LGAs, unique P-codes, clean state mapping
- [x] Row count, key column and admin level recorded per source
- [x] Missingness noted — one LGA lacks population, 99.87% coverage
- [x] Written note on how names differ between sources
- [x] Unit of analysis confirmed as the LGA; coverage is far above the ~85%
      threshold that would have forced the senatorial-district fallback
