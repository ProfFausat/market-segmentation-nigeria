-- ============================================================
-- 11_subsegment_names.sql
-- Names for the four sub-types inside Low-Income Rural Core.
--
-- Same contract as 09_segment_names.sql: `lga_subsegments.sub` KEEPS its
-- original 0-3 labels forever, and every display joins here for the name and
-- the order. If a name changes, it changes in one row.
--
--
-- THE RULE THESE NAMES WERE BUILT TO, AND WHERE IT BENT
-- -----------------------------------------------------
-- The rule from 09: each name comes from the ONE number that separates that
-- group from the others, stated in absolute terms, and the recommendation the
-- name implies must be the right one.
--
-- Applied honestly, the rule did not survive intact here, and the places it
-- bent are recorded in `defining_fact` and `caveat` rather than smoothed over:
--
--   sub 2  NO SINGLE NUMBER SEPARATES IT. 3.5 km is not the shortest distance
--          (sub 1 is 3.2) and 7 percent is not the lowest grid arrival (sub 3
--          is 5). Only the conjunction is unique. More than that: sub 2 has no
--          extreme on any variable at all. It is the CENTRE of the segment,
--          and the largest block in it. The report should say that plainly
--          instead of dressing the biggest market up as a peak.
--
--   sub 3  NAMED ON A CONSEQUENCE. Distance separates it more sharply than
--          solar share does, and the solar share follows from the distance.
--          The name leads with the weaker separator on purpose, because
--          naming it on distance would invite comparison with Deep Off-Grid
--          Frontier at 37.3 km, and 9.6 km is a different proposition
--          entirely. A legibility trade-off, made deliberately.
--
--   sub 0  THE NAME CARRIES THE UPSIDE AND THE CAVEAT CARRIES THE RISK --
--          which is exactly the structure that produced the Dense Emerging
--          Markets error one level up. It is allowed here only because the
--          risk is ordinary: 18 percent grid arrival is the NATIONAL AVERAGE,
--          not a distinctive exposure. The mitigation is that its
--          `operating_step` leads with the horizon, so the row cannot be
--          quoted without it.
--
--
-- HOW THESE NAMES MUST BE WRITTEN
-- --------------------------------
-- NEVER BARE. Always "Low-Income Rural Core -> Off-Plan Grid Edge".
--
-- Two reasons. First, four of the nine names in this project contain the word
-- Grid (Grid-Arrival Markets, Grid-Served Hinterland, Off-Plan Grid Edge,
-- Grid-Bound Exception) and a reader three pages past the definition will
-- blur them. Second, a bare sub-name reads as a sixth segment, which it is
-- not. The view below computes `full_label` so the rule is enforced by the
-- data rather than by anyone remembering it.
--
--
-- WHAT THE NAMING RESTS ON, AND WHAT IT DOES NOT
-- -----------------------------------------------
-- subcluster.py found the four by beating a null model -- each feature column
-- shuffled independently, preserving every marginal distribution while
-- destroying the joint structure. Real silhouette 0.214 against a null 95th
-- percentile of 0.156, an excess of +0.058 over a 0.02 margin, stability ARI
-- 0.902 across 20 seeds.
--
-- TWO THINGS THAT RESULT DOES NOT LICENCE:
--
--   The excess curve is FLAT. k=3 gives +0.047, k=4 gives +0.058, k=6 gives
--   +0.037. Four wins by 0.011, well inside the noise of a 50-run null. So
--   the defensible claim is "real structure, roughly three to five types",
--   NOT "there are exactly four". These names describe one defensible
--   partition, not a discovered natural kind.
--
--   The absolute silhouette is 0.214 -- low. Still a continuum, same as the
--   parent.
--
-- One result worth publishing in its own right: k=2 comes back NEGATIVE
-- (-0.081), worse than shuffled data. The intuitive split, cutting the north
-- in two, is the one division the data actively refuses.
-- ============================================================

DROP TABLE IF EXISTS subsegment_names;

CREATE TABLE subsegment_names (
    parent_segment    INTEGER NOT NULL,   -- seg_kmeans of the parent
    sub               INTEGER NOT NULL,   -- as produced by pipeline/subcluster.py
    display_order     INTEGER NOT NULL UNIQUE,
    subsegment_name   TEXT    NOT NULL UNIQUE,
    defining_fact     TEXT    NOT NULL,
    is_offgrid_market INTEGER NOT NULL,
    operating_step    TEXT    NOT NULL,
    caveat            TEXT,
    PRIMARY KEY (parent_segment, sub)
);

INSERT INTO subsegment_names
    (parent_segment, sub, display_order, subsegment_name, defining_fact,
     is_offgrid_market, operating_step, caveat)
VALUES
  (3, 2, 1, 'Off-Plan Grid Edge',
   '3.5 km from a medium-voltage line yet only 7 percent scheduled for a grid connection by 2030. Neither number is extreme alone -- sub 1 is closer at 3.2 km, sub 3 is lower at 5 percent -- the conjunction is what no other sub-type has. Largest block: 115 LGAs, 17.3M unserved, 36.2 percent of the segment.',
   1,
   'Enter here first. Logistics are cheap at 3.5 km from existing infrastructure with the shortest travel times in the segment, and the grid is not scheduled to close the gap. Stand-alone solar is least-cost for 54 percent of its people and mini-grid for under 1 percent, so plan household systems rather than distribution.',
   'Has no extreme on any single variable. It is the centre of the segment, not a peak, and the write-up should say so. 9 of 115 flagged suspect (8 percent), the cleanest data of the four. A corroborating but weak signal: 95 percent of its LGAs are nearest to Grid-Served Hinterland -- suggestive, not independent evidence, because a well-fitting group (mean silhouette 0.312) has a largely arbitrary second-nearest.'),

  (3, 3, 2, 'Solar-Default Remote',
   'Stand-alone solar is least-cost for 75.1 percent of its people, the highest share anywhere in the country. 9.6 km to a medium-voltage line and 0.96 hours travel to town, both the highest in the segment.',
   1,
   'The purest off-grid market in the volume segment and the best-formed of the four -- mean parent silhouette 0.424, not one LGA below zero. Only 5 percent are scheduled for grid connection, so asset life is not at risk. Price and staff for a cost to serve roughly triple sub 2 at a similar revenue per connection.',
   'NAMED ON A CONSEQUENCE, NOT ITS SHARPEST SEPARATOR -- see the header. Do not read 9.6 km as comparable to Deep Off-Grid Frontier at 37.3 km. 10 of 63 flagged suspect (16 percent).'),

  (3, 0, 3, 'Lower-Poverty Rural',
   'Poverty rate 0.322 against 0.491, 0.513 and 0.608 for the other three -- the only clean single-variable separation in this sub-clustering. Lowest settlement density of the four at 3,734.',
   1,
   'READ THE HORIZON FIRST: 18 percent are scheduled for grid connection by 2030, triple sub 2 at 7 percent and sub 3 at 5 percent. Size asset life accordingly. The offsetting fact is the reason for the name -- this is the best ability to pay in the volume market -- but the horizon leads, because only a name travels into a summary and this name carries the upside.',
   'The name puts the upside in front and the risk behind, the same structure that produced the Dense Emerging Markets error at segment level. Defensible only because 18 percent is the NATIONAL AVERAGE -- an ordinary horizon, nowhere near the 54 percent of Grid-Arrival Markets. If that stops being true, rename it. 15 of 77 flagged suspect (19 percent), the weakest data of the four.'),

  (3, 1, 4, 'Grid-Bound Exception',
   'Stand-alone solar is least-cost for only 24 percent of its people, against 54 to 75 percent for the other three. Mini-grid takes a further 0.9 percent, so roughly three-quarters of this group is grid -- existing or planned.',
   0,
   'Not an off-grid market. Carve it out of any recommendation made about the parent segment and report it separately. 2.9M unserved people is not nothing, but the answer for them is a grid connection, not a solar product.',
   'Also the worst fit to its parent: mean parent silhouette 0.160 against 0.31 to 0.42. Geographically it is Ebonyi, Enugu, Plateau, Benue, Kwara and Oyo -- south-east and Middle Belt inside an otherwise northern segment. Demand is 159 kWh per person per year against 31 for subs 0 and 2, so the parent segment pricing advice is wrong here by more than four times.');


-- ------------------------------------------------------------
-- The join every display uses. `full_label` exists so the never-bare rule
-- is enforced by the data, not by memory.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS lga_subsegments_named;

CREATE VIEW lga_subsegments_named AS
SELECT z.lga_pcode,
       z.lga_name,
       z.state_name,
       z.gep_flag,
       z.seg_kmeans,                     -- parent cluster, never rewritten
       z.sub,                            -- sub-cluster, never rewritten
       p.display_order   AS parent_order,
       p.segment_name    AS parent_name,
       n.display_order   AS sub_order,
       n.subsegment_name,
       p.segment_name || ' -> ' || n.subsegment_name AS full_label,
       n.is_offgrid_market,
       n.operating_step,
       n.caveat
FROM lga_subsegments AS z
JOIN subsegment_names AS n
       ON n.sub = z.sub AND n.parent_segment = z.parent_segment
JOIN segment_names AS p
       ON p.seg_kmeans = z.seg_kmeans;


-- ------------------------------------------------------------
-- Checks.
-- ------------------------------------------------------------

SELECT 'four sub-types named' AS check_name,
       (SELECT COUNT(*) FROM subsegment_names) AS actual, 4 AS expected,
       CASE WHEN (SELECT COUNT(*) FROM subsegment_names) = 4
            THEN 'PASS' ELSE 'FAIL' END AS result;

-- THE CHECK THAT MATTERS MOST. Naming sub-types is only legitimate because
-- the null model was beaten. If substructure_real is ever 0, these names are
-- decoration on noise and must not be used.
SELECT 'the null test passed before any naming',
       (SELECT COUNT(*) FROM lga_subsegments WHERE substructure_real <> 1), 0,
       CASE WHEN (SELECT COUNT(*) FROM lga_subsegments
                  WHERE substructure_real <> 1) = 0
            THEN 'PASS' ELSE 'FAIL' END;

-- Every sub-cluster has exactly one name, and no name refers to a
-- sub-cluster that does not exist. Fires if k ever changes.
SELECT 'names match the sub-clusters exactly',
       (SELECT COUNT(*) FROM (
           SELECT sub FROM lga_subsegments
           EXCEPT SELECT sub FROM subsegment_names
           UNION ALL
           SELECT sub FROM subsegment_names
           EXCEPT SELECT sub FROM lga_subsegments)), 0,
       CASE WHEN (SELECT COUNT(*) FROM (
           SELECT sub FROM lga_subsegments
           EXCEPT SELECT sub FROM subsegment_names
           UNION ALL
           SELECT sub FROM subsegment_names
           EXCEPT SELECT sub FROM lga_subsegments)) = 0
            THEN 'PASS' ELSE 'FAIL' END;

-- The names table and the label table must agree on which parent this is.
SELECT 'both tables name the same parent',
       (SELECT COUNT(*) FROM lga_subsegments z
        WHERE z.parent_segment NOT IN
              (SELECT parent_segment FROM subsegment_names)
           OR z.seg_kmeans <> z.parent_segment), 0,
       CASE WHEN (SELECT COUNT(*) FROM lga_subsegments z
                  WHERE z.parent_segment NOT IN
                        (SELECT parent_segment FROM subsegment_names)
                     OR z.seg_kmeans <> z.parent_segment) = 0
            THEN 'PASS' ELSE 'FAIL' END;

SELECT 'display_order is 1..4',
       (SELECT COUNT(*) FROM subsegment_names
        WHERE display_order NOT BETWEEN 1 AND 4), 0,
       CASE WHEN (SELECT COUNT(*) FROM subsegment_names
                  WHERE display_order NOT BETWEEN 1 AND 4) = 0
             AND (SELECT COUNT(DISTINCT display_order)
                  FROM subsegment_names) = 4
            THEN 'PASS' ELSE 'FAIL' END;

SELECT 'view preserves every LGA',
       (SELECT COUNT(*) FROM lga_subsegments_named),
       (SELECT COUNT(*) FROM lga_subsegments),
       CASE WHEN (SELECT COUNT(*) FROM lga_subsegments_named)
               = (SELECT COUNT(*) FROM lga_subsegments)
            THEN 'PASS' ELSE 'FAIL' END;

SELECT 'every sub-type is actionable',
       (SELECT COUNT(*) FROM subsegment_names
        WHERE operating_step IS NULL OR TRIM(operating_step) = ''), 0,
       CASE WHEN (SELECT COUNT(*) FROM subsegment_names
                  WHERE operating_step IS NULL
                     OR TRIM(operating_step) = '') = 0
            THEN 'PASS' ELSE 'FAIL' END;


-- ------------------------------------------------------------
-- The summary table for the sub-section of the report.
-- ------------------------------------------------------------

SELECT n.display_order                                   AS "#",
       n.subsegment_name,
       COUNT(*)                                          AS n_lgas,
       ROUND(SUM(f.unserved_pop_2020) / 1e6, 1)          AS unserved_m,
       ROUND(100.0 * SUM(f.unserved_pop_2020)
             / (SELECT SUM(cf.unserved_pop_2020)
                FROM cluster_features cf
                JOIN lga_subsegments zz ON zz.lga_pcode = cf.lga_pcode), 1)
                                                         AS pct_of_segment,
       ROUND(AVG(f.elec_rate_2020), 3)                   AS elec_rate,
       ROUND(AVG(f.pct_standalone_pv_2030), 3)           AS sa_pv_share,
       ROUND(AVG(f.pct_grid_new_2030), 3)                AS grid_by_2030,
       ROUND(AVG(f.mv_line_dist_km), 1)                  AS mv_km,
       ROUND(AVG(f.poverty_rate), 3)                     AS poverty,
       SUM(z.gep_flag = 'suspect')                       AS n_suspect,
       n.is_offgrid_market
FROM lga_subsegments AS z
JOIN subsegment_names AS n
       ON n.sub = z.sub AND n.parent_segment = z.parent_segment
JOIN cluster_features AS f ON f.lga_pcode = z.lga_pcode
GROUP BY n.display_order, n.subsegment_name, n.is_offgrid_market
ORDER BY n.display_order;

-- ANSWER expected (12 Sep 2026), verified against the database before this
-- file was written:
--  #  subsegment_name        LGAs  unserved  % seg  elec   SA-PV  grid30  mv_km  pov    susp  off-grid
--  1  Off-Plan Grid Edge      115    17.3M    36.2  0.388  0.540  0.070    3.5   0.491    9     1
--  2  Solar-Default Remote     63    13.3M    28.0  0.187  0.751  0.052    9.6   0.513   10     1
--  3  Lower-Poverty Rural      77    14.2M    29.8  0.191  0.618  0.180    6.6   0.322   15     1
--  4  Grid-Bound Exception     19     2.9M     6.0  0.444  0.240  0.291    3.2   0.608    2     0
--
-- 47.6M unserved across 274 LGAs. Sub-types 1 and 2 are 178 LGAs and 30.6M
-- unserved that the grid is not scheduled to reach -- 64.2 percent of the
-- segment (64.23 percent exactly) and the durable core of the whole
-- opportunity.
