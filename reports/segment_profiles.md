# Segment profiles

Nine profiles: five market types covering all 769 segmented local government
areas, and the four sub-types inside the largest of them. Each carries its
defining indicator, where it is, what an operator should do differently there,
and how far it can be trusted.

This is the reference document. The argument built on it — which markets to
enter, in what order, and why — is the client report in Stage 4.

**Every number here is generated, not typed.** The source is
`reports/segment_profile_data.md`, rebuilt from the database by
`python pipeline/profile_segments.py`.

---

## The five market types

| # | Market type | LGAs | Unserved | Electrified | Stand-alone solar | Off-grid market |
|---|---|---|---|---|---|---|
| 1 | Low-Income Rural Core | 274 | 47.6M | 0.290 | 0.590 | **yes** |
| 2 | Deep Off-Grid Frontier | 26 | 5.3M | 0.037 | 0.720 | **yes** |
| 3 | Grid-Arrival Markets | 135 | 18.8M | 0.365 | 0.099 | no |
| 4 | Grid-Served Hinterland | 292 | 11.3M | 0.827 | 0.051 | no |
| 5 | Served Metros | 42 | 0.7M | 0.967 | 0.001 | no |

*Ordered by descending off-grid commercial priority. `reports/segment_map.png`
shows where each one is.*

**Stand-alone solar share** is the column that decides membership: the
proportion of an LGA's population for whom a household solar system is the
least-cost route to electricity, in the World Bank's own model. At 0.590 and
0.720, segments 1 and 2 are off-grid markets. At 0.099, 0.051 and 0.001, the
other three are grid stories at three different stages — arriving, arrived,
saturated — and each is excluded for a different reason, given in its profile.

---

## Six limits that govern every profile below

1. **These are divisions of a continuum, not five kinds of place.**
   Silhouette 0.309 — weak separation — and DBSCAN finds a single cluster and
   57 noise points, so there are no gaps in this data. An LGA near a boundary
   can be argued either way and that judgement should be made locally.

2. **41 of 769 LGAs sit closer to a segment other than their own, and 33 of
   them are in Grid-Arrival Markets.** Each profile reports its own rate. A
   claim about a Grid-Arrival LGA is the weakest claim in this document; a
   claim about a Grid-Served Hinterland LGA, where not one of 292 falls below
   zero, is the strongest.

3. **No electrification figure should be read without its quality flag.** The
   underlying model assigns settlements to LGAs by a single representative
   coordinate, which misattributes population wholesale in places;
   `sql/04_gep_quality.sql` measures it at 169 of 774 LGAs. Rates differ
   sharply between segments and each profile states its own.

4. **Five LGAs are not here at all.** Agege, Ajeromi-Ifelodun, Mushin and
   Shomolu — 3,121,837 people between them, with no settlement clusters in the
   source model — and Bakassi, recorded as uninhabited. "The country" means
   the remaining 769, and the gap is concentrated in urban Lagos.

5. **Two robustness checks, testing different things.** A different algorithm
   (Ward) agrees with K-Means at ARI 0.602 across all 769: the broad structure
   survives, the exact boundaries move. Re-clustering only the 600 LGAs
   flagged `ok` reproduces their assignment at ARI 0.807: the segmentation is
   not being driven by the LGAs whose data cannot be trusted.

6. **The poverty layer is a 2013 release**, the only LGA-level poverty surface
   available for Nigeria. It separates segments robustly; it does not state
   what poverty is today in any particular LGA.

---

# 1. Low-Income Rural Core

**274 LGAs · 47.6M unserved · 56.9% of the national total · an off-grid
market**

> **Defining indicator — poverty rate 0.457, the highest of the five**, against
> a national 0.326.

The volume market, and a poor one. A quarter of the country's LGAs hold more
than half of everyone without electricity. Twenty-nine per cent are
electrified. Stand-alone solar is the least-cost answer for 59% of the
population and the grid is scheduled to reach only 11% by 2030 against a
national 19%, so an asset placed here has a full commercial life ahead of it.
On the map it is a near-solid block across the northern half of the country.

| indicator | this segment | national |
|---|---|---|
| electrification rate | 0.290 | 0.536 |
| demand, kWh per person per year | 36.990 | 170.116 |
| poverty rate | 0.457 | 0.326 |
| travel time to town, hours | 0.574 | 0.399 |
| distance to MV line, km | 5.739 | 4.350 |
| share getting grid by 2030 | 0.112 | 0.191 |
| settlement density | 4,315 | 7,023 |
| stand-alone solar share, 2030 | 0.590 | 0.271 |

**Where.** Kano (29 LGAs, 5.5M unserved), Bauchi (19, 4.9M), Katsina (30,
4.9M), Jigawa (25, 4.1M), Benue (15, 3.2M).

**What an operator does differently here.** Builds for volume, and prices for
the customer the model actually describes: **37 kWh per person per year
against a national 170**, under a quarter. The trap this segment sets is the
one Q8 names — low cost to serve usually means low revenue per connection, not
a bargain. Prove affordability in one state before a national rollout.

**How far it can be trusted.** The cleanest of the five. Mean silhouette
0.330, 4 of 274 LGAs below zero, **36 flagged `suspect` (13%)** — the lowest
rate in the country. Where it is uncertain the alternative is Grid-Served
Hinterland (59% of boundary cases), which is the direction that would matter.

**It is not one market.** 274 LGAs and 47.6 million people proved to contain
real sub-structure; see the four sub-types below.

---

# 2. Deep Off-Grid Frontier

**26 LGAs · 5.3M unserved · 6.3% of the national total · an off-grid market**

> **Defining indicator — 37.3 km to the nearest medium-voltage line**, +4.2
> standard deviations and the most extreme value anywhere in the feature
> matrix, against a national 4.35 km.

The hardest and purest off-grid market in the country. Electrification is
3.7%. Stand-alone solar is least-cost for 72% of the population and mini-grid
for a further 5% — five times the national rate, and the only segment where
mini-grids are a material part of the answer. Twenty-six LGAs carry 5.3
million unserved people: **203,000 per LGA**, the highest concentration of
need anywhere in Nigeria.

| indicator | this segment | national |
|---|---|---|
| electrification rate | 0.037 | 0.536 |
| demand, kWh per person per year | 30.014 | 170.116 |
| poverty rate | 0.340 | 0.326 |
| travel time to town, hours | 0.950 | 0.399 |
| distance to MV line, km | 37.346 | 4.350 |
| share getting grid by 2030 | 0.202 | 0.191 |
| settlement density | 5,977 | 7,023 |
| stand-alone solar share, 2030 | 0.720 | 0.271 |

**Where.** Borno (12 LGAs, 2.5M unserved), Niger (2, 0.5M), Kogi (3, 0.5M),
Adamawa (2, 0.5M), Taraba (2, 0.4M).

**What an operator does differently here.** Enters only alongside a partner
already operating in the state. At 37 km from the nearest line the grid is not
coming whatever the plan says, so asset life is secure — but travel time is
0.95 hours against a national 0.4 and cost to serve is correspondingly high.
This is not a segment in which to learn a new operating model.

**The caveat that decides it.** **Twelve of these 26 LGAs are in Borno.**
Security and logistics are not a risk to be priced here; they are the first
question, settled before the economics are examined. The deliverable reports
this segment with that caveat attached rather than dropping it.

**How far it can be trusted.** Mean silhouette 0.344, 1 of 26 below zero, 5
flagged `suspect` (19%).

---

# 3. Grid-Arrival Markets

**135 LGAs · 18.8M unserved · 22.5% of the national total · NOT an off-grid
market**

> **Defining indicator — 54.4% of the population is scheduled for a new grid
> connection by 2030**, more than double any other segment and nearly three
> times the national 19%.

The segment most likely to be entered by mistake. It holds 18.8 million people
without electricity — the second-largest pool in the country — and at 36.5%
electrified with a settlement density of 9,090 it has the surface appearance
of a growth market. Stand-alone solar is least-cost for only 9.9% of its
people, because most of them are getting a wire instead.

| indicator | this segment | national |
|---|---|---|
| electrification rate | 0.365 | 0.536 |
| demand, kWh per person per year | 158.537 | 170.116 |
| poverty rate | 0.297 | 0.326 |
| travel time to town, hours | 0.567 | 0.399 |
| distance to MV line, km | 3.987 | 4.350 |
| share getting grid by 2030 | 0.544 | 0.191 |
| settlement density | 9,090 | 7,023 |
| stand-alone solar share, 2030 | 0.099 | 0.271 |

**Where.** Cross River (13 LGAs, 2.0M unserved), Akwa Ibom (11, 1.3M), Kogi
(8, 1.3M), Kaduna (6, 1.2M), Oyo (9, 1.1M).

**What an operator does differently here.** Does not place long-lived assets.
The 18.8 million is real and so is the connection schedule that reaches most
of them inside a normal asset life. If entering at all: portable or removable
systems, or contracts written around the published connection date. This is
the one segment where the right product is defined by an exit rather than by
a customer.

**Stranded-asset risk is the defining commercial fact, not a footnote.** It is
also why the segment is named for its grid arrival rather than its density. An
earlier draft called it *Dense Emerging Markets*, which was true, and the
recommendation that name implies — move early, build scale — is the opposite
of the right advice. See `sql/09_segment_names.sql`.

**How far it can be trusted.** The least well-formed of the five. Mean
silhouette 0.134 and **33 of its 135 LGAs sit closer to another segment
(24.4%)** — 33 of the 41 boundary cases in the entire country. That is
coherent rather than alarming, since a category defined by being mid-transition
should have soft edges, but it means a claim about an individual LGA here is
the weakest in this document. 29 of 135 flagged `suspect` (21%).

---

# 4. Grid-Served Hinterland

**292 LGAs · 11.3M unserved · 13.5% of the national total · NOT an off-grid
market**

> **Defining indicator — 82.7% already electrified and 0.85 km from a
> medium-voltage line.** Its share of new grid connections is *below* the
> national average, because little is left to connect.

The largest segment by LGA count and the most settled. Demand runs at 235 kWh
per person per year against a national 170. Stand-alone solar is least-cost
for 5.1% of its people and mini-grid for 0.2%, the lowest in the country.

| indicator | this segment | national |
|---|---|---|
| electrification rate | 0.827 | 0.536 |
| demand, kWh per person per year | 235.429 | 170.116 |
| poverty rate | 0.232 | 0.326 |
| travel time to town, hours | 0.145 | 0.399 |
| distance to MV line, km | 0.851 | 4.350 |
| share getting grid by 2030 | 0.122 | 0.191 |
| settlement density | 6,439 | 7,023 |
| stand-alone solar share, 2030 | 0.051 | 0.271 |

**Where.** Kano (9 LGAs, 0.8M unserved), Akwa Ibom (20, 0.8M), Imo (22,
0.8M), Oyo (15, 0.7M), Kaduna (8, 0.6M).

**What an operator does differently here.** Sells a different product. The
11.3 million unserved are spread thinly across 292 LGAs among a majority who
already have a connection: reaching them costs what reaching a dense unserved
population costs and returns far less. The real opportunity is **reliability
and backup** — selling to people whose power fails rather than to people who
have none — which is a different sales motion and different unit economics,
and should be a separate business decision rather than an extension of the
off-grid one.

**How far it can be trusted.** The best-formed segment in the country: mean
silhouette 0.368 and **not one LGA below zero in 292**. Against that, 76 of
292 are flagged `suspect` (26%), the second-highest rate. The segmentation is
confident about these places; the underlying electrification figures less so.

---

# 5. Served Metros

**42 LGAs · 0.7M unserved · 0.8% of the national total · NOT an off-grid
market**

> **Defining indicator — 96.7% electrified, 708 kWh per person per year, and
> settlement density 22,750.** The top of every scale.

Forty-two LGAs at 0.35 km from a medium-voltage line, consuming four times the
national average per head. Stand-alone solar is least-cost for 0.1% of the
population — one person in a thousand — and mini-grid for none.

| indicator | this segment | national |
|---|---|---|
| electrification rate | 0.967 | 0.536 |
| demand, kWh per person per year | 708.473 | 170.116 |
| poverty rate | 0.217 | 0.326 |
| travel time to town, hours | 0.142 | 0.399 |
| distance to MV line, km | 0.353 | 4.350 |
| share getting grid by 2030 | 0.040 | 0.191 |
| settlement density | 22,750 | 7,023 |
| stand-alone solar share, 2030 | 0.001 | 0.271 |

**Where.** Rivers (7 LGAs, 0.2M unserved), Anambra (3, 0.1M), Oyo (8, 0.1M),
Kogi (1, 0.1M), Lagos (11, 0.1M).

**What an operator does differently here.** Deprioritises entirely. There is
no off-grid access market in these 42 LGAs.

**How far it can be trusted — and this profile needs the caveat more than any
other.** **23 of these 42 LGAs are flagged `suspect`: 54.8%, four times the
rate in Low-Income Rural Core and the highest in the country.** The apparent
0.7M access gap rests on the least reliable data in the analysis. The
recommendation happens not to depend on it — at 0.1% stand-alone solar share
this segment would be excluded even if its access figures were twice as wrong
— but *we are confident despite the data* is a different claim from *the data
says so*, and only the first is true here. Four Lagos LGAs are also missing
from the analysis entirely, so this is the segment most affected by the
coverage gap.

---

# Inside Low-Income Rural Core: four sub-types

The volume market is too large to treat as one unit, and testing showed it is
not one. Its 274 LGAs divide into four types that shuffled data does not
reproduce: real silhouette **0.214** against a null 95th percentile of
**0.156**, an excess of **+0.058** over a pre-registered margin of 0.02, and
stability ARI **0.902** across 20 seeds. The null model shuffles each feature
column independently, destroying the relationships between features while
preserving every distribution — so it measures what this procedure produces
from nothing. Method in `pipeline/subcluster.py`.

**Two limits travel with that result.** The excess curve is flat — k=3 gives
+0.047, k=4 gives +0.058, k=6 gives +0.037 — so the defensible claim is *real
structure, roughly three to five types*, not *exactly four*. And k=2 comes
back **negative (−0.081)**: cutting the north in two, the intuitive split, is
the one division this data refuses.

| # | Sub-type | LGAs | Unserved | % of segment | Stand-alone solar | Grid by 2030 | Off-grid market |
|---|---|---|---|---|---|---|---|
| 1 | Off-Plan Grid Edge | 115 | 17.3M | 36.2 | 0.540 | 0.070 | **yes** |
| 2 | Solar-Default Remote | 63 | 13.3M | 28.0 | 0.751 | 0.052 | **yes** |
| 3 | Lower-Poverty Rural | 77 | 14.2M | 29.8 | 0.618 | 0.180 | **yes** |
| 4 | Grid-Bound Exception | 19 | 2.9M | 6.0 | 0.240 | 0.291 | no |

*Written in full as `Low-Income Rural Core → <sub-type>`, never bare: a lone
sub-name reads as a sixth segment. `reports/subsegment_map.png`.*

## Low-Income Rural Core → Off-Plan Grid Edge

**115 LGAs · 17.3M unserved · 36.2% of the segment · an off-grid market**

> **Defining indicator — 3.5 km from a medium-voltage line, and only 7%
> scheduled for a grid connection by 2030.** Proximity without a plan.

Neither number is extreme alone — Grid-Bound Exception is closer at 3.2 km,
Solar-Default Remote is lower at 5% — it is the conjunction no other sub-type
has. In fact this group has no extreme on any single variable: it is the
*centre* of the segment, and the largest single block of addressable demand in
the country. Katsina (25 LGAs), Kano (18), Jigawa (16).

**What an operator does differently.** Enters here first. Logistics are cheap
and nobody else is coming. Stand-alone solar is least-cost for 54% and
mini-grid for under 1%, so plan household systems rather than distribution.

**How far it can be trusted.** Cleanest of the four: 9 of 115 flagged
`suspect` (8%). Mean fit to the parent segment 0.312.

## Low-Income Rural Core → Solar-Default Remote

**63 LGAs · 13.3M unserved · 28.0% of the segment · an off-grid market**

> **Defining indicator — stand-alone solar is least-cost for 75.1% of its
> people, the highest share anywhere in the country.**

The purest off-grid market in the volume segment, and the best-formed of the
four. Only 5% are scheduled for a grid connection, so asset life is not at
risk. The price of that is distance: 9.6 km to a line and 0.96 hours to town,
both the highest in the segment. Yobe (11 LGAs), Jigawa (9), Bauchi (7).

**What an operator does differently.** Prices and staffs for a cost to serve
roughly triple Off-Plan Grid Edge at a similar revenue per connection.

**How far it can be trusted.** Mean fit to the parent 0.424, not one LGA below
zero; 10 of 63 flagged `suspect` (16%). Note that it is named for the solar
share, not the distance: **9.6 km is not comparable to Deep Off-Grid
Frontier's 37.3 km** and the two should not be read as the same proposition.

## Low-Income Rural Core → Lower-Poverty Rural

**77 LGAs · 14.2M unserved · 29.8% of the segment · an off-grid market**

> **Defining indicator — poverty rate 0.322**, against 0.491, 0.513 and 0.608
> for the other three. The best ability to pay in the volume market.

Also the lowest settlement density of the four at 3,734. Niger (12 LGAs),
Kano (9), Benue (8).

**What an operator does differently — and read the horizon first.** **18% of
its population is scheduled for a grid connection by 2030, triple Off-Plan
Grid Edge (7%) and Solar-Default Remote (5%).** Size asset life accordingly.
The ability to pay is the reason for the name, but the horizon leads, because
only a name travels into a summary and this name carries the upside. 18% is
the national average, so this is an ordinary exposure rather than a
distinctive one, and nowhere near Grid-Arrival Markets' 54%.

**How far it can be trusted.** Weakest data of the four: 15 of 77 flagged
`suspect` (19%). Mean fit to the parent 0.321.

## Low-Income Rural Core → Grid-Bound Exception

**19 LGAs · 2.9M unserved · 6.0% of the segment · NOT an off-grid market**

> **Defining indicator — stand-alone solar is least-cost for only 24% of its
> people**, against 54–75% for the other three. With mini-grid at 0.9%, around
> three-quarters of this group is grid, existing or planned.

Not a market, an exception. Demand runs at **159 kWh per person per year
against 31** for the other northern sub-types, so the parent segment's pricing
advice is wrong here by more than four times. It is also the worst fit to its
parent — mean fit 0.160 against 0.31–0.42 — and geographically it is Ebonyi,
Enugu, Plateau, Benue, Kwara and Oyo: south-eastern and Middle Belt LGAs
inside an otherwise northern segment.

**What an operator does differently.** Carves it out of any recommendation
made about the parent and reports it separately. 2.9 million unserved people
is not nothing, but the answer for them is a grid connection, not a solar
product.

**How far it can be trusted.** 2 of 19 flagged `suspect` (11%) — but the fit
figure matters more here than the flag, and it is the lowest of the four.

---

## Sources and regeneration

```bash
python pipeline/profile_segments.py      # rebuilds every number above
```

`reports/segment_profile_data.md` carries the full profile of all nine groups
— every indicator beside its national mean, top states by unserved population,
per-group fit and data-quality rates. It is committed so that any figure here
can be checked against its source without running anything, and so that a
number which moves shows up as a diff rather than changing silently.

**Three figures are not stored in the database** and are cited rather than
reproduced: the k-selection curve and bootstrap stability
(`pipeline/cluster.py` output and `reports/k_selection.png`), and the
sub-clustering null table (`pipeline/subcluster.py` output).

| where the decisions live | |
|---|---|
| `sql/04_gep_quality.sql` | how far each LGA's energy data can be trusted |
| `sql/08_cluster_features.sql` | the seven features and the correlation ceiling |
| `sql/09_segment_names.sql` | cluster number → market type, and why |
| `sql/10_business_questions.sql` | the query catalogue, answers recorded |
| `sql/11_subsegment_names.sql` | the four sub-types, and where the naming rule bent |
| `pipeline/cluster.py` | K-Means, Ward, DBSCAN, k selection, stability |
| `pipeline/subcluster.py` | the null-model test inside the largest segment |
| `pipeline/check_subsegment_fit.py` | whether a sub-type belongs to its parent |
