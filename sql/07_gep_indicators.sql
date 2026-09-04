-- ============================================================
-- 07_gep_indicators.sql
-- LGA-level energy indicators from the GEP settlement model.
-- The last build of Stage 1: the table Stage 2 clusters on.
--
-- Column meanings are taken from GEP's own documentation, shipped with the
-- download and committed at
--   data/raw/Description-of-output-columns_GEP_V2(1).docx
-- Nothing here is inferred from a column name.
--
--
-- FOUR DECISIONS THAT SHAPE THIS TABLE
--
-- 1. AGGREGATE BY POPULATION, NOT BY CLUSTER.
--    A cluster of 50 people and a cluster of 50,000 are one row each. A
--    plain AVG() over clusters would let a hamlet count as much as a town.
--    Every rate and every mean below is population-weighted:
--        SUM(x * Pop2020) / SUM(Pop2020)
--
--    This matters most for electrification. `ElecStart` is 1 for only
--    34,814 of 708,536 clusters (4.9%) -- but those are the large urban
--    ones, and they hold 59% of the population. AVG(ElecStart) would say
--    Nigeria is 5% electrified. The correct measure uses GEP's own
--    calibrated electrified population:
--        SUM(ElecPopCalib) / SUM(Pop2020) = 122,413,799 / 206,140,000 = 0.594
--
-- 2. THE 2030 ACCESS RATE IS NOT A VARIABLE. `ElecStatusIn2030` equals 1
--    for ALL 708,536 clusters. This scenario models universal access by
--    2030 by construction, so "electrification rate in 2030" is 100%
--    everywhere and carries no information. What varies, and what a market
--    segmentation actually needs, is HOW each place gets there and at what
--    cost per person. Hence the technology-mix and cost columns below.
--
-- 3. THE TECHNOLOGY ANSWER IS ALREADY LOPSIDED, AND THAT IS A FINDING.
--    Least-cost technology in 2030, by cluster count:
--        code 3  SA_PV (stand-alone solar)   635,717   89.7%
--        code 2  Grid extension               35,656    5.0%
--        code 1  Grid, already connected      34,814    4.9%
--        code 5  Mini-grid PV hybrid           2,330    0.3%
--        code 7  Mini-grid hydro                  18
--        code 6  Mini-grid wind                    1
--
--    Under this scenario's cost assumptions, mini-grids are least-cost
--    almost nowhere in Nigeria. That is a commercially significant claim
--    and it belongs in the write-up -- WITH the caveat that it is a
--    property of scenario ng-2-0_0_0_0_0_0's assumptions, not a law of
--    nature. A different capital cost or demand target would move it.
--
--    For clustering it also means technology mix has little variance and
--    will do little work as a feature. The segmentation will have to turn
--    on unserved population, cost to serve, remoteness and demand.
--
--    NOTE THE TWO CODE SYSTEMS DO NOT AGREE. `FinalElecCode2030` codes
--    mini-grid PV as 5; `MinimumOverallCode2030` codes the same technology
--    as 8. This file uses FinalElecCode2030 throughout, because that is
--    the technology actually selected. Do not mix them.
--
-- 4. THREE COLUMNS ARE DELIBERATELY NOT USED.
--    - `IsUrban`. GEP's documentation says "All 0 after extraction,
--      urban/rural split gets assigned in the algorithm". In this file it
--      takes values 0, 1 AND 2, which the documentation does not describe,
--      and only 3,818 of 708,536 clusters are non-zero. Nigeria is roughly
--      half urban. The column does not mean what its name suggests and is
--      left out rather than guessed at.
--    - School counts (`Prim`, `Sec`, `Unc`). They total 690 for the whole
--      of Nigeria, a country with well over 100,000 primary schools. The
--      columns exist but are effectively unpopulated.
--    - `ElecStatusIn2030`. Constant, see decision 2.
--
--    - `TransformerDist`. It is **9999 for all 708,536 clusters** -- an
--      OnSSET "no data" sentinel, not a distance. GEP has no transformer
--      locations for Nigeria. An earlier version of this file averaged it
--      into a `transformer_dist_km` column that read 9,999 km for every
--      LGA in the country. Caught on 30 Aug 2026 by looking at the
--      standard deviation of every feature before clustering, which is
--      what the zero-variance check below now does automatically. Every
--      other distance column (`SubstationDist`, `RoadDist`,
--      `CurrentMVLineDist`, `MinGridDist2030`, `TravelHours`) is clean.
--
--    Health facility counts (`Cat_1`, `Cat_2`, `Cat_3`) total 19,450 and
--    ARE used: anchor loads are exactly what a mini-grid developer sizes
--    around.
--
--
-- EVERY ROW CARRIES ITS QUALITY FLAG
-- `gep_flag` from 04_gep_quality.sql is joined in, so no indicator can be
-- read without it. 169 of 774 LGAs are flagged; see Q7.
-- ============================================================


-- ------------------------------------------------------------
-- A projection of the columns this file needs, indexed on id.
--
-- raw_gep is 81 columns and 423 MB with no index on its join key, so a
-- join against it scans the whole table. This narrows it to 24 columns and
-- indexes the key. Same device as gep_small in 04_gep_quality.sql, and the
-- same rule: a build artefact rebuilt from raw_gep every time, never a
-- source of truth.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS gep_wide;

CREATE TABLE gep_wide AS
SELECT id,
       Pop2020, Pop2030, ElecPopCalib, ElecStart,
       FinalElecCode2030,
       GridCellArea,
       TravelHours, RoadDist, SubstationDist,
       CurrentMVLineDist, MinGridDist2030,
       GHI, WindCF, GridPenalty,
       PerCapitaDemand, TotalEnergyPerCell, Tier,
       MinimumOverallLCOE2030, InvestmentCapita2030, InvestmentCost2030,
       NewCapacity2030,
       Cat_1, Cat_2, Cat_3
FROM raw_gep;

CREATE UNIQUE INDEX idx_gep_wide_id ON gep_wide (id);


-- ------------------------------------------------------------
-- The indicator table. One row per LGA, all 774.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS lga_gep_indicators;

CREATE TABLE lga_gep_indicators AS
SELECT
    b.lga_pcode,
    b.lga_name,
    b.state_name,
    b.pop_total                                              AS cod_pop_2020,

    -- Quality flag travels with every indicator. Never read a row without it.
    q.gep_flag,
    q.pop_ratio,
    q.pct_foreign,

    COUNT(g.id)                                              AS n_clusters,
    ROUND(SUM(g.Pop2020))                                    AS gep_pop_2020,
    ROUND(SUM(g.Pop2030))                                    AS gep_pop_2030,

    -- ---- ACCESS TODAY: the size of the market ----
    ROUND(SUM(g.ElecPopCalib))                               AS elec_pop_2020,
    ROUND(SUM(g.Pop2020) - SUM(g.ElecPopCalib))              AS unserved_pop_2020,
    CASE WHEN SUM(g.Pop2020) > 0
         THEN ROUND(SUM(g.ElecPopCalib) / SUM(g.Pop2020), 4)
    END                                                      AS elec_rate_2020,

    -- ---- LEAST-COST TECHNOLOGY BY 2030: what the market needs ----
    -- Shares of 2030 population, not of clusters. Codes 1 and 2 are both
    -- grid (already connected, and new extension) and are reported apart
    -- because they are different commercial propositions.
    CASE WHEN SUM(g.Pop2030) > 0 THEN ROUND(
      SUM(CASE WHEN g.FinalElecCode2030 = 1 THEN g.Pop2030 ELSE 0 END)
      / SUM(g.Pop2030), 4) END                               AS pct_grid_existing_2030,
    CASE WHEN SUM(g.Pop2030) > 0 THEN ROUND(
      SUM(CASE WHEN g.FinalElecCode2030 = 2 THEN g.Pop2030 ELSE 0 END)
      / SUM(g.Pop2030), 4) END                               AS pct_grid_new_2030,
    CASE WHEN SUM(g.Pop2030) > 0 THEN ROUND(
      SUM(CASE WHEN g.FinalElecCode2030 = 3 THEN g.Pop2030 ELSE 0 END)
      / SUM(g.Pop2030), 4) END                               AS pct_standalone_pv_2030,
    CASE WHEN SUM(g.Pop2030) > 0 THEN ROUND(
      SUM(CASE WHEN g.FinalElecCode2030 IN (5,6,7) THEN g.Pop2030 ELSE 0 END)
      / SUM(g.Pop2030), 4) END                               AS pct_minigrid_2030,

    -- ---- COST TO SERVE ----
    CASE WHEN SUM(g.Pop2020) > 0 THEN ROUND(
      SUM(g.InvestmentCapita2030 * g.Pop2020) / SUM(g.Pop2020), 2)
    END                                                      AS investment_per_capita_usd,
    ROUND(SUM(g.InvestmentCost2030))                         AS investment_total_usd,
    CASE WHEN SUM(g.Pop2020) > 0 THEN ROUND(
      SUM(g.MinimumOverallLCOE2030 * g.Pop2020) / SUM(g.Pop2020), 4)
    END                                                      AS lcoe_usd_per_kwh,

    -- ---- REMOTENESS AND GRID PROXIMITY ----
    CASE WHEN SUM(g.Pop2020) > 0 THEN ROUND(
      SUM(g.TravelHours * g.Pop2020) / SUM(g.Pop2020), 3)
    END                                                      AS travel_hours,
    CASE WHEN SUM(g.Pop2020) > 0 THEN ROUND(
      SUM(g.RoadDist * g.Pop2020) / SUM(g.Pop2020), 3)
    END                                                      AS road_dist_km,
    CASE WHEN SUM(g.Pop2020) > 0 THEN ROUND(
      SUM(g.CurrentMVLineDist * g.Pop2020) / SUM(g.Pop2020), 3)
    END                                                      AS mv_line_dist_km,

    -- ---- DEMAND AND RESOURCE ----
    CASE WHEN SUM(g.Pop2020) > 0 THEN ROUND(
      SUM(g.PerCapitaDemand * g.Pop2020) / SUM(g.Pop2020), 2)
    END                                                      AS demand_kwh_per_capita,
    CASE WHEN SUM(g.Pop2020) > 0 THEN ROUND(
      SUM(g.Tier * g.Pop2020) / SUM(g.Pop2020), 3)
    END                                                      AS demand_tier,
    ROUND(SUM(g.TotalEnergyPerCell))                         AS total_demand_kwh_2030,
    CASE WHEN SUM(g.Pop2020) > 0 THEN ROUND(
      SUM(g.GHI * g.Pop2020) / SUM(g.Pop2020), 1)
    END                                                      AS solar_ghi,

    -- ---- SETTLEMENT STRUCTURE ----
    ROUND(SUM(g.GridCellArea), 2)                            AS settled_area_sqkm,
    CASE WHEN SUM(g.GridCellArea) > 0
         THEN ROUND(SUM(g.Pop2020) / SUM(g.GridCellArea), 1)
    END                                                      AS settled_density,

    -- ---- ANCHOR LOADS ----
    SUM(g.Cat_1 + g.Cat_2 + g.Cat_3)                         AS health_facilities

FROM lga_base   AS b
LEFT JOIN gep_quality  AS q ON q.lga_pcode  = b.lga_pcode
LEFT JOIN cluster_lga  AS c ON c.lga_pcode  = b.lga_pcode
LEFT JOIN gep_wide     AS g ON g.id         = c.cluster_id
GROUP BY b.lga_pcode, b.lga_name, b.state_name, b.pop_total,
         q.gep_flag, q.pop_ratio, q.pct_foreign;

CREATE UNIQUE INDEX idx_lga_gep_ind_pcode ON lga_gep_indicators (lga_pcode);
CREATE INDEX IF NOT EXISTS idx_lga_gep_ind_flag ON lga_gep_indicators (gep_flag);


-- ------------------------------------------------------------
-- Checks. Run every time this table is rebuilt.
-- ------------------------------------------------------------

SELECT 'one row per LGA' AS check_name,
       (SELECT COUNT(*) FROM lga_gep_indicators) AS actual,
       (SELECT COUNT(*) FROM lga_base)           AS expected,
       CASE WHEN (SELECT COUNT(*) FROM lga_gep_indicators)
               = (SELECT COUNT(*) FROM lga_base)
            THEN 'PASS' ELSE 'FAIL' END          AS result;

-- Every cluster is accounted for exactly once.
SELECT 'clusters conserved',
       (SELECT SUM(n_clusters) FROM lga_gep_indicators),
       (SELECT COUNT(*) FROM cluster_lga),
       CASE WHEN (SELECT SUM(n_clusters) FROM lga_gep_indicators)
               = (SELECT COUNT(*) FROM cluster_lga)
            THEN 'PASS' ELSE 'FAIL' END;

-- Population conserved against the source, not just internally consistent.
SELECT 'gep population conserved',
       (SELECT ROUND(SUM(gep_pop_2020)) FROM lga_gep_indicators),
       (SELECT ROUND(SUM(Pop2020)) FROM gep_wide),
       CASE WHEN ABS((SELECT SUM(gep_pop_2020) FROM lga_gep_indicators)
                   - (SELECT SUM(Pop2020) FROM gep_wide)) < 1000
            THEN 'PASS' ELSE 'FAIL' END;

-- Rates must be rates. A share outside 0-1 means a weighted mean has been
-- computed over the wrong denominator.
SELECT 'all shares within 0-1',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM lga_gep_indicators
WHERE (elec_rate_2020          IS NOT NULL AND elec_rate_2020          NOT BETWEEN 0 AND 1)
   OR (pct_grid_existing_2030  IS NOT NULL AND pct_grid_existing_2030  NOT BETWEEN 0 AND 1)
   OR (pct_grid_new_2030       IS NOT NULL AND pct_grid_new_2030       NOT BETWEEN 0 AND 1)
   OR (pct_standalone_pv_2030  IS NOT NULL AND pct_standalone_pv_2030  NOT BETWEEN 0 AND 1)
   OR (pct_minigrid_2030       IS NOT NULL AND pct_minigrid_2030       NOT BETWEEN 0 AND 1);

-- The four technology shares must sum to 1 for every LGA that has clusters.
-- If they do not, FinalElecCode2030 contains a code this file does not
-- handle, and a technology is being dropped silently.
SELECT 'technology shares sum to 1',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM lga_gep_indicators
WHERE n_clusters > 0
  AND ABS(COALESCE(pct_grid_existing_2030,0) + COALESCE(pct_grid_new_2030,0)
        + COALESCE(pct_standalone_pv_2030,0) + COALESCE(pct_minigrid_2030,0) - 1.0) > 0.001;

-- Electrified population cannot exceed total population.
SELECT 'electrified pop <= total pop',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM lga_gep_indicators
WHERE elec_pop_2020 > gep_pop_2020 + 1;

-- The five LGAs with no clusters must survive as NULL rows, not vanish.
SELECT 'LGAs with no clusters kept',
       COUNT(*), 5,
       CASE WHEN COUNT(*) = 5 THEN 'PASS' ELSE 'FAIL' END
FROM lga_gep_indicators WHERE n_clusters = 0;

-- Every row carries a quality flag.
SELECT 'every row flagged',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM lga_gep_indicators WHERE gep_flag IS NULL;

-- NO INDICATOR MAY BE CONSTANT.
--
-- A column with zero variance is not an indicator. It is either a
-- sentinel value the source uses for "no data", or a bug. Either way it
-- carries no information, and it will sit in a feature matrix looking
-- like a real number.
--
-- This check exists because `TransformerDist` was 9999 for every cluster
-- in Nigeria and this file averaged it into an LGA-level column without
-- anyone looking. Add any new indicator to the list below.
SELECT 'no indicator is constant' AS check_name,
       COUNT(*) AS actual, 0 AS expected,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
    SELECT 'elec_rate_2020'            AS col, COUNT(DISTINCT elec_rate_2020)            AS n FROM lga_gep_indicators
    UNION ALL SELECT 'investment_per_capita_usd', COUNT(DISTINCT investment_per_capita_usd) FROM lga_gep_indicators
    UNION ALL SELECT 'lcoe_usd_per_kwh',          COUNT(DISTINCT lcoe_usd_per_kwh)          FROM lga_gep_indicators
    UNION ALL SELECT 'demand_kwh_per_capita',     COUNT(DISTINCT demand_kwh_per_capita)     FROM lga_gep_indicators
    UNION ALL SELECT 'demand_tier',               COUNT(DISTINCT demand_tier)               FROM lga_gep_indicators
    UNION ALL SELECT 'travel_hours',              COUNT(DISTINCT travel_hours)              FROM lga_gep_indicators
    UNION ALL SELECT 'road_dist_km',              COUNT(DISTINCT road_dist_km)              FROM lga_gep_indicators
    UNION ALL SELECT 'mv_line_dist_km',           COUNT(DISTINCT mv_line_dist_km)           FROM lga_gep_indicators
    UNION ALL SELECT 'solar_ghi',                 COUNT(DISTINCT solar_ghi)                 FROM lga_gep_indicators
    UNION ALL SELECT 'settled_density',           COUNT(DISTINCT settled_density)           FROM lga_gep_indicators
    UNION ALL SELECT 'health_facilities',         COUNT(DISTINCT health_facilities)         FROM lga_gep_indicators
    UNION ALL SELECT 'pct_standalone_pv_2030',    COUNT(DISTINCT pct_standalone_pv_2030)    FROM lga_gep_indicators
)
WHERE n <= 1;


-- ------------------------------------------------------------
-- National summary. Sanity, and the numbers for the write-up.
-- ------------------------------------------------------------

SELECT ROUND(SUM(gep_pop_2020))                                  AS pop_2020,
       ROUND(SUM(elec_pop_2020))                                 AS electrified,
       ROUND(SUM(unserved_pop_2020))                             AS unserved,
       ROUND(SUM(elec_pop_2020) / SUM(gep_pop_2020), 4)          AS national_elec_rate,
       ROUND(SUM(unserved_pop_2020 * pct_standalone_pv_2030)
             / SUM(unserved_pop_2020), 4)                        AS share_unserved_sa_pv,
       ROUND(SUM(investment_total_usd) / 1e9, 1)                 AS investment_usd_bn
FROM lga_gep_indicators
WHERE n_clusters > 0;


-- The same summary split by data quality, because the two populations
-- should not be reported as one.
SELECT gep_flag,
       COUNT(*)                                                  AS n_lgas,
       ROUND(SUM(unserved_pop_2020))                             AS unserved,
       ROUND(SUM(elec_pop_2020) / SUM(gep_pop_2020), 4)          AS elec_rate
FROM lga_gep_indicators
WHERE n_clusters > 0
GROUP BY gep_flag
ORDER BY n_lgas DESC;
