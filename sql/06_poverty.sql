-- ============================================================
-- 06_poverty.sql
-- Joining the WorldPop/KTH poverty layer to the LGA spine.
--
-- THE HARDEST JOIN IN THIS PROJECT, AND WHY
--
-- Every other join here uses a P-code. This one cannot: the poverty
-- source is built on GADM v3.6 boundaries and is keyed on NAMES. It has
-- 775 rows against the spine's 774.
--
-- Note 4 of docs/data_provenance.md is the reason that is dangerous. The
-- 774 LGAs carry only 768 distinct names -- Bassa, Ifelodun, Irepodun,
-- Nasarawa, Obi and Surulere each name two LGAs in different states. So
-- every match here is made on the (state, LGA) PAIR, never on the LGA
-- name alone.
--
-- VINTAGE, WHICH TRAVELS WITH EVERY FIGURE FROM THIS SOURCE
-- The dataset's release year is 2013; its own columns are labelled 2014;
-- it was last touched in 2017. It is being joined to 2020 population on
-- 2019-endorsed boundaries. That gap is stated wherever a poverty number
-- appears. Licence is CC0 1.0 -- no attribution required, given anyway.
--
-- THE METHOD: THREE AUTOMATIC PASSES, THEN A HUMAN
--
--   Pass 1  exact (state, NAME_2)                            606 matched
--   Pass 2  + VARNAME_2, the source's own alternate name      695
--   Pass 3  + normalised: lowercase, strip space - / . | '    747
--   Pass 4  a hand-verified lookup table                      774
--
-- WHY THERE IS NO AUTOMATIC PASS 4
-- A fourth mechanical rule was written and REJECTED. It matched a COD
-- name that begins with the (normalised) poverty name, which cleans up
-- truncation nicely -- and produced seven ambiguities, silently:
--
--   poverty 'IbadanNorth' matched THREE LGAs:
--       Ibadan North, Ibadan North East, Ibadan North West
--   poverty 'Afikpo'  matched Afikpo North and Afikpo South
--   poverty 'Calabar' matched Calabar South and Calabar-Municipal
--   poverty 'Dutsi'   matched Dutsi and Dutsin-Ma
--   poverty 'Warri South' matched Warri South and Warri South West
--   poverty 'Nasarawa'    matched Nasarawa and Nasarawa-Eggon
--   poverty 'IjebuNorth'  matched Ijebu North and Ijebu North East
--
-- None of those raises an error. Each would attach a real poverty rate to
-- the wrong LGA and look entirely plausible downstream. The same is true
-- of any edit-distance rule: it would map 'Girie' -> 'Girei' correctly
-- and 'Oboma Ngwa' -> something wrong, with no way to tell which.
--
-- So the last 27 pairs are written down one row at a time and committed,
-- each with the reason it is what it is. Mechanical rules for mechanical
-- problems; something better than a rule for the rest -- see the next
-- block, which explains why none of the 27 is a guess.
-- ============================================================


-- ------------------------------------------------------------
-- The map. 27 rows -- one per LGA that survived passes 1-3.
--
-- THESE PAIRINGS ARE NOT GUESSES. THEY ARE FORCED BY ARITHMETIC.
--
-- Several of them look like they need local knowledge: is the LGA the COD
-- calls simply 'Kogi' the one the poverty source calls 'Koton-Karfe'? Is
-- 'Gboyin' the same place as 'Aiyekire (Gbonyin)'? A guess there would be
-- exactly the silent-wrong-pair failure this file exists to prevent.
--
-- They do not need to be guessed, because the residue is a CLOSED SET.
-- After passes 1-3, the unmatched rows on each side were counted state by
-- state, and in all 18 affected states THE TWO SIDES HAVE EQUAL COUNTS:
--
--   9 states have exactly 1 unmatched on each side. With one poverty row
--     and one LGA left in that state, the pairing is forced. No judgement
--     is involved at all -- there is nothing else it could be.
--     (Cross River, Gombe, Imo, Kebbi, Nasarawa, Osun, Oyo, Plateau, Zamfara)
--
--   9 states have exactly 2 on each side. In every one of those, one of
--     the two pairs is unambiguous, which forces the other by elimination.
--     Kogi is the clearest case: 'Olamabor'/'Olamaboro' -> 'Olamabolo' is
--     beyond doubt, and the only remaining LGA in Kogi state is 'Kogi',
--     so 'Kotonkar' must be it.
--     (Abia, Adamawa, Ekiti, Jigawa, Kaduna, Kano, Kogi, Rivers, Yobe)
--
--   No state has 3 or more, which is what would break the argument.
--
-- The gazetteer was tried first and could not settle it: raw_gazetteer_adm2
-- carries admin2AltName1_en and admin2AltName2_en, which is exactly what
-- they are for, and both are <Null> for every LGA involved.
--
-- The `equal residue per state` check at the foot of this file is what
-- keeps this argument true. It is not decoration: if a future release of
-- either source changes a name, that check fails and the elimination
-- argument no longer holds, at which point these pairs must be re-derived
-- rather than trusted.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS poverty_name_map;

CREATE TABLE poverty_name_map (
    state_name  TEXT NOT NULL,   -- COD state (after the Nassarawa fix)
    poverty_name TEXT NOT NULL,  -- raw_poverty.NAME_2, exactly as published
    lga_pcode   TEXT NOT NULL,   -- the COD LGA it means
    note        TEXT,
    PRIMARY KEY (state_name, poverty_name)
);

INSERT INTO poverty_name_map (state_name, poverty_name, lga_pcode, note) VALUES
  ('Abia',        'Isuikwua',            'NG001008', 'COD: Isiukwuato (letters transposed vs VARNAME_2 Isuikwuato). Forced: Abia had 2 residual on each side'),
  ('Abia',        'Oboma Ngwa',          'NG001009', 'COD: Obi Ngwa. Forced: the other Abia residual is Isuikwua/Isiukwuato'),
  ('Adamawa',     'Girie',               'NG002005', 'COD: Girei'),
  ('Adamawa',     'Teungo',              'NG002019', 'COD: Toungo'),
  ('Cross River', 'Bekwarra',            'NG009006', 'COD: Bekwara'),
  ('Ekiti',       'Gboyin',              'NG013002', 'COD: Aiyekire (Gbonyin) -- Gbonyin appears inside the COD name. Forced: Ekiti''s other residual is Ilejemeje/Ilejemeji'),
  ('Ekiti',       'Ilejemeje',           'NG013012', 'COD: Ilejemeji'),
  ('Gombe',       'Yamaltu',             'NG016011', 'truncated, VARNAME_2 Deba. COD: Yamaltu/Deba'),
  ('Imo',         'Ezinihit',            'NG017004', 'truncated, VARNAME_2 Ezinihitte Mbaise. COD: Ezinihitte'),
  ('Jigawa',      'BirninKu',            'NG018004', 'truncated, VARNAME_2 Birnin Kudu. COD: Birni Kudu'),
  ('Jigawa',      'MalamMad',            'NG018021', 'truncated, VARNAME_2 Malam Maduri. COD: Malam Madori'),
  ('Kaduna',      'Makarfi',             'NG019018', 'COD: Markafi'),
  ('Kaduna',      'ZangonKa',            'NG019022', 'truncated, VARNAME_2 Zangon Kataf. COD: Zango-Kataf'),
  ('Kano',        'Nassaraw',            'NG020031', 'truncated, VARNAME_2 Nassarawa. COD: Nasarawa (the KANO LGA, not the state)'),
  ('Kano',        'Tundun Wada',         'NG020041', 'COD: Tudun Wada'),
  ('Kebbi',       'Danko Wasagu',        'NG022019', 'COD: Wasagu/Danko, elements reversed. Forced: Kebbi had exactly 1 residual on each side'),
  ('Kogi',        'Kotonkar',            'NG023011', 'VARNAME_2 Koton-Karfe, the COD names this LGA simply Kogi. Forced: Kogi state''s other residual is Olamabor/Olamabolo, leaving this as the only candidate'),
  ('Kogi',        'Olamabor',            'NG023018', 'truncated, VARNAME_2 Olamaboro. COD: Olamabolo'),
  ('Nasarawa',    'Nassarawa Egon',      'NG026010', 'COD: Nasarawa-Eggon'),
  ('Osun',        'Ayedaade',            'NG030001', 'VARNAME_2 Aiyedaade. COD: Aiyedade'),
  ('Oyo',         'Atisbo',              'NG031004', 'COD: Atigbo. Forced: Oyo had exactly 1 residual on each side'),
  ('Plateau',     'Barkin Ladi',         'NG032001', 'COD: Barikin Ladi'),
  ('Rivers',      'Emuoha',              'NG033010', 'COD: Emohua'),
  ('Rivers',      'Obio/Akp',            'NG033015', 'truncated, VARNAME_2 Obio/Akpor. COD: Obia/Akpor'),
  ('Yobe',        'Borsari',             'NG036002', 'COD: Bursari'),
  ('Yobe',        'Tarmuwa',             'NG036015', 'COD: Tarmua'),
  ('Zamfara',     'Birnin-Magaji/Kiyaw', 'NG037003', 'COD: Birnin Magaji, full name Birnin Magaji/Kiyaw. Forced: Zamfara had exactly 1 residual on each side');


-- ------------------------------------------------------------
-- The 775th row, named rather than dropped silently.
--
-- GADM carries a polygon called 'Lake Chad' in Borno with
-- TYPE_2 = 'Water body'. It has no COD counterpart because it is not an
-- LGA. It is excluded -- but it is NOT empty: GADM attributes 136,501
-- people and a poverty rate of 0.273 to it. Those people exist in the COD
-- inside some Borno LGA, so excluding this row loses them from the
-- poverty layer while the spine still counts them.
--
-- That is a real, small, stated limitation. It is the same treatment
-- Bakassi gets in note 2: name it, quantify it, keep it visible.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS poverty_excluded;

CREATE TABLE poverty_excluded AS
SELECT NAME_1 AS gadm_state, NAME_2 AS gadm_name, TYPE_2 AS gadm_type,
       "2014_Popul" AS gadm_pop, Poverty_Ra AS poverty_rate,
       'Water body, not an LGA. No COD counterpart.' AS reason
FROM raw_poverty
WHERE TYPE_2 = 'Water body';


-- ------------------------------------------------------------
-- The join. Passes 1-3 by rule, pass 4 by the map above.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS lga_poverty;

CREATE TABLE lga_poverty AS
WITH pov AS (
    SELECT
        -- The single state-name difference between the two sources.
        CASE NAME_1 WHEN 'Nassarawa' THEN 'Nasarawa' ELSE NAME_1 END AS state_name,
        NAME_2                                                       AS poverty_name,
        VARNAME_2                                                    AS poverty_altname,
        "2014_Popul"                                                 AS gadm_pop_2014,
        Poverty_Ra                                                   AS poverty_rate,
        "2014_Pover"                                                 AS poor_count_2014,
        TYPE_2                                                       AS gadm_type
    FROM raw_poverty
    WHERE TYPE_2 <> 'Water body'          -- the Lake Chad row, excluded above
),
norm AS (
    -- Lowercase and strip the punctuation the two sources disagree about.
    -- SQLite has no regex, so this is nested replace(). Applied to BOTH
    -- sides, never to one.
    SELECT p.*,
           replace(replace(replace(replace(replace(replace(
             lower(p.poverty_name),' ',''),'-',''),'/',''),'.',''),'|',''),'''','') AS n_name,
           replace(replace(replace(replace(replace(replace(
             lower(COALESCE(p.poverty_altname,'')),' ',''),'-',''),'/',''),'.',''),'|',''),'''','') AS n_alt
    FROM pov AS p
)
SELECT
    b.lga_pcode,
    b.lga_name,
    b.state_name,
    n.poverty_name,
    n.poverty_rate,
    n.gadm_pop_2014,
    n.poor_count_2014,
    CASE
        WHEN n.poverty_name = b.lga_name                          THEN 'exact'
        WHEN n.poverty_altname = b.lga_name                       THEN 'varname'
        WHEN m.lga_pcode IS NOT NULL                              THEN 'hand_mapped'
        ELSE                                                           'normalised'
    END AS match_type
FROM lga_base AS b
JOIN norm AS n
  ON n.state_name = b.state_name
LEFT JOIN poverty_name_map AS m
  ON m.state_name = n.state_name AND m.poverty_name = n.poverty_name
WHERE n.poverty_name    = b.lga_name
   OR n.poverty_altname = b.lga_name
   OR n.n_name = replace(replace(replace(replace(replace(replace(
        lower(b.lga_name),' ',''),'-',''),'/',''),'.',''),'|',''),'''','')
   OR n.n_alt  = replace(replace(replace(replace(replace(replace(
        lower(b.lga_name),' ',''),'-',''),'/',''),'.',''),'|',''),'''','')
   OR m.lga_pcode = b.lga_pcode;

CREATE UNIQUE INDEX IF NOT EXISTS idx_lga_poverty_pcode ON lga_poverty (lga_pcode);


-- ------------------------------------------------------------
-- Checks. These are the point of the whole file.
--
-- The unique index above will already have refused to build if any LGA
-- matched twice -- that is deliberate. A duplicate here is not a warning
-- to be read later, it is a failure that must stop the build.
-- ------------------------------------------------------------

-- Every LGA matched exactly once.
SELECT 'one poverty row per LGA' AS check_name,
       (SELECT COUNT(*) FROM lga_poverty)              AS actual,
       (SELECT COUNT(*) FROM lga_base)                 AS expected,
       CASE WHEN (SELECT COUNT(*) FROM lga_poverty)
               = (SELECT COUNT(*) FROM lga_base)
            THEN 'PASS' ELSE 'FAIL' END                AS result;

-- No poverty row used twice.
SELECT 'no poverty row reused',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT state_name, poverty_name
      FROM lga_poverty GROUP BY 1, 2 HAVING COUNT(*) > 1);

-- Every non-water poverty row was consumed.
SELECT 'no poverty row orphaned',
       (SELECT COUNT(*) FROM raw_poverty WHERE TYPE_2 <> 'Water body')
       - (SELECT COUNT(*) FROM lga_poverty), 0,
       CASE WHEN (SELECT COUNT(*) FROM raw_poverty WHERE TYPE_2 <> 'Water body')
               = (SELECT COUNT(*) FROM lga_poverty)
            THEN 'PASS' ELSE 'FAIL' END;

-- Every hand-mapped row was actually used. Catches a stale map entry
-- after a source revision -- a map that silently stops applying is worse
-- than no map.
SELECT 'every map row used',
       (SELECT COUNT(*) FROM poverty_name_map)
       - (SELECT COUNT(*) FROM lga_poverty WHERE match_type = 'hand_mapped'), 0,
       CASE WHEN (SELECT COUNT(*) FROM poverty_name_map)
               = (SELECT COUNT(*) FROM lga_poverty WHERE match_type = 'hand_mapped')
            THEN 'PASS' ELSE 'FAIL' END;

-- Exactly one row excluded, and it is the water body.
SELECT 'exactly 1 excluded row',
       (SELECT COUNT(*) FROM poverty_excluded), 1,
       CASE WHEN (SELECT COUNT(*) FROM poverty_excluded) = 1
            THEN 'PASS' ELSE 'FAIL' END;


-- ------------------------------------------------------------
-- Diagnostics. Run these whenever a check fails, and read them even when
-- nothing fails.
-- ------------------------------------------------------------

-- How each LGA was matched. A large 'hand_mapped' count is fine; a
-- growing one after a source update means the source renamed things.
SELECT match_type, COUNT(*) AS n_lgas
FROM lga_poverty GROUP BY match_type ORDER BY n_lgas DESC;

-- ANSWER expected (27 Aug 2026): exact 606, varname 89, normalised 52,
-- hand_mapped 27. Total 774.

-- LGAs with no poverty row. Should be empty. If it is not, these are the
-- names to add to poverty_name_map -- never to drop.
SELECT b.state_name, b.lga_name, b.lga_pcode
FROM lga_base AS b
WHERE NOT EXISTS (SELECT 1 FROM lga_poverty AS p WHERE p.lga_pcode = b.lga_pcode)
ORDER BY 1, 2;

-- Poverty rows that reached no LGA. Should be empty apart from nothing --
-- the water body is excluded before this point, deliberately, so that
-- this query stays a pure error report.
SELECT CASE NAME_1 WHEN 'Nassarawa' THEN 'Nasarawa' ELSE NAME_1 END AS state_name,
       NAME_2, VARNAME_2
FROM raw_poverty AS r
WHERE r.TYPE_2 <> 'Water body'
  AND NOT EXISTS (SELECT 1 FROM lga_poverty AS p
                  WHERE p.poverty_name = r.NAME_2
                    AND p.state_name = CASE NAME_1 WHEN 'Nassarawa'
                                            THEN 'Nasarawa' ELSE NAME_1 END)
ORDER BY 1, 2;

-- Sanity on the values themselves, not just the join. A poverty rate
-- outside 0-1 means the column is not what it is assumed to be.
SELECT 'poverty_rate within 0-1' AS check_name,
       COUNT(*) AS actual, 0 AS expected,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM lga_poverty
WHERE poverty_rate IS NOT NULL AND poverty_rate NOT BETWEEN 0 AND 1;


-- ------------------------------------------------------------
-- THE CHECK THE HAND MAP DEPENDS ON.
--
-- Every entry in poverty_name_map is justified by elimination inside its
-- own state: after passes 1-3, that state had the same small number of
-- unmatched rows on each side, so the pairing was forced rather than
-- chosen. This query re-derives the residue and asserts that equality.
--
-- If it ever fails, the elimination argument has stopped holding -- a
-- source has renamed, added or removed a unit -- and the 27 pairs must be
-- re-derived from scratch. They must NOT be carried forward on the grounds
-- that they used to be right.
-- ------------------------------------------------------------

WITH pov AS (
    SELECT CASE NAME_1 WHEN 'Nassarawa' THEN 'Nasarawa' ELSE NAME_1 END AS state_name,
           NAME_2 AS nm, COALESCE(VARNAME_2, '') AS alt
    FROM raw_poverty WHERE TYPE_2 <> 'Water body'
),
nrm AS (
    SELECT p.*,
      replace(replace(replace(replace(replace(replace(
        lower(p.nm),' ',''),'-',''),'/',''),'.',''),'|',''),'''','') AS n_nm,
      replace(replace(replace(replace(replace(replace(
        lower(p.alt),' ',''),'-',''),'/',''),'.',''),'|',''),'''','') AS n_alt
    FROM pov AS p
),
lgn AS (
    SELECT b.*,
      replace(replace(replace(replace(replace(replace(
        lower(b.lga_name),' ',''),'-',''),'/',''),'.',''),'|',''),'''','') AS n_lga
    FROM lga_base AS b
),
pov_left AS (
    SELECT state_name, COUNT(*) AS n FROM nrm AS p
    WHERE NOT EXISTS (SELECT 1 FROM lgn AS l WHERE l.state_name = p.state_name
        AND (p.nm = l.lga_name OR p.alt = l.lga_name
             OR p.n_nm = l.n_lga OR p.n_alt = l.n_lga))
    GROUP BY state_name
),
cod_left AS (
    SELECT state_name, COUNT(*) AS n FROM lgn AS l
    WHERE NOT EXISTS (SELECT 1 FROM nrm AS p WHERE p.state_name = l.state_name
        AND (p.nm = l.lga_name OR p.alt = l.lga_name
             OR p.n_nm = l.n_lga OR p.n_alt = l.n_lga))
    GROUP BY state_name
)
SELECT 'residue is equal on both sides in every state' AS check_name,
       COUNT(*) AS actual, 0 AS expected,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (SELECT COALESCE(p.state_name, c.state_name) AS s,
             COALESCE(p.n, 0) AS pn, COALESCE(c.n, 0) AS cn
      FROM pov_left AS p
      LEFT JOIN cod_left AS c ON c.state_name = p.state_name
      UNION
      SELECT COALESCE(p.state_name, c.state_name),
             COALESCE(p.n, 0), COALESCE(c.n, 0)
      FROM cod_left AS c
      LEFT JOIN pov_left AS p ON p.state_name = c.state_name)
WHERE pn <> cn OR pn > 2;

-- ANSWER (27 Aug 2026): 0 -- PASS.
-- 18 states carry residue: 9 with exactly 1 on each side, 9 with exactly 2.
-- None has 3 or more, and no state's two sides disagree. That is what makes
-- every row of poverty_name_map forced rather than guessed.
