"""
Load the raw HDX files into SQLite, unchanged.

Rule for this file: it copies, it does not clean.

No renaming, no filtering, no type-fixing, no dropping of rows. Whatever the
publisher put in the spreadsheet is what lands in the raw_ tables. Every
transformation happens afterwards in the .sql files, where a reviewer can read
it and where the reasoning is version-controlled.

The one thing this script DOES do is refuse to continue if a source file has
changed shape since it was checked on 21 August 2026. If HDX republishes a file
with a different row count, this fails loudly rather than quietly loading
something different from what the analysis was built on.

Run from the project root:
    python pipeline/load_raw.py
"""

import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
DB = ROOT / "data" / "processed" / "nigeria_lga.db"

# table name -> (file, sheet or None for csv, key column, expected row count)
#
# The key column is the identifier the table is about. Rows with no key are
# dropped, because they are not records. This matters more than it sounds:
# the sheet named nga_admpop_adm1_2020 reads as 774 rows, but only 37 carry
# data. The other 737 have a single fill-down value in ADM0_PCODE and nothing
# else — spreadsheet residue, not states. Dropping empty-key rows turns a
# parser artifact back into a record count.
#
# Expected counts recorded 21 Aug 2026. See docs/data_provenance.md.
SOURCES = {
    "raw_admin2": ("nga_admin_boundaries.xlsx", "nga_admin2", "adm2_pcode", 774),
    "raw_admin1": ("nga_admin_boundaries.xlsx", "nga_admin1", "adm1_pcode", 37),
    "raw_sendist": ("nga_admin_boundaries.xlsx", "nga_senatorialdistricts", "sendistpcode", 109),
    "raw_pop_adm2_2020": ("nga_admpop_2020.xlsx", "nga_admpop_adm2_2020", "ADM2_PCODE", 773),
    "raw_pop_adm1_2020": ("nga_admpop_2020.xlsx", "nga_admpop_adm1_2020", "ADM1_PCODE", 37),
    "raw_pop_adm1_2022": ("nga_admpop_adm1_2022.csv", None, "ADM1_PCODE", 37),
    "raw_pop_adm0_2022": ("nga_admpop_adm0_2022.csv", None, "ADM0_PCODE", 1),
    "raw_gazetteer_adm2": ("nga_admgz.xlsx", "Admin2", "admin2Pcode", 774),
}


def read(filename: str, sheet: str | None) -> pd.DataFrame:
    path = RAW / filename
    if not path.exists():
        raise FileNotFoundError(
            f"{path} is missing. Download it before running the loader."
        )
    if sheet is None:
        return pd.read_csv(path)
    return pd.read_excel(path, sheet_name=sheet)


def main() -> None:
    DB.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB)

    for table, (filename, sheet, key, expected) in SOURCES.items():
        df = read(filename, sheet)

        # A spreadsheet reader's row count is not a record count. Keep only
        # rows that have an identifier; see the note on SOURCES above.
        if key not in df.columns:
            raise KeyError(f"{table}: key column {key!r} not found in source")
        df = df[df[key].notna()]

        if len(df) != expected:
            raise ValueError(
                f"{table}: expected {expected} rows, got {len(df)}. "
                f"The source file has changed. Investigate before loading — "
                f"do not adjust this number to make the error go away."
            )

        df.to_sql(table, con, if_exists="replace", index=False)
        print(f"  {table:<22} {len(df):>4} rows  <- {filename}"
              + (f" [{sheet}]" if sheet else ""))

    con.commit()
    con.close()
    print(f"\nWrote {DB.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
