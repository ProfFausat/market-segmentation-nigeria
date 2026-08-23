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
-- size, so, my segmentation models must 
-- rely on rates and densities rather than absolute counts. Clustering on raw figures risks biasing 
-- the output toward larger LGAs based on scale alone, masking structural market characteristics.



-- ------------------------------------------------------------
-- Q5 onwards: to come. Candidates once electrification and settlement
-- data are joined:
--   - Which LGAs have the highest population density, and where do they sit?
--   - Which LGAs combine high population with low electrification?
--   - How much of each state's unserved population sits in its top 5 LGAs?
--   - Which senatorial districts would be chosen if the unit were coarser?
-- ------------------------------------------------------------
