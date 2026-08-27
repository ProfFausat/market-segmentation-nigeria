# Methods review: `sql/04_gep_quality.sql`

> **Status: all nine findings applied, 27 August 2026.** `sql/04_gep_quality.sql`
> and Q7 of `sql/10_business_questions.sql` were rewritten against them and
> re-run; every check passes. The headline moved from 102 flagged LGAs to 169,
> and from 30.5M to 54.4M people. This document is kept as the record of why.

**Reviewed 27 August 2026. Every claim below was executed against a copy of
`data/processed/nigeria_lga.db`, not reasoned about.** The copy was made so
nothing here could touch the working database.

The review reproduced the published result exactly before criticising it:

```
ok            667    174,370,414
suspect       102     27,416,969
no_clusters     5      3,121,837
national ratio                1.006
```

Nine findings follow, ranked by how much they change what the project can
claim. Finding 1 is the one that matters.

---

## 1. `ok` does not mean "correctly assigned". It means "no net imbalance."

This is a claim the file currently makes and cannot support. It says:

> The test: sum GEP's own population per LGA and compare it to the COD
> population used everywhere else in this project. **Agreement means the
> clusters belong to that LGA.**

Agreement means no *net* displacement. An LGA that loses 200,000 of its own
people to one neighbour and gains 200,000 from another reads 1.0 and passes,
with every one of its energy indicators describing somewhere else.

That is not a hypothetical. GEP ships its own `Admin1` (state) label on every
cluster. Comparing it against the state of the LGA the cluster was assigned to:

| | clusters | population |
|---|---|---|
| assigned state agrees with GEP's own Admin1 | 679,735 | — |
| **assigned state disagrees** | **28,801** | **8,097,966** |

Of that 8.1 million misplaced across a **state** line, **7,046,224 people —
87% — sit in LGAs this measure flags `ok`.**

The worst cases are not marginal:

| LGA | state | `pop_ratio` | flag | % of attributed pop from another state |
|---|---|---|---|---|
| Ifo | Ogun | 0.616 | **ok** | **90.7%** |
| Aguata | Anambra | 1.415 | **ok** | **88.8%** |
| Afikpo North | Ebonyi | 1.499 | **ok** | **79.5%** |
| Ado-Odo/Ota | Ogun | 0.919 | **ok** | **77.0%** |
| Karu | Nasarawa | 0.936 | **ok** | **65.8%** |
| Shagamu | Ogun | 0.824 | **ok** | **63.1%** |

Ado-Odo/Ota reads 0.919 — as close to perfect agreement as anything in the
table — and three quarters of the population attributed to it belongs to a
different state.

**Fix the sentence first.** "Agreement means the clusters belong to that LGA"
should read: *agreement means no net displacement was detected; it is not
evidence that the assignment is right.* 667 LGAs are not verified. They are
unfalsified by a test that cannot see balanced exchange.

---

## 2. The project already owns an independent check and throws it away

`pipeline/spatial_join.py` reads `Admin1` — it uses it to justify the three
border exceptions — and then does not carry it forward. `raw_gep.Admin1` is a
second, independently produced geographic label on all 708,536 clusters, and it
is free.

Only two names need reconciling:

```sql
-- GEP spells two states differently from the COD
CASE g.Admin1
     WHEN 'Abuja'     THEN 'Federal Capital Territory'
     WHEN 'Nassarawa' THEN 'Nasarawa'
     ELSE g.Admin1
END
```

The full cross-check, runnable as it stands:

```sql
SELECT COUNT(*) AS total,
       SUM(CASE WHEN CASE g.Admin1 WHEN 'Abuja' THEN 'Federal Capital Territory'
                                   WHEN 'Nassarawa' THEN 'Nasarawa'
                                   ELSE g.Admin1 END = b.state_name
                THEN 1 ELSE 0 END) AS agree,
       SUM(CASE WHEN CASE g.Admin1 WHEN 'Abuja' THEN 'Federal Capital Territory'
                                   WHEN 'Nassarawa' THEN 'Nasarawa'
                                   ELSE g.Admin1 END <> b.state_name
                THEN g.Pop2020 ELSE 0 END) AS pop_disagreeing
FROM cluster_lga AS cl
JOIN raw_gep   AS g ON cl.cluster_id = g.id
JOIN lga_base  AS b ON cl.lga_pcode  = b.lga_pcode;
```

Adding a per-LGA `pct_foreign` column alongside `pop_ratio` changes the size of
the problem:

| threshold on `pct_foreign` | LGAs | population | of which flagged `ok` |
|---|---|---|---|
| > 5% | 135 | 34,034,109 | 122 LGAs / 31,249,784 |
| > 10% | 79 | 19,378,547 | 70 LGAs / 17,503,187 |
| > 25% | 22 | 7,128,366 | 19 LGAs / 6,442,103 |
| > 50% | 13 | 5,130,224 | 10 LGAs / 4,443,961 |

Taking `suspect` OR `no_clusters` OR `pct_foreign > 25%` as the untrustworthy
set moves the headline from **107 LGAs / 30,538,806 people** to
**126 LGAs / 36,980,909 people**. Nineteen LGAs and 6.4 million people the
current method calls fine.

Where the displacement goes, by state pair:

| GEP says | assigned to | clusters | population |
|---|---|---|---|
| Lagos | Ogun | 159 | 1,649,302 |
| Imo | Anambra | 26 | 949,558 |
| Cross River | Ebonyi | 410 | 342,271 |
| Cross River | Akwa Ibom | 54 | 175,363 |
| Kebbi | Sokoto | 937 | 174,696 |
| FCT | Nasarawa | 26 | 172,733 |
| Jigawa | Bauchi | 1,878 | 168,573 |
| Kano | Kaduna | 807 | 162,224 |

Note the cluster counts. Lagos → Ogun moves 1.65 million people in **159
clusters** — an average of 10,400 people per cluster. Imo → Anambra moves
950,000 in **26**. These are the giant conurbation clusters the whole problem
is about, and they are crossing state lines.

**One honest limit on this check.** GEP's `Admin1` may itself have been derived
by point-in-polygon against a different boundary vintage. Where the two labels
disagree, this tells you that two independent assignments disagree — not which
one is wrong. That is still worth far more than nothing, and it is exactly what
a validation is for. Say so rather than overclaiming it.

---

## 3. The band is symmetric in ratio, which is asymmetric in effect

0.5–1.5 *looks* centred on 1.0. It is not. The multiplicative inverse of 0.5 is
2.0, not 1.5, so the band is markedly more forgiving of an LGA that **lost**
population than one that gained it:

| band | flagged | log-symmetric equivalent | flagged |
|---|---|---|---|
| 0.5 – 1.5 | **102** | 0.667 – 1.5 | **154** |
| 0.7 – 1.3 | 240 | 0.769 – 1.3 | 278 |
| 0.3 – 1.7 | 52 | 0.588 – 1.7 | 96 |

Fifty-two extra LGAs, and every one of them is on the low side — the direction
where the damage is worse. An LGA reading 0.4 has lost most of its clusters and
its indicators are built from a fragment. An LGA reading 1.6 has its own
clusters *plus* a neighbour's: degraded, but not absent.

Either widen deliberately and say why, or flag on `ABS(LN(pop_ratio)) > LN(1.5)`
and get a band that treats gain and loss alike.

---

## 4. Direction is measured but never recorded

Under the current band: **67 LGAs read high, 35 read low.** They are different
failure modes and Stage 2 should not treat them as one label. A column costs
nothing:

```sql
CASE WHEN pop_ratio IS NULL     THEN 'none'
     WHEN pop_ratio < 0.5       THEN 'donated'    -- its clusters went elsewhere
     WHEN pop_ratio > 1.5       THEN 'absorbed'   -- it holds a neighbour's
     ELSE                            'balanced'
END AS displacement
```

---

## 5. `no_cod_pop` is unreachable, and `no_clusters` bundles two different things

The `CASE` tests `COUNT(c.cluster_id) = 0` before `b.pop_total IS NULL`. Bakassi
is the only LGA with a NULL population — and it also has zero clusters, so it
takes the earlier branch. Verified: **`no_cod_pop` can never fire on this data.**

That means the check `exactly 5 no_clusters` bundles:

- **Bakassi** — no population recorded, no clusters. Internally consistent.
  Nothing is wrong here.
- **Agege, Ajeromi-Ifelodun, Mushin, Shomolu** — 3,121,837 people between them,
  zero clusters. A defect.

One label, two conditions, and the headline "3.1 million people in LGAs with no
clusters" is only correct by the accident that `SUM` skips Bakassi's NULL. Put
the NULL test first, or add a fifth label.

---

## 6. Hardcoded denominators in a project built on loud failure

```sql
ROUND(100.0 * COUNT(*) / 774, 1)                    AS pct_of_lgas,
ROUND(100.0 * SUM(cod_pop) / 204909220, 1)          AS pct_of_population
```

Both are right today. Both are literals that will keep returning plausible
numbers after the thing they divide by has changed — the one failure mode
`load_raw.py` was written to prevent. Use subqueries:

```sql
ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM lga_base), 1)
ROUND(100.0 * SUM(cod_pop) / (SELECT SUM(pop_total) FROM lga_base), 1)
```

---

## 7. The sensitivity block quietly uses a different denominator

`WHERE pop_ratio IS NOT NULL` drops the 5 no-cluster LGAs, so 240 / 102 / 52 are
counts over 769 LGAs while the headline percentages are over 774. It does not
change any number — those 5 are never `suspect` — but the two tables are
computed on different populations and nothing says so.

---

## 8. The zero-guard is applied in one expression and not the other

`pop_ratio` is guarded by `WHEN b.pop_total > 0`. The flag `CASE` divides by
`b.pop_total` with no such guard. Verified: **no LGA currently has
`pop_total = 0`**, so this does not bite. If one ever did, SQLite would return
NULL from the division, the `BETWEEN` would fail, and a zero-population LGA
would be labelled `suspect` — a data-absence problem wearing a
data-quality label. Guard both the same way.

---

## 9. The national 1.006 is weaker evidence than the file says

The file states the people "are all accounted for". A national ratio of 1.006
would also be produced if GEP's population raster had simply been scaled to a
national control total — in which case national agreement is guaranteed by
construction and proves nothing about any LGA.

This was tested rather than assumed. State-level ratios run from **0.710 (FCT)**
to **1.110 (Ondo)**, with Lagos at 0.889 — so GEP is demonstrably *not*
calibrated state by state, and the national figure is not vacuous. But it still
cannot separate "redistribution between LGAs" from "GEP and the NPC projection
disagree about where Nigerians live". Both are present. The file should say the
national check bounds the problem rather than explaining it.

The FCT reading 0.710 deserves its own line in the write-up: the capital is
missing 29% of its expected population in GEP's account of it.

---

## What survives the review

The measure is real, it is honest, and it found something almost nobody looks
for. Nothing here says throw it out. Findings 3–8 are repairs. Finding 9 is a
wording correction.

Findings 1 and 2 are the substantive ones, and they point the same way: the
current test is a **necessary** condition for trusting an LGA's indicators, not
a sufficient one. Pairing it with the `Admin1` cross-check gives two independent
detectors of the same fault, which is worth far more than one detector with a
better-tuned threshold.

---

## Note on how this was run

`raw_gep` has 81 columns and no index on `id`, which makes the join slow. The
tests above used a helper:

```sql
CREATE TABLE gep_small AS SELECT id, Pop2020, Admin1 FROM raw_gep;
CREATE UNIQUE INDEX ix_gs ON gep_small(id);
```

Build time dropped from minutes to 2.9 seconds. Worth adding to the pipeline
regardless of what is done with the findings.

**Separately — check that `gep_quality` has actually been written to disk.**
Inspecting the database file directly, `gep_quality` was not present in
`sqlite_master`, in either the committed or the pending state. That is
consistent with DB Browser holding the `CREATE TABLE` in an unwritten
transaction. Press **Write Changes**, close DB Browser, reopen, and confirm the
table is still there before building anything on top of it.
