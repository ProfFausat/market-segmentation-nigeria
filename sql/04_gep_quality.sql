-- ============================================================
-- 04_gep_quality.sql
-- How far can each LGA's GEP-derived indicators be trusted?
--
-- REVISED 27 Aug 2026 after a methods review (docs/gep_quality_review.md).
-- The first version used one test and overstated what it proved. What
-- changed, and why, is set out under REVISION NOTE at the foot of this
-- header. The headline moved from 102 flagged LGAs to 169.
--
-- THE PROBLEM THIS MEASURES
-- GEP settlement clusters were assigned to LGAs by point-in-polygon on
-- each cluster's single representative coordinate (pipeline/spatial_join.py).
-- Where clusters are large and LGAs small, one point decides which LGA
-- receives an entire cluster's population. In dense conurbations that
-- misassigns people wholesale: Maiduguri's population appears in Jere,
-- Kano Municipal's in Kumbotso, Ibadan South East's in Ibadan South West.
--
-- The cluster ATTRIBUTES are sound — they describe real places. It is the
-- LGA LABEL attached to them that is uncertain.
--
-- TWO INDEPENDENT TESTS, BECAUSE ONE IS NOT ENOUGH
--
-- TEST 1 — POPULATION RATIO.  Sum GEP's own population per LGA and compare
-- it to the COD population, which is independently sourced and is what this
-- project uses everywhere else.
--
--   pop_ratio = gep_pop / cod_pop
--     1.0  no net displacement detected
--     >1   this LGA holds more people than the census projection expects
--     <1   this LGA holds fewer
--
-- What this test CANNOT see is the point the review turned on. It measures
-- NET displacement only. An LGA that loses 200,000 of its own people to one
-- neighbour and gains 200,000 from another reads 1.0 and passes, with every
-- one of its indicators describing somewhere else. So a ratio near 1.0 is a
-- NECESSARY condition for trusting an LGA's indicators, never a sufficient
-- one. Do not write "agreement means the clusters belong to that LGA".
-- It does not.
--
-- TEST 2 — FOREIGN-STATE SHARE.  GEP ships its own Admin1 (state) label on
-- every cluster, produced independently of this project's spatial join. Where
-- the two disagree, at least one of them is wrong.
--
--   pct_foreign = share of an LGA's attributed GEP population that came from
--                 clusters GEP itself places in a different STATE
--
-- Nationally, 28,801 of 708,536 clusters (4.1%) carrying 8,097,966 people sit
-- in a different state from the one GEP assigns them. Under the old
-- single-test definition, 87% of those people lived in LGAs flagged 'ok'.
--
-- This test catches what Test 1 structurally cannot. Ado-Odo/Ota (Ogun) reads
-- pop_ratio 0.919 — as close to agreement as anything in the table — and 77%
-- of the population attributed to it belongs to another state. Aguata
-- (Anambra) reads 1.415 and is 88.8% foreign. Fifteen LGAs are caught by this
-- test and by nothing else; seven more are caught by both.
--
-- HONEST LIMIT ON TEST 2. GEP's Admin1 may itself have been derived by
-- point-in-polygon against a different boundary vintage. A disagreement says
-- two independent assignments disagree — not which one is wrong. That is what
-- a validation is, and it is worth far more than one detector with a
-- better-tuned threshold. Do not report it as proof that our label is wrong.
--
-- NOTHING IS LOST NATIONALLY — IT IS REDISTRIBUTED
-- Summed nationally, GEP's population is 206,139,999 against COD's
-- 204,909,220: a ratio of 1.006. Every excess in one LGA is matched by a
-- deficit in a neighbour, which is why 1.0 is the correct centre for the band.
--
-- That figure BOUNDS the problem; it does not explain it. A national ratio of
-- 1.006 would also appear if GEP's population raster had simply been scaled to
-- a national control total, in which case national agreement is guaranteed by
-- construction and proves nothing about any LGA. This was tested: state-level
-- ratios run from 0.710 (FCT) to 1.110 (Ondo), with Lagos at 0.889, so GEP is
-- demonstrably NOT calibrated state by state and the national figure is not
-- vacuous. It still cannot separate "redistribution between LGAs" from "GEP
-- and the NPC projection disagree about where Nigerians live". Both are
-- present. The FCT reading 0.710 deserves its own line in the write-up.
--
-- BOTH THRESHOLDS ARE JUDGEMENTS, NOT FACTS
-- The ratio band is expressed as a FACTOR, not as a pair of endpoints:
-- 1/1.5 to 1.5, i.e. 0.667-1.500. The earlier 0.5-1.5 looked symmetric around
-- 1.0 and was not — the inverse of 0.5 is 2.0, so it was markedly more
-- forgiving of an LGA that had LOST population than one that had gained it,
-- which is the wrong way round. An LGA reading 0.4 has lost most of its
-- clusters and its indicators are built from a fragment; one reading 1.6 has
-- its own clusters plus a neighbour's — degraded, but not absent.
--
-- Neither threshold has a natural cut-off in the data. QUOTE THE SENSITIVITY
-- WHENEVER THE HEADLINE IS QUOTED. Both sensitivity queries are at the foot of
-- this file.
--
-- Because of that, `pop_ratio` and `pct_foreign` are kept as columns in their
-- own right. The flag is a convenience for filtering; the two continuous
-- measures are the real measurement, and downstream work should prefer them.
--
-- WHAT REMAINS UNDETECTED
-- 47 LGAs holding 10,332,548 people pass as 'ok' while still carrying between
-- 10% and 25% foreign-state population — under the threshold, not clean. The
-- highest 'ok' reading is 23.7%. And no test here can see a swap between two
-- LGAs of the SAME state that also happens to balance. This measure narrows
-- the untrusted set; it does not certify the remainder.
--
-- WHAT TO DO WITH THE FLAG
-- Not to drop rows. To label them. Stage 2 clusters with and without
-- 'suspect' LGAs and reports whether the segmentation changes; the write-up
-- states which LGAs the electrification indicators cannot speak for. A
-- limitation that is measured and named is a finding. The same limitation
-- unmeasured is a defect.
--
-- REVISION NOTE — WHAT CHANGED ON 27 AUG 2026
--   1. Added Test 2 (pct_foreign) and column `flag_reason`.
--   2. Ratio band moved from 0.5-1.5 to the log-symmetric 1/1.5-1.5.
--   3. `no_cod_pop` moved ahead of `no_clusters` in the CASE. Bakassi has
--      both no population and no clusters; under the old order it took the
--      later-listed branch and `no_cod_pop` could never fire at all.
--   4. Added `displacement` (donated / balanced / absorbed / none): a ratio
--      of 0.0 and a ratio of 3.0 are different failure modes and Stage 2
--      should not treat them as one label.
--   5. Percentage denominators are now computed from lga_base instead of the
--      literals 774 and 204909220.
--   6. The zero-population guard is applied consistently to every expression
--      that divides by pop_total.
--   7. `gep_small` added: a three-column projection of raw_gep with an index
--      on id. raw_gep is 81 columns and unindexed; this cut the build from
--      minutes to seconds.
--
--   Old headline:  ok 667 | suspect 102 | no_clusters 5
--   New headline:  ok 600 | suspect 169 | no_clusters 4 | no_cod_pop 1
-- ============================================================


-- ------------------------------------------------------------
-- Helper. A projection of raw_gep, indexed on id, holding only the three
-- columns this file needs. raw_gep has 81 columns, 708,536 rows and no index
-- on its join key. This is a build artefact, not a source of truth — it is
-- rebuilt from raw_gep every time and nothing else may read from it.
--
-- The CASE reconciles the only two state names GEP spells differently from
-- the COD. Verified as the complete set: every other one of the 37 matches
-- exactly.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS gep_small;

CREATE TABLE gep_small AS
SELECT id,
       Pop2020,
       CASE Admin1
            WHEN 'Abuja'     THEN 'Federal Capital Territory'
            WHEN 'Nassarawa' THEN 'Nasarawa'
            ELSE Admin1
       END AS gep_state
FROM raw_gep;

CREATE UNIQUE INDEX idx_gep_small_id ON gep_small (id);


-- ------------------------------------------------------------
-- The measure.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS gep_quality;

CREATE TABLE gep_quality AS
SELECT
    b.lga_pcode,
    b.lga_name,
    b.state_name,
    b.pop_total                                    AS cod_pop,
    COUNT(c.cluster_id)                            AS n_clusters,
    SUM(g.Pop2020)                                 AS gep_pop,

    -- TEST 1. Guarded against a zero denominator, as is every other
    -- expression below that divides by pop_total.
    CASE WHEN b.pop_total > 0
         THEN ROUND(SUM(g.Pop2020) / b.pop_total, 3)
    END                                            AS pop_ratio,

    -- TEST 2. Share of attributed population whose clusters GEP places in a
    -- different state. NULL where an LGA has no clusters at all.
    CASE WHEN SUM(g.Pop2020) > 0
         THEN ROUND(100.0 * SUM(CASE WHEN g.gep_state <> b.state_name
                                     THEN g.Pop2020 ELSE 0 END)
                    / SUM(g.Pop2020), 1)
    END                                            AS pct_foreign,

    -- Direction of the net displacement. 'donated' and 'absorbed' are not
    -- interchangeable: a donor's indicators are built from a fragment of
    -- itself, an absorber's from itself blended with a neighbour.
    CASE
        WHEN b.pop_total IS NULL OR b.pop_total = 0 THEN 'none'
        WHEN COUNT(c.cluster_id) = 0                THEN 'none'
        WHEN SUM(g.Pop2020) / b.pop_total < 1.0/1.5 THEN 'donated'
        WHEN SUM(g.Pop2020) / b.pop_total > 1.5     THEN 'absorbed'
        ELSE                                             'balanced'
    END                                            AS displacement,

    -- The flag. Ordered so that the absence of a population record is tested
    -- BEFORE the absence of clusters: Bakassi has neither, and the earlier
    -- branch is the one that describes it.
    CASE
        WHEN b.pop_total IS NULL OR b.pop_total = 0 THEN 'no_cod_pop'
        WHEN COUNT(c.cluster_id) = 0                THEN 'no_clusters'
        WHEN SUM(g.Pop2020) / b.pop_total
             NOT BETWEEN 1.0/1.5 AND 1.5            THEN 'suspect'
        WHEN SUM(CASE WHEN g.gep_state <> b.state_name THEN g.Pop2020 ELSE 0 END)
             > 0.25 * SUM(g.Pop2020)                THEN 'suspect'
        ELSE                                             'ok'
    END                                            AS gep_flag,

    -- Which test fired. NULL for every LGA that is not 'suspect'.
    CASE
        WHEN b.pop_total IS NULL OR b.pop_total = 0 THEN NULL
        WHEN COUNT(c.cluster_id) = 0                THEN NULL
        WHEN SUM(g.Pop2020) / b.pop_total NOT BETWEEN 1.0/1.5 AND 1.5
         AND SUM(CASE WHEN g.gep_state <> b.state_name THEN g.Pop2020 ELSE 0 END)
             > 0.25 * SUM(g.Pop2020)                THEN 'ratio+foreign'
        WHEN SUM(g.Pop2020) / b.pop_total
             NOT BETWEEN 1.0/1.5 AND 1.5            THEN 'ratio'
        WHEN SUM(CASE WHEN g.gep_state <> b.state_name THEN g.Pop2020 ELSE 0 END)
             > 0.25 * SUM(g.Pop2020)                THEN 'foreign'
    END                                            AS flag_reason

FROM lga_base   AS b
LEFT JOIN cluster_lga AS c ON b.lga_pcode  = c.lga_pcode
LEFT JOIN gep_small   AS g ON c.cluster_id = g.id
GROUP BY b.lga_pcode, b.lga_name, b.state_name, b.pop_total;

CREATE INDEX IF NOT EXISTS idx_gep_quality_flag ON gep_quality (gep_flag);


-- ------------------------------------------------------------
-- Checks. Run these every time this table is rebuilt.
-- Expected values recorded 27 Aug 2026.
-- ------------------------------------------------------------

-- Row count in equals row count out. LEFT JOIN, so LGAs with no clusters
-- survive. Compared against lga_base rather than the literal 774.
SELECT 'gep_quality row count' AS check_name,
       (SELECT COUNT(*) FROM gep_quality) AS actual,
       (SELECT COUNT(*) FROM lga_base)    AS expected,
       CASE WHEN (SELECT COUNT(*) FROM gep_quality)
               = (SELECT COUNT(*) FROM lga_base)
            THEN 'PASS' ELSE 'FAIL' END   AS result;

-- Every LGA carries exactly one flag, and no flag is NULL.
SELECT 'every LGA flagged',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gep_quality WHERE gep_flag IS NULL;

-- Every 'suspect' row records which test fired, and no other row does.
SELECT 'flag_reason set iff suspect',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gep_quality
WHERE (gep_flag =  'suspect' AND flag_reason IS NULL)
   OR (gep_flag <> 'suspect' AND flag_reason IS NOT NULL);

-- Bakassi: no population record. It is the ONLY such LGA, and under the
-- corrected CASE order it now reaches the branch that describes it.
SELECT 'exactly 1 no_cod_pop',
       COUNT(*), 1,
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM gep_quality WHERE gep_flag = 'no_cod_pop';

-- The four inner-Lagos LGAs whose clusters were absorbed by their
-- neighbours: Agege, Ajeromi-Ifelodun, Mushin, Shomolu. Four, not five —
-- Bakassi is now correctly counted above instead of being folded in here.
SELECT 'exactly 4 no_clusters',
       COUNT(*), 4,
       CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END
FROM gep_quality WHERE gep_flag = 'no_clusters';

-- Nationally, nothing is lost. If this ever fails, the problem is no
-- longer misassignment between LGAs — clusters are being dropped or
-- double-counted, which is a different and worse fault.
SELECT 'national totals agree within 2%',
       ROUND(SUM(gep_pop) / SUM(cod_pop), 3), 1.0,
       CASE WHEN ABS(SUM(gep_pop) / SUM(cod_pop) - 1.0) < 0.02
            THEN 'PASS' ELSE 'FAIL' END
FROM gep_quality;

-- Population reconciles to the spine. Catches an LGA silently dropped or
-- duplicated by the GROUP BY.
SELECT 'population reconciles to lga_base',
       (SELECT SUM(cod_pop)   FROM gep_quality),
       (SELECT SUM(pop_total) FROM lga_base),
       CASE WHEN (SELECT SUM(cod_pop)   FROM gep_quality)
               = (SELECT SUM(pop_total) FROM lga_base)
            THEN 'PASS' ELSE 'FAIL' END;

-- displacement and gep_flag must agree about which LGAs have nothing to
-- measure. Catches the two CASE ladders drifting apart in future edits.
SELECT 'displacement agrees with flag',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gep_quality
WHERE (displacement =  'none' AND gep_flag NOT IN ('no_cod_pop','no_clusters'))
   OR (displacement <> 'none' AND gep_flag     IN ('no_cod_pop','no_clusters'));


-- ------------------------------------------------------------
-- Summary. How much of the country is affected, and how much of
-- its population. Denominators computed, not typed.
-- ------------------------------------------------------------

SELECT gep_flag,
       COUNT(*)                                                   AS n_lgas,
       ROUND(100.0 * COUNT(*)
             / (SELECT COUNT(*) FROM lga_base), 1)                AS pct_of_lgas,
       SUM(cod_pop)                                               AS population,
       ROUND(100.0 * SUM(cod_pop)
             / (SELECT SUM(pop_total) FROM lga_base), 1)          AS pct_of_population
FROM gep_quality
GROUP BY gep_flag
ORDER BY n_lgas DESC;

-- ANSWER (27 Aug 2026):
--   flag            LGAs   % LGAs      population   % population
--   ok               600     77.5     150,470,181        73.4
--   suspect          169     21.8      51,317,202        25.0
--   no_clusters        4      0.5       3,121,837         1.5
--   no_cod_pop         1      0.1            NULL         NULL


-- Which test did the work.
SELECT flag_reason, COUNT(*) AS n_lgas, SUM(cod_pop) AS population
FROM gep_quality
WHERE gep_flag = 'suspect'
GROUP BY flag_reason
ORDER BY n_lgas DESC;

-- ANSWER (27 Aug 2026):
--   ratio           147   44,188,836
--   foreign          15    4,262,750
--   ratio+foreign     7    2,865,616
--
-- Twenty-two LGAs are caught by the foreign-state test; fifteen of them by
-- that test ALONE. Those fifteen were flagged 'ok' by the first version of
-- this file and would have carried recommendations.


-- Direction of net displacement.
SELECT displacement, COUNT(*) AS n_lgas, SUM(cod_pop) AS population
FROM gep_quality
GROUP BY displacement
ORDER BY n_lgas DESC;

-- ANSWER (27 Aug 2026):
--   balanced        615  154,732,931
--   donated          87   31,040,455
--   absorbed         67   16,013,997
--   none              5    3,121,837


-- ------------------------------------------------------------
-- Sensitivity of the ratio band. Expressed as a factor so that gain and
-- loss are treated alike. Quote it whenever the headline is quoted.
-- Denominator: the 769 LGAs that have both a population and clusters.
-- ------------------------------------------------------------

SELECT '1.3  (0.769 - 1.300)' AS band,
       SUM(CASE WHEN pop_ratio NOT BETWEEN 1.0/1.3 AND 1.3 THEN 1 ELSE 0 END) AS n_flagged
FROM gep_quality WHERE pop_ratio IS NOT NULL
UNION ALL
SELECT '1.5  (0.667 - 1.500)  <- used',
       SUM(CASE WHEN pop_ratio NOT BETWEEN 1.0/1.5 AND 1.5 THEN 1 ELSE 0 END)
FROM gep_quality WHERE pop_ratio IS NOT NULL
UNION ALL
SELECT '1.7  (0.588 - 1.700)',
       SUM(CASE WHEN pop_ratio NOT BETWEEN 1.0/1.7 AND 1.7 THEN 1 ELSE 0 END)
FROM gep_quality WHERE pop_ratio IS NOT NULL
UNION ALL
SELECT '2.0  (0.500 - 2.000)',
       SUM(CASE WHEN pop_ratio NOT BETWEEN 1.0/2.0 AND 2.0 THEN 1 ELSE 0 END)
FROM gep_quality WHERE pop_ratio IS NOT NULL;

-- ANSWER (27 Aug 2026): 278 / 154 / 96 / 54 over 769 LGAs.
-- It roughly halves at every step with no plateau. There is no natural
-- cut-off: the disagreement is continuous, not two clean populations of
-- good and bad. "154" is a statement about the threshold as much as about
-- the country.


-- ------------------------------------------------------------
-- Sensitivity of the foreign-state threshold. Same denominator.
-- ------------------------------------------------------------

SELECT '>  5%' AS threshold,
       COUNT(*) AS n_lgas, SUM(cod_pop) AS population
FROM gep_quality WHERE pct_foreign >  5
UNION ALL
SELECT '> 10%', COUNT(*), SUM(cod_pop) FROM gep_quality WHERE pct_foreign > 10
UNION ALL
SELECT '> 25%  <- used', COUNT(*), SUM(cod_pop) FROM gep_quality WHERE pct_foreign > 25
UNION ALL
SELECT '> 50%', COUNT(*), SUM(cod_pop) FROM gep_quality WHERE pct_foreign > 50;

-- ANSWER (27 Aug 2026):
--   >  5%   135 LGAs   34,034,109
--   > 10%    79 LGAs   19,378,547
--   > 25%    22 LGAs    7,128,366
--   > 50%    13 LGAs    5,130,224
--
-- Same shape, same absence of a plateau, and the same obligation to quote it.


-- ------------------------------------------------------------
-- The LGAs the ratio test could never have found. Read this list before
-- trusting any recommendation.
-- ------------------------------------------------------------

-- Only flag_reason = 'foreign'. The seven 'ratio+foreign' LGAs were caught
-- by the ratio test too; these fifteen were not caught by anything before.
SELECT lga_name, state_name, cod_pop, pop_ratio, pct_foreign
FROM gep_quality
WHERE flag_reason = 'foreign'
ORDER BY pct_foreign DESC;

-- ANSWER (27 Aug 2026). Every one of these fifteen was flagged 'ok' by the
-- previous version of this file and would have carried recommendations:
--
--   lga_name          state       cod_pop   pop_ratio   pct_foreign
--   Aguata            Anambra     415,964       1.415          88.8
--   Afikpo North      Ebonyi      198,719       1.499          79.5
--   Ado-Odo/Ota       Ogun      1,030,829       0.919          77.0
--   Karu              Nasarawa    339,039       0.936          65.8
--   Tafa              Niger       144,316       0.730          63.8
--   Shagamu           Ogun        366,363       0.824          63.1
--   Isiala-Ngwa North Abia        221,635       0.968          58.4
--   Bayo              Borno       112,603       1.030          53.0
--   Mayo-Belwa        Adamawa     162,790       1.136          43.2
--   Ohimini           Benue       107,970       0.833          35.4
--   Gulani            Yobe        144,673       1.337          33.1
--   Tambuwal          Sokoto      302,633       1.082          31.8
--   Ogbadibo          Benue       167,103       0.907          29.9
--   Gummi             Zamfara     288,495       0.890          28.7
--   Ekiti East        Ekiti       259,618       0.847          27.8
--
-- Ado-Odo/Ota is the case to remember. A ratio of 0.919 is as close to
-- agreement as anything in the table, and three quarters of the population
-- attributed to it belongs to a different state. Lagos alone pushes
-- 1,649,302 people into Ogun LGAs across just 159 clusters — an average of
-- 10,400 people decided by one coordinate each.
