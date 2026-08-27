"""
Load the raw HDX files into SQLite, unchanged, and record what was loaded.

Rule for this file: it copies, it does not clean.

No renaming, no filtering, no type-fixing, no dropping of rows. Whatever the
publisher put in the spreadsheet is what lands in the raw_ tables. Every
transformation happens afterwards in the .sql files, where a reviewer can read
it and where the reasoning is version-controlled.

Two things this script DOES do, both of them guards:

1. ROW COUNTS. It refuses to continue if a source has a different number of
   records than when it was checked on 21 August 2026. That catches a file
   whose *shape* changed.

2. CHECKSUMS. It records a SHA-256 for every file in data/raw/ in
   data/raw/MANIFEST.csv, and refuses to continue if a file's contents changed
   while its row count stayed the same. That catches a file whose *values*
   changed — a revision, a correction, a silent republication — which no row
   count would ever notice.

These datasets update annually, so both guards will eventually fire. That is
the point. When one does, read the source's release notes, decide deliberately,
then re-run with --accept-changes to record the new state.

Run from the project root:
    python pipeline/load_raw.py
    python pipeline/load_raw.py --accept-changes
"""

import argparse
import csv
import hashlib
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
DB = ROOT / "data" / "processed" / "nigeria_lga.db"
MANIFEST = RAW / "MANIFEST.csv"

MANIFEST_FIELDS = [
    "file",
    "bytes",
    "sha256",
    "file_modified_utc",
    "first_recorded_utc",
    "last_verified_utc",
]

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
    # GEP V2, scenario ng-2-0_0_0_0_0_0. 708,536 settlement clusters, 81 columns.
    # Scenario identity verified against the data itself, not documentation —
    # see docs/data_provenance.md. Read compressed; pandas handles .gz natively.
    "raw_gep": ("ng-2-0_0_0_0_0_0.csv.gz", None, "id", 708536),
    # Global Forest Watch / Global Nature Watch, 30% canopy threshold, 2001-2025.
    # 853 state-year rows, not 37 x 25 = 925: a state-year with no recorded loss
    # is absent rather than zero. That distinction matters when aggregating.
    "raw_gfw_loss_region": (
        "gfw_by_region/treecover_loss_by_region__ha.csv", None, "adm1", 853),
    # The state code lookup, shipped with the same download. Codes are 1-37
    # alphabetically; without this file the loss table identifies nothing.
    "raw_gfw_adm1": (
        "gfw_by_region/adm1_metadata.csv", None, "adm1__id", 37),
    # WorldPop-derived poverty, aggregated to LGA. 775 rows, not 774 — it uses
    # GADM boundaries, which divide Nigeria slightly differently from the COD.
    # Keyed on names, not P-codes: the reconciliation happens in SQL.
    "raw_poverty": ("povertyrate.csv", None, "NAME_2", 775),
}


# ----------------------------------------------------------------------
# Manifest
# ----------------------------------------------------------------------

def sha256_of(path: Path) -> str:
    """Hash a file in chunks, so a large download does not have to fit in RAM."""
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_manifest() -> dict[str, dict]:
    if not MANIFEST.exists():
        return {}
    with MANIFEST.open(newline="", encoding="utf-8") as fh:
        return {row["file"]: row for row in csv.DictReader(fh)}


def write_manifest(rows: list[dict]) -> None:
    with MANIFEST.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=MANIFEST_FIELDS)
        writer.writeheader()
        writer.writerows(sorted(rows, key=lambda r: r["file"]))


def update_manifest(accept_changes: bool) -> list[str]:
    """
    Record every file in data/raw/ and compare against what was recorded before.

    Scans the whole directory rather than only the files named in SOURCES, so a
    newly downloaded source is documented from the moment it lands — before any
    code has been written to load it.

    Returns the list of filenames whose contents changed.
    """
    previous = read_manifest()
    rows, changed = [], []

    # Walk subfolders. Sources that arrive as multi-file downloads live in their
    # own directory — data/raw/gfw_national/, data/raw/gfw_by_region/ — because
    # two GFW downloads ship files with identical names, and flattening them
    # meant one silently overwrote the other.
    # _superseded/ holds files kept only until they are confirmed unwanted.
    files = sorted(
        p for p in RAW.rglob("*")
        if p.is_file()
        and p.name != MANIFEST.name
        and "_superseded" not in p.parts
    )
    if not files:
        raise FileNotFoundError(f"{RAW} is empty. Download the sources first.")

    for path in files:
        rel = path.relative_to(RAW).as_posix()
        digest = sha256_of(path)
        stat = path.stat()
        prior = previous.get(rel)

        if prior and prior["sha256"] != digest:
            changed.append(rel)

        rows.append({
            "file": rel,
            "bytes": stat.st_size,
            "sha256": digest,
            "file_modified_utc": datetime.fromtimestamp(
                stat.st_mtime, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            # first_recorded_utc is preserved across runs: it answers
            # "when did this exact file first enter the project?"
            "first_recorded_utc": (
                prior["first_recorded_utc"]
                if prior and prior["sha256"] == digest
                else utc_now()
            ),
            "last_verified_utc": utc_now(),
        })

    if changed and not accept_changes:
        raise ValueError(
            "Contents changed since the manifest was written:\n  "
            + "\n  ".join(changed)
            + "\n\nThe row counts may still match — a revision can leave the "
              "shape intact and alter the values. Nothing has been loaded.\n"
              "Check the source's release notes, decide whether to adopt the "
              "new version, update docs/data_provenance.md, then re-run with "
              "--accept-changes."
        )

    write_manifest(rows)
    for row in rows:
        note = "  [CHANGED]" if row["file"] in changed else ""
        print(f"  {row['file']:<32} {row['bytes']:>9,} bytes  "
              f"{row['sha256'][:12]}…{note}")
    return changed


# ----------------------------------------------------------------------
# Load
# ----------------------------------------------------------------------

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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--accept-changes",
        action="store_true",
        help="Adopt source files whose contents differ from the manifest. "
             "Use only after checking what changed and why.",
    )
    args = parser.parse_args()

    print("Checksums:")
    changed = update_manifest(args.accept_changes)
    if changed:
        print(f"\n  Adopted {len(changed)} changed file(s) — "
              f"record what changed in docs/data_provenance.md.")

    print("\nLoading:")
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

        # chunksize keeps memory flat on the 708k-row GEP table; it makes no
        # difference to the small ones.
        df.to_sql(table, con, if_exists="replace", index=False, chunksize=50_000)
        print(f"  {table:<22} {len(df):>7,} rows  <- {filename}"
              + (f" [{sheet}]" if sheet else ""))

    con.commit()
    con.close()
    print(f"\nWrote {DB.relative_to(ROOT)}")
    print(f"Wrote {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
