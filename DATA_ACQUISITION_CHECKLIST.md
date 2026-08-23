# Stage 0 — Data acquisition checklist

Work down the list. For each source, I recorded what I actually got in `docs/data_provenance.md` — URL, date downloaded, licence, file format, row count, and the admin level it reports. A source I cannot cite is a source I cannot publish.

**Rule:** I download into `data/raw/` and never edited those files. Every transformation happens in SQL, where it is visible.

---

## 1. The spine — administrative boundaries and codes 

Everything else joins onto this, so it has to be right before anything else is downloaded.

- **HDX — Nigeria Subnational Administrative Boundaries (COD-AB)**
  https://data.humdata.org/dataset/cod-ab-nga
  Look for `NGA_AdminBoundaries_TabularData.xlsx` — official P-codes and names for state, senatorial district and LGA. This is the key every other table must match.
- **HDX — Nigeria Subnational Population Statistics (COD-PS)**
  https://data.humdata.org/dataset/cod-ps-nga
  Population by LGA, disaggregated by sex and age band.

**To check before moving on:** exactly 774 LGA rows, every code unique, every LGA maps to one state. If any of those fail, it should be resolved. It means a broken spine corrupts everything downstream.

## 2. Energy access (the commercial core)

- **energydata.info — Nigeria datasets**
  https://energydata.info/dataset?res_format=CSV&vocab_country_names=NGA
  To be filtered to CSV. The World Bank Nigeria Electrification Project material was built for least-cost electrification planning, which is exactly the decision this project models.
- Also worth a look: **Nigeria - Administrative Boundaries** on the same portal, to check whether their codes match HDX's.

**What I want:** any LGA- or settlement-level measure of grid access, electrification rate, or distance to network.

## 3. Population, settlement and infrastructure

- **GRID3 Nigeria** — https://grid3.org/geospatial-data-nigeria and the data hub at https://data.grid3.org
  980 datasets across 37 states and 12 sectors. Gridded population aggregated to LGA and ward; settlement extents; health facilities (v2.0, Nov 2024); some ready-made per-LGA scores. CSV and GIS formats.

**What I want:** settlement density or count per LGA, population density, and at least one service-access measure.

## 4. Environmental indicators 

- **Global Forest Watch — Nigeria** — https://www.globalforestwatch.org/dashboards/country/NGA/
  Subnational tree cover loss. To check whether the download gives admin-1 only or admin-2; if admin-1 (state), I will keep it as a state-level attribute rather than pretending to LGA precision.

## 5. Development and poverty (optional, join at state or senatorial-district level)

- **NBS / OPHI — Nigeria MPI 2022** — https://ophi.org.uk/publications/Nigeria-MPI-2022
  15 indicators over four dimensions, covering 36 states, FCT and 109 senatorial districts, from a 56,000-household survey.
  **Caution:** This is published as a PDF. Extracting the tables is real work. I will treat this as a bonus join, not a dependency. If I do extract it, I will do it once into a CSV and cite the page numbers.

---

## Indicator shortlist — the Stage 0 decision

Aiming for **12–20 numeric indicators**, each with a one-line reason an energy company should care. A rough starting frame:

| Theme | Candidate indicators | Why an operator cares |
|---|---|---|
| Demand size | population, households, population density | How many potential customers per unit of field effort |
| Energy need | electrification rate, share without grid access, distance to network | The core opportunity signal |
| Ability to pay | consumption or poverty proxies, asset ownership | Whether demand converts to revenue |
| Serviceability | settlement density, road or market access, health-facility density | Cost to serve; dense settlements are cheaper per customer |
| Environment | tree cover loss, fuelwood dependence | Your niche, and a genuine driver of clean-energy demand |
| Risk | conflict or insecurity indicators if credible and citable | Where field operations are not viable |

**Screening rule, carried from the solar feature harvest:** every candidate must be (1) available for all or nearly all LGAs, (2) measured before any expansion decision, and (3) mechanistically connected to the decision. I will write the rejections down as well as the acceptances. The discarded list was one of the strongest parts of the solar repo.

---

## Verification before Stage 1

- [ ] Every source recorded in `docs/data_provenance.md` with URL, date, licence and vintage
- [ ] Spine has 774 LGAs, unique codes, clean state mapping
- [ ] For each source: row count, key column, admin level, and % of LGAs covered
- [ ] Missingness noted per indicator — anything below ~85% LGA coverage is a candidate for rejection or for aggregation to a coarser level
- [ ] A written note on how LGA names differ between sources (they will), since reconciling them is the first real SQL task

**If LGA coverage turns out to be poor across most sources**, the fallback is the 109 senatorial districts. I will decide that before Stage 1, not during it.
