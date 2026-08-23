-- ============================================================
-- 01_build_spine.sql
-- Build the spine: one row per Nigerian LGA, 774 of them.
--
-- Everything else in this project joins onto this table. If it is
-- wrong, every number downstream is wrong, so it is built first and
-- checked hardest.
--
-- Source: HDX COD-AB, nga_admin_boundaries.xlsx, sheet nga_admin2
-- ============================================================

DROP TABLE IF EXISTS lga;

CREATE TABLE lga (
    lga_pcode      TEXT PRIMARY KEY,   -- NG001001 etc. The real identifier.
    lga_name       TEXT NOT NULL,      -- NOT unique: 6 names repeat across states
    state_name     TEXT NOT NULL,
    state_pcode    TEXT NOT NULL,
    sendist_name   TEXT NOT NULL,      -- senatorial district: the fallback unit
    sendist_pcode  TEXT NOT NULL,
    area_sqkm      REAL,
    center_lat     REAL,               -- for mapping later, without shapefiles
    center_lon     REAL
);

-- PRIMARY KEY above is doing real work: SQLite will refuse to insert a
-- duplicate lga_pcode. If the source ever ships a repeated code, this
-- INSERT fails instead of silently creating a table with 775 rows.

INSERT INTO lga (
    lga_pcode, lga_name, state_name, state_pcode,
    sendist_name, sendist_pcode, area_sqkm, center_lat, center_lon
)
SELECT
    adm2_pcode,
    adm2_name,
    adm1_name,
    adm1_pcode,
    sendist_en,
    sendistpcode,
    area_sqkm,
    center_lat,
    center_lon
FROM raw_admin2;

-- Indexes: these make joins and filters fast. Not strictly needed at
-- 774 rows, but the habit is right and costs nothing.
CREATE INDEX idx_lga_state   ON lga (state_pcode);
CREATE INDEX idx_lga_sendist ON lga (sendist_pcode);
