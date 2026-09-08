"""
Stage 2 visuals: what the five segments look like.

Run from the project root, after pipeline/cluster.py:
    python pipeline/visualise.py

Reads  : lga_segments_named (the view built by sql/09_segment_names.sql),
         cluster_features, data/raw/nga_admin2.shp
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


NUMBERING
---------
Nothing in this file knows what a segment is called, and nothing in it decides
what order they come in. Both are read from `segment_names` through the
`lga_segments_named` view, which sql/09_segment_names.sql builds. The raw
scikit-learn labels (seg_kmeans 0-4) never appear on a figure -- they are an
accident of centroid initialisation and mean nothing to a reader.

That is the whole point of the lookup table: if a name changes, it changes in
one row of one table, and every figure here follows on the next run. If you
find yourself typing a segment name into this file, stop -- the table is the
place.
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
            SELECT n.lga_pcode, n.lga_name, n.state_name, n.gep_flag,
                   n.seg_kmeans,          -- carried for traceability, never plotted
                   n.display_order, n.segment_name, n.is_offgrid_market,
                   f.elec_rate_2020, f.demand_kwh_per_capita, f.poverty_rate,
                   f.travel_hours, f.mv_line_dist_km, f.pct_grid_new_2030,
                   f.settled_density, f.unserved_pop_2020, f.gep_pop_2020
            FROM lga_segments_named n
            JOIN cluster_features f ON f.lga_pcode = n.lga_pcode
        """, con)
    except Exception as exc:
        sys.exit(f"Could not read lga_segments_named / cluster_features: {exc}\n"
                 f"\nIf the view is missing, the naming layer has not been built.\n"
                 f"Open sql/09_segment_names.sql in DB Browser, Execute All,\n"
                 f"then WRITE CHANGES -- the last step is the one that persists it.")
    finally:
        con.close()

    # Every LGA must have been named. A silent left-join hole here would
    # quietly drop LGAs from every figure, so refuse to draw anything.
    missing = df["segment_name"].isna().sum()
    if missing:
        sys.exit(f"{missing} LGAs have no segment name. Re-run "
                 f"sql/09_segment_names.sql.")

    print(f"Loaded {len(df)} LGAs in {df.display_order.nunique()} segments.")
    print("Naming read from segment_names (cluster label -> display order):")
    for _, r in (df.drop_duplicates("display_order")
                   .sort_values("display_order").iterrows()):
        mark = "off-grid market" if r.is_offgrid_market else ""
        print(f"  seg_kmeans {r.seg_kmeans}  ->  {int(r.display_order)}  "
              f"{r.segment_name:<24} {mark}")
    return df


def seg_labels(df) -> tuple[list, dict, dict]:
    """display orders 1..k, and the name / off-grid flag for each."""
    u = df.drop_duplicates("display_order").sort_values("display_order")
    orders = [int(o) for o in u["display_order"]]
    names = {int(r.display_order): r.segment_name for _, r in u.iterrows()}
    offgrid = {int(r.display_order): bool(r.is_offgrid_market)
               for _, r in u.iterrows()}
    return orders, names, offgrid


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
    orders, names, _ = seg_labels(df)
    z = ((df.groupby("display_order")[FEATURES].mean() - df[FEATURES].mean())
         / df[FEATURES].std())
    z = z.loc[orders, FEATURES]   # row 0 is display order 1, at the top

    fig, ax = plt.subplots(figsize=(9.5, 4.2), facecolor=SURFACE)
    lim = float(np.abs(z.values).max())
    from matplotlib.colors import LinearSegmentedColormap
    cmap = LinearSegmentedColormap.from_list("div", [BLUE, MID, RED])
    im = ax.imshow(z.values, cmap=cmap, vmin=-lim, vmax=lim, aspect="auto")

    ax.set_xticks(range(len(FEATURES)))
    ax.set_xticklabels([NICE[f] for f in FEATURES], rotation=28, ha="right")
    ax.set_yticks(range(len(z)))
    ax.set_yticklabels(
        [f"{o}  {names[o]}   n={(df.display_order == o).sum()}" for o in z.index],
        fontsize=8.5)

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
    gdf = gdf.merge(df[["lga_pcode", "display_order"]],
                    left_on=pcode_col, right_on="lga_pcode", how="left")
    matched = gdf["display_order"].notna().sum()
    print(f"  map: {matched} of {len(gdf)} polygons matched a segment "
          f"({len(gdf) - matched} unmatched -- the LGAs with no clusters)")

    orders, names, offgrid = seg_labels(df)
    fig, axes = plt.subplots(1, len(orders), figsize=(3.1 * len(orders), 4.2),
                             facecolor=SURFACE)
    for ax, o in zip(np.atleast_1d(axes), orders):
        gdf.plot(ax=ax, color=MUTED, edgecolor=SURFACE, linewidth=0.12)
        sub = gdf[gdf["display_order"] == o]
        sub.plot(ax=ax, color=BLUE, edgecolor=SURFACE, linewidth=0.12)
        n = len(sub)
        pop = df.loc[df.display_order == o, "unserved_pop_2020"].sum() / 1e6
        ax.set_title(f"{o}  {names[o]}", color=INK, fontsize=10, loc="left")
        ax.text(0, -0.03, f"{n} LGAs  ·  {pop:.1f}M unserved",
                transform=ax.transAxes, color=INK_2, fontsize=8.5, va="top")
        if offgrid[o]:
            ax.text(0, -0.09, "off-grid market", transform=ax.transAxes,
                    color=BLUE, fontsize=8.5, va="top", weight="bold")
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
    _, names, _ = seg_labels(df)
    # Sorted by magnitude, not by display order: this chart's job is size.
    # Showing the display number alongside lets the reader see how the two
    # orderings differ -- segment 2 is second in priority and fourth in size,
    # which is the argument of the whole deliverable in one glance.
    g = (df.groupby("display_order")
           .agg(lgas=("lga_pcode", "size"),
                unserved=("unserved_pop_2020", "sum"))
           .sort_values("unserved"))
    fig, ax = plt.subplots(figsize=(8.4, 3.4), facecolor=SURFACE)
    y = np.arange(len(g))
    ax.barh(y, g["unserved"] / 1e6, height=0.62, color=BLUE_RAMP[4])
    ax.set_yticks(y)
    ax.set_yticklabels([f"{int(o)}  {names[int(o)]}" for o in g.index],
                       fontsize=8.5)
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
    # Silhouette is computed on the CLUSTER labels, not the display order --
    # renumbering is cosmetic and must not touch the geometry. Grouping for
    # the figure then uses display order.
    vals = silhouette_samples(Xs, df["seg_kmeans"].values)

    fig, ax = plt.subplots(figsize=(8.4, 4.4), facecolor=SURFACE)
    orders, names, _ = seg_labels(df)
    lo, labels = 0, []
    # Reversed, because matplotlib's y axis grows upward: this puts
    # display order 1 at the TOP, matching every other figure.
    for o in reversed(orders):
        v = np.sort(vals[df.display_order.values == o])
        ax.barh(np.arange(lo, lo + len(v)), v, height=1.0, color=BLUE_RAMP[4])
        labels.append((lo + len(v) / 2, f"{o}  {names[o]}"))
        lo += len(v) + 14

    lo_x = min(-0.02, float(vals.min()) - 0.03)
    hi_x = float(vals.max()) + 0.06

    # Segment names as y-tick labels, so matplotlib places them OUTSIDE the
    # axes. Drawing them inside with ax.text put them on top of the bars.
    ax.set_yticks([y for y, _ in labels])
    ax.set_yticklabels([t for _, t in labels], fontsize=8.5)

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
