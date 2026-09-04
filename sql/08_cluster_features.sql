-- ============================================================
-- 08_cluster_features.sql
-- The feature matrix Stage 2 clusters on. One row per LGA that has
-- settlement clusters: 769 of 774.
--
-- This file assembles and documents. It does NOT transform. Log
-- transforms and standardisation happen once, in the Python clustering
-- script, so that every scaling decision lives in one place and is
-- applied to training data only. Doing half the scaling here and half
-- there is how a leak gets in.
--
--
-- HOW THESE SEVEN WERE CHOSEN
--
-- Seventeen candidate indicators were scanned for variance and pairwise
-- correlation before any of them was used (30 Aug 2026). Two findings
-- decided the set.
--
-- FINDING 1: THE CANDIDATES WERE NEARLY ONE-DIMENSIONAL. Seven of the
-- seventeen form a single block in which every pair correlates above 0.7:
--
--     elec_rate_2020  <->  pct_grid_existing_2030      0.98
--     investment_per_capita_usd <-> demand_kwh_per_capita  0.98
--     demand_kwh_per_capita <-> demand_tier            0.91
--     lcoe_usd_per_kwh <-> pct_standalone_pv_2030      0.94
--     lcoe_usd_per_kwh <-> demand_tier                -0.86
--     elec_rate_2020  <->  lcoe_usd_per_kwh           -0.82
--
-- These are one underlying thing wearing seven names. In the GEP model
-- they ARE each other: an electrified settlement is grid-coded, a poor
-- settlement gets a low demand target, a low demand target buys a small
-- system, and a small system costs little per person. Feeding all seven
-- to K-Means would weight that single axis six times over and recover
-- "developed versus undeveloped" -- which needs no clustering to find.
--
-- FINDING 2: TWO CANDIDATES CANNOT DISCRIMINATE AT ALL.
--     solar_ghi           CV 0.11  -- Nigeria is uniformly sunny
--     pct_minigrid_2030   mean 0.011, almost every LGA zero
-- (A third, transformer_dist_km, was a constant 9999 sentinel. See the
-- note in 07_gep_indicators.sql.)
--
--
-- THE SEVEN, AND THE QUESTION EACH ANSWERS
--
--   elec_rate_2020         How much of this market is still open?
--   demand_kwh_per_capita  What is a customer here worth?
--   poverty_rate           Can they pay?
--   travel_hours           What will it cost to serve them?
--   mv_line_dist_km        How far is the grid?
--   pct_grid_new_2030      Will the grid arrive and strand my asset?
--   settled_density        Dispersed homesteads, or a town?
--
-- TWO FROM THE BLOCK, NOT ONE. `elec_rate_2020` and
-- `demand_kwh_per_capita` correlate at 0.67 -- below the 0.7 threshold --
-- and they answer commercially distinct questions: how many customers are
-- available, versus what each is worth. Q8 showed what happens when those
-- are collapsed: the ranking found the places of greatest need and called
-- them the best markets. Keeping both is the correction.
--
-- `investment_per_capita_usd` IS DELIBERATELY EXCLUDED, despite being the
-- variable Q8 was built on. At r = 0.98 with demand it contributes nothing
-- to the geometry that demand does not already contribute. It is retained
-- below as a profiling column.
--
-- MAXIMUM PAIRWISE CORRELATION AMONG THE SEVEN: 0.67. No pair exceeds the
-- 0.7 threshold. The check at the foot of this file re-derives that and
-- fails if a future rebuild breaks it.
--
-- IF THE SEGMENTS COME OUT UNINTERPRETABLE, DROP `mv_line_dist_km` FIRST.
-- It is the most explained by the others (r -0.53 with elec_rate, 0.34
-- with travel_hours). Recorded here BEFORE the results are seen, so that
-- the decision cannot be shaped by which answer it produces.
--
--
-- PROFILE, DO NOT CLUSTER
-- `unserved_pop_2020` is excluded from the feature set on purpose. It
-- correlates -0.77 with elec_rate, so it is largely the development axis
-- restated as a count -- and clustering on size produces segments called
-- "big" and "small". The deliverable is a typology of market KINDS; size
-- is what each kind is then described WITH. The same applies to
-- investment, anchor loads, state and the quality flag.
--
--
-- TWO LIMITATIONS THAT TRAVEL WITH THIS TABLE
--
-- POVERTY IS A 2013 LAYER ON GADM BOUNDARIES, reconciled to COD P-codes
-- through 27 hand-verified name pairs (06_poverty.sql). It is the only
-- ability-to-pay variable available, and a segmentation without one
-- cannot speak to affordability at all -- so it is included, and the
-- vintage is stated wherever a segment is described.
--
-- FIVE LGAs ARE ABSENT. Bakassi has no population record; Agege,
-- Ajeromi-Ifelodun, Mushin and Shomolu have no settlement clusters and so
-- no indicators. 3.1 million people, all inner Lagos. They cannot be
-- clustered and must be named in the write-up rather than left for a
-- reader to discover as the difference between 774 and 769.
-- ============================================================


DROP TABLE IF EXISTS cluster_features;

CREATE TABLE cluster_features AS
SELECT
    i.lga_pcode,
    i.lga_name,
    i.state_name,

    -- ---------- THE SEVEN CLUSTERING FEATURES ----------
    i.elec_rate_2020,
    i.demand_kwh_per_capita,
    p.poverty_rate,
    i.travel_hours,
    i.mv_line_dist_km,
    i.pct_grid_new_2030,
    i.settled_density,

    -- ---------- PROFILING ONLY: never fed to the algorithm ----------
    i.unserved_pop_2020,
    i.gep_pop_2020,
    i.investment_per_capita_usd,
    i.lcoe_usd_per_kwh,
    i.pct_standalone_pv_2030,
    i.pct_minigrid_2030,
    i.demand_tier,
    -- Facilities per 100,000 people. Raw counts partly measure population
    -- size, which is not what an anchor-load variable should measure.
    CASE WHEN i.gep_pop_2020 > 0
         THEN ROUND(100000.0 * i.health_facilities / i.gep_pop_2020, 2)
    END                                          AS health_per_100k,
    i.health_facilities,
    f.loss_ha_per_1000sqkm,

    -- ---------- QUALITY, CARRIED THROUGH ----------
    -- Stage 2 clusters twice: all 769, and again excluding 'suspect'.
    -- That is the commitment made in Q7 and this column is what makes it
    -- executable.
    i.gep_flag,
    i.pop_ratio,
    i.pct_foreign

FROM lga_gep_indicators AS i
JOIN lga_poverty        AS p ON p.lga_pcode  = i.lga_pcode
JOIN state_forest_feature AS f ON f.state_name = i.state_name
WHERE i.n_clusters > 0;

CREATE UNIQUE INDEX idx_cluster_features_pcode ON cluster_features (lga_pcode);


-- ------------------------------------------------------------
-- Checks. Expected values recorded 1 September 2026.
-- ------------------------------------------------------------

-- 769 LGAs: 774 minus the five with no clusters. If this is lower, an
-- inner join has silently dropped LGAs -- most likely the poverty or
-- forest join, both of which reach this table through name-based
-- reconciliation.
SELECT 'one row per clusterable LGA' AS check_name,
       (SELECT COUNT(*) FROM cluster_features)                        AS actual,
       (SELECT COUNT(*) FROM lga_gep_indicators WHERE n_clusters > 0) AS expected,
       CASE WHEN (SELECT COUNT(*) FROM cluster_features)
               = (SELECT COUNT(*) FROM lga_gep_indicators WHERE n_clusters > 0)
            THEN 'PASS' ELSE 'FAIL' END                               AS result;

-- NO NULLS IN ANY CLUSTERING FEATURE. This is not a style preference.
-- scikit-learn will refuse a matrix containing NaN, and the failure comes
-- hundreds of lines later with no indication of which column caused it.
-- Catch it here, where the column has a name.
SELECT 'no nulls in the seven features',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM cluster_features
WHERE elec_rate_2020        IS NULL
   OR demand_kwh_per_capita IS NULL
   OR poverty_rate          IS NULL
   OR travel_hours          IS NULL
   OR mv_line_dist_km       IS NULL
   OR pct_grid_new_2030     IS NULL
   OR settled_density       IS NULL;

-- No clustering feature may be constant. Same guard as 07, same reason:
-- a zero-variance column is a sentinel or a bug, and in a distance
-- calculation it is silently ignored while looking like a real dimension.
SELECT 'no clustering feature is constant',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(DISTINCT elec_rate_2020)        AS n FROM cluster_features
    UNION ALL SELECT COUNT(DISTINCT demand_kwh_per_capita) FROM cluster_features
    UNION ALL SELECT COUNT(DISTINCT poverty_rate)          FROM cluster_features
    UNION ALL SELECT COUNT(DISTINCT travel_hours)          FROM cluster_features
    UNION ALL SELECT COUNT(DISTINCT mv_line_dist_km)       FROM cluster_features
    UNION ALL SELECT COUNT(DISTINCT pct_grid_new_2030)     FROM cluster_features
    UNION ALL SELECT COUNT(DISTINCT settled_density)       FROM cluster_features
)
WHERE n <= 1;

-- Rates stay rates.
SELECT 'rates within 0-1',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM cluster_features
WHERE elec_rate_2020    NOT BETWEEN 0 AND 1
   OR poverty_rate      NOT BETWEEN 0 AND 1
   OR pct_grid_new_2030 NOT BETWEEN 0 AND 1;

-- The quality flag survived the joins, so the dual-track run is possible.
SELECT 'both flag groups present',
       (SELECT COUNT(DISTINCT gep_flag) FROM cluster_features), 2,
       CASE WHEN (SELECT COUNT(DISTINCT gep_flag) FROM cluster_features) = 2
            THEN 'PASS' ELSE 'FAIL' END;


-- ------------------------------------------------------------
-- The correlation guard.
--
-- The whole feature set rests on one claim: no pair of the seven exceeds
-- |r| = 0.7. That claim was true on 1 September 2026 and will stop being
-- true the moment a source is revised. SQLite has no CORR(), so this
-- computes Pearson's r longhand for the pair that was closest to the
-- threshold -- elec_rate_2020 against demand_kwh_per_capita, r = 0.67.
--
-- The full matrix is recomputed in the Python script, which asserts on
-- all 21 pairs. This check is the cheap early warning.
-- ------------------------------------------------------------

WITH s AS (
    SELECT COUNT(*)                                   AS n,
           SUM(elec_rate_2020)                        AS sx,
           SUM(demand_kwh_per_capita)                 AS sy,
           SUM(elec_rate_2020 * demand_kwh_per_capita) AS sxy,
           SUM(elec_rate_2020 * elec_rate_2020)       AS sxx,
           SUM(demand_kwh_per_capita * demand_kwh_per_capita) AS syy
    FROM cluster_features
)
SELECT 'elec_rate vs demand still under 0.7' AS check_name,
       ROUND((n*sxy - sx*sy)
             / (SQRT(n*sxx - sx*sx) * SQRT(n*syy - sy*sy)), 3) AS actual,
       0.7                                                     AS expected,
       CASE WHEN ABS((n*sxy - sx*sy)
                     / (SQRT(n*sxx - sx*sx) * SQRT(n*syy - sy*sy))) < 0.7
            THEN 'PASS' ELSE 'FAIL' END                        AS result
FROM s;


-- ------------------------------------------------------------
-- What the algorithm will actually see. Read this before clustering:
-- the spread of each feature decides how much it can influence a
-- distance, and the skewed ones are why four of the seven are logged in
-- Python before standardisation.
-- ------------------------------------------------------------

SELECT 'elec_rate_2020'        AS feature, ROUND(MIN(elec_rate_2020),3)        AS min,
       ROUND(AVG(elec_rate_2020),3) AS mean, ROUND(MAX(elec_rate_2020),3) AS max FROM cluster_features
UNION ALL SELECT 'demand_kwh_per_capita', ROUND(MIN(demand_kwh_per_capita),3), ROUND(AVG(demand_kwh_per_capita),3), ROUND(MAX(demand_kwh_per_capita),3) FROM cluster_features
UNION ALL SELECT 'poverty_rate',          ROUND(MIN(poverty_rate),3),          ROUND(AVG(poverty_rate),3),          ROUND(MAX(poverty_rate),3)          FROM cluster_features
UNION ALL SELECT 'travel_hours',          ROUND(MIN(travel_hours),3),          ROUND(AVG(travel_hours),3),          ROUND(MAX(travel_hours),3)          FROM cluster_features
UNION ALL SELECT 'mv_line_dist_km',       ROUND(MIN(mv_line_dist_km),3),       ROUND(AVG(mv_line_dist_km),3),       ROUND(MAX(mv_line_dist_km),3)       FROM cluster_features
UNION ALL SELECT 'pct_grid_new_2030',     ROUND(MIN(pct_grid_new_2030),3),     ROUND(AVG(pct_grid_new_2030),3),     ROUND(MAX(pct_grid_new_2030),3)     FROM cluster_features
UNION ALL SELECT 'settled_density',       ROUND(MIN(settled_density),3),       ROUND(AVG(settled_density),3),       ROUND(MAX(settled_density),3)       FROM cluster_features;
