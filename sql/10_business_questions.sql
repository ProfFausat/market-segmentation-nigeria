-- ============================================================
-- 10_business_questions.sql
--
-- The query catalogue. Target: 15-20 questions an operator would
-- actually ask, each with the query that answers it and the answer
-- recorded underneath.
--
-- Rule for this file: the answer written in the comment is the answer
-- the query produced on the date noted. If the data is rebuilt and a
-- number changes, the comment gets updated or the change gets
-- explained. A stale comment here is the same failure as a stale
-- figure in a README.
--
-- Questions 1-4 answered 21 August 2026 against nigeria_lga.db,
-- built from the sources in docs/data_provenance.md.
-- ============================================================


-- ------------------------------------------------------------
-- Q1. How many LGAs does each state contain?
--
-- Why it matters: the LGA is the unit an operator would enter, so the
-- number of them per state is the number of separate market-entry
-- decisions that state represents.
-- ------------------------------------------------------------

SELECT state_name, COUNT(*) AS lga_count
FROM lga_base
GROUP BY state_name
ORDER BY lga_count DESC
LIMIT 5;

-- ANSWER (21 Aug 2026): Kano 44, Katsina 34, Oyo 33, Akwa Ibom 31, Osun 30.
-- 774 LGAs across 37 states and the FCT, so a mean of about 21 per state.
-- Kano alone holds more than twice that.


-- ------------------------------------------------------------
-- Q2. Which are the ten most populous LGAs in Nigeria?
--
-- Why it matters: the naive answer to "where is the biggest market".
-- ------------------------------------------------------------

SELECT lga_name, state_name, pop_total
FROM lga_base
ORDER BY pop_total DESC
LIMIT 10;

-- ANSWER (21 Aug 2026):
--   Alimosho (Lagos)                    3,499,809
--   Abuja Municipal (FCT)               2,969,407
--   Ajeromi-Ifelodun (Lagos)            1,431,755
--   Ikorodu (Lagos)                     1,311,043
--   Ifo (Ogun)                          1,294,626
--   Surulere (Lagos)                    1,047,767
--   Nasarawa (Kano)                     1,032,652
--   Ado-Odo/Ota (Ogun)                  1,030,829
--   Bwari (FCT)                           880,943
--   Kosofe (Lagos)                        838,360
--
-- INTERPRETATION: four Lagos LGAs, two FCT, two Ogun (greater Lagos
-- overspill), one Kano. Every one is a major urban centre, and every one
-- is largely grid-connected — which makes this list close to a ranking of
-- the WORST markets for an off-grid solar operator.
--
-- This is the argument for the whole project. Population is a demand-size
-- proxy, not an opportunity signal. Rank on any single indicator and the
-- output looks authoritative while pointing the wrong way. The deliverable
-- is a typology, not a ranking.
--
-- NOTE ON THE JOIN: rows 6 and 7 are Surulere and Nasarawa, two of the six
-- LGA names that are not unique in Nigeria. These rows are correct because
-- lga_base was joined on lga_pcode. Joined on lga_name, the error would
-- have landed in the top ten and looked entirely plausible.


-- ------------------------------------------------------------
-- Q3. Which ten states have the largest total population?
--
-- Why it matters: states are where subsidy windows, distribution
-- partnerships and regulatory relationships are negotiated, even when
-- targeting happens at LGA level.
-- ------------------------------------------------------------

SELECT state_name, SUM(pop_total) AS total_pop
FROM lga_base
GROUP BY state_name
ORDER BY total_pop DESC
LIMIT 10;

-- ANSWER (21 Aug 2026):
--   Lagos 14,879,754 | Kano 13,612,130 | Kaduna 8,758,047 | Oyo 8,470,586
--   Katsina 8,050,462 | Rivers 7,840,763 | Bauchi 6,690,134 | Borno 6,594,992
--   Anambra 5,936,784 | Jigawa 5,921,830
--
-- These reproduce the state totals HDX publishes separately, which is
-- check 8 in 00_checks.sql arrived at by a different route.
--
-- INTERPRETATION: six of the ten are northern states, four of them
-- North-West — the opposite emphasis to Q2's southern-urban list, from the
-- same data on the same day. Lagos concentrates population into 20 LGAs;
-- Kano spreads a comparable population across 44. Changing the unit of
-- analysis changes the answer, which is why PROJECT_BRIEF.md treats
-- "LGA or senatorial district" as a decision to be made deliberately.


-- ------------------------------------------------------------
-- Q4. In the seven North-West states, how many LGAs are there and how
--     many people do they hold?
--
-- Why it matters: the North-West is the filtered view named in the
-- project brief, and the region of the solar project that preceded this.
-- ------------------------------------------------------------

SELECT state_name,
       COUNT(*)        AS lga_count,
       SUM(pop_total)  AS total_pop
FROM lga_base
WHERE state_name IN ('Kaduna', 'Kano', 'Katsina', 'Kebbi',
                     'Jigawa', 'Sokoto', 'Zamfara')
GROUP BY state_name
ORDER BY total_pop DESC;

-- ANSWER (21 Aug 2026):
--   Kano     44 LGAs   13,612,130
--   Kaduna   23 LGAs    8,758,047
--   Katsina  34 LGAs    8,050,462
--   Jigawa   27 LGAs    5,921,830
--   Sokoto   23 LGAs    5,027,130
--   Zamfara  14 LGAs    4,568,319
--   Kebbi    21 LGAs    4,510,474
--
-- Region totals: 186 of 774 LGAs (24.0%) holding 50,448,392 of
-- 204,909,220 people (24.6%).
--
-- INTERPRETATION: mean LGA population varies nearly two-fold across the
-- region, Kaduna about 381,000, Kebbi about 215,000, Zamfara about
-- 326,000 across only 14 LGAs. The unit being clustered is not uniform in
-- size, so my segmentation models must 
-- rely on rates and densities rather than absolute counts. Clustering on raw figures risks biasing 
-- the output toward larger LGAs based on scale alone, masking structural market characteristics.



-- ------------------------------------------------------------
-- Q5. Which LGAs hold the largest share of their own state's population?
--
-- Why it matters: an LGA that holds most of its state is a different kind
-- of market from one of forty near-equal units. The first is a single point
-- of entry that reaches a whole state; the second is one of many, and
-- serving it well says little about serving the rest.
--
-- First query in this project to join two tables.
-- ------------------------------------------------------------

SELECT b.lga_name, b.state_name, b.pop_total, s.T_TL AS state_pop,
       ROUND(100.0 * b.pop_total / s.T_TL, 1) AS pct_of_state
FROM lga_base AS b
JOIN raw_pop_adm1_2020 AS s
  ON b.state_pcode = s.ADM1_PCODE
ORDER BY pct_of_state DESC
LIMIT 10;

-- Join integrity: 774 rows in, 774 rows out, verified separately with
-- SELECT COUNT(*) on the same join. The state totals are carried from the
-- 2020 release, the same release the LGA figures come from -- the 2022
-- state file is NOT used here (see docs/data_provenance.md, note 3).

-- ANSWER (23 Aug 2026):
--   Abuja Municipal  FCT        2,969,407 / 4,834,747   61.4%
--   Yenegoa          Bayelsa      776,979 / 2,537,774   30.6%
--   Alimosho         Lagos      3,499,809 / 14,879,754  23.5%
--   Ifo              Ogun       1,294,626 / 5,854,055   22.1%
--   Ekeremor         Bayelsa      509,038 / 2,537,774   20.1%
--   Bwari            FCT          880,943 / 4,834,747   18.2%
--   Ado-Odo/Ota      Ogun       1,030,829 / 5,854,055   17.6%
--   Fune             Yobe         635,522 / 3,619,142   17.6%
--   Ilorin West      Kwara        565,233 / 3,378,707   16.7%
--   Jakusko          Yobe         584,828 / 3,619,142   16.2%
--
-- INTERPRETATION -- and the caution matters more than the ranking.
--
-- This percentage is confounded by how many LGAs a state is divided into.
-- A state cut into six units gives every one of them a baseline share of
-- 16.7% before anything about the place is taken into account; a state cut
-- into forty-four gives a baseline of 2.3%. FCT has 6 LGAs, Bayelsa 8,
-- Lagos and Ogun 20 each, Yobe 17, Kano 44.
--
-- So four of the ten rows above are there partly for administrative
-- reasons. Bwari, sixth, holds 18.2% of a state whose even share is 16.7%
-- -- it is almost exactly average for the FCT and does not belong on a
-- list of dominant LGAs at all.
--
-- Dividing each share by its state's even share reorders the list:
--
--   Alimosho         23.5 / 5.0  = 4.7x its even share
--   Ifo              22.1 / 5.0  = 4.4x
--   Abuja Municipal  61.4 / 16.7 = 3.7x
--   Yenegoa          30.6 / 12.5 = 2.4x
--   Bwari            18.2 / 16.7 = 1.1x
--
-- Alimosho, not Abuja Municipal, is the most dominant LGA relative to how
-- its state is actually divided.
--
-- This is the Q4 caution reappearing in a different disguise. There the
-- distortion came from absolute population; here it comes from a
-- percentage that silently inherits an administrative artefact -- the
-- number of pieces a state happens to be cut into. A ratio is not
-- automatically safer than a count.
--
-- Implications for modeling:Raw pct_of_state cannot be used as a feature in clustering 
-- pipelines without introducing systematic bias. Because the metric inherently absorbs administrative 
--partitioning—where baseline concentration scales inversely with a state's total LGA count, it measures 
-- territorial division as much as demographic dominance.To prevent this distortion, Stage 2 will adopt 
-- a normalized relative dominance index. This normalised version -- share divided by the
-- state's even share -- is the one that carries meaning. Writing it needs
-- the LGA count per state joined back in, which is the next SQL step.
--
-- The normalised version is Q6, below.


-- ------------------------------------------------------------
-- Q6. Which LGAs dominate their state, once the number of LGAs in that
--     state is accounted for?
--
-- Why it matters: Q5's percentage is confounded by administrative
-- partitioning. This is the corrected measure, and the one that will be
-- offered to the clustering in Stage 2.
--
-- THE MEASURE: an LGA's share of its state, divided by the share it would
-- hold if the state were split evenly. A state with n LGAs gives an even
-- share of 100/n, so
--
--     dominance = pct_of_state / (100/n) = pct_of_state * n / 100
--
-- Note that this MULTIPLIES by the LGA count. Dividing by it would
-- amplify the artefact instead of removing it: Abuja Municipal would score
-- 10.2 against Alimosho's 1.2, which is the wrong answer with confidence.
--
-- A dominance of 1.0 means the LGA holds exactly its even share. Above 1.0
-- it is disproportionately large within its state; below, disproportionately
-- small.
--
-- First query in this project to use a subquery.
-- ------------------------------------------------------------

SELECT b.lga_name, b.state_name,
       ROUND(100.0 * b.pop_total / s.T_TL, 1) AS pct_of_state,
       c.lga_count,
       ROUND((100.0 * b.pop_total / s.T_TL) * c.lga_count / 100.0, 2) AS dominance
FROM lga_base AS b
JOIN raw_pop_adm1_2020 AS s
  ON b.state_pcode = s.ADM1_PCODE
JOIN (SELECT state_pcode, COUNT(*) AS lga_count
      FROM lga_base
      GROUP BY state_pcode) AS c
  ON b.state_pcode = c.state_pcode
ORDER BY dominance DESC
LIMIT 10;

-- The bracketed block is an ordinary GROUP BY query -- 37 rows, one per
-- state, giving that state's LGA count -- used where a table name would
-- normally go. It exists only for the duration of this query.
--
-- Join integrity: two joins now, 774 rows in and 774 out.

-- ANSWER (23 Aug 2026):
--   LGA               State          pct    n    dominance
--   Alimosho          Lagos          23.5   20     4.70
--   Ifo               Ogun           22.1   20     4.42
--   Abuja Municipal   FCT            61.4    6     3.69
--   Ado-Odo/Ota       Ogun           17.6   20     3.52
--   Nasarawa          Kano            7.6   44     3.34
--   Fune              Yobe           17.6   17     2.99
--   Lokoja            Kogi           13.7   21     2.89
--   Akpabuyo          Cross River    15.7   18     2.82
--   Jakusko           Yobe           16.2   17     2.75
--   Ilorin West       Kwara          16.7   16     2.68
--
-- INTERPRETATION -- what the correction did:
--
-- 1. Alimosho and Abuja Municipal swap places. Alimosho holds 4.7 times its
--    even share against Abuja Municipal's 3.7, so it is the more
--    disproportionate LGA once state fragmentation is accounted for, even
--    though its raw percentage is a third of Abuja Municipal's.
--
-- 2. Bwari, Yenegoa and Ekeremor disappear from the top ten. All three
--    ranked in Q5 only because FCT is divided into 6 LGAs and Bayelsa into
--    8. Bwari held 18.2% of a state whose even share is 16.7% -- almost
--    exactly typical. The artefact is gone.
--
-- 3. Nasarawa (Kano) enters at fifth on 7.6% of its state. Kano's 44 LGAs
--    make the typical share 2.3%, so 7.6% is more than three times the
--    norm. The raw percentage buried it; the corrected measure surfaces it.
--    (Nasarawa is also one of the six duplicated LGA names. The row is
--    correct because the joins use P-codes.)
--
-- KNOWN BIAS IN ROW 8 -- Akpabuyo, Cross River.
-- Akpabuyo is the LGA into which the publisher folds Bakassi's population
-- (docs/data_provenance.md, note 2). Its share therefore includes residents
-- of a different LGA, so its 15.7% and its dominance of 2.82 are both
-- overstated by an unknown amount. The distortion is a recording decision,
-- not a measurement. Flag this row wherever this measure is used.
--
-- CARRY INTO STAGE 2:
--   - Use `dominance`, not `pct_of_state`, as the feature.
--   - Akpabuyo carries a documented upward bias on any share-based measure.
--   - Bakassi is NULL throughout and will be excluded from clustering.
--     Say so in the write-up rather than letting a reader discover 773.


-- ------------------------------------------------------------
-- Q7. How much of Nigeria can the electrification data actually speak for?
--
-- Why it matters: every energy indicator in this project comes from the
-- GEP settlement model. Before any of them is used to recommend a market,
-- it has to be established where they describe the right place. This is
-- the question a client should ask and usually does not.
--
-- The measure and its construction are in sql/04_gep_quality.sql.
-- REVISED 27 Aug 2026 — see the note at the foot of this question.
-- ------------------------------------------------------------

SELECT gep_flag,
       COUNT(*)                                          AS n_lgas,
       ROUND(100.0 * COUNT(*)
             / (SELECT COUNT(*) FROM lga_base), 1)       AS pct_of_lgas,
       SUM(cod_pop)                                      AS population,
       ROUND(100.0 * SUM(cod_pop)
             / (SELECT SUM(pop_total) FROM lga_base), 1) AS pct_of_population
FROM gep_quality
GROUP BY gep_flag
ORDER BY n_lgas DESC;

-- ANSWER (27 Aug 2026):
--   flag            LGAs   % LGAs      population   % population
--   ok               600     77.5     150,470,181        73.4
--   suspect          169     21.8      51,317,202        25.0
--   no_clusters        4      0.5       3,121,837         1.5
--   no_cod_pop         1      0.1            NULL         NULL
--
-- So the honest headline is: the electrification data speaks confidently for
-- about three quarters of Nigeria's population, and 54,439,039 people —
-- 26.6% — live in LGAs where it cannot be trusted without a caveat.
--
-- BACKGROUND — WHAT IS BEING MEASURED
-- GEP publishes 708,536 settlement clusters with coordinates but no LGA.
-- Each was assigned to an LGA by point-in-polygon on its single
-- representative coordinate (pipeline/spatial_join.py). Where a cluster is
-- large and the LGAs beneath it are small, that one point hands the whole
-- cluster's population to whichever LGA it happens to fall in.
--
-- TWO TESTS, BECAUSE ONE WAS NOT ENOUGH
--
-- TEST 1 — POPULATION RATIO. Sum GEP's own population per LGA and compare it
-- to the COD population used everywhere else. Wide disagreement means the
-- clusters are not that LGA's clusters.
--
-- Read what this test does NOT say. It measures NET displacement. An LGA that
-- loses 200,000 people to one neighbour and gains 200,000 from another reads
-- 1.0 and passes, with every indicator describing somewhere else. Agreement
-- is a NECESSARY condition for trusting an LGA, never a sufficient one.
--
-- TEST 2 — FOREIGN-STATE SHARE. GEP ships its own Admin1 (state) label on
-- every cluster, produced independently of this project's spatial join.
-- 28,801 clusters (4.1%) carrying 8,097,966 people sit in a different state
-- from the one GEP itself assigns them. Under the single-test version of this
-- question, 87% of those people lived in LGAs flagged 'ok'.
--
-- Fifteen LGAs are caught by Test 2 and by nothing else. Ado-Odo/Ota (Ogun)
-- reads pop_ratio 0.919 — as close to agreement as anything in the table —
-- and 77% of the population attributed to it belongs to another state.
-- Aguata (Anambra) reads 1.415 and is 88.8% foreign. All fifteen were 'ok'
-- in the previous answer and would have carried recommendations.
--
-- Test 2 has an honest limit: GEP's Admin1 may itself come from a different
-- boundary vintage, so a disagreement says two independent assignments
-- disagree, not which one is wrong. That is what a validation is.
--
-- NOTHING IS LOST NATIONALLY. GEP totals 206,139,999 against COD's
-- 204,909,220 — a ratio of 1.006. The people are all accounted for; they are
-- attributed to the wrong LGA. Every excess is matched by a deficit next door:
--
--   Maiduguri 0.26  <->  Jere 5.14
--   Kano Municipal 0.00  <->  Kumbotso 2.75, Gwale 2.31
--   Ibadan South East 0.02  <->  Ibadan South West 1.68
--   Sokoto North 0.00  <->  Sokoto South 2.09
--   Onitsha South 0.00  <->  Ogbaru 3.06
--
-- That national figure BOUNDS the problem; it does not explain it. A ratio of
-- 1.006 would also appear if GEP's raster had been scaled to a national
-- control total, in which case it proves nothing about any LGA. Tested:
-- state-level ratios run 0.710 (FCT) to 1.110 (Ondo), Lagos 0.889 — so GEP is
-- NOT calibrated state by state and the national figure is not vacuous. It
-- still cannot separate redistribution between LGAs from GEP and the NPC
-- projection genuinely disagreeing about where Nigerians live.
--
-- The FCT at 0.710 is worth its own line: the capital is missing 29% of the
-- population GEP's own account of it should contain.
--
-- Most major Nigerian cities appear somewhere in the flagged list:
-- Kano, Ibadan, Maiduguri, Onitsha, Sokoto, Kaduna, Aba, Calabar,
-- Ilorin, Owerri, Jalingo, Minna and Lagos all have at least one LGA
-- reading far above or far below 1.0.
--
-- DIRECTION MATTERS, AND IS NOW RECORDED
--   balanced   615 LGAs   154,732,931
--   donated     87 LGAs    31,040,455   its clusters went elsewhere
--   absorbed    67 LGAs    16,013,997   it holds a neighbour's
--   none         5 LGAs     3,121,837
-- A donor's indicators are built from a fragment of itself. An absorber's are
-- built from itself blended with next door. Degraded is not the same as
-- absent, and Stage 2 should not treat them as one label.
--
-- THE FOUR WITH NO CLUSTERS, AND THE ONE WITH NO POPULATION
-- Four inner-Lagos LGAs — Agege, Ajeromi-Ifelodun, Mushin and Shomolu —
-- hold 3,121,837 people between them and have no settlement clusters at all.
-- Ajeromi-Ifelodun alone is Nigeria's third most populous LGA (Q2). Their
-- clusters were absorbed by neighbours; they will be NULL on every GEP
-- indicator.
--
-- Bakassi is a separate case and is now labelled separately as 'no_cod_pop'.
-- It has no population record either — the publisher thinks it uninhabited
-- and folds any residents into Akpabuyo (docs/data_provenance.md). Having
-- no clusters is the correct reading for it, not a defect. The previous
-- version of this question counted it with the four Lagos LGAs, which made
-- "five LGAs with no clusters" a sentence about two different things.
--
-- CLUSTER COUNT DOES NOT PROTECT AGAINST THIS
-- The obvious hypothesis — that this is a dense-city artefact — is wrong.
-- Ukum (Benue) has 6,275 clusters and reads 1.58. Zaki (Bauchi) has 4,335
-- and reads 1.83. Yamaltu/Deba (Gombe) has 2,396 and reads 2.95. What
-- matters is cluster size relative to LGA size, not the count.
--
-- AN INDEPENDENT CORROBORATION
-- Akpabuyo (Cross River) reads 0.434. Akpabuyo is the LGA into which the
-- publisher folds Bakassi's population, so its COD figure is inflated by
-- residents who live elsewhere and the ratio comes out low. A caveat read
-- on a dataset page reappears, unprompted, in a completely separate
-- measurement.
--
-- BOTH THRESHOLDS ARE CHOICES AND MUST BE QUOTED WITH THEIR SENSITIVITY
--
-- Ratio band, expressed as a factor so gain and loss are treated alike:
--   1.3  (0.769-1.300):  278 LGAs
--   1.5  (0.667-1.500):  154 LGAs   <- used
--   1.7  (0.588-1.700):   96 LGAs
--   2.0  (0.500-2.000):   54 LGAs
--
-- Foreign-state share:
--   >  5%:  135 LGAs   34,034,109
--   > 10%:   79 LGAs   19,378,547
--   > 25%:   22 LGAs    7,128,366   <- used
--   > 50%:   13 LGAs    5,130,224
--
-- Both roughly halve at every step with no plateau anywhere. There is no
-- natural cut-off in either: the disagreement is continuous, not two clean
-- populations of good and bad. "169 LGAs" is a statement about the two
-- thresholds as much as about the country, and the figures travel together.
-- `pop_ratio` and `pct_foreign` are retained as continuous columns because
-- they, not the label, are the real measurement.
--
-- WHAT IS STILL NOT DETECTED
-- 47 LGAs holding 10,332,548 people pass as 'ok' while carrying between 10%
-- and 25% foreign-state population — under the threshold, not clean. The
-- highest 'ok' reading is 23.7%. And no test here can see a swap between two
-- LGAs of the SAME state that happens to balance. This measure narrows the
-- untrusted set. It does not certify the remainder, and the write-up must not
-- claim it does.
--
-- 
-- Strategic and Operational Implications for Analysis
-- The spatial misattribution introduced when GEP's settlement clusters are assigned to LGA boundaries directly affects 
-- the validity of every energy indicator in this analysis, requiring an operational shift in how the final segmentation is 
-- executed and presented to stakeholders. Because 26.6% of the national population (54.4M people) resides in affected LGAs, 
-- I will implement a three-part mitigation strategy:
-- •	Dual-Track Cluster Sensitivity: Stage 2 cluster analysis will be run twice: once using the complete dataset and once 
--      excluding all flagged LGAs. If the cluster topology remains stable across both runs, the market segmentations is robust 
--      to the misattribution. If the structure shifts, that divergence will be published explicitly as an analytical finding rather 
--      than masked as a baseline assumption.
-- •	Transparent Risk Flagging: I will never present a flagged LGA without its data-quality indicator (suspect, no_clusters, 
--      or no_cod_pop). Decision-makers will see the caveats directly alongside the opportunity metrics.
-- •	Granular Reporting: I will avoid relying solely on aggregate percentages in the final deliverable. Instead, I will 
--      explicitly list the impacted LGAs so regional operators know exactly where local ground-truthing is required.
-- These figures bound the problem rather than close it. The 26.6% is a function of two chosen thresholds — at a tighter band 
-- the affected share is substantially larger. The remaining 73.4% is not verified but merely unfalsified: the ratio test cannot detect a balanced exchange between neighbours, and 47 LGAs holding 10.3M people pass as clean while still carrying between 10% and 25% of their population from another state. The mitigation strategy above narrows the untrusted set. It does not certify the remainder.

-- Contextual Considerations
-- A practical detail softens but does not eliminate the analytical risk for mini-grid and off-grid developers:
-- •	Urban Mitigation (Population Ratios): Large population ratio distortions cluster heavily in dense urban centers 
--      e.g., Kano Municipal, Ibadan South East, Sokoto North). Because these metro areas already feature higher grid-penetration rates, 
--      they fall outside the primary target profile for decentralized off-grid deployment.
-- •	Peri-Urban Vulnerability (Foreign-State Discrepancies): Displacements driven by cross-state clusters do not follow this urban pattern. 
--      Key manufacturing and peri-urban expansion corridors like Ado-Odo/Ota, Ifo, and Shagamu in Ogun State represent primary targets for 
--      off-grid power investments, yet they display significant spatial distortion. Ground-level verification remains non-negotiable for these 
--      high-value markets.


-- REVISION NOTE — WHY THE NUMBERS CHANGED ON 27 AUG 2026
-- This question first answered ok 667 / suspect 102 / no_clusters 5. A methods
-- review (docs/gep_quality_review.md) found that the single ratio test could
-- not see balanced exchange, that the 0.5-1.5 band was symmetric in
-- appearance only, and that a second independent test was already available
-- in a column the project had loaded and never used. All three were fixed.
-- The finding did not weaken; it got larger and better evidenced.




-- ------------------------------------------------------------
-- Q8. Which LGAs combine the largest unserved population with the
--     lowest cost to serve?
--
-- The first question in this catalogue that answers the client rather
-- than the data. Everything it needs is in lga_gep_indicators; no join.
--
-- "Combine" is three AND conditions, each measured against the data's own
-- distribution rather than a number chosen in advance:
--   - more unserved people than average
--   - cheaper per person than average
--   - more reliant on stand-alone solar than average  <- the off-grid test,
--     because an LGA the grid will reach by 2030 is not this client's market
--
-- The flag is shown, not filtered. A decision-maker sees the caveat beside
-- the opportunity and weighs it, per the Transparent Risk Flagging
-- commitment in Q7.
-- ------------------------------------------------------------

SELECT lga_name,
       state_name,
       gep_flag,
       unserved_pop_2020,
       investment_per_capita_usd
FROM lga_gep_indicators
WHERE n_clusters > 0
  AND unserved_pop_2020        > (SELECT AVG(unserved_pop_2020)        FROM lga_gep_indicators)
  AND investment_per_capita_usd < (SELECT AVG(investment_per_capita_usd) FROM lga_gep_indicators)
  AND pct_standalone_pv_2030    > (SELECT AVG(pct_standalone_pv_2030)   FROM lga_gep_indicators)
ORDER BY investment_per_capita_usd ASC
LIMIT 20;

-- ANSWER (29 Aug 2026). 235 LGAs pass all three filters, holding 47,903,787
-- unserved people -- 57% of the national unserved total in 30% of LGAs.
-- The twenty cheapest:
--
--   lga_name          state     flag      unserved   $/capita
--   Guzamala          Borno     suspect    120,288      57.00
--   Ganjuwa           Bauchi    ok         353,962      57.29
--   Sule-Tankarkar    Jigawa    ok         143,611      58.28
--   Yusufari          Yobe      ok         138,474      58.29
--   Nganzai           Borno     suspect    128,435      58.81
--   Jakusko           Yobe      suspect    257,237      58.85
--   Magumeri          Borno     suspect    183,153      58.96
--   Fune              Yobe      ok         401,584      58.97
--   Bursari           Yobe      ok         119,907      59.75
--   Gubio             Borno     suspect    194,394      61.71
--   Ningi             Bauchi    ok         455,454      61.85
--   Gamawa            Bauchi    ok         367,667      62.46
--   Mariga            Niger     ok         281,744      63.33
--   Yunusari          Yobe      ok         167,455      63.46
--   Wase              Plateau   ok         164,545      63.52
--   Qua'an Pan        Plateau   ok         301,362      64.43
--   Geidam            Yobe      ok         138,503      64.78
--   Mobbar            Borno     ok         130,129      64.83
--   Kaga              Borno     ok         137,162      65.24
--   Gulani            Yobe      suspect    191,557      65.37
--
-- THE ANSWER IS NOT THIS LIST. It is what the list reveals about the
-- question. Three things, in ascending order of importance.
--
--
-- 1. THE GEOGRAPHY. Take a look at the second column.
--
-- Of the forty cheapest LGAs: Yobe 8, Borno 8, Bauchi 5, Plateau 4,
-- Niger 3, Jigawa 3, Zamfara 2, Taraba 2, Nasarawa 2, Sokoto, Kebbi,
-- Adamawa 1 each. Borno and Yobe alone are sixteen of forty. Across the
-- full 235, Borno, Yobe and Adamawa hold 40 LGAs and 7.6 million unserved.
--
-- The model has optimised cost per person and market size. It has no
-- variable for whether an operator can reach a place, keep staff safe, or
-- find customers still living at the coordinates. Guzamala, Magumeri,
-- Gubio, Nganzai, Mobbar and Kaga are Borno LGAs. 
-- 
-- While the model's output is mathematically accurate, presenting these
-- results without contextualizing the severe security and ground-level 
-- logistics challenges in these areas would be commercially misleading and irresponsible.
--
-- 2. A HYPOTHESIS, TESTED AND MOSTLY WRONG.
--
-- Six of the top twenty are flagged 'suspect' -- 30%, against 12% across
-- all 235. The proposed explanation was that the quality flag is partly
-- detecting conflict displacement: the census projection says people live
-- in Magumeri, the settlement model finds them elsewhere, and pop_ratio
-- registers the disagreement.
--
-- Tested:
--   North East (6 states)   112 LGAs   30 suspect   26.8%
--   rest of Nigeria         657 LGAs  139 suspect   21.2%
--   Borno alone              27 LGAs   10 suspect   37.0%
--   Yobe alone               17 LGAs    4 suspect   23.5%
--
-- Borno is genuinely elevated. Yobe sits at the national rate. The North
-- East as a region is barely above the rest of the country. The hypothesis
-- holds for one state and was stated far too broadly. Recorded here as
-- partially refuted rather than quietly dropped -- and it does NOT explain
-- the concentration in the top twenty, which needs another explanation.
--
--
-- 3. THE ONE THAT INVERTS THE RECOMMENDATION.
--
-- Why are these LGAs cheap? Not necessarily because they are easy or attractive markets to serve.
--
--                       demand kWh/cap/yr   tier   $/capita   elec rate
--   top 20 cheapest              13.6       1.35      61.4       11.4%
--   all 235 shortlisted          28.7       1.67      79.8       23.3%
--   all 769 with clusters       170.1       2.58     164.6       53.6%
--
-- The twenty cheapest LGAs are cheap because THE MODEL EXPECTS PEOPLE
-- THERE TO USE 13.6 kWh PER YEAR -- one twelfth of the national average.
-- Investment per capita is roughly proportional to the size of the system
-- installed, and you install a very small system for someone assumed to
-- consume almost nothing. 13.6 kWh a year is a lamp and a phone charger.
--
-- This creates an important distinction: in this model, “lowest cost to serve” is closely linked to “lowest expected consumption.”
-- For a pay-as-you-go operator, however, lower consumption also means lower potential revenue per customer.
-- What looks like a low-cost market can therefore also be a low-revenue market, with much thinner margins.
-- 
--
-- The electrification rate in those same twenty LGAs is 11.4% against 53.6%
-- nationally. The need there is real and severe. But NEED IS NOT MARKET. Distinguishing 
-- the two is precisely what market segmentation is supposed to do.
--
--
-- WHAT THIS MEANS FOR THE METHOD
--
-- `investment_per_capita_usd` must not be used as a standalone ranking
-- variable. It is only interpretable beside demand. A commercially honest
-- measure compares what a connection costs against what it can earn --
-- demand x population against investment -- and that is a feature to build
-- for Stage 2, not a filter to bolt onto Q8.
--
-- CAN A SECURITY VARIABLE BE DERIVED FROM WHAT WE HAVE? No, and it should
-- not be faked. `NightLights` is the tempting candidate -- conflict
-- depopulates settlements and light intensity falls -- but GEP uses night
-- lights in calibrating electrification, so a low value cannot be
-- separated into "no power" and "no people". `TravelHours`, `RoadDist` and
-- `GridPenalty` measure remoteness and terrain, not risk. Building a
-- "security score" out of any of them would dress an inference as a
-- measurement, which is the one thing this project does not do.
--
-- Two honest responses. Declare the exposure as a stated limitation on
-- every ranking, using knowledge from outside the dataset and labelled as
-- such -- free, and done from here on. Or acquire a georeferenced conflict
-- layer (ACLED publishes one) and aggregate it to LGA as a screening
-- variable -- real acquisition work, and a Stage 2+ decision.
--
--
-- DECISION: THE NORTH EAST IS REPORTED, NOT SCREENED OUT.
--
-- The alternative was to filter Borno, Yobe and Adamawa out of every
-- ranking and hand over a shorter, tidier list. That is rejected here.
--
-- Screening them out would silently remove 40 LGAs and 7.6 million
-- unserved people from the analysis and present the remainder as if it
-- were the whole country. The reader would never know the exclusion had
-- happened, and could not disagree with a judgement they were not shown.
-- It would also make a commercial decision -- what risk is acceptable --
-- on behalf of a client who is far better placed to make it. An operator
-- already working in Maiduguri and one considering its first Nigerian
-- market will weigh Guzamala very differently, and neither is served by
-- an analyst who quietly decided for them.
--
-- So these LGAs stay in every ranking, and every ranking that contains
-- them carries the caveat beside them. This is the same principle as the
-- gep_flag: name the limitation and let the decision-maker weigh it,
-- rather than resolving it out of sight.
--
-- What that means in practice for the deliverable:
--   - Borno, Yobe and Adamawa rows appear, marked for security and
--     logistics exposure the same way flagged rows are marked for data
--     quality.
--   - The exposure is stated as knowledge from outside the dataset, and
--     labelled as such. It is not derived from any column here, because
--     no column here can carry it -- see the section above.
--   - Any summary figure quoting the 235 shortlisted LGAs also states how
--     many sit in those three states, so the headline cannot be read
--     without the qualification.


-- ------------------------------------------------------------
-- Q9 onwards: to come.
--   - Which LGAs have the highest share of population without electricity?
--   - How much of each state's unserved population sits in its top 5 LGAs?
--   - Where does demand justify a mini-grid rather than a solar home system?
--   - Which senatorial districts would be chosen if the unit were coarser?
-- ------------------------------------------------------------
