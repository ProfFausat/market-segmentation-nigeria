-- ============================================================
-- 02_build_population.sql
-- LGA population, 2020.
--
-- WHY 2020 AND NOT 2022:
-- The 2022 COD-PS release for Nigeria covers admin levels 0 and 1 only.
-- There is no LGA-level file in it. LGA population therefore comes from
-- the 2020 release, which HDX marks LEGACY.
--
-- WHY THE 2022 STATE FILE IS NOT USED TO UPDATE THESE FIGURES:
-- Comparing the two releases state by state gives FCT -36.6%, Lagos -9.3%,
-- Katsina +28.8% over two years. Those are not demographic movements; the
-- releases use different projection methods. Rescaling 2020 LGA shares onto
-- 2022 state totals would import that methodological break and present it
-- as population change. The 2022 files stay in data/raw/ as a documented
-- discrepancy, not as an input.
--
-- Source: HDX COD-PS, nga_admpop_2020.xlsx, sheet nga_admpop_adm2_2020
-- ============================================================

DROP TABLE IF EXISTS pop_2020;

CREATE TABLE pop_2020 (
    lga_pcode   TEXT PRIMARY KEY,
    pop_total   INTEGER,
    pop_female  INTEGER,
    pop_male    INTEGER
);

INSERT INTO pop_2020 (lga_pcode, pop_total, pop_female, pop_male)
SELECT
    ADM2_PCODE,
    CAST(T_TL AS INTEGER),
    CAST(F_TL AS INTEGER),
    CAST(M_TL AS INTEGER)
FROM raw_pop_adm2_2020;

-- This table has 773 rows, not 774.
--
-- Bakassi (NG009005, Cross River South) carries no population figure. The
-- publisher flags this three ways: the gazetteer sheet marks Bakassi
-- CODPSMATCH = 0 while every other LGA is 1, the Metadata sheet states
-- "# of ADM2 unites: 773", and the HDX dataset page says why --
--
--   "COD-AB ADM2 feature 'Bakassi' [NG009005] is not represented, but is
--    thought to be uninhabited. Any actual population will be incorporated
--    in the 'Akpabuyo' [NG009003] record."
--
-- So the population is absorbed, not lost, which is why the 773 rows still
-- sum exactly to the published national total. Bakassi's NULL means "no
-- resident population per the publisher", not "value unknown" -- it must not
-- be imputed.
--
-- Side effect worth knowing: Akpabuyo's density is marginally overstated,
-- since its population may cover two areas while its area_sqkm covers one.
-- Bakassi is 4.2 sq km, so the distortion is negligible, but it is real.
--
-- The absent row is handled in 03_analysis_base.sql, not here.
