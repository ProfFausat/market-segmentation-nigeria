"""
Stage 2 visuals: what the five segments look like.

Run from the project root, after pipeline/cluster.py:
    python pipeline/visualise.py

Reads  : lga_segments, cluster_features, data/raw/nga_admin2.shp
Writes : reports/segment_fingerprint.png
         reports/segment_map.png
         reports/segment_scale.png
         reports/segment_silhouette.png


WHAT EACH FIGURE IS FOR, AND WHAT IT MUST NOT CLAIM
---------------------------------------------------
The clustering found silhouette 0.309 and DBSCAN found no dense regions at
all. Both say the segments are DIVISIONS OF A CONTINUUM, not natural kinds
with gaps between them. Every figure here has to be honest about that, which
rules out the chart most clustering write-ups reach for first: a 2-D PCA
scatter with five tidy coloured blobs. Projecting seven dimensions onto two
discards most of the variance and then invites the reader to judge separation
by eye in the space where it was destroyed. It flatters the result. It is not
included.

  fingerprint   what actually distinguishes each segment -- the centrepiece
  map           where each segment is -- the finding a table cannot carry
  scale         how much unserved population each holds -- commercial weight
  silhouette    how well-formed each segment is -- the honesty check

COLOUR
------
Five categorical colours cannot pass colour-blind separation on a choropleth:
with all pairs on screen at once the validated palette caps at three. So the
map is SMALL MULTIPLES -- one highlighted segment per panel against a muted
base -- which needs only two colours per panel and reads better besides.

The fingerprint is diverging (above/below the national average), so it takes
the blue<->red pair with a neutral grey midpoint. Grey at the middle matters:
a hue there would read as a value rather than as "average".

Magnitude charts use one blue ramp. No chart here encodes identity by colour
alone; every segment is labelled.
"""

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "processed" / "nigeria_lga.db"
SHP = ROOT / "data" / "raw" / "nga_admin2.shp"
REPORTS = ROOT / "reports"

# Validated reference palette, light surface.
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
BLUE = "#2a78d6"
RED = "#d03b3b"
MID = "#f0efec"          # neutral diverging midpoint
MUTED = "#dedcd6"        # unhighlighted polygons
GRID = "#e8e6e0"
BLUE_RAMP = ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#2a78d6",
             "#256abf", "#184f95"]

FEATURES = [
    "elec_rate_2020", "demand_kwh_per_capita", "poverty_rate", "travel_hours",
    "mv_line_dist_km", "pct_grid_new_2030", "settled_density",
]
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
    if not DB.exists():
        sys.exit(f"{DB} not found.")
    con = sqlite3.connect(DB)
    try:
        df = pd.read_sql("""
            SELECT s.lga_pcode, s.lga_name, s.state_name, s.seg_kmeans, s.gep_flag,
                   f.elec_rate_2020, f.demand_kwh_per_capita, f.poverty_rate,
                   f.travel_hours, f.mv_line_dist_km, f.pct_grid_new_2030,
                   f.settled_density, f.unserved_pop_2020, f.gep_pop_2020
            FROM lga_segments s
            JOIN cluster_features f ON f.lga_pcode = s.lga_pcode
        """, con)
    except Exception as exc:
        sys.exit(f"Could not read lga_segments / cluster_features: {exc}\n"
                 f"Run pipeline/cluster.py first.")
    finally:
        con.close()
    print(f"Loaded {len(df)} LGAs in {df.seg_kmeans.nunique()} segments.")
    return df


def style(ax, title="", sub=""):
    ax.set_facecolor(SURFACE)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.tick_params(colors=INK_2, labelsize=8, length=0)
    if title:
        ax.set_title(title, color=INK, fontsize=12, loc="left", pad=14 if sub else 8)
    if sub:
        ax.text(0, 1.02, sub, transform=ax.transAxes, color=INK_2,
                fontsize=8.5, va="bottom")


# ----------------------------------------------------------------------
# 1. Fingerprint -- what makes each segment different
# ----------------------------------------------------------------------

def fingerprint(df, plt):
    """
    Segment means as z-scores against the national mean. Diverging, because
    the question is direction as well as size: is this segment above or
    below average on each feature? Raw means cannot answer that -- 708 kWh
    and 0.22 are not comparable numbers until they are standardised.
    """
    z = (df.groupby("seg_kmeans")[FEATURES].mean() - df[FEATURES].mean()) / df[FEATURES].std()
    z = z[FEATURES]

    fig, ax = plt.subplots(figsize=(9.5, 4.2), facecolor=SURFACE)
    lim = float(np.abs(z.values).max())
    from matplotlib.colors import LinearSegmentedColormap
    cmap = LinearSegmentedColormap.from_list("div", [BLUE, MID, RED])
    im = ax.imshow(z.values, cmap=cmap, vmin=-lim, vmax=lim, aspect="auto")

    ax.set_xticks(range(len(FEATURES)))
    ax.set_xticklabels([NICE[f] for f in FEATURES], rotation=28, ha="right")
    ax.set_yticks(range(len(z)))
    ax.set_yticklabels([f"segment {i}   n={(df.seg_kmeans == i).sum()}" for i in z.index])

    # Direct labels: identity is never colour alone.
    for i in range(z.shape[0]):
        for j in range(z.shape[1]):
            v = z.values[i, j]
            ax.text(j, i, f"{v:+.1f}", ha="center", va="center", fontsize=8,
                    color="#ffffff" if abs(v) > lim * 0.55 else INK)
    ax.set_xticks(np.arange(-.5, len(FEATURES), 1), minor=True)
    ax.set_yticks(np.arange(-.5, len(z), 1), minor=True)
    ax.grid(which="minor", color=SURFACE, linewidth=2)
    ax.tick_params(which="minor", length=0)
    style(ax, "What distinguishes each segment",
          "standard deviations from the national mean  ·  blue = below, red = above")
    cb = fig.colorbar(im, ax=ax, shrink=0.7, pad=0.02)
    cb.outline.set_visible(False)
    cb.ax.tick_params(colors=INK_2, labelsize=8, length=0)
    fig.tight_layout()
    fig.savefig(REPORTS / "segment_fingerprint.png", dpi=170, facecolor=SURFACE)
    plt.close(fig)
    print("  segment_fingerprint.png")


# ----------------------------------------------------------------------
# 2. Map -- small multiples
# ----------------------------------------------------------------------

def maps(df, plt):
    try:
        import geopandas as gpd
    except ImportError:
        print("  geopandas not available -- skipping the map")
        return
    if not SHP.exists():
        print(f"  {SHP.name} not found -- extract nga_admin_boundaries.shp.zip "
              f"into data/raw/ to draw the map")
        return

    gdf = gpd.read_file(SHP)
    pcode_col = next(c for c in gdf.columns
                     if "2" in c and "code" in c.lower().replace("_", ""))
    gdf = gdf.merge(df[["lga_pcode", "seg_kmeans"]],
                    left_on=pcode_col, right_on="lga_pcode", how="left")
    matched = gdf["seg_kmeans"].notna().sum()
    print(f"  map: {matched} of {len(gdf)} polygons matched a segment "
          f"({len(gdf) - matched} unmatched -- the LGAs with no clusters)")

    segs = sorted(df.seg_kmeans.unique())
    fig, axes = plt.subplots(1, len(segs), figsize=(3.1 * len(segs), 4.0),
                             facecolor=SURFACE)
    for ax, s in zip(np.atleast_1d(axes), segs):
        gdf.plot(ax=ax, color=MUTED, edgecolor=SURFACE, linewidth=0.12)
        sub = gdf[gdf["seg_kmeans"] == s]
        sub.plot(ax=ax, color=BLUE, edgecolor=SURFACE, linewidth=0.12)
        n = len(sub)
        pop = df.loc[df.seg_kmeans == s, "unserved_pop_2020"].sum() / 1e6
        ax.set_title(f"segment {s}", color=INK, fontsize=11, loc="left")
        ax.text(0, -0.04, f"{n} LGAs  ·  {pop:.1f}M unserved",
                transform=ax.transAxes, color=INK_2, fontsize=8.5, va="top")
        ax.set_axis_off()
    fig.suptitle("Where each segment is", color=INK, fontsize=13, x=0.01,
                 ha="left", y=0.99)
    fig.tight_layout(rect=(0, 0.02, 1, 0.94))
    fig.savefig(REPORTS / "segment_map.png", dpi=170, facecolor=SURFACE)
    plt.close(fig)
    print("  segment_map.png")


# ----------------------------------------------------------------------
# 3. Commercial scale
# ----------------------------------------------------------------------

def scale(df, plt):
    g = (df.groupby("seg_kmeans")
           .agg(lgas=("lga_pcode", "size"),
                unserved=("unserved_pop_2020", "sum"))
           .sort_values("unserved"))
    fig, ax = plt.subplots(figsize=(8, 3.4), facecolor=SURFACE)
    y = np.arange(len(g))
    ax.barh(y, g["unserved"] / 1e6, height=0.62, color=BLUE_RAMP[4])
    ax.set_yticks(y)
    ax.set_yticklabels([f"segment {i}" for i in g.index])
    for i, (v, n) in enumerate(zip(g["unserved"] / 1e6, g["lgas"])):
        ax.text(v + 0.6, i, f"{v:.1f}M   ({n} LGAs)", va="center",
                fontsize=9, color=INK_2)
    ax.set_xlim(0, (g["unserved"] / 1e6).max() * 1.28)
    ax.xaxis.grid(True, color=GRID, linewidth=1)
    ax.set_axisbelow(True)
    ax.set_xlabel("people without electricity, millions", color=INK_2, fontsize=9)
    style(ax, "Commercial weight of each segment",
          f"{df.unserved_pop_2020.sum()/1e6:.1f} million unserved across {len(df)} LGAs")
    fig.tight_layout()
    fig.savefig(REPORTS / "segment_scale.png", dpi=170, facecolor=SURFACE)
    plt.close(fig)
    print("  segment_scale.png")


# ----------------------------------------------------------------------
# 4. Silhouette -- the honesty check
# ----------------------------------------------------------------------

def silhouette(df, plt):
    """
    Per-LGA silhouette, grouped by segment. Each bar is one LGA: how much
    closer it sits to its own segment than to the nearest other one.

    This is the figure that keeps the others honest. Values near zero mean an
    LGA sits on a boundary and could plausibly belong to either side; negative
    values mean it is closer to a different segment than its own. A wide, flat
    profile is what a continuum looks like -- which is what DBSCAN already
    said this data is.
    """
    from sklearn.metrics import silhouette_samples
    from sklearn.preprocessing import StandardScaler

    X = df[FEATURES].copy()
    for col in ["mv_line_dist_km", "demand_kwh_per_capita"]:
        X[col] = X[col].clip(upper=X[col].quantile(0.99))
    for col in ["travel_hours", "settled_density"]:
        X[col] = np.log1p(X[col])
    Xs = StandardScaler().fit_transform(X)
    vals = silhouette_samples(Xs, df["seg_kmeans"].values)

    fig, ax = plt.subplots(figsize=(8, 4.4), facecolor=SURFACE)
    segs = sorted(df.seg_kmeans.unique())
    lo, labels = 0, []
    # Reversed, because matplotlib's y axis grows upward: this puts
    # segment 0 at the TOP, matching the reading order of every other figure.
    for s in reversed(segs):
        v = np.sort(vals[df.seg_kmeans.values == s])
        ax.barh(np.arange(lo, lo + len(v)), v, height=1.0, color=BLUE_RAMP[4])
        labels.append((lo + len(v) / 2, f"segment {s}"))
        lo += len(v) + 14

    lo_x = min(-0.02, float(vals.min()) - 0.03)
    hi_x = float(vals.max()) + 0.06

    # Segment names as y-tick labels, so matplotlib places them OUTSIDE the
    # axes. Drawing them inside with ax.text put them on top of the bars.
    ax.set_yticks([y for y, _ in labels])
    ax.set_yticklabels([t for _, t in labels])

    mean = vals.mean()
    ax.axvline(mean, color=RED, linewidth=2, linestyle="--")
    ax.text(mean, -lo * 0.055, f"mean {mean:.3f}", color=RED, fontsize=9,
            va="top", ha="left")
    ax.axvline(0, color=INK_2, linewidth=1)
    ax.set_ylim(-lo * 0.085, lo)
    ax.set_xlim(lo_x, hi_x)
    ax.xaxis.grid(True, color=GRID, linewidth=1)
    ax.set_axisbelow(True)
    style(ax, "How well-formed is each segment?",
          "silhouette per LGA  ·  near zero = sits on a boundary  ·  "
          "below zero = closer to another segment")
    fig.tight_layout()
    fig.savefig(REPORTS / "segment_silhouette.png", dpi=170, facecolor=SURFACE)
    plt.close(fig)
    print("  segment_silhouette.png")
    n_neg = int((vals < 0).sum())
    print(f"  {n_neg} of {len(vals)} LGAs ({100*n_neg/len(vals):.1f}%) have a "
          f"negative silhouette -- they sit closer to a segment other than "
          f"their own. Report that number; do not hide it.")


def main():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size": 9, "figure.facecolor": SURFACE,
                         "text.color": INK, "axes.labelcolor": INK_2})

    REPORTS.mkdir(exist_ok=True)
    df = load()
    print("\nWriting figures:")
    fingerprint(df, plt)
    maps(df, plt)
    scale(df, plt)
    silhouette(df, plt)
    print(f"\nAll figures in {REPORTS.relative_to(ROOT)}/")


if __name__ == "__main__":
    main()
