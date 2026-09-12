"""
Diagnostic: do the sub-segments inside segment 3 differ in how well they fit
the PARENT five-segment solution?

    python pipeline/check_subsegment_fit.py

Reads  : lga_segments_named, lga_subsegments, cluster_features
Writes : nothing. Prints only. No table, no figure, no side effect.


THE QUESTION
------------
subcluster.py found four sub-types inside segment 3. One of them -- sub 1, 19
LGAs concentrated in Ebonyi and Enugu -- looks like it does not belong to the
parent segment at all: stand-alone solar is least-cost for 24% of its people
against 59% for the segment, and demand is 159 kWh/person/year against 31.

If that reading is right, those LGAs should ALSO be the ones the parent
five-segment solution fits worst. That is a prediction, and it can be wrong.

WHY THE OBVIOUS TEST IS TOO WEAK, AND WHAT REPLACES IT
------------------------------------------------------
The obvious test is "how many of the parent's negative-silhouette LGAs fall in
sub 1?" It is too weak here: segment 3 has only FOUR LGAs below zero out of
274. Four is not enough to distinguish a pattern from an accident, and a test
that cannot fail to be inconclusive is not a test.

So the count is reported for completeness and two stronger instruments carry
the weight:

  1. MEAN PARENT SILHOUETTE per sub-segment. Not "how many crossed zero" but
     "how comfortably does each sub-type sit inside its parent". A group that
     does not belong should sit lower on the whole distribution, not merely
     produce a few crossings.

  2. NEAREST OTHER SEGMENT per LGA -- the segment each place would move to if
     it left its own. This is the b() term inside the silhouette, which is
     normally thrown away after the score is computed. If sub 1 is a misfit,
     its LGAs should point somewhere specific and agree with each other. If
     they scatter across all four alternatives, they are simply peripheral,
     which is a different and much less interesting claim.

WHAT WOULD FALSIFY THE HYPOTHESIS
---------------------------------
  - sub 1's mean parent silhouette sits at or above the other three, or
  - its nearest-other-segment votes are spread evenly rather than concentrated.
Either result, and sub 1 is an ordinary sub-type with unusual demand, not a
group filed in the wrong segment. Both outcomes get printed the same way.
"""

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import pairwise_distances
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "processed" / "nigeria_lga.db"

FEATURES = [
    "elec_rate_2020", "demand_kwh_per_capita", "poverty_rate", "travel_hours",
    "mv_line_dist_km", "pct_grid_new_2030", "settled_density",
]
LOG_FEATURES = ["travel_hours", "settled_density"]
WINSORISE_FEATURES = ["mv_line_dist_km", "demand_kwh_per_capita"]
WINSORISE_Q = 0.99


def load():
    if not DB.exists():
        sys.exit(f"{DB} not found.")
    con = sqlite3.connect(DB)
    try:
        df = pd.read_sql(f"""
            SELECT n.lga_pcode, n.lga_name, n.state_name, n.seg_kmeans,
                   n.display_order, n.segment_name,
                   {', '.join('f.' + c for c in FEATURES)}
            FROM lga_segments_named n
            JOIN cluster_features f ON f.lga_pcode = n.lga_pcode
        """, con)
        sub = pd.read_sql(
            "SELECT lga_pcode, sub, parent_segment, substructure_real "
            "FROM lga_subsegments", con)
    except Exception as exc:
        sys.exit(f"Could not read the tables: {exc}\n"
                 f"Run sql/09_segment_names.sql and pipeline/subcluster.py first.")
    finally:
        con.close()
    return df, sub


def prepare(df) -> np.ndarray:
    """Identical to cluster.py / visualise.py, so the geometry is the same one."""
    X = df[FEATURES].copy()
    for c in WINSORISE_FEATURES:
        X[c] = X[c].clip(upper=X[c].quantile(WINSORISE_Q))
    for c in LOG_FEATURES:
        X[c] = np.log1p(X[c])
    return StandardScaler().fit_transform(X)


def silhouette_and_neighbour(Xs, labels):
    """
    Per-point silhouette, plus the label of the nearest OTHER cluster.

    sklearn's silhouette_samples discards the second term. Recomputing it by
    hand costs one 769x769 distance matrix and returns the thing this
    diagnostic is actually about: not how badly a place fits, but where it
    would go instead.
    """
    D = pairwise_distances(Xs)
    uniq = np.unique(labels)
    # mean distance from every point to every cluster
    mean_to = np.column_stack([D[:, labels == c].mean(axis=1) for c in uniq])
    # own-cluster mean must exclude the point itself (distance 0 to itself)
    for j, c in enumerate(uniq):
        m = labels == c
        n = m.sum()
        if n > 1:
            mean_to[m, j] = mean_to[m, j] * n / (n - 1)

    own_idx = np.searchsorted(uniq, labels)
    a = mean_to[np.arange(len(labels)), own_idx]
    other = mean_to.copy()
    other[np.arange(len(labels)), own_idx] = np.inf
    b = other.min(axis=1)
    nearest = uniq[other.argmin(axis=1)]
    sil = (b - a) / np.maximum(a, b)
    return sil, nearest


def main():
    df, sub = load()
    Xs = prepare(df)
    sil, nearest = silhouette_and_neighbour(Xs, df["seg_kmeans"].values)
    df["parent_sil"] = sil
    df["nearest_seg"] = nearest

    name_of = (df.drop_duplicates("seg_kmeans")
                 .set_index("seg_kmeans")[["display_order", "segment_name"]])

    def label(seg):
        r = name_of.loc[seg]
        return f"{int(r.display_order)} {r.segment_name}"

    tot_neg = int((df.parent_sil < 0).sum())
    print(f"{len(df)} LGAs · {tot_neg} with a negative parent silhouette "
          f"({100*tot_neg/len(df):.1f}%)")

    parent = int(sub["parent_segment"].iloc[0])
    real = int(sub["substructure_real"].iloc[0])
    print(f"Sub-segments read from lga_subsegments: parent = segment {parent} "
          f"({label(parent)}), substructure_real = {real}")

    m = df.merge(sub, on="lga_pcode", how="inner")
    if len(m) != len(sub):
        sys.exit(f"Join lost rows: {len(sub)} sub-segment rows, {len(m)} matched.")
    base = df[df.seg_kmeans == parent]
    print(f"Parent segment: {len(base)} LGAs · "
          f"{int((base.parent_sil < 0).sum())} below zero · "
          f"mean parent silhouette {base.parent_sil.mean():.3f}\n")

    # ---- instrument 1: how comfortably each sub sits inside the parent -----
    print("How well each sub-type fits the PARENT five-segment solution")
    print(f"{'sub':>4} {'n':>5} {'mean sil':>9} {'median':>8} "
          f"{'10th pct':>9} {'below 0':>8}")
    g = m.groupby("sub")["parent_sil"]
    for s, v in g:
        print(f"{s:>4} {len(v):>5} {v.mean():>9.3f} {v.median():>8.3f} "
              f"{np.percentile(v, 10):>9.3f} {int((v < 0).sum()):>8}")
    lo = g.mean().idxmin()
    spread = g.mean().max() - g.mean().min()
    print(f"\n  lowest mean: sub {lo}  ·  spread across sub-types {spread:.3f}")

    # ---- instrument 2: where would each one go instead? -------------------
    print("\nIf it left its own segment, where would each LGA go?")
    ct = pd.crosstab(m["sub"], m["nearest_seg"])
    ct.columns = [label(c) for c in ct.columns]
    share = (100 * ct.div(ct.sum(axis=1), axis=0)).round(0).astype(int)
    print(share.to_string())
    print("  (% of each sub-type's LGAs, by nearest alternative segment)")

    for s in sorted(m["sub"].unique()):
        row = share.loc[s]
        top, pct = row.idxmax(), row.max()
        verdict = "concentrated" if pct >= 60 else "spread"
        print(f"  sub {s}: {verdict} -- {pct}% would go to {top}")

    # ---- the weak instrument, reported for completeness --------------------
    neg = m[m.parent_sil < 0]
    print(f"\nNegative-silhouette LGAs inside the parent: {len(neg)}")
    if len(neg):
        print(neg.groupby("sub").size().to_string())
    print("  Too few to carry an argument on their own -- see the header.")

    # ---- the 19 in question ------------------------------------------------
    focus = m[m["sub"] == 1].sort_values("parent_sil")
    shown = focus.head(30)
    print(f"\nsub 1, worst fit first "
          f"({len(shown)} of {len(focus)} shown):")
    for _, r in shown.iterrows():
        print(f"  {r.parent_sil:+.3f}  {r.lga_name:<22} {r.state_name:<14} "
              f"-> {label(r.nearest_seg)}")


if __name__ == "__main__":
    main()
