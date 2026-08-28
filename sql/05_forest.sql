-- ============================================================
-- 05_forest.sql
-- Tree cover loss as a state-level environmental-pressure attribute.
--
-- FOUR THINGS TO KNOW BEFORE READING ANY NUMBER FROM THIS FILE
-- (all four are recorded in docs/data_provenance.md, note 8)
--
-- 1. ABSENCE IS NOT ZERO. The source holds 853 state-year rows where
--    37 x 25 = 925 are possible. A state-year with no recorded loss is
--    MISSING from the file, not present as a zero. Grouping the raw table
--    would divide by the wrong denominator and make the worst-affected
--    states look average. This file builds the full grid first and
--    coalesces, keeping a flag so a reader can tell a measured zero from
--    an assumed one.
--
-- 2. THE METHOD CHANGES AT 2011. GFW's own words: "The data from 2011
--    onward were produced with an updated methodology that may capture
--    additional loss. Comparisons between the original 2001-2010 data and
--    future years should be performed with caution."
--    The evidence block at the foot of this file measures how much that
--    matters. Read it before using any figure spanning the break.
--
-- 3. THE BOUNDARIES ARE GADM v3.6, NOT THE COD. GFW attributes loss to
--    Global Administrative Areas units. At state level the two sources
--    agree on all 37 names exactly -- verified, not assumed, by the
--    anti-join check below. That agreement is a fact about these 37
--    strings, not a general property of GADM and the COD: the LGA-level
--    join in 06_poverty.sql needed 27 hand-verified name pairs.
--
-- 4. "TREE COVER LOSS" IS NOT "DEFORESTATION". It includes change in both
--    natural and planted forest and need not be human-caused. Call it what
--    it is in the deliverable.
--
-- LICENCE CONDITION, NOT A STYLE CHOICE
-- CC BY 4.0 requires the credit line wherever these data are DISPLAYED,
-- not only where they are cited. Every chart or dashboard panel built on
-- this table carries, on the panel itself:
--     Source: Hansen/UMD/Google/USGS/NASA
-- ============================================================


-- ------------------------------------------------------------
-- Guard first. Everything below assumes the 37 GFW state names match the
-- 37 COD state names exactly. Prove it before relying on it.
-- ------------------------------------------------------------

SELECT 'GFW states not in COD' AS check_name,
       COUNT(*) AS actual, 0 AS expected,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM raw_gfw_adm1 AS g
WHERE NOT EXISTS (SELECT 1 FROM lga_base AS b WHERE b.state_name = g.name);

SELECT 'COD states not in GFW',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT DISTINCT state_name FROM lga_base) AS b
WHERE NOT EXISTS (SELECT 1 FROM raw_gfw_adm1 AS g WHERE g.name = b.state_name);

-- Both returned 0 on 27 Aug 2026. If either ever fails, STOP: the state
-- join is no longer safe and the LGA-level lesson from 06_poverty.sql
-- applies here too.


-- ------------------------------------------------------------
-- The state-year grid. Every state, every year, no silent gaps.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS state_forest_loss;

CREATE TABLE state_forest_loss AS
SELECT
    s.state_name,
    y.loss_year,
    COALESCE(l.umd_tree_cover_loss__ha, 0.0)              AS loss_ha,
    COALESCE(l."gfw_gross_emissions_co2e_all_gases__Mg",
             0.0)                                          AS emissions_mg,
    -- 1 means "the source had no row for this state-year and this file
    -- assumed zero". Never aggregate without knowing how many of these
    -- are inside the aggregate.
    CASE WHEN l.umd_tree_cover_loss__ha IS NULL
         THEN 1 ELSE 0 END                                 AS was_absent,
    -- Which side of the methodology break this year falls on.
    CASE WHEN y.loss_year >= 2011 THEN 'v1.7+' ELSE 'original' END
                                                           AS method_era
FROM      (SELECT DISTINCT state_name FROM lga_base)            AS s
CROSS JOIN (SELECT DISTINCT umd_tree_cover_loss__year AS loss_year
            FROM raw_gfw_loss_region)                           AS y
LEFT JOIN raw_gfw_adm1        AS g ON g.name  = s.state_name
LEFT JOIN raw_gfw_loss_region AS l ON l.adm1  = g.adm1__id
                                  AND l.umd_tree_cover_loss__year = y.loss_year;

CREATE INDEX IF NOT EXISTS idx_sfl_state ON state_forest_loss (state_name);
CREATE INDEX IF NOT EXISTS idx_sfl_year  ON state_forest_loss (loss_year);


-- ------------------------------------------------------------
-- Checks. Expected values recorded 27 August 2026.
-- ------------------------------------------------------------

-- 37 states x 25 years. If this is not 925 the CROSS JOIN lost a side.
SELECT 'grid is complete' AS check_name,
       (SELECT COUNT(*) FROM state_forest_loss)                        AS actual,
       (SELECT COUNT(DISTINCT state_name) FROM lga_base)
       * (SELECT COUNT(DISTINCT umd_tree_cover_loss__year)
          FROM raw_gfw_loss_region)                                    AS expected,
       CASE WHEN (SELECT COUNT(*) FROM state_forest_loss)
               = (SELECT COUNT(DISTINCT state_name) FROM lga_base)
                 * (SELECT COUNT(DISTINCT umd_tree_cover_loss__year)
                    FROM raw_gfw_loss_region)
            THEN 'PASS' ELSE 'FAIL' END;

-- Rows carried from the source must equal the source's row count. This is
-- the assertion that catches a join silently dropping or duplicating.
SELECT 'rows carried from source',
       (SELECT SUM(1 - was_absent) FROM state_forest_loss),
       (SELECT COUNT(*) FROM raw_gfw_loss_region),
       CASE WHEN (SELECT SUM(1 - was_absent) FROM state_forest_loss)
               = (SELECT COUNT(*) FROM raw_gfw_loss_region)
            THEN 'PASS' ELSE 'FAIL' END;

-- Hectares must reconcile exactly. Coalescing adds zeros, never hectares.
SELECT 'hectares reconcile',
       (SELECT ROUND(SUM(loss_ha), 2) FROM state_forest_loss),
       (SELECT ROUND(SUM(umd_tree_cover_loss__ha), 2) FROM raw_gfw_loss_region),
       CASE WHEN ROUND((SELECT SUM(loss_ha) FROM state_forest_loss), 2)
               = ROUND((SELECT SUM(umd_tree_cover_loss__ha)
                        FROM raw_gfw_loss_region), 2)
            THEN 'PASS' ELSE 'FAIL' END;

-- How many cells are assumed rather than measured.
SELECT 'assumed zeros counted, not hidden',
       (SELECT SUM(was_absent) FROM state_forest_loss), 72,
       CASE WHEN (SELECT SUM(was_absent) FROM state_forest_loss) = 72
            THEN 'PASS' ELSE 'FAIL' END;

-- ANSWER (27 Aug 2026): 925 grid rows, 853 carried from source,
-- 72 assumed zeros, 1,556,892.44 ha total. All four PASS.


-- ============================================================
-- THE 2011 DECISION
--
-- GFW warns that the series is not comparable across 2011. That warning
-- is not a reason to panic and not a reason to ignore it; it is a reason
-- to measure the size of the problem and then decide. The three queries
-- below are the evidence. Run them before choosing a window.
--
-- This is the same decision already taken once in this project, for the
-- COD-PS 2020 and 2022 population releases (docs/data_provenance.md,
-- note 3). There, rebasing would have presented a change of method as a
-- change in population, and it was refused. The principle carries.
-- ============================================================

-- EVIDENCE 1. The national series. Look at 2010 -> 2011.
SELECT loss_year,
       ROUND(SUM(loss_ha))            AS national_ha,
       SUM(1 - was_absent)            AS states_reporting,
       method_era
FROM state_forest_loss
GROUP BY loss_year
ORDER BY loss_year;

-- ANSWER (27 Aug 2026), abridged:
--   2001  43,386   2006  26,168   2011   53,891   2016   72,190   2021   97,193
--   2002  32,347   2007  24,573   2012   34,971   2017  171,046   2022  106,189
--   2003  13,381   2008  27,471   2013   43,435   2018  119,823   2023   85,267
--   2004  14,644   2009  25,290   2014   68,637   2019   86,895   2024  105,644
--   2005  13,280   2010  32,782   2015   40,928   2020   99,200   2025  118,263


-- EVIDENCE 2. The size of the step.
SELECT method_era,
       MIN(loss_year) || '-' || MAX(loss_year)                  AS window,
       COUNT(DISTINCT loss_year)                                AS n_years,
       ROUND(SUM(loss_ha))                                      AS total_ha,
       ROUND(SUM(loss_ha) / COUNT(DISTINCT loss_year))          AS mean_annual_ha
FROM state_forest_loss
GROUP BY method_era
ORDER BY window;

-- ANSWER (27 Aug 2026):
--   original  2001-2010  10 yrs    253,320 ha    25,332 ha/yr
--   v1.7+     2011-2025  15 yrs  1,303,572 ha    86,905 ha/yr
--
-- A 3.43x step. Some of that is real -- Nigeria's forest loss did
-- accelerate -- and some is the instrument becoming more sensitive.
-- NOTHING IN THIS DATA SEPARATES THE TWO. That is precisely why a single
-- 2001-2025 total per state must not be quoted as a measurement.


-- EVIDENCE 3. The question that actually decides it: does the choice of
-- window change the ANSWER? A methodological choice matters only as much
-- as its effect on the result, and that is measurable rather than
-- arguable.
SELECT COALESCE(f.state_name, r.state_name)                     AS state_name,
       ROUND(f.mean_ha, 1)                                      AS mean_ha_2001_2025,
       ROUND(r.mean_ha, 1)                                      AS mean_ha_2011_2025,
       f.rk                                                     AS rank_full,
       r.rk                                                     AS rank_recent,
       f.rk - r.rk                                              AS rank_shift
FROM (SELECT state_name, AVG(loss_ha) AS mean_ha,
             RANK() OVER (ORDER BY AVG(loss_ha) DESC) AS rk
      FROM state_forest_loss GROUP BY state_name) AS f
JOIN (SELECT state_name, AVG(loss_ha) AS mean_ha,
             RANK() OVER (ORDER BY AVG(loss_ha) DESC) AS rk
      FROM state_forest_loss WHERE loss_year >= 2011 GROUP BY state_name) AS r
  ON f.state_name = r.state_name
ORDER BY r.rk
LIMIT 15;

-- ANSWER (27 Aug 2026) — top ten, both windows:
--   rank  2001-2025               2011-2025
--    1    Edo         14,515.2    Edo         19,739.8
--    2    Taraba       7,325.6    Taraba      10,673.6
--    3    Cross River  6,233.3    Cross River  9,112.9
--    4    Ondo         5,932.4    Ondo         8,184.2
--    5    Ogun         4,907.8    Ogun         6,682.8
--    6    Delta        3,622.8    Ekiti        5,001.9
--    7    Kogi         3,207.7    Delta        4,857.0
--    8    Ekiti        3,184.3    Kogi         4,539.8
--    9    Osun         2,829.1    Osun         4,332.6
--   10    Oyo          2,273.0    Oyo          3,158.6
--
-- THE SAME TEN STATES, in both windows. No state enters or leaves. Only
-- positions 6-8 shuffle, among three states within 12% of each other.


-- ------------------------------------------------------------
-- THE DECISION
--
-- The evidence splits cleanly, so the rule does too:
--
--   MAGNITUDE  -> use 2011-2025 only. Any hectare figure, any rate, any
--                 "X hectares lost" statement. A 3.43x step across the
--                 break makes a 2001-2025 total a statement about GFW's
--                 method as much as about Nigeria.
--
--   RANKING    -> robust either way. The segmentation feature is a
--                 relative measure of environmental pressure between
--                 states, and the top ten are identical across windows.
--                 The choice does not change which states are flagged.
--
-- So: build the clustering feature from 2011-2025, and say in the
-- write-up that the ordering was tested against the full series and did
-- not change. A limitation that was tested and found not to bite is worth
-- more than one that was merely declared.
--
-- Two things that must travel with any figure from this table:
--   - the 2011 break and the window used
--   - "state-level attribute applied to every LGA within the state" --
--     this is not an LGA measurement and must never be presented as one
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- The clustering feature. One row per state, 2011-2025.
--
-- NORMALISED BY AREA, AND THAT CHANGES THE ANSWER.
-- `raw_admin2.area_sqkm` gives every LGA an area, summing to 909,750
-- sq km nationally with no nulls, so state area is available and absolute
-- loss should not be used on its own. Comparing Edo with Lagos on hectares
-- is comparing a large state with a small one.
--
-- Both columns are kept, because they answer different questions. Absolute
-- loss says where the most forest is going. Loss per 1,000 sq km says where
-- the pressure is most intense. For a segmentation feature the second is
-- the right one; for a headline sentence the first is.
--
-- The two disagree. On absolute loss Taraba is second nationally; per unit
-- area it leaves the top five entirely, because it is a very large state.
-- Lagos enters the top ten on intensity while barely registering on
-- hectares. Pick deliberately and say which one a figure is.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS state_forest_feature;

CREATE TABLE state_forest_feature AS
SELECT f.state_name,
       ROUND(f.total_ha, 1)                                     AS loss_ha_2011_2025,
       ROUND(f.total_ha / f.n_years, 1)                         AS mean_annual_loss_ha,
       ROUND(a.area_sqkm)                                       AS state_area_sqkm,
       -- The feature Stage 2 should cluster on.
       ROUND(1000.0 * f.total_ha / f.n_years / a.area_sqkm, 2)  AS loss_ha_per_1000sqkm,
       f.n_years_assumed_zero,
       f.n_years
FROM (SELECT state_name,
             SUM(loss_ha)              AS total_ha,
             SUM(was_absent)           AS n_years_assumed_zero,
             COUNT(*)                  AS n_years
      FROM state_forest_loss
      WHERE loss_year >= 2011
      GROUP BY state_name) AS f
JOIN (SELECT adm1_name AS state_name, SUM(area_sqkm) AS area_sqkm
      FROM raw_admin2 GROUP BY adm1_name) AS a
  ON a.state_name = f.state_name;

-- ANSWER (27 Aug 2026), top eight by intensity, 2011-2025:
--   state         mean ha/yr   area sqkm   ha per 1,000 sqkm
--   Edo             19,739.8      19,514             1,011.55
--   Ekiti            5,001.9       5,754               869.27
--   Ondo             8,184.2      15,076               542.87
--   Osun             4,332.6       8,599               503.86
--   Cross River      9,112.9      20,955               434.88
--   Ogun             6,682.8      16,668               400.94
--   Lagos            1,074.3       3,488               307.97
--   Delta            4,857.0      17,077               284.42

SELECT '37 states in the feature table' AS check_name,
       (SELECT COUNT(*) FROM state_forest_feature) AS actual, 37 AS expected,
       CASE WHEN (SELECT COUNT(*) FROM state_forest_feature) = 37
            THEN 'PASS' ELSE 'FAIL' END AS result;

-- The JOIN above is an INNER JOIN, so a state with no area would vanish
-- silently rather than arrive as NULL. This is the assertion that catches it.
SELECT 'every state has an area',
       (SELECT COUNT(*) FROM raw_admin2 WHERE area_sqkm IS NULL), 0,
       CASE WHEN (SELECT COUNT(*) FROM raw_admin2 WHERE area_sqkm IS NULL) = 0
            THEN 'PASS' ELSE 'FAIL' END;
