# Stage 0 — Data acquisition checklist

**Status: substantially complete. Two optional sources outstanding.**

For each source I record what I actually got in `docs/data_provenance.md` — URL,
date downloaded, licence, file format, row count, and the admin level it
reports. A source I cannot cite is a source I cannot publish.

**Rule:** I download into `data/raw/` and never edit those files. Every
transformation happens in SQL, where it is visible. The single exception is the
point-in-polygon assignment in `pipeline/spatial_join.py`, which is documented
in that file and forced by SQLite having no geometry engine.

---

## Acquired

### 1. The spine — administrative boundaries and codes ✔

**HDX — Nigeria Subnational Administrative Boundaries (COD-AB)**
https://data.humdata.org/dataset/cod-ab-nga · CC BY-IGO

- `nga_admin_boundaries.xlsx` — tabular: 774 LGAs, 37 states, 109 senatorial
  districts, with P-codes, areas and centroids.
- `nga_admin_boundaries.shp.zip` — the same boundaries as polygons, needed for
  the spatial join.

**Checked and passed:** exactly 774 LGA rows, every code unique, every LGA maps
to one state.

### 2. Population ✔

**HDX — Nigeria Subnational Population Statistics (COD-PS)**
https://data.humdata.org/dataset/cod-ps-nga · CC BY-IGO

- `nga_admpop_2020.xlsx` — the 2020 legacy release, the only one published at
  LGA level. 773 of 774 LGAs.
- `nga_admpop_adm1_2022.csv`, `nga_admpop_adm0_2022.csv` — retained as
  cross-checks, **not** as inputs. See provenance note 3.
- `nga_admgz.xlsx` — gazetteer with alternate name spellings, for reconciling
  external sources that key on names rather than codes.

### 3. Energy access — the commercial core ✔

**Global Electrification Platform (GEP) V2, Nigeria**
https://energydata.info/dataset/nigeria-global-electrification-platform-gep · CC BY 4.0

`ng-2-0_0_0_0_0_0.csv.gz` — 708,536 settlement clusters, 81 columns. Supplies
most of the indicator shortlist in one file: electrification status today,
least-cost technology to 2030, distance to grid, transformers and substations,
demand tiers, investment per capita, night lights, travel time, road distance,
health facilities, schools, solar irradiation, and population projections.

**Two things about this source are worth recording.**

*Access.* It is distributed only as a 7.7 GB archive of all 95 scenarios — 96
files, in fact — with no per-scenario download. The Explorer's "Source Data"
link resolves to the same archive. Pre-signed URLs expire in about four hours
while the transfer needs about seven at the speed I could achieve. Two browser
attempts and one `curl` attempt failed, the last after 47 minutes and 862 MB. I
completed it by downloading the archive on a Google Colab machine, extracting
the single 389 MB file I needed, compressing it to 85 MB and bringing that home.

*Scenario identity.* The filenames are coded (`0_0_0_0_0_0`) and no document I
could find maps codes to scenario settings. Rather than assume the coding
followed the Explorer's option order, I tested it: the first position was
confirmed by demand heterogeneity — 13,872 distinct per-capita demand values in
`0_` versus 611 concentrated at a single value in `1_` and `2_`, which is the
signature of bottom-up versus top-down targets — and the third by grid LCOE
minima of exactly 0.052 and 0.065 $/kWh, matching the two documented grid cost
settings. Details in `docs/data_provenance.md`.

---

## Rejected, with reasons

The discarded list matters as much as the accepted one.

**Superseded by GEP** — these were on my original list and are no longer needed,
because GEP supplies the same measures at finer grain from one consistent model:

- **GRID3 Nigeria** (settlement density, service access). GEP's 708,536 clusters
  give settlement counts per LGA directly, plus facility counts per cluster.
- **NMIS health facility data (2014)**. GEP carries health facility counts
  (`Cat_1`–`Cat_3`) and schools, and is current to the model rather than 2014.

**Fails the coverage rule** — single state or single utility, so most of the 774
LGAs would have no value:

- Kano, Katsina and Jigawa state settlement datasets
- Kaduna Electricity Distribution Company service area
- Kano Electricity Distribution Company grid map
- Lagos State rooftop solar potential (both versions)

**Wrong scale or unrelated to the decision**: What a Waste global database;
Global Airports; Belt and Road trade costs; World Integrated Trade Solution;
Global Energy Statistics Yearbook; surface water conductivity; hydropower dams;
crowdsourced price data.

**Rejected on effort, not merit** — genuinely relevant, but the work needed
exceeds what this stage can carry:

- **Medium-Voltage Distribution (Predictive)** — a modelled grid-line network.
  Converting lines into a per-LGA distance measure is GIS work, and GEP already
  provides `CurrentMVLineDist` per cluster. Revisit only if that proves
  inadequate.
- **NBS / OPHI Nigeria MPI 2022** — 15 indicators at senatorial-district level,
  but published as a PDF. Table extraction is real work and it joins at a
  coarser unit than the analysis. Bonus, not dependency.

**Cannot become an LGA indicator**: Nigeria Solar Radiation Measurement Data — a
handful of weather stations. Sparse points cannot be spread across 774 LGAs, and
GEP's `GHI` column already covers solar resource per settlement.

---

## Outstanding

### 4. Ability to pay — an independent measure

**energydata.info — Nigeria Aggregated Poverty map**
https://energydata.info/dataset/nigeria-aggregated-poverty-map

WorldPop's 1 km poverty surface, already aggregated to LGA level. Small, and
joins immediately.

**Why it still matters despite GEP.** Every ability-to-pay signal in GEP —
`Tier`, `PerCapitaDemand`, `InvestmentCapita2030` — is an *output* of the
electrification model. If I build segments entirely from one model's outputs, I
am partly clustering that model's assumptions rather than Nigeria. This is an
independent measurement, and independence is the point.

### 5. Environmental pressure — my niche

**Global Forest Watch — Nigeria** https://www.globalforestwatch.org/dashboards/country/NGA/

Subnational tree cover loss. Nothing in GEP touches environmental degradation or
fuelwood pressure, so this fills the one theme that is otherwise empty.

**Decision rule on download:** check whether the file reports admin-1 (state) or
admin-2 (LGA). If state only, I keep it as a state-level attribute and say so in
the write-up rather than pretending it varies by LGA. False precision is one of
the four named failure modes in `PROJECT_BRIEF.md`.

---

## Indicator shortlist — the Stage 0 decision

Aiming for **12–20 numeric indicators**, each with a one-line reason an energy
company should care.

| Theme | Indicators | Source | Why an operator cares |
|---|---|---|---|
| Demand size | population, households, population density, settlement count | COD-PS, GEP | How many potential customers per unit of field effort |
| Energy need | share unelectrified, distance to grid / transformer, least-cost technology mix | GEP | The core opportunity signal |
| Ability to pay | consumption tier, investment per capita, night lights, **poverty rate** | GEP, poverty map | Whether demand converts to revenue |
| Serviceability | settlement density, travel hours to town, road distance, grid penalty | GEP | Cost to serve; dense settlements are cheaper per customer |
| Environment | **tree cover loss**, solar irradiation | GFW, GEP | My niche, and a genuine driver of clean-energy demand |
| Risk | conflict or insecurity indicators if credible and citable | none yet | Where field operations are not viable |

**Screening rule, carried from the solar feature harvest:** every candidate must
be (1) available for all or nearly all LGAs, (2) measured before any expansion
decision, and (3) mechanistically connected to the decision. I write the
rejections down as well as the acceptances — the discarded list was one of the
strongest parts of the solar repo.

---

## Verification before Stage 1

- [x] Every source recorded in `docs/data_provenance.md` with URL, date, licence and vintage
- [x] Spine has 774 LGAs, unique codes, clean state mapping
- [x] For each source: row count, key column, admin level, and % of LGAs covered
- [x] Missingness noted per indicator — one LGA lacks population (Bakassi, absorbed into Akpabuyo by the publisher)
- [x] A written note on how LGA names differ between sources — 774 LGAs carry 768 distinct names
- [x] Unit of analysis confirmed as the LGA. At 99.87% population coverage the
      fallback to 109 senatorial districts is not needed.
- [ ] Poverty map acquired
- [ ] Tree cover loss acquired, admin level recorded
- [ ] GEP clusters assigned to LGAs and coverage per LGA measured
