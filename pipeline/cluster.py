"""
Stage 2: segment Nigeria's 769 clusterable LGAs into market types.

Run from the project root, with DB Browser CLOSED:
    python pipeline/cluster.py

Reads  : cluster_features   (built by sql/08_cluster_features.sql)
Writes : lga_segments       (one row per LGA, one label per method)
         reports/*.png      (diagnostics)


WHY THE TRANSFORMS ARE NOT WHAT THEY FIRST LOOKED LIKE
------------------------------------------------------
Four of the seven features are right-skewed, and the obvious move is to log
all four. That was the plan until it was tested:

    log all four            max |r| = 0.880   FAIL
    log travel + density    max |r| = 0.668   PASS

Logging `mv_line_dist_km` took its correlation with `elec_rate_2020` from
-0.53 to -0.88. The underlying relationship is log-linear, so logging it
LINEARISED it, and Pearson's r -- which only sees linear association --
then detected what it had been missing. Logging `demand_kwh_per_capita`
pushed its correlation with `elec_rate_2020` from 0.668 to 0.742.

So neither of those two is logged. That leaves their skew untreated, and
untreated it is severe: raw, `mv_line_dist_km` has a maximum sitting 13.0
standard deviations from its mean, with 10 LGAs beyond 4 SD. In seven standardised dimensions a
point that far out is so distant from everything else that K-Means will
spend a cluster on it. That is not a risk to watch for; it is a certainty
to prevent.

So the two unlogged skewed features are WINSORISED at the 99th percentile:
values above p99 are pulled back to p99. The ordering is preserved, the
variable keeps its meaning, and ten points stop deciding the geometry.
Tested against the alternatives:

    treatment        max |r|        mv_line z(max)
    none             0.668 PASS     12.99
    cap at p99       0.682 PASS      5.66     <- used
    cap at p97.5     0.731 FAIL      4.00
    cap at p95       0.811 FAIL      2.55

Note what that table shows: EVERY treatment that tames the skew raises the
correlation. Compressing a tail linearises a log-linear relationship, and
Pearson's r then sees it. p99 is the only setting that fixes the worst of
the outlier problem while staying under the correlation ceiling. It is a
compromise, and it is recorded as one.

If a segment still comes back as a handful of LGAs, the pre-registered
fallback stands: DROP `mv_line_dist_km`, do not transform it harder. That
was written into sql/08_cluster_features.sql before any clustering was
run, so the choice cannot be shaped by which answer it produces.


THE DUAL TRACK
--------------
Q7 committed this project to clustering twice: once on all 769 LGAs, and
once excluding the 169 whose GEP indicators are flagged 'suspect'. If the
structure holds, the segmentation is robust to the misattribution. If it
moves, that divergence is published as a finding rather than buried.

Agreement is measured with the Adjusted Rand Index on the 600 LGAs common
to both runs. ARI is 1.0 for identical partitions and ~0 for chance
agreement, and unlike raw accuracy it does not care what the labels are
called -- which matters, because cluster 2 in one run has no reason to be
cluster 2 in the other.
"""

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.cluster import DBSCAN, AgglomerativeClustering, KMeans
from sklearn.metrics import adjusted_rand_score, silhouette_score
from sklearn.neighbors import NearestNeighbors
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "processed" / "nigeria_lga.db"
REPORTS = ROOT / "reports"

FEATURES = [
    "elec_rate_2020",          # how much of this market is still open
    "demand_kwh_per_capita",   # what a customer here is worth
    "poverty_rate",            # can they pay
    "travel_hours",            # what it costs to serve them
    "mv_line_dist_km",         # how far the grid is
    "pct_grid_new_2030",       # will the grid arrive and strand the asset
    "settled_density",         # dispersed homesteads or a town
]

# See the module docstring. Logging the other two skewed features creates
# collinearity that did not exist in the raw data.
LOG_FEATURES = ["travel_hours", "settled_density"]

# Skewed, but logging them creates collinearity (see the docstring). Capped
# at the 99th percentile instead.
WINSORISE_FEATURES = ["mv_line_dist_km", "demand_kwh_per_capita"]
WINSORISE_Q = 0.99

MAX_ABS_CORR = 0.70
K_RANGE = range(2, 11)

# Set this to pick k by hand. Leave None to take the silhouette peak -- but
# read the warnings choose_k() prints before trusting that peak.
K_OVERRIDE = None

# Below this, the silhouette is telling you the clusters overlap heavily.
WEAK_SILHOUETTE = 0.25
# A silhouette curve flatter than this across the whole k range means the
# data has no preferred k and the choice is yours to justify, not the
# algorithm's to make.
FLAT_SILHOUETTE_RANGE = 0.05
SEED = 42
N_STABILITY_RUNS = 20


# ----------------------------------------------------------------------
# Load and prepare
# ----------------------------------------------------------------------

def load() -> pd.DataFrame:
    if not DB.exists():
        sys.exit(f"{DB} not found. Run the sql/ files first.")
    con = sqlite3.connect(DB)
    try:
        df = pd.read_sql("SELECT * FROM cluster_features", con)
    except Exception:
        sys.exit("Table cluster_features not found. Run sql/08_cluster_features.sql "
                 "and press Write Changes in DB Browser.")
    finally:
        con.close()

    if len(df) != 769:
        raise ValueError(f"Expected 769 LGAs, got {len(df)}.")
    missing = df[FEATURES].isna().sum()
    if missing.any():
        raise ValueError(f"NaNs in feature columns:\n{missing[missing > 0]}")
    print(f"Loaded {len(df)} LGAs, {len(FEATURES)} features.")
    return df


def prepare(df: pd.DataFrame, strict: bool = True) -> np.ndarray:
    """Winsorise two features, log1p two others, then standardise all seven."""
    X = df[FEATURES].copy()
    for col in WINSORISE_FEATURES:
        cap = X[col].quantile(WINSORISE_Q)
        n_capped = int((X[col] > cap).sum())
        X[col] = X[col].clip(upper=cap)
        print(f"  winsorised {col} at p{WINSORISE_Q:.0%} = {cap:.2f} "
              f"({n_capped} LGAs capped)")
    for col in LOG_FEATURES:
        # log1p, not log: mv_line_dist_km and elec_rate_2020 both contain
        # exact zeros elsewhere in the table, and one rule is safer than an
        # exception to remember.
        X[col] = np.log1p(X[col])
        print(f"  log1p applied to {col}")

    # THE GUARD. The correlation structure of the transformed matrix is not
    # the correlation structure of the raw one, and it is the transformed
    # matrix the algorithm sees. Checking the raw data and assuming the
    # transformed data inherits the result is exactly the mistake this
    # assertion exists to prevent.
    corr = X.corr().abs()
    # Mask the diagonal by building a new frame. Mutating corr.values in
    # place is unreliable -- pandas may hand back a copy, in which case the
    # diagonal stays at 1.0 and this guard silently always fails.
    corr = corr.mask(np.eye(len(corr), dtype=bool))
    worst = corr.stack().idxmax()
    worst_r = float(corr.stack().max())
    print(f"  max |r| after transform: {worst_r:.3f}  ({worst[0]} vs {worst[1]})")
    if worst_r >= MAX_ABS_CORR and not strict:
        print(f"  WARNING: {worst[0]} and {worst[1]} at {worst_r:.3f} exceed "
              f"{MAX_ABS_CORR} on this subset. Reported, not fatal -- track 2 "
              f"is a robustness check, not the headline result.")
    elif worst_r >= MAX_ABS_CORR:
        raise ValueError(
            f"{worst[0]} and {worst[1]} correlate at {worst_r:.3f}, above the "
            f"{MAX_ABS_CORR} threshold. Two features this alike give one idea "
            f"two votes. Drop one, or change the transform, but do not "
            f"proceed and hope."
        )

    Xs = StandardScaler().fit_transform(X)
    print(f"  standardised: mean ~{Xs.mean():.2e}, sd ~{Xs.std():.3f}")
    return Xs


# ----------------------------------------------------------------------
# How many segments?
# ----------------------------------------------------------------------

def choose_k(X: np.ndarray) -> pd.DataFrame:
    """
    Inertia and silhouette across k. These routinely disagree, and when
    they do the disagreement is information: inertia always improves with
    more clusters, so its 'elbow' is a judgement call, while silhouette
    measures whether points sit closer to their own cluster than to the
    next one and can genuinely peak.
    """
    rows = []
    for k in K_RANGE:
        km = KMeans(n_clusters=k, random_state=SEED, n_init=10).fit(X)
        rows.append({
            "k": k,
            "inertia": km.inertia_,
            "silhouette": silhouette_score(X, km.labels_),
            "smallest_cluster": np.bincount(km.labels_).min(),
        })
    out = pd.DataFrame(rows)
    print("\nChoosing k:")
    print(out.to_string(index=False, float_format=lambda v: f"{v:.3f}"))

    peak = out["silhouette"].max()
    spread = peak - out["silhouette"].min()
    best = int(out.loc[out["silhouette"].idxmax(), "k"])
    print(f"\n  highest silhouette at k={best} ({peak:.3f})")

    # Two ways the silhouette peak can be worthless, both worth saying out
    # loud rather than discovering in a viva.
    if peak < WEAK_SILHOUETTE:
        print(f"  WEAK: peak silhouette {peak:.3f} is below {WEAK_SILHOUETTE}. "
              f"The segments overlap heavily. They may still be useful as a "
              f"way of dividing a continuum, but they are not natural kinds "
              f"and must not be described as though they were.")
    if spread < FLAT_SILHOUETTE_RANGE:
        print(f"  FLAT: silhouette varies by only {spread:.3f} across k=2..10. "
              f"The data has no preferred number of clusters, so taking the "
              f"argmax is picking noise. CHOOSE k FOR INTERPRETABILITY -- how "
              f"many market types a client can actually act on -- set "
              f"K_OVERRIDE at the top of this file, and say in the write-up "
              f"that the choice was yours and why.")

    if out["smallest_cluster"].loc[out["k"] == best].iloc[0] < 10:
        print("  TINY CLUSTER at the chosen k. This is the outlier symptom in "
              "the docstring. Check which LGAs it holds: if they are the "
              "extremes of mv_line_dist_km, apply the pre-registered fallback "
              "and drop that feature.")
    return out


# ----------------------------------------------------------------------
# The three algorithms
# ----------------------------------------------------------------------

def dbscan_eps(X: np.ndarray, min_samples: int) -> float:
    """
    The knee of the sorted k-distance curve, the standard heuristic. DBSCAN
    is included because it can decline to classify a point, which K-Means
    cannot: it is the only one of the three that can say 'this LGA is not
    like anything else'. That is worth knowing even if the answer is messy.
    """
    d, _ = NearestNeighbors(n_neighbors=min_samples).fit(X).kneighbors(X)
    kd = np.sort(d[:, -1])
    # Furthest point from the chord joining the curve's two ends.
    x = np.arange(len(kd))
    x1, y1, x2, y2 = 0, kd[0], len(kd) - 1, kd[-1]
    num = np.abs((y2 - y1) * x - (x2 - x1) * kd + x2 * y1 - y2 * x1)
    return float(kd[np.argmax(num / np.hypot(y2 - y1, x2 - x1))])


def fit_all(X: np.ndarray, k: int) -> dict:
    out = {}
    out["kmeans"] = KMeans(n_clusters=k, random_state=SEED, n_init=10).fit_predict(X)
    out["ward"] = AgglomerativeClustering(n_clusters=k, linkage="ward").fit_predict(X)
    min_samples = 2 * X.shape[1]          # 2 x dimensions, the usual default
    eps = dbscan_eps(X, min_samples)
    out["dbscan"] = DBSCAN(eps=eps, min_samples=min_samples).fit_predict(X)
    n_noise = int((out["dbscan"] == -1).sum())
    n_found = len(set(out["dbscan"])) - (1 if n_noise else 0)
    print(f"\n  DBSCAN: eps={eps:.3f}, min_samples={min_samples} -> "
          f"{n_found} clusters, {n_noise} LGAs labelled noise "
          f"({100 * n_noise / len(X):.1f}%)")
    if n_found < 2:
        print("  DBSCAN found no usable structure. That is a result, not a "
              "failure: it means the data has no dense, well-separated "
              "regions -- the segments are divisions of a continuum, not "
              "natural kinds. Report it.")
    return out


def agreement(labels: dict) -> pd.DataFrame:
    names = list(labels)
    m = pd.DataFrame(index=names, columns=names, dtype=float)
    for a in names:
        for b in names:
            m.loc[a, b] = adjusted_rand_score(labels[a], labels[b])
    print("\nAgreement between methods (Adjusted Rand Index):")
    print(m.to_string(float_format=lambda v: f"{v:.3f}"))
    return m


def stability(X: np.ndarray, k: int) -> float:
    """
    K-Means starts from random centroids. If the segmentation is real,
    different starts land in the same place; if it is an artefact of one
    lucky seed, they will not. Mean pairwise ARI across N runs.
    """
    runs = [KMeans(n_clusters=k, random_state=s, n_init=10).fit_predict(X)
            for s in range(N_STABILITY_RUNS)]
    scores = [adjusted_rand_score(runs[i], runs[j])
              for i in range(len(runs)) for j in range(i + 1, len(runs))]
    mean = float(np.mean(scores))
    print(f"\nStability over {N_STABILITY_RUNS} seeds: mean ARI {mean:.3f} "
          f"(min {min(scores):.3f})")
    if mean < 0.75:
        print("  Below 0.75. The partition moves with the starting point, so "
              "the segment boundaries are not solid. Say so in the write-up.")
    return mean


# ----------------------------------------------------------------------
# Plots
# ----------------------------------------------------------------------

def plots(sel: pd.DataFrame) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    REPORTS.mkdir(exist_ok=True)
    fig, ax = plt.subplots(1, 2, figsize=(11, 4))
    ax[0].plot(sel["k"], sel["inertia"], marker="o")
    ax[0].set(xlabel="k", ylabel="inertia", title="Elbow (always falls -- judge the bend)")
    ax[1].plot(sel["k"], sel["silhouette"], marker="o", color="darkorange")
    ax[1].set(xlabel="k", ylabel="silhouette", title="Silhouette (can genuinely peak)")
    for a in ax:
        a.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(REPORTS / "k_selection.png", dpi=150)
    print(f"\nWrote {(REPORTS / 'k_selection.png').relative_to(ROOT)}")


# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

def main() -> None:
    df = load()

    print("\n--- TRACK 1: all 769 LGAs ---")
    X = prepare(df)
    sel = choose_k(X)
    k = K_OVERRIDE or int(sel.loc[sel["silhouette"].idxmax(), "k"])
    if K_OVERRIDE:
        print(f"\n  k={k} set by hand (K_OVERRIDE), overriding the silhouette peak.")
    labels = fit_all(X, k)
    agreement(labels)
    stability(X, k)
    plots(sel)

    print(f"\n--- TRACK 2: excluding 'suspect' LGAs, k={k} held fixed ---")
    ok = df["gep_flag"] == "ok"
    print(f"  {ok.sum()} LGAs ('ok' only), {(~ok).sum()} excluded")
    X_ok = prepare(df.loc[ok], strict=False)
    labels_ok = fit_all(X_ok, k)

    # THE Q7 TEST. Same LGAs, two runs, one of which never saw the flagged
    # rows. Do the clean LGAs land together either way?
    ari = adjusted_rand_score(labels["kmeans"][ok.values], labels_ok["kmeans"])
    print(f"\n  ARI between tracks on the {ok.sum()} shared LGAs: {ari:.3f}")
    if ari >= 0.75:
        print("  The segmentation is ROBUST to the misattribution. The flagged "
              "LGAs are not driving the structure. Q7's first response is "
              "satisfied and can be reported as such.")
    else:
        print("  The structure MOVES when flagged LGAs are excluded. Per the "
              "Q7 commitment this is published as a finding, not smoothed "
              "over. Report both segmentations and which LGAs change hands.")

    out = df[["lga_pcode", "lga_name", "state_name", "gep_flag"]].copy()
    out["seg_kmeans"] = labels["kmeans"]
    out["seg_ward"] = labels["ward"]
    out["seg_dbscan"] = labels["dbscan"]
    out["seg_kmeans_ok_only"] = pd.Series(labels_ok["kmeans"], index=df.index[ok])
    out["k_used"] = k

    con = sqlite3.connect(DB)
    out.to_sql("lga_segments", con, if_exists="replace", index=False)
    con.commit()
    con.close()
    print(f"\nWrote lga_segments ({len(out)} rows) to "
          f"{DB.relative_to(ROOT)}")
    print("\nNothing here names a segment. Naming is Stage 3, and it is done "
          "by reading the profiles -- not by looking at a scatter plot and "
          "deciding what feels right.")


if __name__ == "__main__":
    main()
