"""
Stage 2b: is there structure INSIDE the largest segment?

Run from the project root, after pipeline/cluster.py:
    python pipeline/subcluster.py

Reads  : lga_segments, cluster_features
Writes : lga_subsegments      (one row per LGA in the target segment)
         reports/subsegment_fingerprint.png
         reports/subsegment_map.png


WHY THIS EXISTS
---------------
PROJECT_BRIEF.md, written at Stage 0 before any data was loaded, names the
failure mode this file tests:

    "Segments that only recover geography. If the clusters reduce to
     'north versus south,' the analysis has told the reader what a map
     already tells them. I will report it honestly if it happens and then
     look for structure WITHIN the obvious split."

It partly happened. Segment 3 is 274 LGAs forming a near-solid block across
the northern half of Nigeria, holding 47.6 million unserved people -- 57% of
the national total. Reporting "the North is one market" would be true and
almost useless to an operator deciding where to put agents.

So this file does the second half of that promise. Either the volume market
divides into types a developer could treat differently, or it does not, and
BOTH answers get published.


THE TRAP THIS FILE IS BUILT AROUND
----------------------------------
K-Means ALWAYS returns k clusters. Ask it for four and it gives you four,
whether or not there are four of anything. Run it on pure noise and it will
hand back tidy, plausible, entirely meaningless groups. So "I clustered
segment 3 and found four sub-types" is not a finding; it is a description of
what the algorithm is obliged to do.

The only way to tell a real division from a decorative one is to ask what
the same procedure produces on data with NO joint structure. That is the
null model below: each feature column is shuffled independently, which
destroys the relationships between features while preserving every marginal
distribution exactly. Cluster that, many times, and you get the silhouette
this procedure yields from nothing.

If the real sub-clustering does not clearly beat that null, there is no
sub-structure worth reporting, however tidy the output looks.
"""

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.metrics import adjusted_rand_score, silhouette_score
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "processed" / "nigeria_lga.db"
SHP = ROOT / "data" / "raw" / "nga_admin2.shp"
REPORTS = ROOT / "reports"

# Which parent segment to look inside. 3 is the northern volume market.
TARGET_SEGMENT = 3

FEATURES = [
    "elec_rate_2020", "demand_kwh_per_capita", "poverty_rate", "travel_hours",
    "mv_line_dist_km", "pct_grid_new_2030", "settled_density",
]
LOG_FEATURES = ["travel_hours", "settled_density"]
WINSORISE_FEATURES = ["mv_line_dist_km", "demand_kwh_per_capita"]
WINSORISE_Q = 0.99

K_RANGE = range(2, 8)
SEED = 42
N_NULL_RUNS = 50
N_STABILITY_RUNS = 20

# How much the real silhouette must exceed the null's 95th percentile before
# the sub-structure is called real. A margin, not a coin flip.
NULL_MARGIN = 0.02

SURFACE, INK, INK_2 = "#fcfcfb", "#0b0b0b", "#52514e"
BLUE, RED, MID, MUTED = "#2a78d6", "#d03b3b", "#f0efec", "#dedcd6"

NICE = {
    "elec_rate_2020": "electrification rate",
    "demand_kwh_per_capita": "demand per person",
    "poverty_rate": "poverty rate",
    "travel_hours": "travel time to town",
    "mv_line_dist_km": "distance to grid",
    "pct_grid_new_2030": "grid arriving by 2030",
    "settled_density": "settlement density",
}


def load() -> pd.DataFrame:
    con = sqlite3.connect(DB)
    try:
        df = pd.read_sql(f"""
            SELECT s.lga_pcode, s.lga_name, s.state_name, s.gep_flag, s.seg_kmeans,
                   f.elec_rate_2020, f.demand_kwh_per_capita, f.poverty_rate,
                   f.travel_hours, f.mv_line_dist_km, f.pct_grid_new_2030,
                   f.settled_density, f.unserved_pop_2020, f.gep_pop_2020,
                   f.investment_per_capita_usd, f.health_per_100k
            FROM lga_segments s
            JOIN cluster_features f ON f.lga_pcode = s.lga_pcode
            WHERE s.seg_kmeans = {TARGET_SEGMENT}
        """, con)
    except Exception as exc:
        sys.exit(f"Could not read the segment tables: {exc}\n"
                 f"Run pipeline/cluster.py first.")
    finally:
        con.close()
    if df.empty:
        sys.exit(f"Segment {TARGET_SEGMENT} is empty.")
    print(f"Segment {TARGET_SEGMENT}: {len(df)} LGAs, "
          f"{df.unserved_pop_2020.sum()/1e6:.1f}M unserved, "
          f"{df.state_name.nunique()} states.")
    return df


def prepare(df: pd.DataFrame) -> np.ndarray:
    """
    Re-scaled WITHIN the subset, not inherited from the national run.

    This matters. Nationally, most of each feature's variance sits BETWEEN
    segments. Inside one segment that variance is gone, so national z-scores
    would compress these 274 LGAs into a narrow band and the sub-structure --
    if any -- would be invisible. Standardising within the subset asks the
    right question: how do these LGAs differ FROM EACH OTHER?
    """
    X = df[FEATURES].copy()
    for col in WINSORISE_FEATURES:
        X[col] = X[col].clip(upper=X[col].quantile(WINSORISE_Q))
    for col in LOG_FEATURES:
        X[col] = np.log1p(X[col])

    corr = X.corr().abs().mask(np.eye(len(FEATURES), dtype=bool))
    worst, worst_r = corr.stack().idxmax(), float(corr.stack().max())
    print(f"  max |r| within the subset: {worst_r:.3f} ({worst[0]} vs {worst[1]})")
    if worst_r >= 0.70:
        print(f"  NOTE: above 0.70. Reported rather than fatal -- this is a "
              f"diagnostic run inside one segment, not the headline "
              f"segmentation. But weight it when reading the result.")
    return StandardScaler().fit_transform(X)


def null_silhouette(X: np.ndarray, k: int, rng) -> np.ndarray:
    """
    Silhouettes from data with the same marginals and no joint structure.

    Shuffling each column independently keeps every feature's distribution
    exactly as it is and destroys only the relationships between them. What
    K-Means finds in that is what K-Means finds in nothing.
    """
    out = []
    for _ in range(N_NULL_RUNS):
        Z = np.column_stack([rng.permutation(X[:, j]) for j in range(X.shape[1])])
        lab = KMeans(n_clusters=k, random_state=SEED, n_init=10).fit_predict(Z)
        out.append(silhouette_score(Z, lab))
    return np.array(out)


def choose_k(X: np.ndarray) -> pd.DataFrame:
    rng = np.random.default_rng(SEED)
    rows = []
    for k in K_RANGE:
        lab = KMeans(n_clusters=k, random_state=SEED, n_init=10).fit_predict(X)
        real = silhouette_score(X, lab)
        null = null_silhouette(X, k, rng)
        rows.append({
            "k": k,
            "silhouette": real,
            "null_mean": null.mean(),
            "null_p95": np.percentile(null, 95),
            "excess": real - np.percentile(null, 95),
            "smallest": np.bincount(lab).min(),
        })
    out = pd.DataFrame(rows)
    print(f"\nSub-structure against a null model ({N_NULL_RUNS} shuffles per k):")
    print(out.to_string(index=False, float_format=lambda v: f"{v:.3f}"))
    return out


def stability(X: np.ndarray, k: int) -> float:
    runs = [KMeans(n_clusters=k, random_state=s, n_init=10).fit_predict(X)
            for s in range(N_STABILITY_RUNS)]
    sc = [adjusted_rand_score(runs[i], runs[j])
          for i in range(len(runs)) for j in range(i + 1, len(runs))]
    print(f"  stability over {N_STABILITY_RUNS} seeds: mean ARI {np.mean(sc):.3f}")
    return float(np.mean(sc))


def profile(df: pd.DataFrame) -> pd.DataFrame:
    z = ((df.groupby("sub")[FEATURES].mean() - df[FEATURES].mean())
         / df[FEATURES].std())
    # Commercial columns alongside the feature z-scores: a sub-type is only
    # worth naming if it differs in something an operator can act on.
    size = df.groupby("sub").agg(
        n=("lga_pcode", "size"),
        unserved_m=("unserved_pop_2020", lambda v: round(v.sum() / 1e6, 2)),
        inv_capita=("investment_per_capita_usd", lambda v: round(v.mean())),
        health_100k=("health_per_100k", lambda v: round(v.mean(), 1)),
        n_suspect=("gep_flag", lambda v: int((v == "suspect").sum())),
    )
    print("\nSub-segment profiles (z-scores WITHIN segment "
          f"{TARGET_SEGMENT}):")
    print(pd.concat([size, z], axis=1).to_string(
        float_format=lambda v: f"{v:+.2f}"))
    print("\nTop states in each sub-segment:")
    for s in sorted(df["sub"].unique()):
        top = df.loc[df["sub"] == s, "state_name"].value_counts().head(3)
        print(f"  sub {s}: " + ", ".join(f"{k} {v}" for k, v in top.items()))
    return z


def figures(df: pd.DataFrame, z: pd.DataFrame):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap
    REPORTS.mkdir(exist_ok=True)

    fig, ax = plt.subplots(figsize=(9.5, 0.75 * len(z) + 2.4), facecolor=SURFACE)
    lim = float(np.abs(z.values).max())
    im = ax.imshow(z.values, aspect="auto", vmin=-lim, vmax=lim,
                   cmap=LinearSegmentedColormap.from_list("d", [BLUE, MID, RED]))
    ax.set_xticks(range(len(FEATURES)))
    ax.set_xticklabels([NICE[f] for f in FEATURES], rotation=28, ha="right")
    ax.set_yticks(range(len(z)))
    ax.set_yticklabels([f"sub {i}   n={(df['sub'] == i).sum()}" for i in z.index])
    for i in range(z.shape[0]):
        for j in range(z.shape[1]):
            v = z.values[i, j]
            ax.text(j, i, f"{v:+.1f}", ha="center", va="center", fontsize=8,
                    color="#ffffff" if abs(v) > lim * 0.55 else INK)
    ax.set_xticks(np.arange(-.5, len(FEATURES), 1), minor=True)
    ax.set_yticks(np.arange(-.5, len(z), 1), minor=True)
    ax.grid(which="minor", color=SURFACE, linewidth=2)
    ax.tick_params(which="minor", length=0, labelsize=8)
    ax.tick_params(colors=INK_2, labelsize=8, length=0)
    for sp in ax.spines.values():
        sp.set_visible(False)
    ax.set_title(f"Inside segment {TARGET_SEGMENT}: what separates the sub-types",
                 color=INK, fontsize=12, loc="left", pad=14)
    ax.text(0, 1.02, "standard deviations from the segment mean, not the national one",
            transform=ax.transAxes, color=INK_2, fontsize=8.5, va="bottom")
    fig.tight_layout()
    fig.savefig(REPORTS / "subsegment_fingerprint.png", dpi=170, facecolor=SURFACE)
    plt.close(fig)
    print("  subsegment_fingerprint.png")

    try:
        import geopandas as gpd
    except ImportError:
        return
    if not SHP.exists():
        return
    gdf = gpd.read_file(SHP)
    pc = next(c for c in gdf.columns
              if "2" in c and "code" in c.lower().replace("_", ""))
    gdf = gdf.merge(df[["lga_pcode", "sub"]], left_on=pc,
                    right_on="lga_pcode", how="left")
    subs = sorted(df["sub"].unique())
    fig, axes = plt.subplots(1, len(subs), figsize=(3.1 * len(subs), 4.0),
                             facecolor=SURFACE)
    for ax, s in zip(np.atleast_1d(axes), subs):
        gdf.plot(ax=ax, color=MUTED, edgecolor=SURFACE, linewidth=0.12)
        gdf[gdf["sub"] == s].plot(ax=ax, color=BLUE, edgecolor=SURFACE,
                                  linewidth=0.12)
        n = int((df["sub"] == s).sum())
        pop = df.loc[df["sub"] == s, "unserved_pop_2020"].sum() / 1e6
        ax.set_title(f"sub {s}", color=INK, fontsize=11, loc="left")
        ax.text(0, -0.04, f"{n} LGAs  ·  {pop:.1f}M unserved",
                transform=ax.transAxes, color=INK_2, fontsize=8.5, va="top")
        ax.set_axis_off()
    fig.suptitle(f"Inside segment {TARGET_SEGMENT}", color=INK, fontsize=13,
                 x=0.01, ha="left", y=0.99)
    fig.tight_layout(rect=(0, 0.02, 1, 0.94))
    fig.savefig(REPORTS / "subsegment_map.png", dpi=170, facecolor=SURFACE)
    plt.close(fig)
    print("  subsegment_map.png")


def main():
    df = load()
    X = prepare(df)
    sel = choose_k(X)

    best = sel.loc[sel["excess"].idxmax()]
    k = int(best["k"])
    real, p95, excess = best["silhouette"], best["null_p95"], best["excess"]

    print(f"\nBest k by excess over the null: k={k}")
    print(f"  real silhouette      {real:.3f}")
    print(f"  null 95th percentile {p95:.3f}")
    print(f"  excess               {excess:+.3f}")

    if excess < NULL_MARGIN:
        print(f"\n  VERDICT: NO SUB-STRUCTURE WORTH REPORTING.")
        print(f"  The best sub-clustering beats shuffled data by only "
              f"{excess:+.3f}, under the {NULL_MARGIN} margin. K-Means still "
              f"returned {k} tidy groups -- it always does -- but they are no "
              f"better than what the same procedure produces from noise with "
              f"these same marginal distributions.")
        print(f"\n  This is a real answer to the question PROJECT_BRIEF.md "
              f"asked, and it publishes: segment {TARGET_SEGMENT} is ONE "
              f"market, not several. An operator should treat its "
              f"{len(df)} LGAs with one approach and choose between them on "
              f"size and access, not on type.")
    else:
        print(f"\n  VERDICT: SUB-STRUCTURE IS REAL.")
        print(f"  {excess:+.3f} above the null's 95th percentile. The "
              f"{len(df)} LGAs of segment {TARGET_SEGMENT} divide into {k} "
              f"types that shuffled data does not reproduce.")

    df["sub"] = KMeans(n_clusters=k, random_state=SEED, n_init=10).fit_predict(X)
    stability(X, k)
    z = profile(df)

    print("\nWriting figures:")
    figures(df, z)

    out = df[["lga_pcode", "lga_name", "state_name", "gep_flag",
              "seg_kmeans", "sub", "unserved_pop_2020"]].copy()
    out["parent_segment"] = TARGET_SEGMENT
    out["k_used"] = k
    out["null_excess"] = excess
    out["substructure_real"] = int(excess >= NULL_MARGIN)
    con = sqlite3.connect(DB)
    out.to_sql("lga_subsegments", con, if_exists="replace", index=False)
    con.commit()
    con.close()
    print(f"\nWrote lga_subsegments ({len(out)} rows).")
    print("\nThe labels are written whatever the verdict, so the negative "
          "result can be inspected too. `substructure_real` records which "
          "answer came back -- read it before using `sub` for anything.")


if __name__ == "__main__":
    main()
