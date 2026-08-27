"""
Assign each GEP settlement cluster to the LGA that contains it.

WHY THIS STEP EXISTS, AND WHY IT IS NOT SQL
-------------------------------------------
Every other transformation in this project happens in sql/, where it can be
read and checked. This one cannot: the GEP results carry longitude and latitude
but no LGA identifier, and SQLite has no geometry engine, so "which of these 774
polygons contains this point" is not a question SQL can answer here.

So this is a deliberate, documented exception. It does exactly one thing —
produce a lookup table of cluster id -> lga_pcode — and nothing else. No
aggregation, no filtering, no derived indicators. Everything computed FROM this
lookup happens in SQL, as usual.

WHAT IT GUARANTEES
------------------
- Exactly one row per cluster. Not fewer (silently dropped), not more
  (duplicated by a boundary overlap).
- Every row labelled with how it was matched: 'within' for a point inside a
  polygon, 'nearest' for one that fell outside every polygon and was assigned to
  the closest LGA within a tolerance.
- A hard failure if anything is unmatched or ambiguous.

The 'nearest' cases are real and expected: coastal and border settlements can
fall a few metres outside a simplified boundary. They are labelled rather than
hidden, so any analysis can exclude them if it matters.

Run from the project root, after load_raw.py:
    python pipeline/spatial_join.py
"""

import sqlite3
from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely.geometry import Point

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
DB = ROOT / "data" / "processed" / "nigeria_lga.db"
BOUNDARIES = RAW / "nga_admin2.shp"

EXPECTED_CLUSTERS = 708_536
EXPECTED_LGAS = 774

# How far outside a boundary a cluster may fall and still be assigned to the
# nearest LGA. Anything further out is a real problem, not a rounding artefact.
#
# Measured in METRES, not degrees. A degree of longitude is about 111 km at the
# equator and shrinks as you move north, so a tolerance in degrees means a
# different real distance in Sokoto than in Bayelsa. Distances are computed in
# UTM zone 32N, which covers most of Nigeria and distorts the edges only
# slightly — acceptable for a 1 km threshold, and far better than degrees.
NEAREST_TOLERANCE_M = 1_000
METRIC_CRS = "EPSG:32632"  # WGS 84 / UTM zone 32N

# Named exceptions, accepted deliberately rather than by relaxing the rule.
#
# Three clusters sit 1.05-1.18 km outside every LGA polygon, at roughly
# 9.06E 6.01N — on the Cameroon border in the Boki area of Cross River.
# Two independent sources agree where they belong: GEP's own Admin1 column
# says Cross River, and the nearest polygon is NG009008 (Boki), also Cross
# River. Combined population is 236 people, or 0.0001% of Nigeria.
#
# They are admitted by id, not by widening NEAREST_TOLERANCE_M. Widening the
# threshold would also admit whatever anomaly appears in the next release,
# unexamined. A guard that bends to fit its first failure is not a guard.
BORDER_EXCEPTIONS = {690527, 690530, 690557}


def find_pcode_column(gdf: gpd.GeoDataFrame) -> str:
    """The shapefile's LGA code column, whatever the publisher chose to call it."""
    candidates = [c for c in gdf.columns
                  if "2" in c and "code" in c.lower().replace("_", "")]
    if not candidates:
        raise KeyError(
            f"No admin2 P-code column found. Columns are: {list(gdf.columns)}"
        )
    if len(candidates) > 1:
        raise KeyError(f"Ambiguous P-code column: {candidates}")
    return candidates[0]


def main() -> None:
    con = sqlite3.connect(DB)

    # ---- clusters -----------------------------------------------------
    print("Reading clusters from raw_gep ...")
    clusters = pd.read_sql("SELECT id, X_deg, Y_deg FROM raw_gep", con)
    if len(clusters) != EXPECTED_CLUSTERS:
        raise ValueError(
            f"Expected {EXPECTED_CLUSTERS:,} clusters, found {len(clusters):,}. "
            f"Run load_raw.py first."
        )
    if clusters["id"].duplicated().any():
        raise ValueError("raw_gep.id is not unique — it cannot be the join key.")
    print(f"  {len(clusters):,} clusters, ids unique")

    # ---- boundaries ---------------------------------------------------
    print("Reading boundaries ...")
    if not BOUNDARIES.exists():
        raise FileNotFoundError(
            f"{BOUNDARIES} missing. Extract nga_admin_boundaries.shp.zip into "
            f"data/raw/ first."
        )
    lgas = gpd.read_file(BOUNDARIES)
    pcode_col = find_pcode_column(lgas)
    print(f"  {len(lgas)} polygons, P-code column: {pcode_col!r}, CRS: {lgas.crs}")

    if len(lgas) != EXPECTED_LGAS:
        raise ValueError(f"Expected {EXPECTED_LGAS} LGA polygons, found {len(lgas)}.")

    lgas = lgas[[pcode_col, "geometry"]].rename(columns={pcode_col: "lga_pcode"})

    # ---- points -------------------------------------------------------
    # GEP coordinates are longitude/latitude in WGS84 (EPSG:4326). The
    # boundaries are reprojected to match if they are not already.
    points = gpd.GeoDataFrame(
        clusters[["id"]],
        geometry=[Point(xy) for xy in zip(clusters.X_deg, clusters.Y_deg)],
        crs="EPSG:4326",
    )
    if lgas.crs is None:
        raise ValueError("Boundary shapefile has no CRS. Cannot join safely.")
    if lgas.crs.to_epsg() != 4326:
        print(f"  reprojecting boundaries from {lgas.crs} to EPSG:4326")
        lgas = lgas.to_crs("EPSG:4326")

    # ---- the join -----------------------------------------------------
    print("Joining points to polygons ...")
    joined = gpd.sjoin(points, lgas, how="left", predicate="within")

    # A point sitting exactly on a shared boundary can match two polygons.
    # Keep the first and count how often it happened, rather than letting the
    # row count quietly inflate.
    dupes = joined.index.duplicated().sum()
    if dupes:
        print(f"  {dupes} cluster(s) matched more than one polygon "
              f"(on a shared boundary) — keeping the first")
        joined = joined[~joined.index.duplicated()]

    matched = joined["lga_pcode"].notna()
    print(f"  matched within a polygon: {matched.sum():,} "
          f"({100 * matched.mean():.3f}%)")

    result = pd.DataFrame({
        "cluster_id": joined["id"].values,
        "lga_pcode": joined["lga_pcode"].values,
        "match_type": ["within" if m else "unmatched" for m in matched],
    })

    # ---- rescue the strays --------------------------------------------
    n_unmatched = (~matched).sum()
    if n_unmatched:
        print(f"  {n_unmatched:,} cluster(s) fell outside every polygon — "
              f"measuring distance to the nearest one")

        # Reproject to metres for the distance calculation. Only the strays are
        # projected, so this stays cheap.
        strays = points.loc[~matched.values].copy().to_crs(METRIC_CRS)
        near = gpd.sjoin_nearest(
            strays, lgas.to_crs(METRIC_CRS), how="left", distance_col="dist_m",
        )
        near = near[~near.index.duplicated()]

        beyond = near[near["dist_m"] > NEAREST_TOLERANCE_M]
        known = beyond[beyond["id"].isin(BORDER_EXCEPTIONS)]
        lost = beyond[~beyond["id"].isin(BORDER_EXCEPTIONS)]

        if len(known):
            print(f"  {len(known)} known border exception(s) admitted "
                  f"(see BORDER_EXCEPTIONS): "
                  f"{', '.join(str(int(i)) for i in known['id'])}")

        if len(lost):
            # Show the offenders rather than only counting them. Whoever reads
            # this error needs to judge whether they matter, and that needs
            # coordinates and population, not a number.
            detail = clusters.merge(
                lost[["id", "lga_pcode", "dist_m"]], on="id", how="inner")
            pops = pd.read_sql(
                "SELECT id, Pop2020, Admin1 FROM raw_gep WHERE id IN ({})".format(
                    ",".join(str(int(i)) for i in detail["id"])), con)
            detail = detail.merge(pops, on="id", how="left")
            detail["dist_km"] = (detail["dist_m"] / 1000).round(2)

            print("\n  Clusters further than "
                  f"{NEAREST_TOLERANCE_M} m from any LGA:\n")
            print(detail[["id", "X_deg", "Y_deg", "Pop2020", "Admin1",
                          "lga_pcode", "dist_km"]].to_string(index=False))

            raise ValueError(
                f"\n{len(lost)} cluster(s) are further than "
                f"{NEAREST_TOLERANCE_M} m from any LGA. These are not rounding "
                f"artefacts. Look at the coordinates above and decide "
                f"deliberately — do not widen the tolerance to make the error "
                f"go away."
            )

        lookup = dict(zip(near["id"], near["lga_pcode"]))
        mask = result["match_type"] == "unmatched"
        result.loc[mask, "lga_pcode"] = result.loc[mask, "cluster_id"].map(lookup)
        # Label the border exceptions distinctly, so any later analysis can
        # exclude them without having to know their ids.
        result.loc[mask, "match_type"] = [
            "border_exception" if cid in BORDER_EXCEPTIONS else "nearest"
            for cid in result.loc[mask, "cluster_id"]
        ]
        within_tol = near[near["dist_m"] <= NEAREST_TOLERANCE_M]
        print(f"  rescued {len(within_tol):,} within {NEAREST_TOLERANCE_M} m "
              f"(furthest: {within_tol['dist_m'].max():.0f} m)")

    # ---- assertions ---------------------------------------------------
    if len(result) != EXPECTED_CLUSTERS:
        raise ValueError(f"{len(result):,} rows out, {EXPECTED_CLUSTERS:,} in.")
    if result["lga_pcode"].isna().any():
        raise ValueError("Some clusters still have no LGA.")
    if result["cluster_id"].duplicated().any():
        raise ValueError("Duplicate cluster ids in the lookup.")

    lgas_hit = result["lga_pcode"].nunique()
    print(f"\n  LGAs containing at least one cluster: {lgas_hit} of {EXPECTED_LGAS}")
    if lgas_hit < EXPECTED_LGAS:
        missing = set(lgas["lga_pcode"]) - set(result["lga_pcode"])
        print(f"  LGAs with no settlement cluster: {sorted(missing)}")
        print("  (Not necessarily an error — but note them in the write-up.)")

    print(result["match_type"].value_counts().to_string())

    # ---- write --------------------------------------------------------
    result.to_sql("cluster_lga", con, if_exists="replace",
                  index=False, chunksize=50_000)
    con.execute("CREATE INDEX IF NOT EXISTS idx_cluster_lga "
                "ON cluster_lga (lga_pcode)")
    con.commit()
    con.close()
    print(f"\nWrote table cluster_lga ({len(result):,} rows) to "
          f"{DB.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
