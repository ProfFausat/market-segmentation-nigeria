-- ============================================================
-- 09_segment_names.sql
-- The single place where a cluster number becomes a market type.
--
-- THIS FILE EXISTS SO THAT THE RENUMBERING HAPPENS ONCE.
--
-- scikit-learn returns clusters labelled 0-4 in an order decided by where
-- the centroids happened to initialise. That order carries no meaning and
-- is not the order a reader should meet them in. So the deliverable
-- renumbers them 1-5 by commercial priority.
--
-- The danger in that is obvious and it is why this table exists: as soon
-- as "segment 3" means one thing in the database, another in a chart and
-- a third in the report, nobody can check anything. Six weeks from now
-- neither can you.
--
-- SO: `lga_segments.seg_kmeans` KEEPS its original 0-4 labels forever.
-- Nothing renames it. Nothing renumbers it. Every display of a segment --
-- every figure, every table, every paragraph of the report, the Power BI
-- dashboard -- joins to this table and reads `display_order` and
-- `segment_name` from here. If a name changes, it changes in one row.
--
--
-- THE ORDERING PRINCIPLE, STATED SO IT CAN BE ARGUED WITH
--
-- Descending off-grid commercial priority: what an expansion director is
-- reading for. NOT unserved population (that would put the grid-arrival
-- segment second, ahead of a market where the grid is not coming), and
-- NOT electrification rate (which is an input to the decision, not the
-- decision).
--
-- The consequence is deliberate: the two segments where an operator would
-- actually deploy capital sit at positions 1 and 2, so a reader who stops
-- after the first page has the answer.
--
--
-- WHAT THE NAMES ARE TAKEN FROM
--
-- Each name comes from the ONE number that separates that segment from
-- the others, not from what its profile looks like in aggregate. An
-- earlier draft named segment 2 "Dense Emerging Markets" -- true of its
-- density, and it buried the fact that 54% of its population is
-- scheduled for grid connection by 2030. The recommendation that followed
-- ("prioritise for scalable customer acquisition") was therefore the
-- opposite of the right advice for the one place an off-grid asset is
-- most likely to be stranded. Names taken from the defining number do not
-- fail that way.
--
--
-- THE SPINE OF THE DELIVERABLE
--
-- Only TWO of the five are off-grid markets at all:
--     seg 1  72% stand-alone solar
--     seg 3  59%
--     seg 2  10%
--     seg 4   5%
--     seg 0   0.1%
-- Segments 0, 2 and 4 are grid stories in three different phases --
-- saturated, arriving, served. The report should say so plainly: here are
-- the two markets, and here are the three reasons the rest are not.
-- ============================================================

DROP TABLE IF EXISTS segment_names;

CREATE TABLE segment_names (
    seg_kmeans     INTEGER PRIMARY KEY,  -- as produced by pipeline/cluster.py
    display_order  INTEGER NOT NULL UNIQUE,
    segment_name   TEXT    NOT NULL UNIQUE,
    defining_fact  TEXT    NOT NULL,     -- the one number the name comes from
    is_offgrid_market INTEGER NOT NULL,  -- 1 = deploy capital here
    operating_step TEXT    NOT NULL,
    caveat         TEXT                  -- what must travel with any use of it
);

INSERT INTO segment_names
    (seg_kmeans, display_order, segment_name, defining_fact,
     is_offgrid_market, operating_step, caveat)
VALUES
  (3, 1, 'Low-Income Rural Core',
   'Poverty rate 0.46 -- the highest of the five -- across 274 LGAs holding 47.6M unserved, 57% of the national total.',
   1,
   'Build here for volume. But price for a customer the model expects to use 37 kWh a year: per Q8, low cost to serve is low revenue per connection, not a bargain. Prove affordability in one state before scaling.',
   'Cleanest data of the five: 36 of 274 LGAs flagged suspect (13%).'),

  (1, 2, 'Deep Off-Grid Frontier',
   'Mean 37.3 km to the nearest MV line, +4.2 SD -- the most extreme value anywhere in the feature matrix. 3.7% electrified.',
   1,
   'The highest concentration of need in the country at 203,000 unserved per LGA, and at this distance the grid is not coming. Enter only alongside a partner already operating in the state.',
   'SECURITY AND LOGISTICS EXPOSURE. 12 of these 26 LGAs are in Borno. Feasibility is decided here before economics is. See the North East decision in Q8.'),

  (2, 3, 'Grid-Arrival Markets',
   '54.4% of population scheduled for new grid connection by 2030 -- more than double any other segment.',
   0,
   'Do not place long-lived assets. 18.8M unserved is a real number, but the grid reaches most of them within the planning horizon. If entering, sell portable or removable systems, or contract around the connection date.',
   'Stranded-asset risk is the defining commercial fact, not a footnote. 29 of 135 flagged suspect (21%).'),

  (4, 4, 'Grid-Served Hinterland',
   '82.7% already electrified and 0.9 km from an MV line. Grid arrival is BELOW average because little is left to connect.',
   0,
   'Not an access market. The opportunity is reliability and backup -- a different product, a different sales motion, and a different customer conversation from anything in segments 1 and 2.',
   '76 of 292 flagged suspect (26%).'),

  (0, 5, 'Served Metros',
   '96.7% electrified, 708 kWh per person per year, settlement density 22,750 -- the top of every scale.',
   0,
   'Not an off-grid market. Deprioritise entirely.',
   'LEAST TRUSTWORTHY DATA IN THE COUNTRY: 23 of 42 LGAs flagged suspect (55%), four times the rate in segment 1 of this ordering. The small remaining access gap it appears to show may not be real.');


-- ------------------------------------------------------------
-- The join every display uses. Never renumber by hand; read from here.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS lga_segments_named;

CREATE VIEW lga_segments_named AS
SELECT s.lga_pcode,
       s.lga_name,
       s.state_name,
       s.gep_flag,
       s.seg_kmeans,               -- the original label, never rewritten
       n.display_order,
       n.segment_name,
       n.is_offgrid_market,
       n.operating_step,
       n.caveat
FROM lga_segments AS s
JOIN segment_names AS n ON n.seg_kmeans = s.seg_kmeans;


-- ------------------------------------------------------------
-- Checks.
-- ------------------------------------------------------------

SELECT 'five segments named' AS check_name,
       (SELECT COUNT(*) FROM segment_names) AS actual, 5 AS expected,
       CASE WHEN (SELECT COUNT(*) FROM segment_names) = 5
            THEN 'PASS' ELSE 'FAIL' END AS result;

-- Every cluster the pipeline produced has exactly one name, and no name
-- refers to a cluster that does not exist. This is the check that fires if
-- k ever changes and the naming is not revisited.
SELECT 'names match the clusters exactly',
       (SELECT COUNT(*) FROM (
           SELECT seg_kmeans FROM lga_segments
           EXCEPT SELECT seg_kmeans FROM segment_names
           UNION ALL
           SELECT seg_kmeans FROM segment_names
           EXCEPT SELECT seg_kmeans FROM lga_segments)), 0,
       CASE WHEN (SELECT COUNT(*) FROM (
           SELECT seg_kmeans FROM lga_segments
           EXCEPT SELECT seg_kmeans FROM segment_names
           UNION ALL
           SELECT seg_kmeans FROM segment_names
           EXCEPT SELECT seg_kmeans FROM lga_segments)) = 0
            THEN 'PASS' ELSE 'FAIL' END;

-- display_order must be exactly 1..5, no gaps, no repeats.
SELECT 'display_order is 1..5',
       (SELECT COUNT(*) FROM segment_names
        WHERE display_order NOT BETWEEN 1 AND 5), 0,
       CASE WHEN (SELECT COUNT(*) FROM segment_names
                  WHERE display_order NOT BETWEEN 1 AND 5) = 0
             AND (SELECT COUNT(DISTINCT display_order) FROM segment_names) = 5
            THEN 'PASS' ELSE 'FAIL' END;

-- The view must not lose or duplicate an LGA.
SELECT 'view preserves every LGA',
       (SELECT COUNT(*) FROM lga_segments_named),
       (SELECT COUNT(*) FROM lga_segments),
       CASE WHEN (SELECT COUNT(*) FROM lga_segments_named)
               = (SELECT COUNT(*) FROM lga_segments)
            THEN 'PASS' ELSE 'FAIL' END;

-- Every segment carries an operating step. A segment nobody can act on is
-- a description, not a segment -- PROJECT_BRIEF.md names that as a way this
-- project fails.
SELECT 'every segment is actionable',
       (SELECT COUNT(*) FROM segment_names
        WHERE operating_step IS NULL OR TRIM(operating_step) = ''), 0,
       CASE WHEN (SELECT COUNT(*) FROM segment_names
                  WHERE operating_step IS NULL OR TRIM(operating_step) = '') = 0
            THEN 'PASS' ELSE 'FAIL' END;


-- ------------------------------------------------------------
-- The deliverable's summary table. This is the shape the report's first
-- page takes.
-- ------------------------------------------------------------

SELECT n.display_order                                  AS "#",
       n.segment_name,
       COUNT(*)                                         AS n_lgas,
       ROUND(SUM(f.unserved_pop_2020) / 1e6, 1)         AS unserved_m,
       ROUND(100.0 * SUM(f.unserved_pop_2020)
             / (SELECT SUM(unserved_pop_2020) FROM cluster_features), 1)
                                                        AS pct_of_unserved,
       ROUND(AVG(f.elec_rate_2020), 3)                  AS elec_rate,
       ROUND(AVG(f.pct_standalone_pv_2030), 3)          AS sa_pv_share,
       SUM(s.gep_flag = 'suspect')                      AS n_suspect,
       n.is_offgrid_market
FROM lga_segments AS s
JOIN segment_names AS n     ON n.seg_kmeans = s.seg_kmeans
JOIN cluster_features AS f  ON f.lga_pcode  = s.lga_pcode
GROUP BY n.display_order, n.segment_name, n.is_offgrid_market
ORDER BY n.display_order;

-- ANSWER expected (4 Sep 2026):
--   #  segment_name              LGAs  unserved  % unserved  elec   SA-PV  susp  off-grid
--   1  Low-Income Rural Core      274     47.6M      56.9    0.290  0.590    36     1
--   2  Deep Off-Grid Frontier      26      5.3M       6.3    0.037  0.720     5     1
--   3  Grid-Arrival Markets       135     18.8M      22.5    0.365  0.099    29     0
--   4  Grid-Served Hinterland     292     11.3M      13.5    0.827  0.051    76     0
--   5  Served Metros               42      0.7M       0.8    0.967  0.001    23     0
--
-- Two segments carry 63.2% of the unserved population and are the only two
-- where stand-alone solar is the least-cost answer for most people. The
-- other three are grid stories at three different stages.
