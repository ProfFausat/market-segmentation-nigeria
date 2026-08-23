-- ============================================================
-- 03_analysis_base.sql
-- Join the spine to population. This is the table you will query.
--
-- THE ONE DECISION IN THIS FILE:
-- LEFT JOIN, not INNER JOIN.
--
-- The spine has 774 LGAs. Population has 773. An INNER JOIN keeps only
-- rows present in both, so it would return 774 - 1 = 773 rows, quietly
-- dropping Bakassi. Nothing would error. Every later count would say 773,
-- every later sentence claiming "774 LGAs" would be false, and the loss
-- would be invisible.
--
-- A LEFT JOIN keeps all 774 rows from the left-hand table and writes NULL
-- where the right-hand table has nothing. Bakassi survives, visibly
-- incomplete, which is the honest state of the data.
-- ============================================================

DROP TABLE IF EXISTS lga_base;

CREATE TABLE lga_base AS
SELECT
    l.lga_pcode,
    l.lga_name,
    l.state_name,
    l.state_pcode,
    l.sendist_name,
    l.sendist_pcode,
    l.area_sqkm,
    l.center_lat,
    l.center_lon,
    p.pop_total,
    p.pop_female,
    p.pop_male,
    -- Population density. NULL area or NULL population propagates to NULL
    -- density, which is correct: an unknown divided by anything is unknown.
    CASE
        WHEN l.area_sqkm > 0 THEN p.pop_total / l.area_sqkm
        ELSE NULL
    END AS pop_density
FROM lga AS l
LEFT JOIN pop_2020 AS p
    ON l.lga_pcode = p.lga_pcode;

-- NOTE THE JOIN KEY: lga_pcode, never lga_name.
-- 774 LGAs carry only 768 distinct names. Bassa, Ifelodun, Irepodun,
-- Nasarawa, Obi and Surulere each name two different LGAs in two different
-- states. Joining on name would attach the wrong population to twelve rows
-- and raise no error at all.
