# Segment profile data

**GENERATED FILE — do not edit.** Regenerate with `python pipeline/profile_segments.py`.

Generated 2026-09-18 from `data/processed/nigeria_lga.db`.

Every number in `reports/segment_profiles.md` must come from here or from a source this file names. Restate no number you did not generate.

---

## 1. The five market types

| # | market type            | LGAs | unserved (M) | % of segmented unserved | electrified | stand-alone PV | suspect | off-grid market |
|---|------------------------|------|--------------|-------------------------|-------------|----------------|---------|-----------------|
| 1 | Low-Income Rural Core  | 274  | 47.6         | 56.9                    | 0.29        | 0.59           | 36      | yes             |
| 2 | Deep Off-Grid Frontier | 26   | 5.3          | 6.3                     | 0.037       | 0.72           | 5       | yes             |
| 3 | Grid-Arrival Markets   | 135  | 18.8         | 22.5                    | 0.365       | 0.099          | 29      | no              |
| 4 | Grid-Served Hinterland | 292  | 11.3         | 13.5                    | 0.827       | 0.051          | 76      | no              |
| 5 | Served Metros          | 42   | 0.7          | 0.8                     | 0.967       | 0.001          | 23      | no              |

Off-grid markets: **2 of 5**, holding **52.9M** of 83.7M unserved (**63.2%**).

---

## 2. What this does not tell you

**Coverage.** 769 of 774 LGAs are segmented. The 5 that are not:

- Bakassi (Cross River) — no population figure
- Agege (Lagos) — 549,699 people, no settlement clusters
- Ajeromi-Ifelodun (Lagos) — 1,431,755 people, no settlement clusters
- Mushin (Lagos) — 644,842 people, no settlement clusters
- Shomolu (Lagos) — 495,541 people, no settlement clusters

**Boundary cases.** 41 of 769 LGAs (5.3%) have a negative silhouette — they sit closer to a market type other than their own. Mean silhouette 0.309. By segment:

| market type              | LGAs | mean silhouette | below zero | % below zero |
|--------------------------|------|-----------------|------------|--------------|
| 1 Low-Income Rural Core  | 274  | 0.33            | 4          | 1.5          |
| 2 Deep Off-Grid Frontier | 26   | 0.344           | 1          | 3.8          |
| 3 Grid-Arrival Markets   | 135  | 0.134           | 33         | 24.4         |
| 4 Grid-Served Hinterland | 292  | 0.368           | 0          | 0            |
| 5 Served Metros          | 42   | 0.31            | 3          | 7.1          |

**Second opinion 1 — a different algorithm.** Ward agglomerative clustering on the same matrix agrees with K-Means at **ARI 0.602** across all 769 LGAs. ARI is 0 for chance agreement and 1 for identical partitions. Interpretation belongs in the profile, not here -- a generated file that judges its own numbers would have to be rewritten every time they moved.

**Second opinion 2 — the data-quality dual track.** Re-clustering only the 600 LGAs whose GEP data is flagged `ok`, and comparing against their assignment in the full run, gives **ARI 0.807**. This is the check that tests the sql/04 finding directly: it asks whether excluding the 169 LGAs with suspect GEP data changes where the clean ones land.

**Second opinion 3 — density.** DBSCAN returns **1 cluster(s) and 57 noise points** — there are no density gaps in this data. These are divisions of a continuum, not natural kinds.

**Data quality.** Every electrification figure carries a `gep_flag`. Suspect rates differ sharply by segment, and the least trustworthy data sits where the access gap looks smallest:

| market type              | ok  | suspect | % suspect |
|--------------------------|-----|---------|-----------|
| 1 Low-Income Rural Core  | 238 | 36      | 13.1      |
| 2 Deep Off-Grid Frontier | 21  | 5       | 19.2      |
| 3 Grid-Arrival Markets   | 106 | 29      | 21.5      |
| 4 Grid-Served Hinterland | 216 | 76      | 26        |
| 5 Served Metros          | 19  | 23      | 54.8      |

**Not regenerable here** — cite the source, do not retype from memory: the k-selection curve and bootstrap stability (`pipeline/cluster.py` stdout, `reports/k_selection.png`), and the sub-clustering null table (`pipeline/subcluster.py` stdout). The poverty layer is a 2013 release; that vintage belongs beside every poverty figure.

---

## 3. Each market type

### 1. Low-Income Rural Core

*274 LGAs · 47.6M unserved · 56.9% of the national total · an off-grid market*

**Defining fact.** Poverty rate 0.46 -- the highest of the five -- across 274 LGAs holding 47.6M unserved, 57% of the national total.

**Operating step.** Build here for volume. But price for a customer the model expects to use 37 kWh a year: per Q8, low cost to serve is low revenue per connection, not a bargain. Prove affordability in one state before scaling.

**Caveat.** Cleanest data of the five: 36 of 274 LGAs flagged suspect (13%).

| indicator | this group | national |
|---|---|---|
| electrification rate | 0.290 | 0.536 |
| demand, kWh per person per year | 36.990 | 170.116 |
| poverty rate | 0.457 | 0.326 |
| travel time to town, hours | 0.574 | 0.399 |
| distance to MV line, km | 5.739 | 4.350 |
| share getting grid by 2030 | 0.112 | 0.191 |
| settlement density | 4,315 | 7,023 |
| stand-alone solar share, 2030 | 0.590 | 0.271 |
| mini-grid share, 2030 | 0.016 | 0.011 |

**Where.** Kano (29 LGAs, 5.5M), Bauchi (19 LGAs, 4.9M), Katsina (30 LGAs, 4.9M), Jigawa (25 LGAs, 4.1M), Benue (15 LGAs, 3.2M)

**Fit.** mean silhouette 0.330 · 4 of 274 below zero · 36 flagged suspect (13%)

**Nearest alternative** (informative only where the fit is poor): 4 Grid-Served Hinterland 59%, 3 Grid-Arrival Markets 35%, 2 Deep Off-Grid Frontier 6%

### 2. Deep Off-Grid Frontier

*26 LGAs · 5.3M unserved · 6.3% of the national total · an off-grid market*

**Defining fact.** Mean 37.3 km to the nearest MV line, +4.2 SD -- the most extreme value anywhere in the feature matrix. 3.7% electrified.

**Operating step.** The highest concentration of need in the country at 203,000 unserved per LGA, and at this distance the grid is not coming. Enter only alongside a partner already operating in the state.

**Caveat.** SECURITY AND LOGISTICS EXPOSURE. 12 of these 26 LGAs are in Borno. Feasibility is decided here before economics is. See the North East decision in Q8.

| indicator | this group | national |
|---|---|---|
| electrification rate | 0.037 | 0.536 |
| demand, kWh per person per year | 30.014 | 170.116 |
| poverty rate | 0.340 | 0.326 |
| travel time to town, hours | 0.950 | 0.399 |
| distance to MV line, km | 37.346 | 4.350 |
| share getting grid by 2030 | 0.202 | 0.191 |
| settlement density | 5,977 | 7,023 |
| stand-alone solar share, 2030 | 0.720 | 0.271 |
| mini-grid share, 2030 | 0.050 | 0.011 |

**Where.** Borno (12 LGAs, 2.5M), Niger (2 LGAs, 0.5M), Kogi (3 LGAs, 0.5M), Adamawa (2 LGAs, 0.5M), Taraba (2 LGAs, 0.4M)

**Fit.** mean silhouette 0.344 · 1 of 26 below zero · 5 flagged suspect (19%)

**Nearest alternative** (informative only where the fit is poor): 1 Low-Income Rural Core 92%, 3 Grid-Arrival Markets 8%

### 3. Grid-Arrival Markets

*135 LGAs · 18.8M unserved · 22.5% of the national total · NOT an off-grid market*

**Defining fact.** 54.4% of population scheduled for new grid connection by 2030 -- more than double any other segment.

**Operating step.** Do not place long-lived assets. 18.8M unserved is a real number, but the grid reaches most of them within the planning horizon. If entering, sell portable or removable systems, or contract around the connection date.

**Caveat.** Stranded-asset risk is the defining commercial fact, not a footnote. 29 of 135 flagged suspect (21%).

| indicator | this group | national |
|---|---|---|
| electrification rate | 0.365 | 0.536 |
| demand, kWh per person per year | 158.537 | 170.116 |
| poverty rate | 0.297 | 0.326 |
| travel time to town, hours | 0.567 | 0.399 |
| distance to MV line, km | 3.987 | 4.350 |
| share getting grid by 2030 | 0.544 | 0.191 |
| settlement density | 9,090 | 7,023 |
| stand-alone solar share, 2030 | 0.099 | 0.271 |
| mini-grid share, 2030 | 0.016 | 0.011 |

**Where.** Cross River (13 LGAs, 2.0M), Akwa Ibom (11 LGAs, 1.3M), Kogi (8 LGAs, 1.3M), Kaduna (6 LGAs, 1.2M), Oyo (9 LGAs, 1.1M)

**Fit.** mean silhouette 0.134 · 33 of 135 below zero · 29 flagged suspect (21%)

**Nearest alternative** (informative only where the fit is poor): 1 Low-Income Rural Core 61%, 4 Grid-Served Hinterland 38%, 5 Served Metros 1%

### 4. Grid-Served Hinterland

*292 LGAs · 11.3M unserved · 13.5% of the national total · NOT an off-grid market*

**Defining fact.** 82.7% already electrified and 0.9 km from an MV line. Grid arrival is BELOW average because little is left to connect.

**Operating step.** Not an access market. The opportunity is reliability and backup -- a different product, a different sales motion, and a different customer conversation from anything in segments 1 and 2.

**Caveat.** 76 of 292 flagged suspect (26%).

| indicator | this group | national |
|---|---|---|
| electrification rate | 0.827 | 0.536 |
| demand, kWh per person per year | 235.429 | 170.116 |
| poverty rate | 0.232 | 0.326 |
| travel time to town, hours | 0.145 | 0.399 |
| distance to MV line, km | 0.851 | 4.350 |
| share getting grid by 2030 | 0.122 | 0.191 |
| settlement density | 6,439 | 7,023 |
| stand-alone solar share, 2030 | 0.051 | 0.271 |
| mini-grid share, 2030 | 0.002 | 0.011 |

**Where.** Kano (9 LGAs, 0.8M), Akwa Ibom (20 LGAs, 0.8M), Imo (22 LGAs, 0.8M), Oyo (15 LGAs, 0.7M), Kaduna (8 LGAs, 0.6M)

**Fit.** mean silhouette 0.368 · 0 of 292 below zero · 76 flagged suspect (26%)

**Nearest alternative** (informative only where the fit is poor): 1 Low-Income Rural Core 49%, 5 Served Metros 30%, 3 Grid-Arrival Markets 21%

### 5. Served Metros

*42 LGAs · 0.7M unserved · 0.8% of the national total · NOT an off-grid market*

**Defining fact.** 96.7% electrified, 708 kWh per person per year, settlement density 22,750 -- the top of every scale.

**Operating step.** Not an off-grid market. Deprioritise entirely.

**Caveat.** LEAST TRUSTWORTHY DATA IN THE COUNTRY: 23 of 42 LGAs flagged suspect (55%), four times the rate in segment 1 of this ordering. The small remaining access gap it appears to show may not be real.

| indicator | this group | national |
|---|---|---|
| electrification rate | 0.967 | 0.536 |
| demand, kWh per person per year | 708.473 | 170.116 |
| poverty rate | 0.217 | 0.326 |
| travel time to town, hours | 0.142 | 0.399 |
| distance to MV line, km | 0.353 | 4.350 |
| share getting grid by 2030 | 0.040 | 0.191 |
| settlement density | 22,750 | 7,023 |
| stand-alone solar share, 2030 | 0.001 | 0.271 |
| mini-grid share, 2030 | 0.000 | 0.011 |

**Where.** Rivers (7 LGAs, 0.2M), Anambra (3 LGAs, 0.1M), Oyo (8 LGAs, 0.1M), Kogi (1 LGAs, 0.1M), Lagos (11 LGAs, 0.1M)

**Fit.** mean silhouette 0.310 · 3 of 42 below zero · 23 flagged suspect (55%)

**Nearest alternative** (informative only where the fit is poor): 4 Grid-Served Hinterland 100%

---

## 4. Inside the largest segment

Parent: **Low-Income Rural Core** — 274 LGAs, 47.6M unserved.

| # | sub-type             | LGAs | unserved (M) | % of segment | stand-alone PV | grid by 2030 | suspect | off-grid market |
|---|----------------------|------|--------------|--------------|----------------|--------------|---------|-----------------|
| 1 | Off-Plan Grid Edge   | 115  | 17.3         | 36.2         | 0.54           | 0.07         | 9       | yes             |
| 2 | Solar-Default Remote | 63   | 13.3         | 28           | 0.751          | 0.052        | 10      | yes             |
| 3 | Lower-Poverty Rural  | 77   | 14.2         | 29.8         | 0.618          | 0.18         | 15      | yes             |
| 4 | Grid-Bound Exception | 19   | 2.9          | 6            | 0.24           | 0.291        | 2       | no              |

### Low-Income Rural Core -> Off-Plan Grid Edge

*115 LGAs · 17.3M unserved · an off-grid market*

**Defining fact.** 3.5 km from a medium-voltage line yet only 7 percent scheduled for a grid connection by 2030. Neither number is extreme alone -- sub 1 is closer at 3.2 km, sub 3 is lower at 5 percent -- the conjunction is what no other sub-type has. Largest block: 115 LGAs, 17.3M unserved, 36.2 percent of the segment.

**Operating step.** Enter here first. Logistics are cheap at 3.5 km from existing infrastructure with the shortest travel times in the segment, and the grid is not scheduled to close the gap. Stand-alone solar is least-cost for 54 percent of its people and mini-grid for under 1 percent, so plan household systems rather than distribution.

**Caveat.** Has no extreme on any single variable. It is the centre of the segment, not a peak, and the write-up should say so. 9 of 115 flagged suspect (8 percent), the cleanest data of the four. A corroborating but weak signal: 95 percent of its LGAs are nearest to Grid-Served Hinterland -- suggestive, not independent evidence, because a well-fitting group (mean silhouette 0.312) has a largely arbitrary second-nearest.

| indicator | this group | segment |
|---|---|---|
| electrification rate | 0.388 | 0.290 |
| demand, kWh per person per year | 30.975 | 36.990 |
| poverty rate | 0.491 | 0.457 |
| travel time to town, hours | 0.382 | 0.574 |
| distance to MV line, km | 3.463 | 5.739 |
| share getting grid by 2030 | 0.070 | 0.112 |
| settlement density | 4,896 | 4,315 |
| stand-alone solar share, 2030 | 0.540 | 0.590 |
| mini-grid share, 2030 | 0.007 | 0.016 |

**Where.** Katsina (25 LGAs, 3.8M), Kano (18 LGAs, 3.2M), Jigawa (16 LGAs, 2.3M), Bauchi (8 LGAs, 1.4M), Zamfara (7 LGAs, 1.3M)

### Low-Income Rural Core -> Solar-Default Remote

*63 LGAs · 13.3M unserved · an off-grid market*

**Defining fact.** Stand-alone solar is least-cost for 75.1 percent of its people, the highest share anywhere in the country. 9.6 km to a medium-voltage line and 0.96 hours travel to town, both the highest in the segment.

**Operating step.** The purest off-grid market in the volume segment and the best-formed of the four -- mean parent silhouette 0.424, not one LGA below zero. Only 5 percent are scheduled for grid connection, so asset life is not at risk. Price and staff for a cost to serve roughly triple sub 2 at a similar revenue per connection.

**Caveat.** NAMED ON A CONSEQUENCE, NOT ITS SHARPEST SEPARATOR -- see the header. Do not read 9.6 km as comparable to Deep Off-Grid Frontier at 37.3 km. 10 of 63 flagged suspect (16 percent).

| indicator | this group | segment |
|---|---|---|
| electrification rate | 0.187 | 0.290 |
| demand, kWh per person per year | 19.112 | 36.990 |
| poverty rate | 0.513 | 0.457 |
| travel time to town, hours | 0.958 | 0.574 |
| distance to MV line, km | 9.625 | 5.739 |
| share getting grid by 2030 | 0.052 | 0.112 |
| settlement density | 4,407 | 4,315 |
| stand-alone solar share, 2030 | 0.751 | 0.590 |
| mini-grid share, 2030 | 0.018 | 0.016 |

**Where.** Bauchi (7 LGAs, 2.6M), Yobe (11 LGAs, 1.9M), Jigawa (9 LGAs, 1.8M), Zamfara (6 LGAs, 1.7M), Katsina (4 LGAs, 0.8M)

### Low-Income Rural Core -> Lower-Poverty Rural

*77 LGAs · 14.2M unserved · an off-grid market*

**Defining fact.** Poverty rate 0.322 against 0.491, 0.513 and 0.608 for the other three -- the only clean single-variable separation in this sub-clustering. Lowest settlement density of the four at 3,734.

**Operating step.** READ THE HORIZON FIRST: 18 percent are scheduled for grid connection by 2030, triple sub 2 at 7 percent and sub 3 at 5 percent. Size asset life accordingly. The offsetting fact is the reason for the name -- this is the best ability to pay in the volume market -- but the horizon leads, because only a name travels into a summary and this name carries the upside.

**Caveat.** The name puts the upside in front and the risk behind, the same structure that produced the Dense Emerging Markets error at segment level. Defensible only because 18 percent is the NATIONAL AVERAGE -- an ordinary horizon, nowhere near the 54 percent of Grid-Arrival Markets. If that stops being true, rename it. 15 of 77 flagged suspect (19 percent), the weakest data of the four.

| indicator | this group | segment |
|---|---|---|
| electrification rate | 0.191 | 0.290 |
| demand, kWh per person per year | 30.625 | 36.990 |
| poverty rate | 0.322 | 0.457 |
| travel time to town, hours | 0.620 | 0.574 |
| distance to MV line, km | 6.591 | 5.739 |
| share getting grid by 2030 | 0.180 | 0.112 |
| settlement density | 3,734 | 4,315 |
| stand-alone solar share, 2030 | 0.618 | 0.590 |
| mini-grid share, 2030 | 0.031 | 0.016 |

**Where.** Niger (12 LGAs, 1.9M), Kano (9 LGAs, 1.8M), Benue (8 LGAs, 1.8M), Sokoto (7 LGAs, 1.3M), Kaduna (4 LGAs, 1.1M)

### Low-Income Rural Core -> Grid-Bound Exception

*19 LGAs · 2.9M unserved · NOT an off-grid market*

**Defining fact.** Stand-alone solar is least-cost for only 24 percent of its people, against 54 to 75 percent for the other three. Mini-grid takes a further 0.9 percent, so roughly three-quarters of this group is grid -- existing or planned.

**Operating step.** Not an off-grid market. Carve it out of any recommendation made about the parent segment and report it separately. 2.9M unserved people is not nothing, but the answer for them is a grid connection, not a solar product.

**Caveat.** Also the worst fit to its parent: mean parent silhouette 0.160 against 0.31 to 0.42. Geographically it is Ebonyi, Enugu, Plateau, Benue, Kwara and Oyo -- south-east and Middle Belt inside an otherwise northern segment. Demand is 159 kWh per person per year against 31 for subs 0 and 2, so the parent segment pricing advice is wrong here by more than four times.

| indicator | this group | segment |
|---|---|---|
| electrification rate | 0.444 | 0.290 |
| demand, kWh per person per year | 158.472 | 36.990 |
| poverty rate | 0.608 | 0.457 |
| travel time to town, hours | 0.278 | 0.574 |
| distance to MV line, km | 3.183 | 5.739 |
| share getting grid by 2030 | 0.291 | 0.112 |
| settlement density | 2,847 | 4,315 |
| stand-alone solar share, 2030 | 0.240 | 0.590 |
| mini-grid share, 2030 | 0.009 | 0.016 |

**Where.** Ebonyi (7 LGAs, 0.8M), Plateau (3 LGAs, 0.6M), Benue (2 LGAs, 0.6M), Enugu (4 LGAs, 0.4M), Oyo (1 LGAs, 0.2M)
