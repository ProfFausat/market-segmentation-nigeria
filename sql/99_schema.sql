-- ============================================================
-- 99_schema.sql
--
-- What is in this database? Run this first after any break, and
-- before writing any join against a table you haven't touched
-- recently. Every table, every column, every type.
--
-- Note: DB Browser's Database Structure panel is drawn when the
-- file is opened and does NOT refresh when the loader adds tables
-- from outside. This query reads the live database. When the two
-- disagree, this is right — close and reopen the database.
-- ============================================================

-- Just the table names
SELECT name
FROM sqlite_master
WHERE type = 'table'
ORDER BY name;

-- For columns on a table, e.g. cluster_lga
PRAGMA table_info(cluster_lga);

-- Every table and column, with types
SELECT m.name AS table_name,
       p.name AS column_name,
       p.type
FROM sqlite_master AS m
JOIN pragma_table_info(m.name) AS p
WHERE m.type = 'table'
ORDER BY m.name, p.cid;

-- One table's columns, when that is all you need
-- PRAGMA table_info(cluster_lga);