-- ============================================================
-- 00_checks.sql
-- Assertions. Run this after every rebuild, before trusting anything.
--
-- Each query returns a PASS or FAIL. Nothing here is decorative: every
-- check corresponds to a way this data could be silently wrong.
--
-- Numbered 00 because it is the file you run most often.
-- ============================================================

-- 1. The spine has exactly 774 LGAs.
SELECT 'spine row count' AS check_name,
       COUNT(*) AS actual, 774 AS expected,
       CASE WHEN COUNT(*) = 774 THEN 'PASS' ELSE 'FAIL' END AS result
FROM lga;

-- 2. Every P-code is unique. (The PRIMARY KEY enforces this, so a FAIL
--    here means the table was built some other way.)
SELECT 'unique lga_pcode',
       COUNT(DISTINCT lga_pcode), 774,
       CASE WHEN COUNT(DISTINCT lga_pcode) = 774 THEN 'PASS' ELSE 'FAIL' END
FROM lga;

-- 3. LGA names are NOT unique — 768 distinct names for 774 LGAs.
--    This check does not guard data quality. It guards against forgetting.
--    If it ever reads 774, the source changed and the join rules need review.
SELECT 'distinct lga_name (expected < count)',
       COUNT(DISTINCT lga_name), 768,
       CASE WHEN COUNT(DISTINCT lga_name) = 768 THEN 'PASS' ELSE 'FAIL' END
FROM lga;

-- 4. Every LGA belongs to exactly one state.
SELECT 'lga -> one state',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT lga_pcode
    FROM lga
    GROUP BY lga_pcode
    HAVING COUNT(DISTINCT state_pcode) > 1
);

-- 5. The join did not lose or duplicate rows. 774 in, 774 out.
SELECT 'lga_base row count',
       COUNT(*), 774,
       CASE WHEN COUNT(*) = 774 THEN 'PASS' ELSE 'FAIL' END
FROM lga_base;

-- 6. Exactly one LGA has no population, and it is Bakassi.
SELECT 'exactly 1 null population',
       COUNT(*), 1,
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM lga_base
WHERE pop_total IS NULL;

SELECT 'the null is Bakassi',
       COUNT(*), 1,
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM lga_base
WHERE pop_total IS NULL AND lga_pcode = 'NG009005';

-- 7. LGA populations sum to the publisher's own national total for 2020.
--    204,909,220 is the figure in the same workbook's adm0 sheet.
SELECT 'national total reconciles',
       SUM(pop_total), 204909220,
       CASE WHEN SUM(pop_total) = 204909220 THEN 'PASS' ELSE 'FAIL' END
FROM lga_base;

-- 8. State sums reconcile to the 2020 state file, for all 37 states.
--    This is the strongest check here: it proves the join attached the
--    right populations to the right LGAs, not merely the right count.
SELECT 'state sums reconcile (2020)',
       COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT b.state_pcode
    FROM lga_base AS b
    JOIN raw_pop_adm1_2020 AS s
      ON s.ADM1_PCODE = b.state_pcode
    GROUP BY b.state_pcode
    HAVING ABS(SUM(b.pop_total) - MAX(s.T_TL)) > 1
);
